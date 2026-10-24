#!/usr/bin/env python3
"""Builds The Sift mod: generates every data/asset file into src/ and zips it into a jar.

The mod is fully data-driven, so the same jar loads as:
  * a Fabric / Quilt mod (needs Fabric API for its resource loader),
  * a NeoForge / Forge resource-only mod (lowcodefml),
  * a plain datapack (drop the jar into a world's datapacks folder).

Target: Minecraft Java 1.21 - 1.21.1 (data pack format 48).
Usage: python3 build.py
"""
import json
import math
import random
import shutil
import zipfile
from pathlib import Path

import nbt

MOD_ID = "thesift"
VERSION = "1.0.0"
MC_RANGE_FABRIC = ">=1.21 <1.21.2"
MC_RANGE_FORGE = "[1.21,1.21.2)"
DATA_PACK_FORMAT = 48

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
JAR = ROOT / f"the-sift-{VERSION}.jar"

NS = MOD_ID
DIM = f"{NS}:the_sift"
MEADOWS, CARAPACE, HILLS = f"{NS}:meadows", f"{NS}:carapace", f"{NS}:hills"


def rgb(hex_str):
    return int(hex_str.lstrip("#"), 16)


def write_json(rel, obj):
    p = SRC / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_text(rel, text):
    p = SRC / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip("\n") + "\n", encoding="utf-8")


def state(name, **props):
    s = {"Name": name}
    if props:
        s["Properties"] = {k: str(v).lower() if isinstance(v, bool) else str(v) for k, v in props.items()}
    return s


def simple(name, **props):
    return {"type": "minecraft:simple_state_provider", "state": state(name, **props)}


def weighted(*entries):
    return {"type": "minecraft:weighted_state_provider",
            "entries": [{"weight": w, "data": s} for w, s in entries]}


def uniform(lo, hi):
    return {"type": "minecraft:uniform", "min_inclusive": lo, "max_inclusive": hi}


# ---------------------------------------------------------------------------
# Palette - taken from the reveal: flat teal/turquoise sky, coral-pink growth,
# red-pink ground under tall blue grass, white willows, pale rock wrapped in
# green, pink iridescent ichor pools, pale fossil sands with blue walls.
# ---------------------------------------------------------------------------
SKY_TEAL = rgb("#3FC6BA")
ICHOR = rgb("#E8579F")
ICHOR_FOG = rgb("#7A2368")


# ---------------------------------------------------------------------------
# Dimension, dimension type, noise
# ---------------------------------------------------------------------------
def gen_dimension():
    write_json(f"data/{NS}/dimension_type/the_sift.json", {
        "ultrawarm": False,
        "natural": False,
        "coordinate_scale": 1.0,
        "has_skylight": True,
        "has_ceiling": False,
        "ambient_light": 0.1,
        "fixed_time": 6000,
        "monster_spawn_light_level": 0,
        "monster_spawn_block_light_limit": 0,
        "piglin_safe": False,
        "bed_works": False,
        "respawn_anchor_works": False,
        "has_raids": False,
        "logical_height": 384,
        "min_y": -64,
        "height": 384,
        "infiniburn": "#minecraft:infiniburn_overworld",
        "effects": "minecraft:overworld",
    })

    any_param = 0.0
    write_json(f"data/{NS}/dimension/the_sift.json", {
        "type": DIM,
        "generator": {
            "type": "minecraft:noise",
            "settings": DIM,
            "biome_source": {
                "type": "minecraft:multi_noise",
                "biomes": [
                    {"biome": CARAPACE, "parameters": {
                        "temperature": [-1.0, -0.25], "humidity": any_param, "continentalness": any_param,
                        "erosion": any_param, "weirdness": any_param, "depth": 0.0, "offset": 0.0}},
                    {"biome": MEADOWS, "parameters": {
                        "temperature": [-0.25, 0.3], "humidity": any_param, "continentalness": any_param,
                        "erosion": any_param, "weirdness": any_param, "depth": 0.0, "offset": 0.0}},
                    {"biome": HILLS, "parameters": {
                        "temperature": [0.3, 1.0], "humidity": any_param, "continentalness": any_param,
                        "erosion": any_param, "weirdness": any_param, "depth": 0.0, "offset": 0.0}},
                ],
            },
        },
    })

    noises = {
        "region": (-10, [1.0, 1.0, 0.0, 1.0]),
        "height": (-8, [1.0, 1.0, 1.0, 0.5]),
        "hill": (-7, [1.0, 0.6, 0.3]),
        "dune": (-5, [1.0, 0.5]),
        "detail": (-6, [1.0, 1.0]),
        "patches": (-5, [1.0, 1.0]),
        "variant": (-8, [1.0, 1.0]),
    }
    for name, (octave, amps) in noises.items():
        write_json(f"data/{NS}/worldgen/noise/{name}.json", {"firstOctave": octave, "amplitudes": amps})

    def noise2d(name):
        return {"type": "minecraft:noise", "noise": f"{NS}:{name}", "xz_scale": 1.0, "y_scale": 0.0}

    def add(a, b):
        return {"type": "minecraft:add", "argument1": a, "argument2": b}

    def mul(a, b):
        return {"type": "minecraft:mul", "argument1": a, "argument2": b}

    def clamp(x, lo, hi):
        return {"type": "minecraft:clamp", "input": x, "min": lo, "max": hi}

    # Region noise picks the biome AND shapes the terrain so the land matches the biome:
    # hills are rolling and wide open, the carapace has dunes, the meadows sit low with ichor pools.
    write_json(f"data/{NS}/worldgen/density_function/region.json",
               {"type": "minecraft:flat_cache", "argument": noise2d("region")})
    region = f"{NS}:region"
    write_json(f"data/{NS}/worldgen/density_function/hills_weight.json",
               clamp(add(mul(region, 3.0), -0.6), 0.0, 1.0))
    write_json(f"data/{NS}/worldgen/density_function/dunes_weight.json",
               clamp(add(mul(region, -3.0), -0.45), 0.0, 1.0))
    # Surface height / 48, centred on y=68.
    surface = add(
        add(1.4167, mul(0.25, {"type": "minecraft:flat_cache", "argument": noise2d("height")})),
        add(mul(f"{NS}:hills_weight", mul(0.8333, {"type": "minecraft:abs", "argument": noise2d("hill")})),
            mul(f"{NS}:dunes_weight", mul(0.25, {"type": "minecraft:abs", "argument": noise2d("dune")}))),
    )
    write_json(f"data/{NS}/worldgen/density_function/surface.json",
               {"type": "minecraft:cache_2d", "argument": surface})
    gradient = {"type": "minecraft:y_clamped_gradient", "from_y": -64, "to_y": 320,
                "from_value": 1.3333, "to_value": -6.6667}
    terrain = add(add(gradient, f"{NS}:surface"),
                  mul(0.12, {"type": "minecraft:noise", "noise": f"{NS}:detail", "xz_scale": 1.0, "y_scale": 1.0}))
    write_json(f"data/{NS}/worldgen/density_function/terrain.json", terrain)

    write_json(f"data/{NS}/worldgen/noise_settings/the_sift.json", {
        "sea_level": 63,
        "disable_mob_generation": False,
        "aquifers_enabled": False,
        "ore_veins_enabled": False,
        "legacy_random_source": False,
        "default_block": state("minecraft:stone"),
        "default_fluid": state("minecraft:water", level=0),
        "noise": {"min_y": -64, "height": 384, "size_horizontal": 1, "size_vertical": 2},
        "noise_router": {
            "barrier": 0.0,
            "fluid_level_floodedness": 0.0,
            "fluid_level_spread": 0.0,
            "lava": 0.0,
            "temperature": region,
            "vegetation": {"type": "minecraft:flat_cache", "argument": noise2d("variant")},
            "continents": 0.0,
            "erosion": 0.0,
            "depth": 0.0,
            "ridges": 0.0,
            "initial_density_without_jaggedness": f"{NS}:terrain",
            "final_density": {"type": "minecraft:interpolated", "argument": f"{NS}:terrain"},
            "vein_toggle": 0.0,
            "vein_ridged": 0.0,
            "vein_gap": 0.0,
        },
        "spawn_target": [{"temperature": [-1.0, 1.0], "humidity": [-1.0, 1.0], "continentalness": [-1.0, 1.0],
                          "erosion": [-1.0, 1.0], "weirdness": [-1.0, 1.0], "depth": 0.0, "offset": 0.0}],
        "surface_rule": surface_rule(),
    })


