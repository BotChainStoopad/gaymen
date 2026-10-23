--[[
	Hollowmourne — 1 in 1,666,666,666

	Horror aura under a blood moon: ghost-fire jack-o'-lanterns with carved
	faces, a floating witch hat, spectral hands that reach up out of blood-red
	cracks, a ring of blue-flame candles, ghost wisps, bats, red lightning and
	ash. Built only from Parts, Highlights, Trails, ParticleEmitters and
	Surface/Billboard GUIs with textures that ship with the Roblox client.

		local aura = HollowAura.new(character, { parent = workspace.LocalAuras, groundY = fn })
		RunService.RenderStepped:Connect(function(dt) aura:Step(dt) end)
		aura:Hold() / aura:Spawn() / aura:Pulse(1) / aura:Destroy()

	Step never yields and only touches instance properties, so build.luau runs it under Lune.
]]

local Aura = {}
Aura.__index = Aura

Aura.Name = "Hollowmourne"
Aura.Odds = "1 in 1,666,666,666"
Aura.Condition = "Blood Moon"
Aura.Lore = "Something under the hollow learned your name. Every candle you light is one more it can see you by, and it never closes its eye."

local TAU = math.pi * 2
local BEAT = 3.4

local SHADOW = Color3.fromRGB(10, 12, 30)
local NAVY = Color3.fromRGB(18, 26, 70)
local SPECT = Color3.fromRGB(80, 140, 255)
local FROST = Color3.fromRGB(190, 220, 255)
local BLOOD = Color3.fromRGB(255, 20, 10)
local EMBER = Color3.fromRGB(255, 90, 40)
local WAX = Color3.fromRGB(196, 180, 164)

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"

-- Swapped out by build.luau, which runs Step under Lune where :Emit does not exist.
Aura.emit = function(emitter, n)
	emitter:Emit(n)
end

local rng = Random.new()
local function rr(a, b)
	return a + (b - a) * rng:NextNumber()
end
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function easeOut3(x)
	return 1 - (1 - clamp01(x)) ^ 3
end
local function easeIn3(x)
	return clamp01(x) ^ 3
end

---------------------------------------------------------------------------
-- builders
---------------------------------------------------------------------------
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function seq(...)
	local args = { ... }
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end
local function cseq(...)
	local args = { ... }
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, ColorSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return ColorSequence.new(kps)
end

local function circle(parent, d, z)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(d, d),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	return f
end
local function ring(parent, d, thick, color, transp, z)
	local f = circle(parent, d, z)
	local s = new("UIStroke", { Thickness = thick, Color = color, Transparency = transp or 0 }, f)
	return f, s
end
local function line(parent, x1, y1, x2, y2, thick, color, transp, z)
	local dx, dy = x2 - x1, y2 - y1
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.new(math.sqrt(dx * dx + dy * dy), thick, 0, thick),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BackgroundTransparency = transp or 0,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
end
local function block(parent, x, y, w, h, rot, color, z)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = rot or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
end

