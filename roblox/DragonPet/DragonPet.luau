--!strict
--[[
	DragonPet  ·  blocky pixel-art dragon pet (classic stud style)

	Builds a fully rigged, procedurally animated dragon out of plain Parts:
	no meshes, no uploaded assets, no animation IDs. Everything is authored
	on a 0.25-stud "pixel" grid so faces, belly plates and wings read as
	crisp pixel art, and the big blocks carry classic Studs/Inlet surfaces.

	API
		DragonPet.build(variant?: string, options?) -> Model
			variant  : "Classic" | "Frost" | "Inferno" | "Void" | "Golden" | "Rainbow"
			options  : { studs: boolean? }      -- default true

		DragonPet.recolor(model, variant)
		DragonPet.animate(model) -> Controller      -- CLIENT ONLY (RenderStepped)
			Controller:SetSpeed(alpha 0..1)       -- 0 idle hover, 1 full flight
			Controller:SetEyes("Open" | "Closed" | "Happy")
			Controller:Celebrate()                -- hatch / level-up spin + happy eyes
			Controller:Destroy()

	Rig (Motor6D, all driven through .Transform so it never fights C0/C1):
		Root ─ Body ─┬─ Head
		             ├─ WingRight / WingLeft
		             ├─ ArmRight / ArmLeft
		             ├─ LegRight / LegLeft
		             └─ Tail1 ─ Tail2 ─ Tail3

	Model:ScaleTo() is fully supported; animation offsets follow Model:GetScale().
]]

local DragonPet = {}

local P = 0.25 -- studs per pixel
local rad = math.rad

export type Palette = {
	Main: Color3,
	MainDark: Color3,
	Belly: Color3,
	BellyShade: Color3,
	Accent: Color3,
	Membrane: Color3,
	Horn: Color3,
	Eye: Color3,
	Iris: Color3,
	Highlight: Color3,
	Blush: Color3,
	Claw: Color3,
}

export type Variant = {
	Rarity: string,
	Palette: Palette,
	Neon: { [string]: boolean }?,
	Reflectance: { [string]: number }?,
	Rainbow: boolean?,
}

local rgb = Color3.fromRGB

local function palette(p: { [string]: Color3 }): Palette
	return {
		Main = p.Main,
		MainDark = p.MainDark,
		Belly = p.Belly,
		BellyShade = p.BellyShade,
		Accent = p.Accent,
		Membrane = p.Membrane,
		Horn = p.Horn,
		Eye = p.Eye or rgb(30, 26, 48),
		Iris = p.Iris,
		Highlight = p.Highlight or rgb(255, 255, 255),
		Blush = p.Blush or rgb(255, 138, 170),
		Claw = p.Claw or rgb(255, 250, 238),
	}
end