def surface_rule():
    def block(name, **p):
        return {"type": "minecraft:block", "result_state": state(name, **p)}

    def cond(c, then):
        return {"type": "minecraft:condition", "if_true": c, "then_run": then}

    def seq(*rules):
        return {"type": "minecraft:sequence", "sequence": list(rules)}

    def depth(surface_type="floor", add_surface=False):
        return {"type": "minecraft:stone_depth", "offset": 0, "add_surface_depth": add_surface,
                "secondary_depth_range": 0, "surface_type": surface_type}

    def biome(b):
        return {"type": "minecraft:biome", "biome_is": [b]}

    def noise(n, lo, hi):
        return {"type": "minecraft:noise_threshold", "noise": n, "min_threshold": lo, "max_threshold": hi}

    def vgrad(name, below, above):
        return {"type": "minecraft:vertical_gradient", "random_name": name,
                "true_at_and_below": below, "false_at_and_above": above}

    floor, under, ceiling = depth("floor"), depth("floor", True), depth("ceiling")
    above_water = {"type": "minecraft:water", "offset": -1, "surface_depth_multiplier": 0, "add_stone_depth": False}
    steep = {"type": "minecraft:steep"}
    patches = f"{NS}:patches"

    meadows = cond(biome(MEADOWS), seq(
        cond(floor, seq(
            cond(steep, block("minecraft:calcite")),
            cond(above_water, seq(
                # tall blue grass grows in the blue grass patches; the rest is red "sculk" ground
                cond(noise(patches, -0.22, 0.22), block("minecraft:grass_block", snowy=False)),
                block("minecraft:crimson_nylium"),
            )),
            block("minecraft:clay"),
        )),
        cond(under, seq(cond(steep, block("minecraft:calcite")), block("minecraft:dirt"))),
    ))
    carapace = cond(biome(CARAPACE), seq(
        cond(ceiling, block("minecraft:sandstone")),
        # the strange blue walls
        cond(under, cond(steep, seq(
            cond(noise(patches, 0.0, 4.0), block("minecraft:cyan_terracotta")),
            block("minecraft:light_blue_terracotta"),
        ))),
        cond(floor, seq(
            cond(noise("minecraft:surface", 0.35, 4.0), block("minecraft:smooth_sandstone")),
            block("minecraft:sand"),
        )),
        cond(under, block("minecraft:sandstone")),
    ))
    hills = cond(biome(HILLS), seq(
        cond(floor, seq(
            cond(steep, block("minecraft:calcite")),
            cond(above_water, seq(
                cond(noise(patches, 0.25, 4.0), block("minecraft:coarse_dirt")),
                cond(noise(patches, -4.0, -0.35), block("minecraft:gravel")),
                block("minecraft:grass_block", snowy=False),
            )),
            block("minecraft:gravel"),
        )),
        cond(under, seq(cond(steep, block("minecraft:calcite")), block("minecraft:dirt"))),
    ))
    return seq(
        cond(vgrad("minecraft:bedrock_floor", {"above_bottom": 0}, {"above_bottom": 5}), block("minecraft:bedrock")),
        meadows, carapace, hills,
        cond(vgrad("minecraft:deepslate", {"absolute": 0}, {"absolute": 8}), block("minecraft:deepslate", axis="y")),
        # pale rock: the upper crust of the Sift is calcite
        cond({"type": "minecraft:not", "invert": vgrad(f"{NS}:calcite", {"absolute": 28}, {"absolute": 44})},
             block("minecraft:calcite")),
    )


# ---------------------------------------------------------------------------
# Features
# ---------------------------------------------------------------------------
def tree(trunk, foliage, foliage_placer, trunk_placer, dirt, decorators=(), min_size=None, ignore_vines=True):
    return {"type": "minecraft:tree", "config": {
        "dirt_provider": dirt,
        "trunk_provider": trunk,
        "foliage_provider": foliage,
        "foliage_placer": foliage_placer,
        "trunk_placer": trunk_placer,
        "minimum_size": min_size or {"type": "minecraft:two_layers_feature_size", "limit": 1,
                                     "lower_size": 0, "upper_size": 1},
        "decorators": list(decorators),
        "ignore_vines": ignore_vines,
        "force_dirt": False,
    }}


def patch(provider, tries, spread=7, survive_as=None):
    preds = [{"type": "minecraft:matching_blocks", "blocks": "minecraft:air"}]
    if survive_as:
        preds.append({"type": "minecraft:would_survive", "state": state(survive_as)})
    return {"type": "minecraft:random_patch", "config": {
        "tries": tries, "xz_spread": spread, "y_spread": 3,
        "feature": {
            "feature": {"type": "minecraft:simple_block", "config": {"to_place": provider}},
            "placement": [{"type": "minecraft:block_predicate_filter",
                           "predicate": {"type": "minecraft:all_of", "predicates": preds}}],
        },
    }}


