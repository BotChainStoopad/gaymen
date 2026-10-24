# The Sift

**Download:** [`the-sift-1.0.0.jar`](the-sift-1.0.0.jar) · Minecraft Java **1.21 – 1.21.1**

Mojang called it the first new dimension in over 14 years. This mod adds The Sift to your world now: a turquoise sky, coral-pink towers, red ground under tall blue grass, white willows, iridescent pink ichor that burns you, and fossil deserts full of giant bones. It's based on the Minecraft Dungeons II reveal.

## One file, every loader

The jar contains only data, with no Java code, so the same file works as:

| Loader | How |
|---|---|
| **Fabric / Quilt** | Put it in `mods/` alongside **Fabric API** |
| **NeoForge / Forge** | Put it in `mods/` (it's a resource-only mod, so it needs no other mods) |
| **Vanilla** | Put it in `<world>/datapacks/` |

## Getting in: rifts

1. Get a **Sculk Catalyst** and an **Echo Shard** from the Deep Dark.
2. Place the catalyst and **drop the echo shard on top of it**. A rift opens with a shriek and a sonic boom.
3. Step into the rift.

You arrive somewhere in The Sift. If there isn't already a rift within 48 blocks, a **return rift** opens under your feet. Step off it, wait a moment, then step back on to go home. If you break the catalyst, the rift closes.

**Rift Ruins** are deepslate shrines with a rift that's already open. You'll find them scattered through both the Overworld and The Sift, each with a chest of loot.

## Biomes

| Biome | Look |
|---|---|
| **Meadows** | Turquoise sky. Red-pink ground with patches of **tall blue grass**, warped roots and sprouts. **Coral-pink bushes and towers**, pointed coral spires and **white willows** with hanging white vines. Pink petals, pale-blue blossoms, yellow patches and green moss. Pale calcite rocks covered in green lichen. **Ichor pools** and drifting spores. Rabbits, frogs and singing allays live here. |
| **Carapace** | Pale fossil sands and smooth sandstone. **Giant rib cages**, hollow **giant skulls** you can climb into (with treasure), bone tusks, buried fossils and **strange blue walls** on the cliffs. Ash in the air. Golden rabbits. |
| **Hills** | Barren, wide-open rolling hills of pale grass, coarse dirt and gravel. Calcite outcrops and the occasional lone coral spire. |

Below the surface there's a calcite crust over stone and deepslate, with caves, canyons, amethyst geodes, ores and springs.

## Ichor

In The Sift, every liquid pool is **ichor**: an iridescent pink fluid. It burns players (2 damage about every half second) but leaves the Sift's own creatures alone. **Fire Resistance** protects you, and both loot tables can drop it.

## Advancements

The Sift tab: *The Sift*, *Tear in the World*, *Singer's Meadow*, *Shell of the World*, *Wide Open*, *Sift Walker* (challenge), *Iridescent Agony*, *Inside the Giant*, *Under the Ribs*.

## Building from source

```
python3 build.py
```

This regenerates `src/` (every JSON file, function and generated `.nbt` structure) and repacks the jar. You need Python 3 and Pillow (Pillow is only used for the icon).

## Notes

- Mojang hasn't released The Sift's vanilla blocks or mobs yet (that's planned for 2027). Until then, this mod builds its look from vanilla blocks recoloured through biome colours. The mobs that have been revealed, such as the Blub and the Licker, would need custom code, so the mod uses vanilla stand-ins: rabbits, frogs and allays.
- Want to explore without a rift? Run `/execute in thesift:the_sift run tp @s ~ 120 ~`