local function surface(p, face, ppS, brightness)
	local g = new("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = ppS,
		LightInfluence = 0,
		Brightness = brightness,
		ZOffset = 1,
		ResetOnSpawn = false,
	}, p)
	local canvas = new("Frame", { Name = "Canvas", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, g)
	return g, canvas
end

local function spectral(p)
	new("Highlight", {
		Adornee = p,
		FillTransparency = 1,
		OutlineColor = SPECT,
		OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	}, p)
end

local function blueFire(parent, size, rate)
	return new("ParticleEmitter", {
		Name = "GhostFire",
		Texture = TEX_FIRE,
		Rate = rate,
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(10, 10),
		Size = seq(0, size, 0.5, size * 0.7, 1, 0),
		Color = cseq(0, FROST, 0.35, SPECT, 1, NAVY),
		Transparency = seq(0, 0.1, 0.7, 0.4, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		Rotation = NumberRange.new(-20, 20),
	}, parent)
end

-- jagged branching cracks for the ground canvas
local function cracks(canvas, seed)
	local r = Random.new(seed)
	local function walk(x, y, a, len, thick, depth)
		local px, py = x, y
		for _ = 1, len do
			a += r:NextNumber(-0.6, 0.6)
			local step = r:NextNumber(0.02, 0.045)
			local nx, ny = px + math.cos(a) * step, py + math.sin(a) * step
			if (nx - 0.5) ^ 2 + (ny - 0.5) ^ 2 > 0.22 then
				return
			end
			line(canvas, px, py, nx, ny, thick, BLOOD, 0)
			if depth > 0 and r:NextNumber() < 0.18 then
				walk(nx, ny, a + r:NextNumber(-1.3, 1.3), math.floor(len * 0.5), math.max(1, thick - 1), depth - 1)
			end
			px, py = nx, ny
		end
	end
	for i = 0, 8 do
		local a = i / 9 * TAU + r:NextNumber(-0.2, 0.2)
		walk(0.5 + math.cos(a) * 0.04, 0.5 + math.sin(a) * 0.04, a, 14, 4, 2)
	end
	for _ = 1, 8 do
		local a = r:NextNumber() * TAU
		local d = r:NextNumber(0.15, 0.35)
		walk(0.5 + math.cos(a) * d, 0.5 + math.sin(a) * d, r:NextNumber() * TAU, 7, 2, 1)
	end
	ring(canvas, 0.96, 6, BLOOD, 0.35)
	ring(canvas, 0.93, 2, EMBER, 0.2)
end

-- carved face drawn on a plate in front of each lantern
local function carvedFace(canvas)
	local c = FROST
	block(canvas, 0.32, 0.36, 0.16, 0.16, 45, c)
	block(canvas, 0.68, 0.36, 0.16, 0.16, 45, c)
	block(canvas, 0.5, 0.52, 0.08, 0.08, 45, c)
	block(canvas, 0.5, 0.72, 0.56, 0.1, 0, c)
	for i = 0, 4 do
		local x = 0.28 + i * 0.11
		block(canvas, x, i % 2 == 0 and 0.66 or 0.79, 0.06, 0.06, 45, c)
	end
end

---------------------------------------------------------------------------
-- Aura
---------------------------------------------------------------------------
function Aura.new(character, opts)
	opts = opts or {}
	local self = setmetatable({}, Aura)
	self.character = character
	self.root = character:FindFirstChild("HumanoidRootPart")
	self.head = character:FindFirstChild("Head")
	self.groundY = opts.groundY or function(root)
		return root.CFrame.Position.Y - 3
	end
	self.t = rr(0, 10)
	self.S = 0
	self.P = 0
	self.spawnT = 0
	self.spawning = true
	self.held = false
	self.beat = 1.2
	self.timers = { storm = 3, arc = 1, crackle = 0 }
	self.bolts = {}
	self.waveCursor = 1

	local F = new("Folder", { Name = "Hollowmourne_" .. character.Name })
	self.folder = F

	-- blood-red cracks under the player
	self.crackPart = part({ Size = Vector3.new(20, 0.05, 20), Transparency = 1, Name = "Cracks" }, F)
	local crackGui, crackCv = surface(self.crackPart, Enum.NormalId.Top, 32, 3)
	cracks(crackCv, 1666)
	self.crackGui = crackGui
	self.floorLight = new("PointLight", { Color = BLOOD, Range = 16, Brightness = 3, Shadows = false }, self.crackPart)

	-- candle ring with blue flames
	self.candles = {}
	for i = 0, 12 do
		local a = i / 13 * TAU
		local h = rr(0.6, 1.2)
		local c = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.3, 0.3), Color = WAX, Material = Enum.Material.SmoothPlastic, Name = "Candle" }, F)
		local wick = new("Attachment", { Position = Vector3.new(h * 0.5 + 0.1, 0, 0), Orientation = Vector3.new(0, 0, -90) }, c)
		blueFire(wick, 0.45, 18)
		if i % 4 == 0 then
			new("PointLight", { Color = SPECT, Range = 6, Brightness = 1.5, Shadows = false }, wick)
		end
		table.insert(self.candles, { part = c, a = a, h = h })
	end

	-- ghost-fire jack-o'-lanterns
	self.lanterns = {}
	for i = 1, 3 do
		local shell = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.45, 1.15, 1.45),
			Color = NAVY,
			Material = Enum.Material.SmoothPlastic,
			Name = "Lantern" .. i,
		}, F)
		spectral(shell)
		local face = part({ Size = Vector3.new(1.2, 1, 0.05), Transparency = 1, Name = "Face" }, F)
		local fg, fcv = surface(face, Enum.NormalId.Front, 60, 4)
		carvedFace(fcv)
		local stem = part({ Size = Vector3.new(0.14, 0.34, 0.14), Color = SHADOW, Name = "Stem" }, F)
		local top = new("Attachment", { Position = Vector3.new(0, 0.55, 0) }, shell)
		blueFire(top, 1.1, 30)
		local light = new("PointLight", { Color = SPECT, Range = 9, Brightness = 2.5, Shadows = false }, shell)
		local t0 = new("Attachment", { Position = Vector3.new(0, 0.3, 0) }, shell)
		local t1 = new("Attachment", { Position = Vector3.new(0, -0.3, 0) }, shell)
		new("Trail", {
			Attachment0 = t0,
			Attachment1 = t1,
			Lifetime = 0.5,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2.5,
			Color = cseq(0, FROST, 0.4, SPECT, 1, NAVY),
			Transparency = seq(0, 0.1, 1, 1),
			WidthScale = seq(0, 1, 1, 0),
		}, shell)
		table.insert(self.lanterns, { shell = shell, face = face, faceGui = fg, stem = stem, light = light, ph = (i - 1) / 3 * TAU, i = i })
	end

	-- floating witch hat: stacked, bent cylinders over a wide brim
	self.hat = {}
	local brim = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2.6, 2.6), Color = SHADOW, Name = "HatBrim" }, F)
	spectral(brim)
	table.insert(self.hat, { part = brim, y = 0, x = 0, size = brim.Size })
	for k = 0, 5 do
		local d = 1.25 * (1 - k / 6.2)
		local seg = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, d, d), Color = SHADOW, Name = "HatCone" }, F)
		local bend = (k / 5) ^ 2.2
		table.insert(self.hat, { part = seg, y = 0.2 + k * 0.32 - bend * 0.25, x = -bend * 0.6, size = seg.Size })
	end
	local band = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 1.27, 1.27), Color = SPECT, Material = Enum.Material.Neon, Name = "HatBand" }, F)
	table.insert(self.hat, { part = band, y = 0.16, x = 0, size = band.Size })

	-- hands reaching up out of the ground
	self.hands = {}
	for i = 1, 6 do
		local pieces = {}
		local function piece(name, size)
			local p = part({ Size = size, Color = NAVY, Material = Enum.Material.SmoothPlastic, Name = name }, F)
			table.insert(pieces, p)
			return p
		end
		local hand = {
			fore = piece("Forearm", Vector3.new(0.55, 3, 0.55)),
			palm = piece("Palm", Vector3.new(0.75, 0.8, 0.26)),
			thumb = piece("Thumb", Vector3.new(0.15, 0.5, 0.15)),
			fingers = {},
			pieces = pieces,
		}
		for k = 1, 4 do
			local len = ({ 0.62, 0.78, 0.74, 0.55 })[k]
			table.insert(hand.fingers, { a = piece("Finger", Vector3.new(0.14, len, 0.14)), b = piece("Claw", Vector3.new(0.1, 0.38, 0.1)), len = len, x = -0.27 + (k - 1) * 0.18 })
		end
		local model = new("Model", { Name = "Hand" .. i }, F)
		for _, p in pieces do
			p.Parent = model
		end
		new("Highlight", {
			Adornee = model,
			FillTransparency = 1,
			OutlineColor = SPECT,
			OutlineTransparency = 0.1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, model)
		hand.model = model
		self:_placeHand(hand)
		hand.t = -(i - 1) * 0.9
		table.insert(self.hands, hand)
	end

	-- ghost wisps with trails
	self.wisps = {}
	for i = 1, 5 do
		local p = part({ Size = Vector3.one * 0.2, Transparency = 1, Name = "Wisp" .. i }, F)
		local bb = new("BillboardGui", { Adornee = p, Size = UDim2.fromScale(1.6, 1.6), LightInfluence = 0, Brightness = 2.4, ResetOnSpawn = false }, p)
		local body = circle(bb, 0.8)
		body.BackgroundColor3 = SPECT
		body.BackgroundTransparency = 0.15
		body.Size = UDim2.fromScale(0.72, 0.84)
		new("UIGradient", { Rotation = 90, Color = cseq(0, FROST, 1, SPECT), Transparency = seq(0, 0, 0.8, 0.2, 1, 1) }, body)
		for _, e in { { 0.36, 0.38 }, { 0.64, 0.38 }, { 0.5, 0.64 } } do
			local hole = circle(bb, 0.16, 2)
			hole.Position = UDim2.fromScale(e[1], e[2])
			hole.Size = UDim2.fromScale(0.14, e[2] > 0.5 and 0.2 or 0.17)
			hole.BackgroundColor3 = SHADOW
			hole.BackgroundTransparency = 0
		end
		local t0 = new("Attachment", { Position = Vector3.new(0, 0.25, 0) }, p)
		local t1 = new("Attachment", { Position = Vector3.new(0, -0.25, 0) }, p)
		new("Trail", {
			Attachment0 = t0,
			Attachment1 = t1,
			Lifetime = 0.8,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2,
			Color = cseq(0, FROST, 1, SPECT),
			Transparency = seq(0, 0.2, 1, 1),
			WidthScale = seq(0, 1, 1, 0),
		}, p)
		table.insert(self.wisps, { part = p, gui = bb, ph = (i - 1) / 5 * TAU, r = rr(3.5, 6.5), sp = rr(0.5, 0.9) * (i % 2 == 0 and 1 or -1), y = rr(2, 9) })
	end

	-- bats
	self.bats = {}
	for i = 1, 10 do
		local body = part({ Size = Vector3.new(0.22, 0.2, 0.4), Color = Color3.fromRGB(6, 2, 4), Name = "Bat" .. i }, F)
		local wings = {}
		for _ = 1, 2 do
			table.insert(wings, part({ Size = Vector3.new(0.9, 0.04, 0.4), Color = Color3.fromRGB(6, 2, 4), Name = "BatWing" }, F))
		end
		table.insert(self.bats, { body = body, wings = wings, a = rr(0, TAU), r = rr(7, 12), y = rr(10, 15), sp = rr(0.35, 0.7) * (i % 2 == 0 and -1 or 1), ph = rr(0, TAU), s = rr(0.7, 1.2) })
	end

	-- particles
	self.groundHost = part({ Size = Vector3.new(13, 0.2, 13), Transparency = 1, Name = "Ground" }, F)
	new("ParticleEmitter", {
		Name = "SpiritEmbers",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SPARK,
		Rate = 45,
		Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(12, 12),
		Size = seq(0, 0.1, 0.5, 0.28, 1, 0),
		Color = cseq(0, SPECT, 0.7, FROST, 1, SPECT),
		Transparency = seq(0, 1, 0.15, 0, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	}, self.groundHost)
	new("ParticleEmitter", {
		Name = "BloodEmbers",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SPARK,
		Rate = 14,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(15, 15),
		Size = seq(0, 0.1, 0.5, 0.22, 1, 0),
		Color = cseq(0, EMBER, 1, BLOOD),
		Transparency = seq(0, 1, 0.15, 0, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	}, self.groundHost)
	new("ParticleEmitter", {
		Name = "Smoke",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SMOKE,
		Rate = 6,
		Lifetime = NumberRange.new(4, 6.5),
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(30, 30),
		Size = seq(0, 2.5, 1, 7),
		Color = cseq(0, Color3.fromRGB(8, 2, 4), 1, Color3.fromRGB(4, 1, 2)),
		Transparency = seq(0, 1, 0.25, 0.45, 1, 1),
		LightEmission = 0,
		LightInfluence = 0,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
	}, self.groundHost)
	new("ParticleEmitter", {
		Name = "Mist",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SMOKE,
		Rate = 4,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(70, 70),
		Size = seq(0, 3, 1, 8),
		Color = cseq(0, Color3.fromRGB(40, 60, 130), 1, Color3.fromRGB(20, 30, 80)),
		Transparency = seq(0, 1, 0.3, 0.7, 1, 1),
		LightEmission = 0.3,
		LightInfluence = 0,
		Rotation = NumberRange.new(0, 360),
	}, self.groundHost)
	self.skyHost = part({ Size = Vector3.new(24, 0.2, 24), Transparency = 1, Name = "Ash" }, F)
	new("ParticleEmitter", {
		Name = "Ash",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Bottom,
		Texture = TEX_SPARK,
		Rate = 22,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(20, 20),
		Size = seq(0, 0.12, 1, 0.08),
		Color = cseq(0, EMBER, 1, BLOOD),
		Transparency = seq(0, 1, 0.1, 0.2, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		RotSpeed = NumberRange.new(-180, 180),
	}, self.skyHost)
	self.burstHost = part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Transparency = 1, Name = "Burst" }, F)
	self.burst = new("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Texture = TEX_SPARK,
		Rate = 0,
		Lifetime = NumberRange.new(0.9, 1.8),
		Speed = NumberRange.new(12, 28),
		Drag = 3.5,
		Size = seq(0, 0.5, 1, 0),
		Color = cseq(0, FROST, 0.5, SPECT, 1, BLOOD),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
	}, self.burstHost)

	-- shockwave rings
	self.waves = {}
	for i = 1, 3 do
		local p = part({ Size = Vector3.new(1, 0.05, 1), Transparency = 1, Name = "Shockwave" .. i }, F)
		local g, cv = surface(p, Enum.NormalId.Top, 12, 3)
		local _, s1 = ring(cv, 0.98, 6, BLOOD)
		local _, s2 = ring(cv, 0.9, 16, EMBER, 0.6)
		g.Enabled = false
		table.insert(self.waves, { part = p, gui = g, strokes = { s1, s2 }, age = 1, str = 1 })
	end

	-- lightning segment pool
	self.segs = {}
	for _ = 1, 150 do
		table.insert(self.segs, part({ Size = Vector3.new(0.16, 0.16, 1), Color = BLOOD, Material = Enum.Material.Neon, Transparency = 1, Name = "Bolt" }, F))
	end
	self.boltLight = new("PointLight", { Color = BLOOD, Range = 30, Brightness = 0, Shadows = false }, self.crackPart)

	-- gothic name tag
	self.tag = new("BillboardGui", {
		Name = "AuraTag",
		Adornee = self.head,
		Size = UDim2.fromScale(10, 2.5),
		StudsOffset = Vector3.new(0, 4.6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 160,
		ResetOnSpawn = false,
	}, F)
	local odds = new("TextLabel", {
		Name = "Odds",
		Size = UDim2.fromScale(1, 0.26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = Aura.Odds,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
	}, self.tag)
	new("UIStroke", { Color = Color3.fromRGB(120, 0, 0), Thickness = 1.5 }, odds)
	local nm = new("TextLabel", {
		Name = "Name",
		Size = UDim2.fromScale(1, 0.74),
		Position = UDim2.fromScale(0, 0.26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GrenzeGotisch,
		Text = Aura.Name,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
	}, self.tag)
	new("UIGradient", {
		Rotation = 90,
		Color = cseq(0, Color3.new(1, 1, 1), 0.4, Color3.fromRGB(255, 205, 190), 0.75, Color3.fromRGB(255, 80, 50), 1, Color3.fromRGB(190, 10, 0)),
	}, nm)
	new("UIStroke", { Color = Color3.fromRGB(18, 0, 0), Thickness = 2.5 }, nm)
	self.nameLabel = nm
	self.oddsLabel = odds

	self.emitters = {}
	for _, d in F:GetDescendants() do
		if d:IsA("ParticleEmitter") and d ~= self.burst then
			table.insert(self.emitters, d)
		end
	end

	F.Parent = opts.parent
	self:Step(0)
	return self
end

function Aura:_placeHand(h)
	h.a = rr(0, TAU)
	h.r = rr(3.2, 6.8)
	h.dur = rr(3.5, 5.5)
	h.t = 0
	h.lean = rr(-0.25, 0.25)
end

---------------------------------------------------------------------------
-- lightning
---------------------------------------------------------------------------
local function boltPath(a, b, detail, jag)
	local pts = { a, b }
	local off = (b - a).Magnitude * jag
	for _ = 1, detail do
		local np = {}
		for i = 1, #pts - 1 do
			table.insert(np, pts[i])
			table.insert(np, pts[i]:Lerp(pts[i + 1], 0.5) + Vector3.new(rr(-off, off), rr(-off, off), rr(-off, off)))
		end
		table.insert(np, pts[#pts])
		pts = np
		off *= 0.55
	end
	return pts
end

function Aura:_bolt(o)
	o.age = 0
	o.regen = 0
	o.width = o.width or 0.2
	o.detail = o.detail or 5
	o.jag = o.jag or 0.14
	o.color = o.color or BLOOD
	table.insert(self.bolts, o)
end

function Aura:_drawBolts(dt)
	local used = 0
	local segs = self.segs
	local function draw(pts, w, transp, color)
		for i = 1, #pts - 1 do
			used += 1
			local s = segs[used]
			if not s then
				return
			end
			local p0, p1 = pts[i], pts[i + 1]
			s.Size = Vector3.new(w, w, (p1 - p0).Magnitude + w * 0.6)
			s.CFrame = CFrame.lookAt((p0 + p1) * 0.5, p1)
			s.Transparency = transp
			s.Color = color
		end
	end
	local flash = 0
	for i = #self.bolts, 1, -1 do
		local b = self.bolts[i]
		b.age += dt
		if b.age > b.life then
			table.remove(self.bolts, i)
		else
			b.regen -= dt
			if b.regen <= 0 or not b.pts then
				b.regen = rr(0.04, 0.09)
				b.pts = boltPath(b.a, b.b, b.detail, b.jag)
				b.branch = {}
				for _ = 1, b.branches or 0 do
					local j = math.max(2, math.floor(#b.pts * rr(0.25, 0.7)))
					local s = b.pts[j]
					local dir = Vector3.new(rr(-1, 1), rr(-1, -0.2), rr(-1, 1))
					table.insert(b.branch, boltPath(s, s + dir.Unit * (b.a - b.b).Magnitude * rr(0.12, 0.3), 3, 0.3))
				end
			end
			local k = (1 - b.age / b.life) ^ 0.6
			local transp = 1 - k * rr(0.55, 1) * self.S
			draw(b.pts, b.width, transp, b.color)
			for _, br in b.branch do
				draw(br, b.width * 0.55, math.min(1, transp + 0.2), b.color)
			end
			if b.color == BLOOD then
				flash = math.max(flash, k)
			end
		end
	end
	for i = used + 1, #segs do
		local s = segs[i]
		if s.Transparency ~= 1 then
			s.Transparency = 1
		end
	end
	self.boltLight.Brightness = flash * 6 * self.S
	return #self.bolts
end

function Aura:_strike()
	local base = self.base or Vector3.zero
	local a, r = rr(0, TAU), rr(4, 9)
	local endp = base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	self:_bolt({ a = endp + Vector3.new(rr(-8, 8), 34, rr(-8, 8)), b = endp, life = rr(0.25, 0.45), width = 0.3, detail = 6, branches = 3 })
	self.lastStrike = true
end

---------------------------------------------------------------------------
-- public
---------------------------------------------------------------------------
function Aura:Hold()
	self.held = true
	self.spawning = false
	self.S = 0
	self.P = 0
	table.clear(self.bolts)
end

function Aura:Spawn()
	self.held = false
	self.spawning = true
	self.spawnT = 0
	self.beat = 2.2
	self:Pulse(1.4)
	Aura.emit(self.burst, 120)
end

function Aura:Pulse(str)
	str = str or 1
	local w = self.waves[self.waveCursor]
	self.waveCursor = self.waveCursor % #self.waves + 1
	w.age = 0
	w.str = str
	self.P = math.max(self.P, str)
	Aura.emit(self.burst, math.floor(40 * str))
	for _ = 1, (str > 1 and 3 or 1) do
		self:_strike()
	end
end

-- returns "pulse" on heartbeat frames, "thunder" when a sky strike lands, else nil
function Aura:Step(dt)
	local root = self.root
	if not root or not root.Parent then
		return nil
	end
	self.t += dt
	local t = self.t
	local event = nil

	if self.spawning then
		self.spawnT += dt
		local k = clamp01(self.spawnT / 1.3)
		self.S = k < 1 and 1 + 2.7 * (k - 1) ^ 3 + 1.7 * (k - 1) ^ 2 or 1
		if k >= 1 then
			self.spawning = false
		end
	end
	if not self.held and not self.spawning then
		self.beat -= dt
		if self.beat <= 0 then
			self.beat = BEAT
			self:Pulse(1)
			event = "pulse"
		end
	end
	self.P *= math.exp(-dt * 2.8)
	local S, P = self.S, self.P
	local sc = math.max(S, 0.001)
	local visible = S > 0.01

	local rp = root.CFrame.Position
	local base = Vector3.new(rp.X, self.groundY(root), rp.Z)
	self.base = base

	-- cracks + candles
	self.crackPart.Size = Vector3.new(20 * sc, 0.05, 20 * sc)
	self.crackPart.CFrame = CFrame.new(base + Vector3.new(0, 0.06, 0))
	self.crackGui.Enabled = visible
	self.crackGui.Brightness = (2.2 + math.sin(t * 2.5) * 0.6 + P * 3) * S
	self.floorLight.Brightness = (2.5 + P * 4) * S
	for _, c in self.candles do
		local r = 8.2 * sc
		c.part.CFrame = CFrame.new(base + Vector3.new(math.cos(c.a) * r, c.h * 0.5, math.sin(c.a) * r)) * CFrame.Angles(0, 0, math.pi / 2)
		c.part.Transparency = visible and 0 or 1
	end

	-- lanterns: carved face always turned outward
	for _, l in self.lanterns do
		local a = l.ph + t * 0.6
		local r = 3.6 * sc
		local pos = base + Vector3.new(math.cos(a) * r, 2.2 + l.i * 0.45 + math.sin(t * 1.6 + l.i * 2) * 0.4, math.sin(a) * r)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local cf = CFrame.lookAt(pos, pos + out)
		local s = sc * (1 + P * 0.12)
		l.shell.Size = Vector3.new(1.45, 1.15, 1.45) * s
		l.shell.CFrame = cf
		l.face.Size = Vector3.new(1.2 * s, 1 * s, 0.05)
		l.face.CFrame = cf * CFrame.new(0, 0, -0.66 * s)
		l.faceGui.Enabled = visible
		l.faceGui.Brightness = (3.5 + math.sin(t * 17 + l.i) * math.sin(t * 5.3) * 0.8 + P * 2) * S
		l.stem.CFrame = cf * CFrame.new(0, 0.62 * s, 0) * CFrame.Angles(0, 0, 0.3)
		l.stem.Transparency = visible and 0 or 1
		l.shell.Transparency = visible and 0 or 1
		l.light.Brightness = (2.2 + math.sin(t * 13 + l.i) * 0.5 + P * 2) * S
	end

	-- witch hat
	local head = self.head
	if head and head.Parent then
		local top = head.CFrame.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.55 + math.sin(t * 2) * 0.06, 0)
		local hatCf = CFrame.new(top) * CFrame.Angles(0, math.sin(t * 0.6) * 0.3, 0.12)
		for _, h in self.hat do
			h.part.Size = h.size * sc
			h.part.CFrame = hatCf * CFrame.new(h.x * sc, h.y * sc, 0) * CFrame.Angles(0, 0, math.pi / 2)
			h.part.Transparency = visible and 0 or 1
		end
	end

	-- hands rise, grab and sink
	for _, h in self.hands do
		h.t += dt
		if h.t > h.dur then
			self:_placeHand(h)
		end
		local ht = math.max(0, h.t)
		local rise = easeOut3(ht / 0.8) * (1 - easeIn3((ht - (h.dur - 0.9)) / 0.9)) * S
		local grip = clamp01((ht - 0.7) / 0.6) * (1 - clamp01((ht - (h.dur - 1)) / 0.6))
		local at = base + Vector3.new(math.cos(h.a) * h.r * sc, -3.2 + rise * 3.4, math.sin(h.a) * h.r * sc)
		local cf = CFrame.new(at) * CFrame.Angles(0, -h.a + math.pi / 2, 0) * CFrame.Angles(-0.25 + h.lean, 0, math.sin(t * 1.7 + h.a) * 0.1)
		h.fore.CFrame = cf * CFrame.new(0, -1.6, 0)
		h.palm.CFrame = cf * CFrame.new(0, 0.3, 0)
		for k, f in h.fingers do
			local bend = grip * (1 + k * 0.08)
			local knuckle = cf * CFrame.new(f.x, 0.7, 0) * CFrame.Angles(bend, 0, 0)
			f.a.CFrame = knuckle * CFrame.new(0, f.len * 0.5, 0)
			f.b.CFrame = knuckle * CFrame.new(0, f.len, 0) * CFrame.Angles(grip * 1.1, 0, 0) * CFrame.new(0, 0.19, 0)
		end
		h.thumb.CFrame = cf * CFrame.new(0.4, 0.25, 0) * CFrame.Angles(grip * 0.8, 0, -0.9) * CFrame.new(0, 0.25, 0)
		local hidden = rise < 0.02
		for _, p in h.pieces do
			p.Transparency = hidden and 1 or 0
		end
	end

	-- wisps
	for _, w in self.wisps do
		local a = w.ph + t * w.sp
		w.part.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * w.r * sc, w.y + math.sin(t * 1.2 + w.ph) * 1.2, math.sin(a) * w.r * sc))
		w.gui.Enabled = visible
	end

	-- bats
	for _, b in self.bats do
		b.a += b.sp * dt * 0.4
		local pos = base + Vector3.new(math.cos(b.a) * b.r * sc, b.y + math.sin(t * 1.3 + b.ph) * 0.8, math.sin(b.a) * b.r * sc)
		local fwd = Vector3.new(-math.sin(b.a), 0, math.cos(b.a)) * (b.sp > 0 and 1 or -1)
		local cf = CFrame.lookAt(pos, pos + fwd)
		local flap = math.sin(t * 14 + b.ph) * 0.9
		b.body.CFrame = cf
		b.body.Transparency = visible and 0 or 1
		for i, wing in b.wings do
			local side = i == 1 and -1 or 1
			wing.CFrame = cf * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.5 * b.s, 0, 0)
			wing.Transparency = visible and 0 or 1
		end
	end

	-- particle hosts
	self.groundHost.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0))
	self.skyHost.CFrame = CFrame.new(base + Vector3.new(0, 18, 0))
	self.burstHost.CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0))
	local emitOn = S > 0.5
	for _, e in self.emitters do
		if e.Enabled ~= emitOn then
			e.Enabled = emitOn
		end
	end

	-- shockwaves
	for _, w in self.waves do
		if w.age < 1 then
			w.age = math.min(1, w.age + dt / 1.3)
			local e = easeOut3(w.age)
			w.gui.Enabled = w.age < 1
			w.part.Size = Vector3.new(1 + e * 26, 0.05, 1 + e * 26)
			w.part.CFrame = CFrame.new(base + Vector3.new(0, 0.1, 0))
			w.strokes[1].Transparency = w.age
			w.strokes[2].Transparency = 0.6 + w.age * 0.4
		end
	end

	-- storm + blue arcs between lanterns
	local tm = self.timers
	if S > 0.5 then
		tm.storm -= dt
		if tm.storm <= 0 then
			tm.storm = rr(3, 7)
			self:_strike()
		end
		tm.arc -= dt
		if tm.arc <= 0 then
			tm.arc = rr(0.8, 2.2)
			local i = rng:NextInteger(1, 3)
			self:_bolt({
				a = self.lanterns[i].shell.CFrame.Position,
				b = self.lanterns[i % 3 + 1].shell.CFrame.Position,
				life = rr(0.15, 0.3),
				width = 0.12,
				detail = 4,
				jag = 0.18,
				branches = 1,
				color = SPECT,
			})
		end
	end
	if self.lastStrike then
		self.lastStrike = false
		event = event or "thunder"
	end
	self:_drawBolts(dt)

	-- tag flicker
	self.tag.Enabled = visible
	local f = (t % 5.3) / 5.3
	local flick = (f > 0.61 and f < 0.62 or f > 0.63 and f < 0.64) and 0.7 or (f > 0.93 and f < 0.94) and 0.4 or 0
	local tr = math.max(1 - clamp01(S), flick)
	self.nameLabel.TextTransparency = tr
	self.oddsLabel.TextTransparency = tr

	return event
end

function Aura:Destroy()
	self.folder:Destroy()
	self.root = nil
end

return Aura
