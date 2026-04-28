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

function updateBtn(btn, url) {
  if (!url || url === "#") {
    btn.classList.add("disabled");
    btn.textContent = "Indisponível no momento";
    btn.removeAttribute("href");
    return;
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

    const rawDate = data.updated_at || data.lastUpdate || "";
    let updateText = "Indisponível";
    if (rawDate) {
      const dt = new Date(rawDate);
      updateText = Number.isNaN(dt.getTime()) ? rawDate : dt.toLocaleString("pt-BR");
    }
    document.getElementById("last-update").textContent = updateText;
    document.getElementById("compiler").textContent = data.compiler || "Indisponível";

    // Prioridade para as chaves de instalador do mirror.
    updateBtn(
      document.getElementById("win-installer-link"),
      data.win_installer_url || data.installer_url || ""
    );
    updateBtn(document.getElementById("linux-installer-link"), data.linux_installer_url || "");

    const releaseLink = document.getElementById("github-release-link");
    const rel = data.github_release || "https://github.com/geanferreira96/gbox-flet-mirror/releases/latest";
    releaseLink.href = rel;
  } catch (error) {
    console.error("Erro ao carregar update.json:", error);
    document.getElementById("current-version").textContent = "Erro ao carregar";
    document.getElementById("last-update").textContent = "Erro ao carregar";
    document.getElementById("compiler").textContent = "Erro ao carregar";
    updateBtn(document.getElementById("win-installer-link"), "");
    updateBtn(document.getElementById("linux-installer-link"), "");
  }
}

loadUpdateInfo();
