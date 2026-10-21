// RoTheme background worker: tracks per-game playtime by polling your Roblox presence once a minute.

const POLL_ALARM = "rbxt-poll";
const MAX_GAP_SECONDS = 180; // never credit more than this between two polls (sleep, offline, etc.)

const DEFAULTS = {
  theme: "aero",
  effects: true,
  retroWords: true,
  hideSponsored: false,
  showPlaytime: true,
};

function ensureAlarm() {
  chrome.alarms.get(POLL_ALARM, (alarm) => {
    if (!alarm) chrome.alarms.create(POLL_ALARM, { periodInMinutes: 1 });
  });
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.sync.get(DEFAULTS, (s) => chrome.storage.sync.set(s));
  ensureAlarm();
  poll();
});
chrome.runtime.onStartup.addListener(ensureAlarm);
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === POLL_ALARM) poll();
});

// ---------- Roblox API helpers ----------

let csrfToken = "";

async function rbxFetch(url, options = {}) {
  const opts = {
    credentials: "include",
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  };
  if (opts.method && opts.method !== "GET" && csrfToken) opts.headers["x-csrf-token"] = csrfToken;
  let res = await fetch(url, opts);
  // Roblox answers the first POST with 403 + a fresh CSRF token; retry once with it.
  if (res.status === 403 && res.headers.get("x-csrf-token")) {
    csrfToken = res.headers.get("x-csrf-token");
    opts.headers["x-csrf-token"] = csrfToken;
    res = await fetch(url, opts);
  }
  return res;
}

async function getJson(url, options) {
  try {
    const res = await rbxFetch(url, options);
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
}

const getMe = () => getJson("https://users.roblox.com/v1/users/authenticated");

async function getPresence(userId) {
  const data = await getJson("https://presence.roblox.com/v1/presence/users", {
    method: "POST",
    body: JSON.stringify({ userIds: [userId] }),
  });
  return data?.userPresences?.[0] || null;
}

async function getGameInfo(universeId) {
  const [games, icons] = await Promise.all([
    getJson(`https://games.roblox.com/v1/games?universeIds=${universeId}`),
    getJson(`https://thumbnails.roblox.com/v1/games/icons?universeIds=${universeId}&size=150x150&format=Png&isCircular=false`),
  ]);
  return {
    name: games?.data?.[0]?.name,
    rootPlaceId: games?.data?.[0]?.rootPlaceId,
    icon: icons?.data?.[0]?.imageUrl,
  };
}

// ---------- Tracking ----------

const store = {
  get: (keys) => chrome.storage.local.get(keys),
  set: (obj) => chrome.storage.local.set(obj),
};

let polling = false;

async function poll() {
  if (polling) return;
  polling = true;
  try {
    await pollOnce();
  } finally {
    polling = false;
  }
}

async function pollOnce() {
  const now = Date.now();
  const { tracker = {}, playtime = {} } = await store.get(["tracker", "playtime"]);

  const me = await getMe();
  if (!me) {
    await store.set({ tracker: { lastPoll: now, current: null, user: null, status: "signed-out" } });
    chrome.action.setBadgeText({ text: "" });
    return;
  }

  const presence = await getPresence(me.id);
  // userPresenceType: 0 offline, 1 online (website), 2 in game, 3 in Studio
  const inGame = presence && presence.userPresenceType === 2 && presence.universeId;
  const user = { id: me.id, name: me.name, displayName: me.displayName };

  if (!inGame) {
    await store.set({ tracker: { lastPoll: now, current: null, user, status: presence ? "online" : "unknown" } });
    chrome.action.setBadgeText({ text: "" });
    return;
  }

  const uid = String(presence.universeId);
  const entry = (playtime[uid] ||= {
    universeId: uid,
    name: presence.lastLocation || "Unknown experience",
    placeId: presence.rootPlaceId || presence.placeId || null,
    seconds: 0,
    sessions: 0,
    firstPlayed: now,
  });

  if (tracker.current === uid && tracker.lastPoll) {
    entry.seconds += Math.min((now - tracker.lastPoll) / 1000, MAX_GAP_SECONDS);
  } else {
    entry.sessions += 1;
  }
  entry.lastPlayed = now;

  if (!entry.icon || entry.name === "Unknown experience") {
    const info = await getGameInfo(uid);
    if (info.name) entry.name = info.name;
    if (info.rootPlaceId) entry.placeId = info.rootPlaceId;
    if (info.icon) entry.icon = info.icon;
  }

  await store.set({
    playtime,
    tracker: { lastPoll: now, current: uid, currentName: entry.name, user, status: "in-game" },
  });
  chrome.action.setBadgeBackgroundColor({ color: "#00b06f" });
  chrome.action.setBadgeText({ text: "▶" });
}

// ---------- Messages from the popup / content script ----------

async function findEntryForPlace(placeId) {
  const { playtime = {} } = await store.get("playtime");
  const direct = Object.values(playtime).find((e) => String(e.placeId) === String(placeId));
  if (direct) return direct;
  const res = await getJson(`https://apis.roblox.com/universes/v1/places/${placeId}/universe`);
  return (res?.universeId && playtime[String(res.universeId)]) || null;
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type === "getPlaytimeForPlace") {
    findEntryForPlace(msg.placeId).then((entry) => sendResponse({ entry }));
    return true;
  }
  if (msg?.type === "pollNow") {
    poll().then(() => sendResponse({ ok: true }));
    return true;
  }
  if (msg?.type === "resetPlaytime") {
    store.set({ playtime: {}, tracker: {} }).then(() => sendResponse({ ok: true }));
    return true;
  }
});