DragonPet.Variants = {
	Classic = {
		Rarity = "Rare",
		Palette = palette({
			Main = rgb(84, 204, 108),
			MainDark = rgb(46, 152, 84),
			Belly = rgb(255, 228, 140),
			BellyShade = rgb(242, 178, 82),
			Accent = rgb(255, 98, 78),
			Membrane = rgb(255, 186, 72),
			Horn = rgb(255, 244, 212),
			Iris = rgb(92, 196, 255),
		}),
	},
	Frost = {
		Rarity = "Epic",
		Palette = palette({
			Main = rgb(124, 198, 255),
			MainDark = rgb(74, 136, 232),
			Belly = rgb(236, 250, 255),
			BellyShade = rgb(176, 222, 252),
			Accent = rgb(96, 108, 255),
			Membrane = rgb(196, 242, 255),
			Horn = rgb(245, 252, 255),
			Iris = rgb(110, 255, 246),
			Blush = rgb(255, 170, 214),
		}),
		Neon = { Iris = true },
	},
	Inferno = {
		Rarity = "Legendary",
		Palette = palette({
			Main = rgb(232, 62, 52),
			MainDark = rgb(160, 28, 40),
			Belly = rgb(255, 216, 92),
			BellyShade = rgb(255, 150, 40),
			Accent = rgb(255, 170, 36),
			Membrane = rgb(255, 128, 36),
			Horn = rgb(58, 38, 46),
			Iris = rgb(255, 226, 64),
			Blush = rgb(255, 150, 120),
		}),
		Neon = { Accent = true, Iris = true },
	},
	Void = {
		Rarity = "Mythical",
		Palette = palette({
			Main = rgb(112, 66, 204),
			MainDark = rgb(66, 34, 138),
			Belly = rgb(224, 186, 255),
			BellyShade = rgb(176, 128, 240),
			Accent = rgb(255, 84, 222),
			Membrane = rgb(255, 128, 232),
			Horn = rgb(40, 30, 62),
			Eye = rgb(16, 10, 30),
			Iris = rgb(255, 104, 255),
			Blush = rgb(255, 120, 200),
		}),
		Neon = { Accent = true, Iris = true, Membrane = true },
	},
	Golden = {
		Rarity = "Golden",
		Palette = palette({
			Main = rgb(255, 196, 46),
			MainDark = rgb(222, 146, 26),
			Belly = rgb(255, 238, 152),
			BellyShade = rgb(255, 208, 86),
			Accent = rgb(255, 248, 196),
			Membrane = rgb(255, 222, 110),
			Horn = rgb(255, 255, 232),
			Eye = rgb(74, 40, 10),
			Iris = rgb(255, 136, 0),
			Blush = rgb(255, 160, 110),
		}),
		Reflectance = { Main = 0.22, MainDark = 0.22, Accent = 0.18, Membrane = 0.15, Horn = 0.15 },
	},
	Rainbow = {
		Rarity = "Rainbow",
		Palette = palette({
			Main = rgb(255, 92, 140),
			MainDark = rgb(200, 52, 110),
			Belly = rgb(255, 246, 220),
			BellyShade = rgb(255, 214, 236),
			Accent = rgb(255, 255, 255),
			Membrane = rgb(120, 220, 255),
			Horn = rgb(255, 255, 255),
			Iris = rgb(255, 255, 255),
		}),
		Neon = { Accent = true },
		Rainbow = true,
	},
} :: { [string]: Variant }

-- Parts large enough to show studs nicely. Small pixel details stay smooth.
local STUDDED_ROLES = { Main = true, MainDark = true, Belly = true, Accent = true, Horn = true }

--------------------------------------------------------------------------
-- Builder
--------------------------------------------------------------------------

type Builder = {
	model: Model,
	variant: Variant,
	studs: boolean,
	bones: { [string]: BasePart },
}

local function px(x: number, y: number, z: number): Vector3
	return Vector3.new(x * P, y * P, z * P)
end

local function applyLook(part: BasePart, role: string, variant: Variant)
	local neon = variant.Neon and variant.Neon[role]
	part.Color = (variant.Palette :: any)[role]
	neon = neon or role == "Highlight"
	part.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
	part.Reflectance = (variant.Reflectance and variant.Reflectance[role]) or 0
end

