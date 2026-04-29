#!/usr/bin/env bash
set -euo pipefail

URL=""
TARGET_DIR=""
TARGET_PID=""
MIRROR_URL="https://raw.githubusercontent.com/geanferreira96/gbox-flet-mirror/main/docs/update.json"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/gbox/updater.log"
APP_LAUNCH_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/gbox/app_launch.log"
DOWNLOAD_CHUNK_SIZE_MB="${DOWNLOAD_CHUNK_SIZE_MB:-1}"
DOWNLOAD_CONNECTIONS="${DOWNLOAD_CONNECTIONS:-8}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  local line
  line="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1"
  printf '%s\n' "$line" >> "$LOG_FILE"
  printf '%s\n' "$line"
}

usage() {
  echo "Usage:"
  echo "  $0 --url <zip_url> --dir <target_dir> [--target-pid <pid>]"
  echo "  $0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      URL="${2:-}"
      shift 2
      ;;
    --dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    --target-pid)
      TARGET_PID="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Ignoring unknown argument: $1"
      shift
      ;;
  esac
done

pick_json_value() {
  local key="$1"
  python3 -c '
import json,sys
key = sys.argv[1]
try:
    data = json.load(sys.stdin)
    value = data.get(key, "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")
' "$key"
}

resolve_default_url() {
  if ! command -v curl >/dev/null 2>&1; then
    return 1
  fi
  local meta
  meta="$(curl -fsSL "$MIRROR_URL" || true)"
  [[ -n "$meta" ]] || return 1
  local chosen
  chosen="$(printf '%s' "$meta" | pick_json_value "linux_pyinstaller_download_url")"
  if [[ -z "$chosen" ]]; then
    chosen="$(printf '%s' "$meta" | pick_json_value "linux_nuitka_download_url")"
  fi
  if [[ -z "$chosen" ]]; then
    chosen="$(printf '%s' "$meta" | pick_json_value "pyinstaller_download_url")"
  fi
  if [[ -z "$chosen" ]]; then
    chosen="$(printf '%s' "$meta" | pick_json_value "nuitka_download_url")"
  fi
  [[ -n "$chosen" ]] || return 1
  URL="$chosen"
  return 0
}

stop_target_process() {
  if [[ -n "$TARGET_PID" ]] && kill -0 "$TARGET_PID" >/dev/null 2>&1; then
    log "Stopping process PID=$TARGET_PID"
    kill -TERM "$TARGET_PID" >/dev/null 2>&1 || true
    sleep 1
    kill -KILL "$TARGET_PID" >/dev/null 2>&1 || true
  fi
}

install_update() {
  local tmp_zip tmp_extract source_dir
  tmp_zip="$(mktemp /tmp/gbox_update_XXXXXX.zip)"
  tmp_extract="$(mktemp -d /tmp/gbox_extract_XXXXXX)"
  trap 'rm -f "${tmp_zip:-}"; rm -rf "${tmp_extract:-}"' RETURN

  log "Downloading package: $URL (chunk=${DOWNLOAD_CHUNK_SIZE_MB}MB, connections=${DOWNLOAD_CONNECTIONS})"
  if command -v aria2c >/dev/null 2>&1; then
    log "Using aria2c parallel downloader."
    aria2c \
      --file-allocation=none \
      --max-connection-per-server="${DOWNLOAD_CONNECTIONS}" \
      --split="${DOWNLOAD_CONNECTIONS}" \
      --min-split-size=1M \
      --summary-interval=1 \
      --allow-overwrite=true \
      --out="$(basename "$tmp_zip")" \
      --dir="$(dirname "$tmp_zip")" \
      "$URL"
  elif ! python3 - "$URL" "$tmp_zip" "$DOWNLOAD_CHUNK_SIZE_MB" <<'PY'
import sys
import urllib.request

url = sys.argv[1]
out = sys.argv[2]
chunk_mb = int(sys.argv[3])
chunk_size = max(1024 * 1024, chunk_mb * 1024 * 1024)
downloaded = 0
last_report = -1

with urllib.request.urlopen(url, timeout=60) as r, open(out, "wb") as f:
    total = int(r.headers.get("Content-Length", "0") or "0")
    while True:
        chunk = r.read(chunk_size)
        if not chunk:
            break
        f.write(chunk)
        downloaded += len(chunk)
        if total > 0:
            pct = int((downloaded * 100) / total)
            if pct != last_report:
                print(f"[download] {pct}% ({downloaded}/{total} bytes)", flush=True)
                last_report = pct
    if total == 0:
        print(f"[download] completed ({downloaded} bytes)", flush=True)
    elif last_report < 100:
        print(f"[download] 100% ({downloaded}/{total} bytes)", flush=True)
PY
  then
    log "Python downloader failed, falling back to curl."
    curl -fL --progress-bar "$URL" -o "$tmp_zip"
    printf '\n'
  fi

  log "Extracting package"
  mkdir -p "$tmp_extract"
  unzip -oq "$tmp_zip" -d "$tmp_extract"

  source_dir="$tmp_extract"
  if [[ "$(find "$tmp_extract" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]]; then
    source_dir="$(find "$tmp_extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  fi

  mkdir -p "$TARGET_DIR"
  log "Cleaning target dir: $TARGET_DIR"
  find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

  log "Copying new files"
  cp -a "$source_dir"/. "$TARGET_DIR"/

  local executable=""
  if [[ -x "$TARGET_DIR/Gbox" ]]; then
    executable="$TARGET_DIR/Gbox"
  elif [[ -x "$TARGET_DIR/main.bin" ]]; then
    executable="$TARGET_DIR/main.bin"
  else
    executable="$(find "$TARGET_DIR" -maxdepth 1 -type f -perm -111 | head -n 1 || true)"
  fi

  if [[ -n "$executable" ]]; then
    log "Starting updated app: $executable"
    mkdir -p "$(dirname "$APP_LAUNCH_LOG")"
    nohup bash -c "cd \"$TARGET_DIR\" && \"$executable\"" >> "$APP_LAUNCH_LOG" 2>&1 &
    local app_pid=$!
    sleep 2
    if kill -0 "$app_pid" >/dev/null 2>&1; then
      log "App started successfully (pid=$app_pid)."
    else
      log "App process exited early. Check launch log: $APP_LAUNCH_LOG"
    fi
  else
    log "No executable found after update."
  fi
}

main() {
  log "Updater started"

  if [[ -z "$URL" ]]; then
    resolve_default_url || {
      log "Unable to resolve linux download URL from metadata."
      echo "Erro: nao foi possivel obter URL de download do Linux." >&2
      exit 1
    }
    log "Installer mode: URL resolved from metadata."
  fi

  if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="${HOME}/.local/share/Gbox"
  fi

  stop_target_process
  install_update
  log "Updater finished"
}

main "$@"
