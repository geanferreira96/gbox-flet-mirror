const updateJsonPath = "update.json";

const themeBtn = document.getElementById("theme-toggle");
const sunIcon = document.getElementById("sun-icon");
const moonIcon = document.getElementById("moon-icon");
const body = document.body;

function setTheme(theme) {
  body.setAttribute("data-theme", theme);
  const dark = theme === "dark";
  sunIcon.style.display = dark ? "none" : "block";
  moonIcon.style.display = dark ? "block" : "none";
  localStorage.setItem("theme", theme);
}

themeBtn.addEventListener("click", () => {
  const current = body.getAttribute("data-theme") || "light";
  setTheme(current === "dark" ? "light" : "dark");
});

const savedTheme =
  localStorage.getItem("theme") ||
  (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
setTheme(savedTheme);

function updateBtn(btn, url, labelWhenOk, labelIsHtml = false) {
  if (!url || url === "#") {
    btn.classList.add("disabled");
    btn.textContent = "Indisponível no momento";
    btn.removeAttribute("href");
    return;
  }
  btn.classList.remove("disabled");
  if (labelWhenOk) {
    if (labelIsHtml) {
      btn.innerHTML = labelWhenOk;
    } else {
      btn.textContent = labelWhenOk;
    }
  }
  btn.href = url;
}

async function loadUpdateInfo() {
  try {
    const response = await fetch(updateJsonPath, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();

    document.getElementById("current-version").textContent = data.version || "Indisponível";
    document.getElementById("version-win").textContent =
      data.win_version || data.version || "Indisponível";
    document.getElementById("version-linux").textContent =
      data.linux_version || data.version || "Indisponível";
    document.getElementById("version-android-x64").textContent =
      data.android_x64_version || data.android_arm64_v8a_version || data.version || "Indisponível";
    document.getElementById("version-android-x86").textContent =
      data.android_x86_version || data.android_armeabi_v7a_version || data.version || "Indisponível";

    const rawDate = data.updated_at || data.lastUpdate || "";
    let updateText = "Indisponível";
    if (rawDate) {
      const dt = new Date(rawDate);
      updateText = Number.isNaN(dt.getTime()) ? rawDate : dt.toLocaleString("pt-BR");
    }
    document.getElementById("last-update").textContent = updateText;
    document.getElementById("compiler").textContent = data.compiler || "Indisponível";

    // Chaves alinhadas ao build-executables.yml (bloco Python que grava update.json).
    updateBtn(
      document.getElementById("win-installer-link"),
      data.win_installer_url || data.installer_url || "",
      "Baixar Instalador Windows (.exe)"
    );
    updateBtn(
      document.getElementById("linux-installer-link"),
      data.linux_installer_url || "",
      "Baixar Instalador Linux (.deb)"
    );
    // Compatibilidade: prioriza novas chaves (x64/x86), com fallback legadas (arm64-v8a/armeabi-v7a).
    const androidRecommendedUrl =
      data.android_x64_download_url || data.android_arm64_v8a_download_url || "";
    const androidCompatUrl =
      data.android_x86_download_url || data.android_armeabi_v7a_download_url || "";
    updateBtn(
      document.getElementById("android-v8a-link"),
      androidRecommendedUrl,
      '<span class="button-text-main">Android (Celular)</span><span class="button-text-sub">Arquitetura x64/arm64</span>',
      true
    );
    updateBtn(
      document.getElementById("android-v7a-link"),
      androidCompatUrl,
      '<span class="button-text-main">Android (SOL7)</span><span class="button-text-sub">Arquitetura x86/armeabi-v7a</span>',
      true
    );

    const releaseLink = document.getElementById("github-release-link");
    const rel = data.github_release || "https://github.com/geanferreira96/gbox-flet-mirror/releases/latest";
    releaseLink.href = rel;
  } catch (error) {
    console.error("Erro ao carregar update.json:", error);
    document.getElementById("current-version").textContent = "Erro ao carregar";
    document.getElementById("version-win").textContent = "Erro ao carregar";
    document.getElementById("version-linux").textContent = "Erro ao carregar";
    document.getElementById("version-android-x64").textContent = "Erro ao carregar";
    document.getElementById("version-android-x86").textContent = "Erro ao carregar";
    document.getElementById("last-update").textContent = "Erro ao carregar";
    document.getElementById("compiler").textContent = "Erro ao carregar";
    updateBtn(document.getElementById("win-installer-link"), "");
    updateBtn(document.getElementById("linux-installer-link"), "");
    updateBtn(document.getElementById("android-v8a-link"), "");
    updateBtn(document.getElementById("android-v7a-link"), "");
  }
}

loadUpdateInfo();
