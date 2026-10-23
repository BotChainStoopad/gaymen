# Hollowmourne (Roblox)

A horror aura (1 in 1,666,666,666, during Blood Moon) inspired by the look of Roblox's spooky events: a blood-red sky and cold blue spectral things. Every design is original, and none of the event's characters are copied. It is made only from Parts, Highlights, Trails, ParticleEmitters and Surface/Billboard GUIs. The particle textures come with the Roblox client, so there is nothing to upload or get moderated.

| File | What it is |
| --- | --- |
| `Hollowmourne.rbxl` | Open in Studio and press Play. You get the roll cutscene, then the aura on your character and on a showcase dummy in a graveyard with tombstones and dead trees. |
| `HollowAura.luau` | ModuleScript that builds and animates the aura on one character. |
| `HollowCutscene.luau` | ModuleScript for the roll cutscene, the Aura Collection panel, the buttons, the heartbeat vignette and the lights-out flicker. |
| `HollowClient.client.luau` | LocalScript that draws the aura on every model with `Aura = "Hollowmourne"` and runs the cutscene, Blood Moon lighting and camera punch. |
| `HollowServer.server.luau` | Script that gives every character the aura. Swap it for your own roll logic. |
| `build.luau` | Runs the aura and the cutscene headlessly, then rebuilds the place: `lune run roblox/Hollowmourne/build.luau` (Lune 0.8.9). |

## Layers

- **3 ghost-fire jack-o'-lanterns** orbit the player. Their glowing carved faces always turn outward, and they have blue flames, trails and blue arcs between them.
- **Floating witch hat** with a glowing blue band.
- **Blood-red cracks** branch out under the player and pulse, inside a ring of 13 candles with blue flames.
- **6 spectral hands** rise out of the ground, close into a grab and sink back down.
- **5 ghost wisps** with hollow eyes and trails, and 10 bats flapping overhead.
- **Particles**: blue and red embers, falling ash, black smoke and blue mist.
- **Red lightning** strikes from the sky every few seconds and lights the ground.
- **Heartbeat** every 3.4 s: a red shockwave, a spark burst, a strike, the screen edges throbbing red and a small camera shake. Every 9–16 s the lights cut out for a moment.
- **Name tag** in a gothic font with a flicker.
- **Blood Moon lighting**: a huge moon and red atmosphere, fog, bloom and grading. Press **E** for a plain baseplate.

Controls: **R** replays the cutscene, **E** switches the sky, **H** hides the UI.

## Sound

The place ships silent. Paste asset ids (`rbxassetid://…`) into these attributes on `ReplicatedStorage.Hollowmourne`:
`MusicSoundId`, `ImpactSoundId`, `HeartbeatSoundId`, `PulseSoundId`, `ThunderSoundId`.

## Using it in your game

1. Copy `ReplicatedStorage.Hollowmourne` and `StarterPlayerScripts.HollowClient` into your game.
2. When a player rolls it, set the attribute on their character: `character:SetAttribute("Aura", "Hollowmourne")`.
3. Copy the Lighting effects (Sky, Atmosphere, Bloom, ColorCorrection) for the Blood Moon look.
