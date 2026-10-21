# RoTheme: custom themes for roblox.com

A Chrome / Edge / Brave / Opera extension (Manifest V3) that reskins the Roblox website and tracks your per-game playtime.

## Themes

| Theme | Look |
| --- | --- |
| **Actually Classic** | 2008–2012 site: glossy blue bar, white boxes, grey borders, square corners, green Play button |
| **Frutiger Aero** | Sky and grass gradient, frosted glass panels, glossy aqua pill buttons, floating bubbles |
| **2016 Roblox** | The first flat redesign: blue header, light grey page, Source Sans |
| **2020 Roblox** | The dark theme from the Discover / Avatar Shop era |
| **Vaporwave** | Neon pink and cyan, sunset gradient, moving retro grid |
| **Midnight OLED** | True black with a purple accent |
| **Terminal** | Green phosphor monospace, green-tinted thumbnails, CRT scanlines |
| **Bubblegum** | Pastel pink and mint, extra-round corners |

On the retro themes, "Era-accurate wording" also renames the nav links: Charts becomes Games, Marketplace becomes Catalog or Avatar Shop, and Communities becomes Groups.

## Playtime tracker

While you're signed in to roblox.com in the same browser, the extension checks your Roblox presence once a minute. When you're in a game, it adds the time to that game. It works with the desktop client because it reads your presence, not the browser tab.

- The **Playtime** tab in the popup shows total time, game count and sessions. You can sort by most played, recently played or most sessions.
- Game pages show a badge under the title, for example "You've played 12h 4m • 31 sessions • last played 2 hours ago".
- The extension icon shows a green ▶ while you're in a game.
- You can export your data as JSON or reset it from **Settings**.

Time is counted in roughly one-minute steps, so very short sessions may count as 0m. Data is stored only in your browser (`chrome.storage.local`) and is never sent anywhere except Roblox's own APIs.

## Other settings

- **Animated effects**: turn the bubbles, grid and scanlines on or off.
- **Hide sponsored rows**: removes "Sponsored" carousels and ad slots.

## Install (unpacked)

1. Download or clone this repo.
2. Go to `chrome://extensions` (or `edge://extensions`) and turn on **Developer mode**.
3. Click **Load unpacked** and pick the `roblox-themes` folder.
4. Pin RoTheme, open roblox.com and pick a theme.

## How it works / tweaking

- `themes/base.css` holds every rule, keyed off `--rx-*` CSS variables. It only applies when `<html data-rbxt="...">` is set.
- Each `themes/<name>.css` file sets those variables and adds its own extras. To add a theme, copy one, change the colours, add it to `manifest.json` and to the `THEMES` list in `popup/popup.js`.
- `content.js` sets the theme attribute, renames the nav links, hides sponsored rows and adds the playtime badge.
- `background.js` polls `users.roblox.com` and `presence.roblox.com` and stores the playtime.

Roblox changes its site markup often. If a part of the page stops getting themed, find its class in DevTools and add it to the right selector list in `themes/base.css`.