PINK_LEAVES = state("minecraft:cherry_leaves", persistent=True, waterlogged=False, distance=7)
AZALEA_PINK = state("minecraft:flowering_azalea_leaves", persistent=True, waterlogged=False, distance=7)
CORAL_TRUNK = weighted((5, state("minecraft:pink_terracotta")), (2, state("minecraft:magenta_terracotta")))


def gen_configured_features():
    cf = {}
    cf["coral_tower"] = tree(
        CORAL_TRUNK, {"type": "minecraft:simple_state_provider", "state": PINK_LEAVES},
        {"type": "minecraft:blob_foliage_placer", "radius": 2, "offset": 0, "height": 3},
        {"type": "minecraft:straight_trunk_placer", "base_height": 6, "height_rand_a": 5, "height_rand_b": 3},
        simple("minecraft:pink_terracotta"))
    cf["coral_tower_tall"] = tree(
        CORAL_TRUNK, {"type": "minecraft:simple_state_provider", "state": PINK_LEAVES},
        {"type": "minecraft:spruce_foliage_placer", "radius": uniform(1, 2), "offset": 0,
         "trunk_height": uniform(1, 2)},
        {"type": "minecraft:straight_trunk_placer", "base_height": 11, "height_rand_a": 6, "height_rand_b": 4},
        simple("minecraft:pink_terracotta"))
    cf["coral_bush"] = tree(
        simple("minecraft:pink_terracotta"),
        {"type": "minecraft:weighted_state_provider",
         "entries": [{"weight": 3, "data": PINK_LEAVES}, {"weight": 1, "data": AZALEA_PINK}]},
        {"type": "minecraft:bush_foliage_placer", "radius": 2, "offset": 1, "height": 2},
        {"type": "minecraft:straight_trunk_placer", "base_height": 1, "height_rand_a": 0, "height_rand_b": 0},
        simple("minecraft:pink_terracotta"),
        min_size={"type": "minecraft:two_layers_feature_size", "limit": 0, "lower_size": 0, "upper_size": 0})
    # White willow: pale birch bark, leaves + drooping vines tinted near-white by the meadow foliage colour.
    cf["white_willow"] = tree(
        simple("minecraft:birch_log", axis="y"),
        {"type": "minecraft:simple_state_provider",
         "state": state("minecraft:oak_leaves", persistent=False, waterlogged=False, distance=7)},
        {"type": "minecraft:fancy_foliage_placer", "radius": 2, "offset": 4, "height": 4},
        {"type": "minecraft:fancy_trunk_placer", "base_height": 8, "height_rand_a": 4, "height_rand_b": 0},
        simple("minecraft:dirt"),
        decorators=[{"type": "minecraft:leave_vine", "probability": 0.75}],
        min_size={"type": "minecraft:two_layers_feature_size", "limit": 0, "lower_size": 0, "upper_size": 0,
                  "min_clipped_height": 4},
        ignore_vines=False)
    cf["blue_grass"] = patch(weighted((3, state("minecraft:short_grass")),
                                      (2, state("minecraft:tall_grass", half="lower"))),
                             72, survive_as="minecraft:short_grass")
    cf["blue_roots"] = patch(weighted((4, state("minecraft:warped_roots")), (2, state("minecraft:nether_sprouts"))),
                             64, survive_as="minecraft:warped_roots")
    cf["pink_petals"] = patch(weighted(*[(1, state("minecraft:pink_petals", facing=f, flower_amount=n))
                                         for f in ("north", "east", "south", "west") for n in (1, 2, 3, 4)]),
                              48, spread=5, survive_as="minecraft:pink_petals")
    cf["sift_flowers"] = patch(weighted((3, state("minecraft:blue_orchid")), (1, state("minecraft:cornflower")),
                                        (2, state("minecraft:dandelion")),
                                        (1, state("minecraft:lily_of_the_valley"))),
                               40, spread=6, survive_as="minecraft:blue_orchid")
    cf["moss_patch"] = patch(simple("minecraft:moss_carpet"), 40, spread=4)
    cf["calcite_rock"] = {"type": "minecraft:forest_rock", "config": {"state": state("minecraft:calcite")}}
    cf["rock_lichen"] = {"type": "minecraft:multiface_growth", "config": {
        "block": "minecraft:glow_lichen", "search_range": 20, "chance_of_spreading": 0.5,
        "can_place_on_floor": False, "can_place_on_ceiling": False, "can_place_on_wall": True,
        "can_be_placed_on": ["minecraft:calcite"]}}
    cf["ichor_lake"] = {"type": "minecraft:lake", "config": {
        "fluid": simple("minecraft:water", level=0), "barrier": simple("minecraft:calcite")}}
    cf["bone_tusk"] = {"type": "minecraft:block_column", "config": {
        "direction": "up",
        "allowed_placement": {"type": "minecraft:matching_blocks", "blocks": "minecraft:air"},
        "prioritize_tip": False,
        "layers": [{"height": uniform(3, 9), "provider": simple("minecraft:bone_block", axis="y")}]}}
    cf["dead_bush"] = patch(simple("minecraft:dead_bush"), 6, survive_as="minecraft:dead_bush")
    cf["hills_grass"] = patch(simple("minecraft:short_grass"), 20, survive_as="minecraft:short_grass")
    for name, obj in cf.items():
        write_json(f"data/{NS}/worldgen/configured_feature/{name}.json", obj)
    return cf


def below_is(*blocks):
    return {"type": "minecraft:block_predicate_filter",
            "predicate": {"type": "minecraft:matching_blocks", "offset": [0, -1, 0], "blocks": list(blocks)}}


IN_SQUARE = {"type": "minecraft:in_square"}
BIOME = {"type": "minecraft:biome"}


def count(n):
    return {"type": "minecraft:count", "count": n}


def rarity(n):
    return {"type": "minecraft:rarity_filter", "chance": n}


def heightmap(h):
    return {"type": "minecraft:heightmap", "heightmap": h}


DRY = {"type": "minecraft:surface_water_depth_filter", "max_water_depth": 0}
MEADOW_GROUND = ("minecraft:crimson_nylium", "minecraft:grass_block")


def tree_place(freq):
    return freq + [IN_SQUARE, DRY, heightmap("OCEAN_FLOOR"), below_is(*MEADOW_GROUND), BIOME]


