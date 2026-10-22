# Umbral Sovereign (Roblox)

A purple aura (1 in 2,500,000,000, during Eclipse) built in the style of Sol's RNG's rarest auras. It is made only from Parts, Highlights, Beams, Trails, ParticleEmitters and Surface/Billboard GUIs. The particle textures come with the Roblox client, so there is nothing to upload or get moderated.

| File | What it is |
| --- | --- |
| `UmbralSovereign.rbxl` | Open in Studio and press Play. You get the roll cutscene, then the aura on your character and on a showcase dummy. |
| `UmbralAura.luau` | ModuleScript that builds and animates the aura on one character. |
| `UmbralCutscene.luau` | ModuleScript for the roll cutscene, the Aura Collection panel and the buttons. |
| `AuraClient.client.luau` | LocalScript that draws the aura on every model with `Aura = "Umbral Sovereign"` and runs the cutscene, Eclipse lighting and camera punch. |
| `AuraServer.server.luau` | Script that gives every character the aura. Swap it for your own roll logic. |
| `build.luau` | Runs the aura and the cutscene headlessly, then rebuilds the place: `lune run roblox/UmbralSovereign/build.luau` (Lune 0.8.9). |

## Layers

- **Event-horizon core**: a black sphere with a Highlight rim, a photon-ring billboard, a tilted accretion disk with a sweeping gradient, a sky jet beam and particles falling inward.
- **Rune circles**: three ground circles turning in opposite directions plus a camera-facing sigil halo behind the core. The runes are generated from GUI strokes.
- **Barrier**: a ForceField dome with lightning crawling over it.
- **3 plasma orbs**: void spheres with trails and sparks that orbit the player, with lightning tethered to the core.
- **More effects**: spiral energy trails, obsidian shards, a floating crown, rising motes, twinkling stars, black smoke and wisps at the feet.
- **Heartbeat pulse** about every 3.4 s: a ground shockwave, an expanding shell, lightning striking the ground, a spark burst and a small camera shake.
- **Name tag**: the rarity and name float above the head, with a short color-split glitch.
- **Eclipse lighting**: Future lighting with a purple atmosphere, bloom and color grading. Press **E** to switch to daylight.

Controls: **R** replays the cutscene, **E** switches the sky, **H** hides the UI. The same actions are on the on-screen buttons.

## Sound

Roblox only plays audio you have the rights to, so the place ships silent. Paste asset ids (`rbxassetid://…`) into these attributes on `ReplicatedStorage.UmbralSovereign`:
`MusicSoundId`, `ImpactSoundId`, `HeartbeatSoundId`, `PulseSoundId`.

## Using it in your game

1. Copy `ReplicatedStorage.UmbralSovereign` and `StarterPlayerScripts.AuraClient` into your game.
2. When a player rolls it, set the attribute on their character model: `character:SetAttribute("Aura", "Umbral Sovereign")`. Set it to anything else to remove the aura.
3. Copy the Lighting effects (Atmosphere, Bloom, ColorCorrection) if you want the eclipse look. Without them the aura still works, but it glows less.
