const DEFAULTS = {
  theme: "aero",
  effects: true,
  retroWords: true,
  hideSponsored: false,
  showPlaytime: true,
};

// bar, page bg, card, play button
const THEMES = [
  { id: "classic", name: "Actually Classic", desc: "2008–2012 blue bar & boxes", colors: ["linear-gradient(#4a9de5,#0b5cad)", "#e8e8e8", "#fff", "linear-gradient(#8fd36b,#3c9a1a)"] },
  { id: "aero", name: "Frutiger Aero", desc: "Glossy glass, sky & bubbles", colors: ["linear-gradient(#fff,#a0d6f5)", "linear-gradient(#2b9fe0,#d8f3ff 70%,#b6ea9a)", "rgba(255,255,255,.55)", "linear-gradient(#d6ffb8,#3fae12)"] },
  { id: "2016", name: "2016 Roblox", desc: "Flat blue light site", colors: ["#00a2ff", "#e3e3e3", "#fff", "#02b757"] },
  { id: "2020", name: "2020 Roblox", desc: "Avatar Shop-era dark", colors: ["#191b1d", "#232527", "#393b3d", "#00b06f"] },
  { id: "vaporwave", name: "Vaporwave", desc: "Neon sunset & grid", colors: ["linear-gradient(90deg,#ff71ce,#01cdfe)", "linear-gradient(#12002b,#b3266e,#ff8a5c)", "rgba(30,6,60,.8)", "linear-gradient(90deg,#01cdfe,#05ffa1)"] },
  { id: "midnight", name: "Midnight OLED", desc: "True black + purple", colors: ["#000", "#000", "#17171c", "#7c3aed"] },
  { id: "terminal", name: "Terminal", desc: "Green phosphor CRT", colors: ["#010601", "#020a02", "#072407", "#33ff66"] },
  { id: "bubblegum", name: "Bubblegum", desc: "Pastel pink & mint", colors: ["linear-gradient(90deg,#ff9cc6,#ffc1a1)", "linear-gradient(135deg,#ffe3ef,#e3fff4)", "#fff", "#3ccf9b"] },
  { id: "off", name: "Off", desc: "Default Roblox look", colors: ["#fff", "#f2f4f5", "#fff", "#335fff"] },
];

const $ = (id) => document.getElementById(id);

// ---------- Tabs ----------
document.querySelectorAll(".tab").forEach((tab) =>
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab, .panel").forEach((el) => el.classList.remove("active"));
    tab.classList.add("active");
    $(tab.dataset.tab).classList.add("active");
    if (tab.dataset.tab === "playtime") chrome.runtime.sendMessage({ type: "pollNow" }, renderPlaytime);
  })
);

// ---------- Themes ----------
function renderThemes(current) {
  const grid = $("theme-grid");
  grid.innerHTML = "";
  for (const t of THEMES) {
    const [bar, bg, card, play] = t.colors;
    const btn = document.createElement("button");
    btn.className = "theme" + (t.id === current ? " selected" : "");
    btn.innerHTML = `
      <div class="preview" style="background:${bg}">
        <div class="bar" style="background:${bar}"></div>
        <div class="card" style="background:${card}"></div>
        <div class="card" style="background:${card}"></div>
        <div class="card" style="background:${card}"></div>
        <div class="play" style="background:${play}"></div>
      </div>
      <span class="name">${t.name}</span>
      <span class="desc">${t.desc}</span>`;
    btn.addEventListener("click", () => {
      chrome.storage.sync.set({ theme: t.id });
      renderThemes(t.id);
    });
    grid.appendChild(btn);
  }
}

// ---------- Settings ----------
const TOGGLES = ["effects", "retroWords", "showPlaytime", "hideSponsored"];

chrome.storage.sync.get(DEFAULTS, (s) => {
  renderThemes(s.theme);
  for (const key of TOGGLES) {
    $(key).checked = s[key];
    $(key).addEventListener("change", (e) => chrome.storage.sync.set({ [key]: e.target.checked }));
  }
});

$("reset").addEventListener("click", () => {
  if (!confirm("Delete all tracked playtime? This can't be undone.")) return;
  chrome.runtime.sendMessage({ type: "resetPlaytime" }, renderPlaytime);
});

$("export").addEventListener("click", async () => {
  const { playtime = {} } = await chrome.storage.local.get("playtime");
  const blob = new Blob([JSON.stringify(playtime, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "rotheme-playtime.json";
  a.click();
});

// ---------- Playtime ----------
function formatDuration(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m`;
  return seconds > 0 ? "<1m" : "0m";
}

function timeAgo(ts) {
  const diff = (Date.now() - ts) / 1000;
  if (diff < 120) return "just now";
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

async function renderPlaytime() {
  const { playtime = {}, tracker = {} } = await chrome.storage.local.get(["playtime", "tracker"]);
  const games = Object.values(playtime);
  const sortKey = $("sort").value;
  games.sort((a, b) => (b[sortKey] || 0) - (a[sortKey] || 0));

  const status = $("status");
  status.classList.toggle("live", tracker.status === "in-game");
  status.textContent =
    tracker.status === "in-game" ? `● Playing ${tracker.currentName} — tracking now`
    : tracker.status === "signed-out" ? "Not signed in to roblox.com in this browser — sign in to track playtime."
    : tracker.user ? `Tracking ${tracker.user.displayName} (@${tracker.user.name}) — not in a game right now.`
    : "Checking…";

  $("total-time").textContent = formatDuration(games.reduce((n, g) => n + g.seconds, 0));
  $("total-games").textContent = games.length;
  $("total-sessions").textContent = games.reduce((n, g) => n + g.sessions, 0);
  $("empty").style.display = games.length ? "none" : "block";

  const max = Math.max(1, ...games.map((g) => g.seconds));
  $("game-list").innerHTML = games
    .map((g) => {
      const link = g.placeId ? `https://www.roblox.com/games/${g.placeId}` : "#";
      const icon = g.icon ? `<img src="${escapeHtml(g.icon)}" alt="">` : `<div class="noicon"></div>`;
      return `<li class="game">
        ${icon}
        <div>
          <a href="${link}" target="_blank" title="${escapeHtml(g.name)}">${escapeHtml(g.name)}</a>
          <div class="meta">${g.sessions} session${g.sessions === 1 ? "" : "s"} · ${timeAgo(g.lastPlayed)}</div>
          <div class="bar" style="width:${Math.max(4, (g.seconds / max) * 100)}%"></div>
        </div>
        <div class="time">${formatDuration(g.seconds)}</div>
      </li>`;
    })
    .join("");
}

$("sort").addEventListener("change", renderPlaytime);
chrome.storage.onChanged.addListener((_changes, area) => area === "local" && renderPlaytime());
renderPlaytime();
