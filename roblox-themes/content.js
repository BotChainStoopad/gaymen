// RoTheme content script: applies the chosen theme and page tweaks to roblox.com.

const DEFAULTS = {
  theme: "aero",
  effects: true,
  retroWords: true,
  hideSponsored: false,
  showPlaytime: true,
};

// Nav-label swaps so each era reads like it used to.
const RETRO_WORDS = {
  classic: {
    Home: "Home",
    Charts: "Games",
    Discover: "Games",
    Marketplace: "Catalog",
    "Avatar Shop": "Catalog",
    Create: "Develop",
    Communities: "Groups",
    Robux: "ROBUX",
  },
  "2016": {
    Charts: "Games",
    Discover: "Games",
    Marketplace: "Catalog",
    Communities: "Groups",
  },
  "2020": {
    Charts: "Discover",
    Marketplace: "Avatar Shop",
    Communities: "Groups",
  },
};

const root = document.documentElement;
let settings = { ...DEFAULTS };

function applyTheme() {
  if (settings.theme === "off") delete root.dataset.rbxt;
  else root.dataset.rbxt = settings.theme;
  root.dataset.rbxtFx = settings.effects ? "on" : "off";
}

chrome.storage.sync.get(DEFAULTS, (stored) => {
  settings = stored;
  applyTheme();
  scheduleTweaks();
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== "sync") return;
  for (const key in changes) settings[key] = changes[key].newValue;
  applyTheme();
  scheduleTweaks();
});

// ---------- DOM tweaks (run after load and whenever the page changes) ----------

let tweakTimer = 0;
function scheduleTweaks() {
  clearTimeout(tweakTimer);
  tweakTimer = setTimeout(runTweaks, 150);
}

function runTweaks() {
  if (!document.body) return;
  applyRetroWords();
  applySponsoredFilter();
  if (settings.showPlaytime) injectPlaytime();
  else document.querySelectorAll(".rbxt-playtime").forEach((el) => el.remove());
}

function applyRetroWords() {
  const map = (settings.retroWords && RETRO_WORDS[settings.theme]) || {};
  const leaves = document.querySelectorAll(
    "#header a, #header a *, .rbx-header a, .rbx-header a *, #navigation a, #navigation a *"
  );
  for (const el of leaves) {
    if (el.children.length) continue;
    const original = el.dataset.rbxtOrig ?? el.textContent.trim();
    const wanted = map[original] ?? original;
    if (el.textContent.trim() === wanted) continue;
    if (el.dataset.rbxtOrig === undefined) el.dataset.rbxtOrig = original;
    el.textContent = wanted;
  }
}

function applySponsoredFilter() {
  const headings = document.querySelectorAll(".container-header h2, .container-header h3, h2, h3");
  for (const h of headings) {
    if (!/^\s*sponsored/i.test(h.textContent)) continue;
    const block =
      h.closest(".game-sort-carousel-wrapper, .game-carousel, [data-testid*='carousel'], .container-list") ||
      h.parentElement?.parentElement;
    block?.classList.toggle("rbxt-hidden", settings.hideSponsored);
  }
  document
    .querySelectorAll(".ad, .abp, [id*='Skyscraper'], iframe[src*='/user-sponsorship/']")
    .forEach((el) => el.classList.toggle("rbxt-hidden", settings.hideSponsored));
}

// ---------- Playtime badge on game pages ----------

let playtimeFor = null;
let playtimeData = null;

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
  if (diff < 3600) return `${Math.floor(diff / 60)} minutes ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} hours ago`;
  return `${Math.floor(diff / 86400)} days ago`;
}

function injectPlaytime() {
  const match = location.pathname.match(/^\/games\/(\d+)/);
  if (!match) return;
  const placeId = match[1];

  if (playtimeFor !== placeId) {
    playtimeFor = placeId;
    playtimeData = null;
    chrome.runtime.sendMessage({ type: "getPlaytimeForPlace", placeId }, (res) => {
      if (chrome.runtime.lastError) return;
      playtimeData = res || { entry: null };
      document.querySelectorAll(".rbxt-playtime").forEach((el) => el.remove());
      injectPlaytime();
    });
    return;
  }
  if (!playtimeData || document.querySelector(".rbxt-playtime")) return;

  const title = document.querySelector(".game-title-container .game-name, .game-name, .game-title-container h1, h1");
  if (!title) return;

  const e = playtimeData.entry;
  const badge = document.createElement("div");
  badge.className = "rbxt-playtime";
  badge.innerHTML = e && e.seconds > 0
    ? `⏱ You've played <b>${formatDuration(e.seconds)}</b>
       <span class="rbxt-sep">•</span> ${e.sessions} session${e.sessions === 1 ? "" : "s"}
       <span class="rbxt-sep">•</span> last played ${timeAgo(e.lastPlayed)}`
    : `⏱ No playtime tracked yet — RoTheme will count it next time you play.`;
  title.insertAdjacentElement("afterend", badge);
}

// Refresh the badge every minute so it stays current while you play.
setInterval(() => {
  if (!settings.showPlaytime) return;
  playtimeFor = null;
  document.querySelectorAll(".rbxt-playtime").forEach((el) => el.remove());
  injectPlaytime();
}, 60_000);

new MutationObserver(scheduleTweaks).observe(document.documentElement, { childList: true, subtree: true });