PLACED = {
    "ichor_lake": ("ichor_lake", [rarity(30), IN_SQUARE, heightmap("WORLD_SURFACE_WG"), BIOME]),
    "calcite_rock": ("calcite_rock", [count(uniform(0, 2)), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "hills_calcite_rock": ("calcite_rock", [count(uniform(1, 3)), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "coral_tower_tall": ("coral_tower_tall", tree_place([rarity(2)])),
    "coral_tower": ("coral_tower", tree_place([count(uniform(1, 3))])),
    "white_willow": ("white_willow", tree_place([rarity(3)])),
    "coral_bush": ("coral_bush", tree_place([count(uniform(2, 5))])),
    "hills_coral_tower": ("coral_tower_tall", [rarity(14), IN_SQUARE, DRY, heightmap("OCEAN_FLOOR"),
                                               below_is("minecraft:grass_block", "minecraft:coarse_dirt"), BIOME]),
    "bone_tusk": ("bone_tusk", [count(uniform(0, 3)), IN_SQUARE, heightmap("WORLD_SURFACE_WG"),
                                below_is("minecraft:sand", "minecraft:smooth_sandstone"), BIOME]),
    "blue_grass": ("blue_grass", [count(6), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "blue_roots": ("blue_roots", [count(8), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "pink_petals": ("pink_petals", [count(3), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "sift_flowers": ("sift_flowers", [count(2), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "moss_patch": ("moss_patch", [count(2), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "rock_lichen": ("rock_lichen", [count(24), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "dead_bush": ("dead_bush", [count(2), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
    "hills_grass": ("hills_grass", [count(3), IN_SQUARE, heightmap("MOTION_BLOCKING"), BIOME]),
}

# One global, ordered list keeps per-step feature order identical across biomes (no feature-order cycles).
ALL, M, C, H = {"m", "c", "h"}, {"m"}, {"c"}, {"h"}
FEATURE_ORDER = [
    (1, f"{NS}:ichor_lake", M | H),
    (2, "minecraft:amethyst_geode", ALL),
    (2, f"{NS}:calcite_rock", M),
    (2, f"{NS}:hills_calcite_rock", H),
    (3, "minecraft:fossil_upper", C),
    (3, "minecraft:fossil_lower", C),
    (6, "minecraft:ore_coal_lower", ALL),
    (6, "minecraft:ore_iron_middle", ALL),
    (6, "minecraft:ore_iron_small", ALL),
    (6, "minecraft:ore_gold", ALL),
    (6, "minecraft:ore_redstone", ALL),
    (6, "minecraft:ore_diamond", ALL),
    (6, "minecraft:ore_lapis", ALL),
    (6, "minecraft:ore_copper", ALL),
    (8, "minecraft:spring_water", ALL),
    (9, f"{NS}:coral_tower_tall", M),
    (9, f"{NS}:coral_tower", M),
    (9, f"{NS}:white_willow", M),
    (9, f"{NS}:coral_bush", M),
    (9, f"{NS}:hills_coral_tower", H),
    (9, f"{NS}:bone_tusk", C),
    (9, f"{NS}:blue_grass", M),
    (9, f"{NS}:blue_roots", M),
    (9, f"{NS}:pink_petals", M),
    (9, f"{NS}:sift_flowers", M),
    (9, f"{NS}:moss_patch", M),
    (9, f"{NS}:rock_lichen", M | H),
    (9, f"{NS}:dead_bush", C),
    (9, f"{NS}:hills_grass", H),
    (9, "minecraft:glow_lichen", ALL),
]


def gen_placed_features():
    for name, (feature, placement) in PLACED.items():
        write_json(f"data/{NS}/worldgen/placed_feature/{name}.json",
                   {"feature": f"{NS}:{feature}", "placement": placement})


def features_for(key):
    steps = [[] for _ in range(11)]
    for step, fid, biomes in FEATURE_ORDER:
        if key in biomes:
            steps[step].append(fid)
    return steps


# ---------------------------------------------------------------------------
# Biomes
# ---------------------------------------------------------------------------
def spawners(creature=(), ambient=()):
    s = {k: [] for k in ("monster", "creature", "ambient", "axolotls", "underground_water_creature",
                         "water_creature", "water_ambient", "misc")}
    s["creature"] = [{"type": t, "weight": w, "minCount": a, "maxCount": b} for t, w, a, b in creature]
    s["ambient"] = [{"type": t, "weight": w, "minCount": a, "maxCount": b} for t, w, a, b in ambient]
    return s


def gen_biomes():
    common_carvers = {"air": ["minecraft:cave", "minecraft:cave_extra_underground", "minecraft:canyon"]}
    mood = {"sound": "minecraft:ambient.cave", "tick_delay": 6000, "block_search_extent": 8, "offset": 2.0}
    additions = {"sound": "minecraft:ambient.soul_sand_valley.additions", "tick_chance": 0.0111}

    def music(event):
        return {"sound": event, "min_delay": 12000, "max_delay": 24000, "replace_current_music": False}

    biomes = {
        "meadows": dict(
            temperature=0.8, downfall=0.6, key="m",
            effects={
                "sky_color": SKY_TEAL, "fog_color": rgb("#9BE3DA"),
                "water_color": ICHOR, "water_fog_color": ICHOR_FOG,
                "grass_color": rgb("#4E9BE0"), "foliage_color": rgb("#E6F2EE"),
                "particle": {"options": {"type": "minecraft:spore_blossom_air"}, "probability": 0.008},
                "mood_sound": mood, "additions_sound": additions,
                "music": music("minecraft:music.overworld.cherry_grove"),
            },
            spawns=spawners(creature=[("minecraft:rabbit", 10, 2, 3), ("minecraft:frog", 6, 2, 4),
                                      ("minecraft:allay", 2, 1, 2)]),
        ),
        "carapace": dict(
            temperature=2.0, downfall=0.0, key="c",
            effects={
                "sky_color": rgb("#5CC9BE"), "fog_color": rgb("#E5D9B0"),
                "water_color": ICHOR, "water_fog_color": ICHOR_FOG,
                "grass_color": rgb("#C8BE8A"), "foliage_color": rgb("#BDB48A"),
                "particle": {"options": {"type": "minecraft:white_ash"}, "probability": 0.02},
                "mood_sound": mood, "additions_sound": additions,
                "music": music("minecraft:music.overworld.desert"),
            },
            spawns=spawners(creature=[("minecraft:rabbit", 6, 1, 3)]),
        ),
        "hills": dict(
            temperature=0.5, downfall=0.3, key="h",
            effects={
                "sky_color": SKY_TEAL, "fog_color": rgb("#B5DDD6"),
                "water_color": ICHOR, "water_fog_color": ICHOR_FOG,
                "grass_color": rgb("#8FB9A8"), "foliage_color": rgb("#A9C7B5"),
                "particle": {"options": {"type": "minecraft:warped_spore"}, "probability": 0.004},
                "mood_sound": mood, "additions_sound": additions,
                "music": music("minecraft:music.overworld.meadow"),
            },
            spawns=spawners(creature=[("minecraft:rabbit", 4, 1, 2)]),
        ),
    }
    for name, b in biomes.items():
        write_json(f"data/{NS}/worldgen/biome/{name}.json", {
            "has_precipitation": False,
            "temperature": b["temperature"],
            "downfall": b["downfall"],
            "effects": b["effects"],
            "spawners": b["spawns"],
            "spawn_costs": {},
            "carvers": common_carvers,
            "features": features_for(b["key"]),
        })

    write_json(f"data/{NS}/tags/worldgen/biome/is_sift.json", {"values": [MEADOWS, CARAPACE, HILLS]})
    write_json("data/minecraft/tags/worldgen/biome/spawns_gold_rabbits.json",
               {"replace": False, "values": [CARAPACE]})
    write_json(f"data/{NS}/tags/worldgen/biome/has_rift_ruin_overworld.json", {"values": [
        "minecraft:plains", "minecraft:sunflower_plains", "minecraft:meadow", "minecraft:cherry_grove",
        "minecraft:desert", "minecraft:snowy_plains", "minecraft:dark_forest",
        "#minecraft:is_forest", "#minecraft:is_taiga", "#minecraft:is_savanna", "#minecraft:is_jungle",
        "#minecraft:is_badlands"]})


# ---------------------------------------------------------------------------
# Structures (generated templates + jigsaw definitions)
# ---------------------------------------------------------------------------
def bone(axis):
    return "minecraft:bone_block", {"axis": axis}


def gen_rib_cage(path):
    t = nbt.Template()
    body0, body1 = 6, 26

    def r_at(x):
        if x < body0:
            return 1.0 + 2.0 * x / body0
        if x > body1:
            return max(0.0, 3.0 * (1 - (x - body1) / 8.0))
        return 3.0 + 6.0 * math.sin(math.pi * (x - body0) / (body1 - body0))

    # spine with dorsal spikes
    for x in range(0, 34):
        y = round(r_at(x))
        t.set(x, y, 0, *bone("x"))
        if x % 2 == 0 and body0 <= x <= body1:
            t.set(x, y + 1, 0, *bone("y"))
            if r_at(x) > 7:
                t.set(x, y + 2, 0, *bone("y"))
    # ribs arc from the spine down to (and slightly under) the ground on both sides
    for x in range(body0 + 2, body1 - 1, 3):
        r = r_at(x)
        thick = 2 if r > 6 else 1
        for side in (-1, 1):
            theta = 90.0
            while theta >= -22.0:
                rad = math.radians(theta)
                z = side * r * 1.15 * math.cos(rad)
                y = r * math.sin(rad)
                axis = "y" if abs(math.cos(rad)) > abs(math.sin(rad)) else "z"
                for dx in range(thick):
                    t.set(x + dx, round(y), round(z), *bone(axis))
                theta -= 2.0
    # legs / hip bones poking out of the sand
    for x, z in ((9, -6), (9, 6), (22, -6), (22, 6)):
        for y in range(-2, 2):
            t.set(x, y, z, *bone("y"))
    size = t.save(path)
    min_y = min(p[1] for p in t.blocks)
    return size, min_y


def gen_skull(path):
    rng = random.Random(7)
    t = nbt.Template()
    rx, ry, rz, cy = 7.0, 6.0, 5.5, 5.0
    eyes = [(4.6, 6.6, -2.6), (4.6, 6.6, 2.6)]
    for x in range(-8, 9):
        for y in range(-2, 13):
            for z in range(-7, 8):
                d = math.sqrt((x / rx) ** 2 + ((y - cy) / ry) ** 2 + (z / rz) ** 2)
                in_eye = any(math.dist((x, y, z), e) < 2.2 for e in eyes)
                in_nose = math.dist((x, y, z), (6.6, 4.4, 0)) < 1.3
                in_mouth = x > 2 and 0 <= y <= 2
                if d <= 1.0 and y >= -2:
                    if d > 0.78 and not in_eye and not in_nose and not in_mouth:
                        t.set(x, y, z, *bone("y" if abs(z) < abs(x) else "z"))
                    elif y >= 1:
                        t.set(x, y, z, "minecraft:air")
    # teeth
    for z in range(-4, 5, 2):
        t.set(6, 2, z, *bone("y"))
        t.set(6, 1, z + 1, *bone("y"))
    # glowing eyes deep in the sockets
    for ex, ey, ez in eyes:
        t.set(round(ex) - 2, round(ey), round(ez), "minecraft:sea_lantern")
    # floor and treasure inside
    for x in range(-5, 3):
        for z in range(-3, 4):
            if t.get(x, 0, z) is None or t.get(x, 0, z)[0] == "minecraft:air":
                if rng.random() < 0.7:
                    t.set(x, 0, z, "minecraft:sand")
                else:
                    t.set(x, 0, z, *bone("y"))
    t.set(-3, 1, 0, "minecraft:chest", {"facing": "east", "type": "single", "waterlogged": "false"},
          nbt={"id": "minecraft:chest", "LootTable": f"{NS}:chests/giant_skull"})
    size = t.save(path)
    return size, min(p[1] for p in t.blocks)


def gen_rift_ruin(path):
    rng = random.Random(42)
    t = nbt.Template()
    c = 4
    for x in range(9):
        for z in range(9):
            d = math.dist((x, z), (c, c))
            if d > 4.6:
                continue
            for y in (-2, -1):
                t.set(x, y, z, "minecraft:deepslate", {"axis": "y"})
            roll = rng.random()
            if d < 1.6:
                top = "minecraft:sculk"
            elif roll < 0.35:
                top = "minecraft:deepslate_tiles"
            elif roll < 0.55:
                top = "minecraft:cracked_deepslate_tiles"
            elif roll < 0.8:
                top = "minecraft:polished_deepslate"
            else:
                top = "minecraft:sculk"
            t.set(x, 0, z, top)
            for y in range(1, 6):
                t.set(x, y, z, "minecraft:air")
    t.set(c, 0, c, "minecraft:sculk_catalyst", {"bloom": "false"})
    for (px, pz), h in zip(((1, 1), (7, 1), (1, 7), (7, 7)), (5, 2, 4, 3)):
        for y in range(1, h + 1):
            block = "minecraft:deepslate_bricks"
            if y == 2 and rng.random() < 0.6:
                block = "minecraft:crying_obsidian"
            if y == h:
                block = "minecraft:chiseled_deepslate"
            t.set(px, y, pz, block)
    t.set(1, 6, 1, "minecraft:soul_lantern", {"hanging": "false", "waterlogged": "false"})
    t.set(6, 1, 2, "minecraft:chest", {"facing": "north", "type": "single", "waterlogged": "false"},
          nbt={"id": "minecraft:chest", "LootTable": f"{NS}:chests/rift_ruin"})
    t.add_entity(c + 0.5, 1.0, c + 0.5, {"id": "minecraft:marker", "Tags": nbt.List(nbt.TAG_STRING, ["thesift.rift"])})
    size = t.save(path)
    return size, min(p[1] for p in t.blocks)


def gen_structures():
    out = SRC / f"data/{NS}/structure"
    out.mkdir(parents=True, exist_ok=True)
    templates = {
        "rib_cage": gen_rib_cage(out / "rib_cage.nbt"),
        "giant_skull": gen_skull(out / "giant_skull.nbt"),
        "rift_ruin": gen_rift_ruin(out / "rift_ruin.nbt"),
    }
    defs = [
        # structure id, template, biomes, spacing, separation, salt
        ("rib_cage", "rib_cage", CARAPACE, 24, 8, 1846391027),
        ("giant_skull", "giant_skull", CARAPACE, 30, 11, 573920184),
        ("rift_ruin", "rift_ruin", f"#{NS}:is_sift", 36, 12, 994021337),
        ("rift_ruin_overworld", "rift_ruin", f"#{NS}:has_rift_ruin_overworld", 56, 20, 310255809),
    ]
    for sid, tmpl, biomes, spacing, sep, salt in defs:
        _, min_y = templates[tmpl]
        write_json(f"data/{NS}/worldgen/template_pool/{sid}.json", {
            "fallback": "minecraft:empty",
            "elements": [{"weight": 1, "element": {
                "element_type": "minecraft:single_pool_element", "location": f"{NS}:{tmpl}",
                "processors": "minecraft:empty", "projection": "rigid"}}],
        })
        write_json(f"data/{NS}/worldgen/structure/{sid}.json", {
            "type": "minecraft:jigsaw",
            "biomes": biomes,
            "step": "surface_structures",
            "spawn_overrides": {},
            "terrain_adaptation": "beard_thin",
            "start_pool": f"{NS}:{sid}",
            "size": 1,
            # sink the buried part of the template below the surface
            "start_height": {"absolute": min_y},
            "project_start_to_heightmap": "WORLD_SURFACE_WG",
            "max_distance_from_center": 80,
            "use_expansion_hack": False,
        })
        write_json(f"data/{NS}/worldgen/structure_set/{sid}.json", {
            "structures": [{"structure": f"{NS}:{sid}", "weight": 1}],
            "placement": {"type": "minecraft:random_spread", "spacing": spacing, "separation": sep, "salt": salt},
        })


# ---------------------------------------------------------------------------
# Loot
# ---------------------------------------------------------------------------
def item(name, weight, lo=1, hi=1, extra=()):
    e = {"type": "minecraft:item", "name": name, "weight": weight}
    funcs = list(extra)
    if hi > 1:
        funcs.insert(0, {"function": "minecraft:set_count", "count": {"type": "minecraft:uniform", "min": lo, "max": hi}})
    if funcs:
        e["functions"] = funcs
    return e


def gen_loot():
    write_json(f"data/{NS}/loot_table/chests/rift_ruin.json", {"type": "minecraft:chest", "pools": [
        {"rolls": 1, "entries": [item("minecraft:echo_shard", 1, 1, 2)]},
        {"rolls": {"type": "minecraft:uniform", "min": 3, "max": 6}, "entries": [
            item("minecraft:amethyst_shard", 10, 2, 6),
            item("minecraft:sculk", 8, 4, 12),
            item("minecraft:sculk_catalyst", 2),
            item("minecraft:disc_fragment_5", 3),
            item("minecraft:bone", 8, 2, 6),
            item("minecraft:glow_berries", 6, 2, 5),
            item("minecraft:light_blue_candle", 5, 1, 3),
            item("minecraft:experience_bottle", 4, 1, 3),
            item("minecraft:ender_pearl", 4),
            item("minecraft:potion", 3, extra=[{"function": "minecraft:set_potion", "id": "minecraft:fire_resistance"}]),
            item("minecraft:book", 3, extra=[{"function": "minecraft:enchant_randomly"}]),
        ]},
    ]})
    write_json(f"data/{NS}/loot_table/chests/giant_skull.json", {"type": "minecraft:chest", "pools": [
        {"rolls": {"type": "minecraft:uniform", "min": 4, "max": 7}, "entries": [
            item("minecraft:bone_block", 10, 1, 4),
            item("minecraft:bone", 12, 3, 9),
            item("minecraft:gold_ingot", 8, 1, 4),
            item("minecraft:emerald", 6, 1, 3),
            item("minecraft:diamond", 2, 1, 2),
            item("minecraft:skull_pottery_sherd", 3),
            item("minecraft:echo_shard", 3),
            item("minecraft:brush", 4),
            item("minecraft:sniffer_egg", 1),
            item("minecraft:potion", 3, extra=[{"function": "minecraft:set_potion", "id": "minecraft:fire_resistance"}]),
        ]},
    ]})


# ---------------------------------------------------------------------------
# Rifts (the way in) + ichor, as functions
# ---------------------------------------------------------------------------
FUNCTIONS = {
    "load": """
scoreboard objectives add thesift.cd dummy
scoreboard objectives add thesift.tmp dummy
scoreboard objectives add thesift.ichor dummy
""",
    "tick": """
# Open a rift: drop an Echo Shard onto a Sculk Catalyst.
execute as @e[type=item] if items entity @s contents minecraft:echo_shard at @s if block ~ ~-1 ~ minecraft:sculk_catalyst align xyz positioned ~0.5 ~ ~0.5 unless entity @e[type=marker,tag=thesift.rift,distance=..1.5] run function thesift:rift/open
execute as @e[type=marker,tag=thesift.rift] at @s run function thesift:rift/tick
scoreboard players remove @a[scores={thesift.cd=1..}] thesift.cd 1
execute as @a[gamemode=!spectator] at @s if entity @e[type=marker,tag=thesift.rift,distance=..0.9] run function thesift:rift/enter
# Ichor burns visitors, never the Sift's own creatures.
execute as @a[gamemode=!creative,gamemode=!spectator] if predicate thesift:in_ichor at @s run function thesift:ichor/burn
execute as @a unless predicate thesift:in_ichor run scoreboard players set @s thesift.ichor 9
""",
    "rift/open": """
summon minecraft:marker ~ ~ ~ {Tags:["thesift.rift"]}
playsound minecraft:block.sculk_shrieker.shriek block @a ~ ~ ~ 1.5 0.6
playsound minecraft:block.respawn_anchor.charge block @a ~ ~ ~ 1 0.5
particle minecraft:sonic_boom ~ ~1 ~ 0 0 0 0 1
particle minecraft:sculk_soul ~ ~1 ~ 0.4 1 0.4 0.05 60
advancement grant @a[distance=..8] only thesift:open_rift
execute store result score #count thesift.tmp run data get entity @s Item.count
scoreboard players remove #count thesift.tmp 1
execute if score #count thesift.tmp matches ..0 run return run kill @s
execute store result entity @s Item.count int 1 run scoreboard players get #count thesift.tmp
""",
    "rift/tick": """
execute unless block ~ ~-1 ~ minecraft:sculk_catalyst run return run function thesift:rift/close
particle minecraft:reverse_portal ~ ~1 ~ 0.25 0.7 0.25 0.01 6
particle minecraft:dust{color:[0.25,0.9,0.82],scale:1.4} ~ ~1 ~ 0.2 0.8 0.2 0 3
particle minecraft:dust{color:[0.91,0.34,0.62],scale:1.1} ~ ~1 ~ 0.2 0.8 0.2 0 2
particle minecraft:end_rod ~ ~1.2 ~ 0.15 0.6 0.15 0.005 1
execute if predicate thesift:chance_2 run particle minecraft:sculk_charge_pop ~ ~0.1 ~ 0.4 0 0.4 0.01 2
execute if predicate thesift:chance_2 run playsound minecraft:block.amethyst_block.chime ambient @a ~ ~ ~ 0.6 0.5
""",
    "rift/close": """
particle minecraft:sculk_soul ~ ~1 ~ 0.3 0.5 0.3 0.05 30
playsound minecraft:block.sculk_catalyst.break block @a ~ ~ ~ 1 0.5
kill @s
""",
    "rift/enter": """
execute if score @s thesift.cd matches 1.. run return run scoreboard players set @s thesift.cd 40
scoreboard players set @s thesift.cd 60
effect give @s minecraft:darkness 3 0 true
effect give @s minecraft:slow_falling 8 0 true
playsound minecraft:entity.warden.sonic_charge player @s ~ ~ ~ 1 1.4
execute if dimension thesift:the_sift run return run function thesift:rift/to_overworld
function thesift:rift/to_sift
""",
    "rift/to_sift": """
scoreboard players set #ok thesift.tmp 0
execute store success score #ok thesift.tmp in thesift:the_sift run spreadplayers ~ ~ 0 24 false @s
execute if score #ok thesift.tmp matches 0 in thesift:the_sift run tp @s ~ 180 ~
execute if score #ok thesift.tmp matches 1 at @s run function thesift:rift/arrive
title @s times 10 60 20
title @s subtitle {"text":"Strange and beautiful.","color":"#E8579F","italic":true}
title @s title {"text":"The Sift","color":"#3FC6BA","bold":true}
""",
    "rift/to_overworld": """
scoreboard players set #ok thesift.tmp 0
execute store success score #ok thesift.tmp in minecraft:overworld run spreadplayers ~ ~ 0 24 false @s
execute if score #ok thesift.tmp matches 0 in minecraft:overworld run tp @s ~ 200 ~
execute if score #ok thesift.tmp matches 1 at @s run function thesift:rift/arrive
""",
    # Every rift has a twin: arriving somewhere without a rift nearby tears a return rift open under you.
    "rift/arrive": """
execute unless entity @e[type=marker,tag=thesift.rift,distance=..48] align xyz positioned ~0.5 ~ ~0.5 run function thesift:rift/make_return
""",
    "rift/make_return": """
setblock ~ ~-1 ~ minecraft:sculk_catalyst
summon minecraft:marker ~ ~ ~ {Tags:["thesift.rift"]}
particle minecraft:sculk_soul ~ ~1 ~ 0.4 1 0.4 0.05 40
""",
    "ichor/burn": """
scoreboard players add @s thesift.ichor 1
particle minecraft:dust{color:[0.91,0.34,0.62],scale:1.2} ~ ~0.6 ~ 0.3 0.4 0.3 0 4
particle minecraft:flame ~ ~0.4 ~ 0.25 0.2 0.25 0.01 1
execute if score @s thesift.ichor matches 10.. run function thesift:ichor/hurt
""",
    "ichor/hurt": """
scoreboard players set @s thesift.ichor 0
damage @s 2 minecraft:on_fire
playsound minecraft:entity.generic.burn player @a ~ ~ ~ 0.6 1.2
advancement grant @s only thesift:ichor
""",
}


def gen_functions():
    for name, body in FUNCTIONS.items():
        write_text(f"data/{NS}/function/{name}.mcfunction", body)
    write_json("data/minecraft/tags/function/load.json", {"values": [f"{NS}:load"]})
    write_json("data/minecraft/tags/function/tick.json", {"values": [f"{NS}:tick"]})
    write_json(f"data/{NS}/predicate/in_ichor.json", {
        "condition": "minecraft:entity_properties", "entity": "this",
        "predicate": {"location": {"dimension": DIM, "fluid": {"fluids": "#minecraft:water"}}}})
    write_json(f"data/{NS}/predicate/chance_2.json", {"condition": "minecraft:random_chance", "chance": 0.02})


# ---------------------------------------------------------------------------
# Advancements
# ---------------------------------------------------------------------------
def adv(name, icon, title, desc, criteria, parent=f"{NS}:root", frame="task", hidden=False, requirements=None,
        background=None):
    display = {"icon": {"id": icon}, "title": {"text": title}, "description": {"text": desc},
               "frame": frame, "show_toast": True, "announce_to_chat": True, "hidden": hidden}
    if background:
        display["background"] = background
    obj = {"display": display, "criteria": criteria}
    if parent:
        obj["parent"] = parent
    if requirements:
        obj["requirements"] = requirements
    write_json(f"data/{NS}/advancement/{name}.json", obj)


def in_biome(b):
    return {"trigger": "minecraft:location", "conditions": {"player": [
        {"condition": "minecraft:entity_properties", "entity": "this",
         "predicate": {"location": {"biomes": b}}}]}}


def in_structure(s):
    return {"trigger": "minecraft:location", "conditions": {"player": [
        {"condition": "minecraft:entity_properties", "entity": "this",
         "predicate": {"location": {"structures": s}}}]}}


def gen_advancements():
    impossible = {"granted": {"trigger": "minecraft:impossible"}}
    adv("root", "minecraft:echo_shard", "The Sift", "Step through a rift into Minecraft's fourth dimension",
        {"entered": {"trigger": "minecraft:changed_dimension", "conditions": {"to": DIM}}},
        parent=None, background="minecraft:textures/block/calcite.png")
    adv("open_rift", "minecraft:sculk_catalyst", "Tear in the World",
        "Drop an Echo Shard on a Sculk Catalyst to open a rift", impossible)
    adv("meadows", "minecraft:cherry_leaves", "Singer's Meadow", "Walk the coral-pink Meadows",
        {"visit": in_biome(MEADOWS)})
    adv("carapace", "minecraft:bone_block", "Shell of the World", "Cross the fossil sands of the Carapace",
        {"visit": in_biome(CARAPACE)})
    adv("hills", "minecraft:calcite", "Wide Open", "Climb the barren Hills", {"visit": in_biome(HILLS)})
    adv("sift_walker", "minecraft:recovery_compass", "Sift Walker", "Visit every biome of the Sift",
        {"meadows": in_biome(MEADOWS), "carapace": in_biome(CARAPACE), "hills": in_biome(HILLS)},
        parent=f"{NS}:hills", frame="challenge", requirements=[["meadows"], ["carapace"], ["hills"]])
    adv("ichor", "minecraft:magma_cream", "Iridescent Agony", "Learn the hard way that ichor burns",
        impossible, parent=f"{NS}:meadows")
    adv("giant_skull", "minecraft:skeleton_skull", "Inside the Giant", "Enter a giant skull in the Carapace",
        {"enter": in_structure(f"{NS}:giant_skull")}, parent=f"{NS}:carapace", frame="goal")
    adv("rib_cage", "minecraft:bone", "Under the Ribs", "Stand beneath a fossil rib cage",
        {"enter": in_structure(f"{NS}:rib_cage")}, parent=f"{NS}:carapace")


# ---------------------------------------------------------------------------
# Assets, metadata, icon
# ---------------------------------------------------------------------------
def gen_assets():
    write_json(f"assets/{NS}/lang/en_us.json", {
        f"biome.{NS}.meadows": "Meadows",
        f"biome.{NS}.carapace": "Carapace",
        f"biome.{NS}.hills": "Hills",
        f"{NS}.dimension.the_sift": "The Sift",
    })
    icon = make_icon()
    icon.save(SRC / "pack.png")
    (SRC / f"assets/{NS}").mkdir(parents=True, exist_ok=True)
    icon.save(SRC / f"assets/{NS}/icon.png")


def make_icon():
    from PIL import Image, ImageDraw
    px = 32
    img = Image.new("RGB", (px, px), "#3FC6BA")
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    for y in range(px):  # soft teal sky gradient
        k = y / px
        d.line([(0, y), (px, y)], fill=(int(63 + 80 * k), int(198 + 30 * k), int(186 + 30 * k)))
    d.rectangle([0, 22, px, px], fill="#B8324E")  # red-pink ground
    for x in range(px):
        if rng.random() < 0.6:
            d.line([(x, 22), (x, 22 - rng.randint(1, 3))], fill="#4E9BE0")  # tall blue grass
    for tx, h in ((5, 11), (25, 14), (28, 8)):
        d.rectangle([tx, 22 - h, tx + 1, 22], fill="#D9828F")  # coral towers
        d.ellipse([tx - 2, 22 - h - 3, tx + 3, 22 - h + 1], fill="#F4A9C8")
    d.ellipse([10, 26, 22, 31], fill="#E8579F")  # ichor pool
    d.rectangle([15, 8, 16, 21], fill="#1F3E4A")  # rift
    for i, c in enumerate(("#5FE0D0", "#E8579F", "#FFFFFF")):
        d.line([(15 - i, 9 + i * 3), (15 - i, 19 - i)], fill=c)
    return img.resize((256, 256), Image.NEAREST)


DESCRIPTION = ("Adds The Sift - Minecraft's fourth dimension - with its Meadows, Carapace and Hills biomes, "
               "pink ichor pools, coral towers, white willows, giant fossils and sculk rifts.")


def gen_metadata():
    write_json("pack.mcmeta", {"pack": {"pack_format": DATA_PACK_FORMAT, "description": "The Sift - the fourth dimension"}})
    write_json("fabric.mod.json", {
        "schemaVersion": 1,
        "id": MOD_ID,
        "version": VERSION,
        "name": "The Sift",
        "description": DESCRIPTION,
        "authors": ["BotChainStoopad"],
        "license": "MIT",
        "icon": f"assets/{NS}/icon.png",
        "environment": "*",
        "depends": {"fabricloader": ">=0.15.0", "minecraft": MC_RANGE_FABRIC, "fabric-resource-loader-v0": "*"},
    })
    toml = f'''
modLoader="lowcodefml"
loaderVersion="[1,)"
license="MIT"

[[mods]]
modId="{MOD_ID}"
version="{VERSION}"
displayName="The Sift"
authors="BotChainStoopad"
logoFile="pack.png"
description=\'\'\'{DESCRIPTION}\'\'\'

[[dependencies.{MOD_ID}]]
modId="minecraft"
type="required"
mandatory=true
versionRange="{MC_RANGE_FORGE}"
ordering="NONE"
side="BOTH"
'''
    write_text("META-INF/neoforge.mods.toml", toml)
    write_text("META-INF/mods.toml", toml)
    write_text("LICENSE", "MIT License\n\nCopyright (c) 2026 BotChainStoopad\n\n"
               "Permission is hereby granted, free of charge, to any person obtaining a copy of this software, "
               "to deal in the software without restriction. THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY "
               "OF ANY KIND.")


def build_jar():
    if JAR.exists():
        JAR.unlink()
    with zipfile.ZipFile(JAR, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(SRC.rglob("*")):
            if p.is_file():
                z.write(p, p.relative_to(SRC).as_posix())


def main():
    if SRC.exists():
        shutil.rmtree(SRC)
    SRC.mkdir()
    gen_dimension()
    gen_configured_features()
    gen_placed_features()
    gen_biomes()
    gen_structures()
    gen_loot()
    gen_functions()
    gen_advancements()
    gen_assets()
    gen_metadata()
    build_jar()
    files = sum(1 for p in SRC.rglob("*") if p.is_file())
    print(f"Built {JAR.name}: {files} files, {JAR.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    main()