-- Adds a block. `cf` is the block's centre in model space (studs).
-- The first block added to a bone becomes that bone's Motor6D part; the rest weld to it.
local function block(b: Builder, bone: string, name: string, role: string, size: Vector3, cf: CFrame, eyeState: string?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * P
	part.CFrame = cf
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	applyLook(part, role, b.variant)

	local studded = b.studs and STUDDED_ROLES[role] and size.X >= 2 and size.Z >= 2
	part.TopSurface = if studded then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.BottomSurface = if studded then Enum.SurfaceType.Inlet else Enum.SurfaceType.Smooth

	part:SetAttribute("Role", role)
	if eyeState then
		part:SetAttribute("EyeState", eyeState)
		if eyeState ~= "Open" then
			part.Transparency = 1
		end
	end

	local root = b.bones[bone]
	if root then
		local weld = Instance.new("Weld")
		weld.Name = "Weld"
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = root.CFrame:Inverse() * cf
		weld.Parent = part
	else
		b.bones[bone] = part
	end
	part.Parent = b.model
	return part
end

-- Axis-aligned block from pixel size + pixel centre.
local function box(b: Builder, bone: string, name: string, role: string, sx: number, sy: number, sz: number, cx: number, cy: number, cz: number, eyeState: string?)
	return block(b, bone, name, role, Vector3.new(sx, sy, sz), CFrame.new(px(cx, cy, cz)), eyeState)
end

local function joint(b: Builder, name: string, parentBone: string, childBone: string, pivot: CFrame)
	local part0, part1 = b.bones[parentBone], b.bones[childBone]
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * pivot
	motor.C1 = part1.CFrame:Inverse() * pivot
	motor.Parent = part1
end

--------------------------------------------------------------------------
-- Anatomy (pixel coordinates · facing -Z · +X is the dragon's right)
--------------------------------------------------------------------------

local function buildBody(b: Builder)
	box(b, "Body", "Body", "Main", 8, 8, 8, 0, 8, 0)

	-- Belly plates: shade frame with three cream plates
	box(b, "Body", "BellyBase", "BellyShade", 6, 6.5, 0.4, 0, 7.75, -4.2)
	for i, y in { 5.75, 7.75, 9.75 } do
		box(b, "Body", "BellyPlate" .. i, "Belly", 5, 1.5, 0.4, 0, y, -4.4)
	end

	-- Back spikes (stepped pixel fins)
	for i, y in { 10, 6.75 } do
		box(b, "Body", "BackSpike" .. i, "Accent", 2, 2, 1.5, 0, y, 4.75)
		box(b, "Body", "BackSpikeTip" .. i, "Accent", 1, 1, 1, 0, y + 0.5, 6)
	end

	-- Side spots (pixel freckles)
	for _, s in { 1, -1 } do
		box(b, "Body", "Spot", "MainDark", 0.3, 1, 1, 4.1 * s, 9.5, 1.5)
		box(b, "Body", "Spot", "MainDark", 0.3, 1, 1, 4.1 * s, 8.5, 2.5)
	end
end

local function buildHead(b: Builder)
	box(b, "Head", "Head", "Main", 12, 10, 8, 0, 16, -1)
	box(b, "Head", "Snout", "Main", 8, 4, 3, 0, 13, -6.5)
	box(b, "Head", "Jaw", "MainDark", 7, 0.5, 2.5, 0, 10.85, -6.25)

	-- Snout details
	for _, s in { 1, -1 } do
		box(b, "Head", "Nostril", "Eye", 1, 0.3, 1, 1.75 * s, 15.1, -7)
	end
	box(b, "Head", "Mouth", "Eye", 3, 0.75, 0.3, 0, 11.875, -8.1)
	for _, s in { 1, -1 } do
		box(b, "Head", "MouthCorner", "Eye", 1, 0.75, 0.3, 2 * s, 12.375, -8.1)
	end
	box(b, "Head", "Tongue", "Blush", 1.5, 0.75, 0.3, -0.25, 11.375, -8.05)
	box(b, "Head", "Fang", "Claw", 1, 1.25, 1, 1.75, 10.4, -7.4)

	-- Eyes (Open / Closed / Happy states for blinking & emotes)
	for _, s in { 1, -1 } do
		local cx = 3 * s
		box(b, "Head", "Eye", "Eye", 3, 4, 0.4, cx, 18, -5.15, "Open")
		box(b, "Head", "Iris", "Iris", 3, 1, 0.3, cx, 16.5, -5.4, "Open")
		box(b, "Head", "Sparkle", "Highlight", 1, 1, 0.3, cx + 1, 19.5, -5.4, "Open")
		box(b, "Head", "Sparkle2", "Highlight", 1, 1, 0.3, cx - 1, 17.5, -5.4, "Open")

		box(b, "Head", "EyeClosed", "Eye", 3, 1, 0.4, cx, 17, -5.15, "Closed")

		-- ^ ^ arc
		box(b, "Head", "EyeHappy", "Eye", 1, 1.5, 0.4, cx - 1.5, 17.25, -5.15, "Happy")
		box(b, "Head", "EyeHappy", "Eye", 2, 1, 0.4, cx, 18.5, -5.15, "Happy")
		box(b, "Head", "EyeHappy", "Eye", 1, 1.5, 0.4, cx + 1.5, 17.25, -5.15, "Happy")

		box(b, "Head", "Blush", "Blush", 2, 1, 0.3, 5 * s, 15.5, -5.15)
	end

	-- Horns: stepped pixel staircase sweeping up, back and out
	for _, s in { 1, -1 } do
		box(b, "Head", "Horn", "Horn", 2, 2, 2, 3.5 * s, 22, 0.5)
		box(b, "Head", "Horn", "Horn", 2, 2, 2, 4 * s, 23.5, 2)
		box(b, "Head", "HornTip", "Horn", 1, 1.5, 1.5, 4.5 * s, 25, 3.25)
	end

	-- Crest running over the crown and down the back of the head
	box(b, "Head", "Crest", "Accent", 2, 1.5, 2, 0, 21.75, -2)
	box(b, "Head", "Crest", "Accent", 2, 2, 2, 0, 22, 0.5)
	box(b, "Head", "Crest", "Accent", 2, 2, 1.5, 0, 20, 3.5)
	box(b, "Head", "Crest", "Accent", 2, 1.5, 1.5, 0, 16.5, 3.5)

	-- Ear fins
	for _, s in { 1, -1 } do
		box(b, "Head", "EarFin", "Membrane", 1, 3, 3, 6.5 * s, 18, 1)
		box(b, "Head", "EarFin", "Membrane", 1, 2, 2, 6.5 * s, 19, 3.5)
		box(b, "Head", "EarFinTip", "Membrane", 1, 1, 1, 6.5 * s, 20, 5)
	end

	-- Head spots
	for _, s in { 1, -1 } do
		box(b, "Head", "Spot", "MainDark", 1.5, 0.3, 1.5, 3 * s, 21.1, -3)
	end
end

local function buildLimbs(b: Builder)
	for _, s in { 1, -1 } do
		local side = if s == 1 then "Right" else "Left"

		local arm = "Arm" .. side
		box(b, arm, "Arm", "Main", 2, 4, 2, 4.5 * s, 8, -3)
		box(b, arm, "Claw", "Claw", 1, 1, 0.5, 4 * s, 6.5, -4.25)
		box(b, arm, "Claw", "Claw", 1, 1, 0.5, 5 * s, 6.5, -4.25)
		joint(b, arm, "Body", arm, CFrame.new(px(4.5 * s, 9.5, -3)))

		local leg = "Leg" .. side
		box(b, leg, "Leg", "Main", 3, 3, 4, 2.5 * s, 3, 0)
		box(b, leg, "Foot", "Main", 3.5, 1.5, 5, 2.75 * s, 0.75, -1)
		box(b, leg, "Sole", "BellyShade", 3, 0.3, 4, 2.75 * s, -0.1, -1)
		box(b, leg, "Toe", "Claw", 1, 1, 0.5, 1.75 * s, 0.5, -3.75)
		box(b, leg, "Toe", "Claw", 1, 1, 0.5, 3.75 * s, 0.5, -3.75)
		joint(b, leg, "Body", leg, CFrame.new(px(2.5 * s, 4, -0.5)))
	end
end

local WING_SWEEP = 30 -- degrees swept back
local WING_LIFT = 32 -- degrees raised

-- bottom edge (pixels) of each 1px membrane column, shoulder -> tip
local WING_EDGE = { -2.5, -3, -3.5, -4.5, -5.5, -4.25, -3.5, -4, -5, -3.5, -2.5, 0 }

local function wingPivot(s: number): CFrame
	return CFrame.new(px(3 * s, 11, 4.6)) * CFrame.Angles(0, rad(-WING_SWEEP * s), 0) * CFrame.Angles(0, 0, rad(WING_LIFT * s))
end

local function buildWings(b: Builder)
	for _, s in { 1, -1 } do
		local bone = "Wing" .. (if s == 1 then "Right" else "Left")
		local pivot = wingPivot(s)
		-- local wing space: +x runs out along the wing (mirrored per side), +y up, z is thickness
		local function w(name: string, role: string, sx: number, sy: number, sz: number, cx: number, cy: number)
			block(b, bone, name, role, Vector3.new(sx, sy, sz), pivot * CFrame.new(px(cx * s, cy, 0)))
		end

		-- arm bone, stepping up toward a claw
		w("WingBone", "MainDark", 4.5, 1.5, 1.5, 2.25, 1.75)
		w("WingBone", "MainDark", 4.5, 1.5, 1.5, 6.25, 3.25)
		w("WingBone", "MainDark", 3.5, 1.5, 1.5, 9.75, 4.75)
		w("WingClaw", "Claw", 1, 1.5, 1, 11.5, 6.25)

		-- membrane: 1-pixel columns from the bone down to a scalloped trailing edge,
		-- dipping to a point under each finger and arching up between them
		for i, bottom in WING_EDGE do
			local top = if i <= 4 then 1.25 elseif i <= 8 then 2.75 else 4.25
			w("Membrane", "Membrane", 1, top - bottom, 0.5, i - 0.5, (top + bottom) / 2)
		end

		-- slim finger struts running down to the scallop points
		w("Finger", "MainDark", 0.75, 7.5, 0.75, 4.5, -1.75)
		w("Finger", "MainDark", 0.75, 7, 0.75, 8.5, 0)

		joint(b, bone, "Body", bone, pivot)
	end
end

local function buildTail(b: Builder)
	box(b, "Tail1", "Tail1", "Main", 4, 4, 4, 0, 6, 5.5)
	box(b, "Tail1", "TailSpike", "Accent", 1, 1, 1.5, 0, 8.5, 6)
	joint(b, "Tail1", "Body", "Tail1", CFrame.new(px(0, 6, 4)))

	box(b, "Tail2", "Tail2", "Main", 3, 3, 4, 0, 7, 9)
	box(b, "Tail2", "TailSpike", "Accent", 1, 1, 1.5, 0, 9, 9.5)
	joint(b, "Tail2", "Tail1", "Tail2", CFrame.new(px(0, 7, 7.5)))

	box(b, "Tail3", "Tail3", "Main", 2, 2, 4, 0, 8.5, 12.5)
	-- pixel diamond spade, faces backward so it reads from the follow camera
	for i, w in { 2, 4, 6, 4, 2 } do
		box(b, "Tail3", "Spade", "Accent", w, 1, 2, 0, 8.5 + (i - 3), 15.25)
	end
	joint(b, "Tail3", "Tail2", "Tail3", CFrame.new(px(0, 8.5, 11)))
end

--------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------

function DragonPet.build(variantName: string?, options: { studs: boolean? }?): Model
	local name = variantName or "Classic"
	local variant = DragonPet.Variants[name]
	assert(variant, `Unknown dragon variant "{name}"`)

	local model = Instance.new("Model")
	model.Name = name .. "Dragon"
	model:SetAttribute("Variant", name)
	model:SetAttribute("Rarity", variant.Rarity)

	local b: Builder = {
		model = model,
		variant = variant,
		studs = not (options and options.studs == false),
		bones = {},
	}

	-- Invisible anchor the follow script moves. Sits at the body's centre.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(px(0, 8, 0))
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	b.bones.Root = root
	model.PrimaryPart = root

	buildBody(b)
	joint(b, "Body", "Root", "Body", CFrame.new(px(0, 8, 0)))

	buildHead(b)
	joint(b, "Head", "Body", "Head", CFrame.new(px(0, 12, -1)))

	buildLimbs(b)
	buildWings(b)
	buildTail(b)

	return model
end

function DragonPet.recolor(model: Model, variantName: string)
	local variant = DragonPet.Variants[variantName]
	assert(variant, `Unknown dragon variant "{variantName}"`)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Role")
			if role then
				applyLook(part, role :: string, variant)
			end
		end
	end
	model:SetAttribute("Variant", variantName)
	model:SetAttribute("Rarity", variant.Rarity)
end

--------------------------------------------------------------------------
-- Procedural animation (client)
--------------------------------------------------------------------------

local Controller = {}
Controller.__index = Controller

export type Controller = typeof(setmetatable(
	{} :: {
		_model: Model,
		_conn: RBXScriptConnection?,
		_speed: number,
		_targetSpeed: number,
		_eyes: string,
		_eyeParts: { BasePart },
		_celebrateAt: number,
		_nextBlink: number,
		_shownEyes: string,
	},
	Controller
))

local function sin(x: number): number
	return math.sin(x)
end

function DragonPet.animate(model: Model): Controller
	local RunService = game:GetService("RunService")

	local motors: { [string]: Motor6D } = {}
	local eyeParts: { BasePart } = {}
	local rainbowParts: { [string]: { BasePart } } = {}
	for _, inst in model:GetDescendants() do
		if inst:IsA("Motor6D") then
			motors[inst.Name] = inst
		elseif inst:IsA("BasePart") then
			if inst:GetAttribute("EyeState") then
				table.insert(eyeParts, inst)
			end
			local role = inst:GetAttribute("Role") :: string?
			if role then
				rainbowParts[role] = rainbowParts[role] or {}
				table.insert(rainbowParts[role], inst)
			end
		end
	end

	local self = setmetatable({
		_model = model,
		_conn = nil :: RBXScriptConnection?,
		_speed = 0,
		_targetSpeed = 0,
		_eyes = "Open",
		_eyeParts = eyeParts,
		_celebrateAt = -math.huge,
		_nextBlink = os.clock() + 1.5,
		_shownEyes = "Open",
	}, Controller)

	local rng = Random.new()
	local phase = rng:NextNumber(0, 100) -- desync pets so a team never flaps in lockstep
	local isRainbow = DragonPet.Variants[model:GetAttribute("Variant") :: string]
		and DragonPet.Variants[model:GetAttribute("Variant") :: string].Rainbow

	self._conn = RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local t = now + phase
		local scale = model:GetScale()

		self._speed += (self._targetSpeed - self._speed) * (1 - math.exp(-dt * 6))
		local speed = self._speed

		-- celebrate: 0..1 over 0.9s
		local c = math.clamp((now - self._celebrateAt) / 0.9, 0, 1)
		local celebrating = c < 1
		local spin = if celebrating then (1 - (1 - c) ^ 3) * math.pi * 2 else 0
		local hop = if celebrating then sin(c * math.pi) * 1.4 else 0

		-- Body: hover bob, lean into flight, celebrate spin + hop
		local bob = sin(t * 2.4) * 0.12 + hop
		local lean = -rad(14) * speed
		motors.Body.Transform = CFrame.new(0, bob * scale, 0)
			* CFrame.Angles(lean + sin(t * 2.4 + 0.8) * rad(2), spin, sin(t * 1.2) * rad(2))

		-- Head: lazy look-around, counter the lean so the face stays on camera
		motors.Head.Transform = CFrame.Angles(
			-lean * 0.6 + sin(t * 2.4 + 1.6) * rad(3),
			sin(t * 0.7) * rad(8) * (1 - speed),
			sin(t * 0.9) * rad(4)
		)

		-- Wings: flap faster and wider in flight; a quick flurry when celebrating
		local flapRate = 6 + speed * 5 + (if celebrating then 8 else 0)
		local flapAmp = rad(22 + speed * 16)
		local flap = sin(t * flapRate) * flapAmp
		motors.WingRight.Transform = CFrame.Angles(0, 0, flap)
		motors.WingLeft.Transform = CFrame.Angles(0, 0, -flap)

		-- Arms: tiny paddles; Legs: dangle, tuck back in flight
		local paddle = sin(t * 2.4 + 0.4) * rad(10)
		motors.ArmRight.Transform = CFrame.Angles(paddle - rad(20) * speed, 0, 0)
		motors.ArmLeft.Transform = CFrame.Angles(-paddle - rad(20) * speed, 0, 0)
		local dangle = sin(t * 2.4 + 1.2) * rad(7)
		motors.LegRight.Transform = CFrame.Angles(dangle + rad(35) * speed, 0, 0)
		motors.LegLeft.Transform = CFrame.Angles(-dangle + rad(35) * speed, 0, 0)

		-- Tail: travelling wave, streams out straighter in flight
		local swing = rad(14) * (1 - speed * 0.6)
		for i = 1, 3 do
			local k = t * 2.2 - i * 0.75
			motors["Tail" .. i].Transform = CFrame.Angles(sin(k + 1) * rad(5) + rad(6) * speed, sin(k) * swing, 0)
		end

		-- Eyes: auto blink unless an emote owns them
		local eyes = self._eyes
		if celebrating then
			eyes = "Happy"
		elseif eyes == "Open" then
			if now >= self._nextBlink then
				if now >= self._nextBlink + 0.12 then
					self._nextBlink = now + rng:NextNumber(2.2, 5)
					if rng:NextNumber() < 0.2 then
						self._nextBlink = now + 0.25 -- occasional double blink
					end
				else
					eyes = "Closed"
				end
			end
		end
		if eyes ~= self._shownEyes then
			self._shownEyes = eyes
			for _, part in self._eyeParts do
				part.Transparency = if part:GetAttribute("EyeState") == eyes then 0 else 1
			end
		end

		if isRainbow then
			local h = (t * 0.12) % 1
			local function paint(role: string, hue: number, sat: number, val: number)
				for _, part in rainbowParts[role] or {} do
					part.Color = Color3.fromHSV(hue % 1, sat, val)
				end
			end
			paint("Main", h, 0.62, 1)
			paint("MainDark", h, 0.75, 0.82)
			paint("Membrane", h + 0.33, 0.5, 1)
			paint("Iris", h + 0.5, 0.6, 1)
		end
	end)

	return self
end

function Controller.SetSpeed(self: Controller, alpha: number)
	self._targetSpeed = math.clamp(alpha, 0, 1)
end

function Controller.SetEyes(self: Controller, state: string)
	self._eyes = state
end

function Controller.Celebrate(self: Controller)
	self._celebrateAt = os.clock()
end

function Controller.Destroy(self: Controller)
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

return DragonPet
