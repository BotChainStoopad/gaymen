# Dragon Pet (Roblox)

A blocky, pixel-art dragon pet in classic stud style. It is built entirely from Parts on a ¼-stud pixel grid, with Studs/Inlet surfaces on the big blocks. It needs no meshes, no uploaded assets and no animation IDs, so there is nothing to moderate or re-upload.

| File | What it is |
| --- | --- |
| `DragonPetKit.rbxmx` | Drag into Studio. Contains the `DragonPet` ModuleScript, 6 prebuilt models and the `PetFollow` LocalScript. |
| `DragonPet.luau` | Builds the model, the Motor6D rig, procedural animation and the variants. |
| `PetFollow.client.luau` | Example: hovers the pet beside the local player and feeds walk speed into the flight pose. |
| `build.luau` | Regenerates the `.rbxmx` and `preview.html` with [Lune](https://github.com/lune-org/lune): `lune run roblox/DragonPet/build.luau` |
| `preview.html` | Browser preview of the exact exported rig and animation. |

## Setup

1. Drag `DragonPetKit.rbxmx` into Studio and put the `DragonPetKit` folder in **ReplicatedStorage**.
2. Move `PetFollow` into **StarterPlayer › StarterPlayerScripts**, then press Play.

## API

```lua
local DragonPet = require(ReplicatedStorage.DragonPetKit.DragonPet)

local pet = DragonPet.build("Void")          -- Classic, Frost, Inferno, Void, Golden, Rainbow
pet:ScaleTo(0.75)                            -- 1.0 is about 6.5 studs tall with horns
pet:PivotTo(somewhere)
pet.Parent = workspace

local anim = DragonPet.animate(pet)          -- client only
anim:SetSpeed(1)                             -- 0 hover … 1 full flight (lean, fast flap, tucked legs)
anim:Celebrate()                             -- hatch / level-up: spin, hop, happy ^ ^ eyes
anim:SetEyes("Happy")                        -- "Open" (auto-blinks), "Closed", "Happy"
anim:Destroy()

DragonPet.recolor(pet, "Golden")             -- reskin in place (e.g. on golden/rainbow upgrade)
```

| Variant | Rarity | Notes |
| --- | --- | --- |
| Classic | Rare | Green, cream belly, orange wings |
| Frost | Epic | Glowing ice-blue irises |
| Inferno | Legendary | Neon flame spikes and spade |
| Void | Mythical | Neon pink membranes and spikes |
| Golden | Golden | Reflective gold |
| Rainbow | Rainbow | Body, wings and eyes cycle hue at runtime |

## Rig

```
Root (anchored, invisible, PrimaryPart)
└─ Body ─┬─ Head
         ├─ WingRight / WingLeft
         ├─ ArmRight / ArmLeft
         ├─ LegRight / LegLeft
         └─ Tail1 ─ Tail2 ─ Tail3
```

Animation writes only `Motor6D.Transform`, so it never fights `C0`/`C1`, and it works after `ScaleTo` because offsets follow `Model:GetScale()`. Each pet gets a random phase, so a team of dragons doesn't flap in lockstep.

Every part is `CanCollide/CanTouch/CanQuery = false` and `Massless`. Each part carries a `Role` attribute (Main, Belly, Accent, Membrane, …), and the eye parts carry an `EyeState` attribute, which is how recoloring and blinking find them.

One dragon is 121 parts. If a server shows many pets at once, consider swapping far-away pets for a lower-detail version (for example, skip `DragonPet.animate` beyond about 150 studs).
