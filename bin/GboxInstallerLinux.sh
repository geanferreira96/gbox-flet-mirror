#!/usr/bin/env bash
set -euo pipefail

URL=""
TARGET_DIR=""
TARGET_PID=""
MIRROR_URL="https://raw.githubusercontent.com/geanferreira96/gbox-flet-mirror/main/docs/update.json"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/gbox/updater.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >> "$LOG_FILE"
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
  python3 - "$key" <<'PY'
import json,sys
key = sys.argv[1]
try:
    data = json.load(sys.stdin)
    value = data.get(key, "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")
PY
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
  trap 'rm -f "$tmp_zip"; rm -rf "$tmp_extract"' RETURN

  log "Downloading package: $URL"
  curl -fL "$URL" -o "$tmp_zip"

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
    nohup "$executable" >/dev/null 2>&1 &
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
