# Aerosphere (Roblox)

A Frutiger Aero aura (1 in 2,000,000,000, during Clear Skies). It has a midday sun with a rainbow halo, glass bubbles with a thin-film sheen, Vista-style aurora light curtains and swoosh ribbons, a glossy water pool ringed with swaying grass, glass butterflies, bokeh, clouds, droplets and ripples. It is made only from Parts, Beams, Trails, ParticleEmitters and Surface/Billboard GUIs. The particle textures come with the Roblox client, so there is nothing to upload or get moderated.

| File | What it is |
| --- | --- |
| `Aerosphere.rbxl` | Open in Studio and press Play. You get the roll cutscene, then the aura on your character and on a showcase dummy in a sunny meadow. |
| `AeroAura.luau` | ModuleScript that builds and animates the aura on one character. |
| `AeroCutscene.luau` | ModuleScript for the roll cutscene, the glass Aura Collection panel, the glossy pill buttons and the lens flare. |
| `AeroClient.client.luau` | LocalScript that draws the aura on every model with `Aura = "Aerosphere"` and runs the cutscene, Aero lighting, Terrain clouds, lens flare and camera punch. |
| `AeroServer.server.luau` | Script that gives every character the aura. Swap it for your own roll logic. |
| `build.luau` | Runs the aura and the cutscene headlessly, then rebuilds the place: `lune run roblox/Aerosphere/build.luau` (Lune 0.8.9). |

## Layers

- **Sun**: a neon core with a rotating sunburst, two rainbow halo rings and glints. It drives a screen-space lens flare (ghosts, a rainbow ring and a streak) that hides when something blocks the sun.
- **12 glass bubbles**: Glass spheres with a specular spot, a rim light and a rainbow thin-film ring. They rise, wobble and pop into droplets.
- **Aurora curtains**: 14 swaying beams that run blue → aqua → lime → cream, the Vista palette.
- **Swooshes**: three bundles of five curved ribbons sweeping around the player.
- **Pool**: reflective glass water with an aqua rim, sweeping highlights and ripples scattered across it.
- **Grass**: 84 swaying blades around the pool.
- **More effects**: 4 glass butterflies with trails, 30 bokeh discs, sparkles, droplets, soft clouds and a rainbow halo above the head.
- **Pulse** every 3.4 s: a rainbow shockwave, an expanding glass shell, a rainbow spark burst and the bubbles jiggling.
- **Aero lighting**: Future lighting, a bright atmosphere, sun rays, bloom, extra saturation and Terrain clouds. Press **E** for a plain sky.

Controls: **R** replays the cutscene, **E** switches the sky, **H** hides the UI. The same actions are on the on-screen buttons.

## Sound

The place ships silent. Paste asset ids (`rbxassetid://…`) into these attributes on `ReplicatedStorage.Aerosphere`:
`MusicSoundId`, `ImpactSoundId`, `HeartbeatSoundId` (plays on each cutscene chime), `PulseSoundId`.

## Using it in your game

1. Copy `ReplicatedStorage.Aerosphere` and `StarterPlayerScripts.AeroClient` into your game.
2. When a player rolls it, set the attribute on their character: `character:SetAttribute("Aura", "Aerosphere")`.
3. Copy the Lighting effects (Atmosphere, Bloom, ColorCorrection, SunRays) for the full look.
