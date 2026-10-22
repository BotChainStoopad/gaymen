--[[
	Umbral Sovereign — 1 in 2,500,000,000

	Client-side aura VFX. Everything is built from Parts, Highlights, Beams, Trails,
	ParticleEmitters and Surface/Billboard GUIs, so there are no uploaded assets to
	moderate. Particle textures are the ones that ship with the Roblox client.

		local aura = UmbralAura.new(character, { parent = workspace.LocalAuras, groundY = fn })
		RunService.RenderStepped:Connect(function(dt) aura:Step(dt) end)
		aura:Hold()      -- hide until revealed (cutscene)
		aura:Spawn()     -- burst in
		aura:Pulse(1)    -- extra shockwave
		aura:Destroy()

	Step never yields and only touches instance properties, so build.luau can run it under Lune.
]]

local Aura = {}
Aura.__index = Aura

Aura.Name = "Umbral Sovereign"
Aura.Odds = "1 in 2,500,000,000"
Aura.Condition = "Eclipse"
Aura.Lore = "They sealed the sun to bury me. I learned to wear the dark as a crown, and every star that fell into my orbit kneeled."

local TAU = math.pi * 2
local CORE_Y = 10.2
local DOME_R = 6.9
local BEAT = 3.4

local BLACK = Color3.fromRGB(4, 1, 9)
local DEEP = Color3.fromRGB(46, 10, 110)
local VIOLET = Color3.fromRGB(112, 44, 235)
local PURPLE = Color3.fromRGB(160, 96, 255)
local ORCHID = Color3.fromRGB(228, 188, 255)
local HOT = Color3.fromRGB(255, 236, 255)

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

-- GUI primitives, all in parent scale so they survive resizing
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
	new("UIStroke", { Thickness = thick, Color = color, Transparency = transp or 0 }, f)
	return f
end
local function disc(parent, d, color, transp, z)
	local f = circle(parent, d, z)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transp or 0
	return f
end
local function line(parent, x1, y1, x2, y2, thick, color, transp)
	local dx, dy = x2 - x1, y2 - y1
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.new(math.sqrt(dx * dx + dy * dy), thick, 0, thick),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BackgroundTransparency = transp or 0,
		BorderSizePixel = 0,
	}, parent)
end
local function polygon(parent, r, k, rot, thick, color)
	for i = 0, k - 1 do
		local a1, a2 = rot + i / k * TAU, rot + (i + 1) / k * TAU
		line(parent, 0.5 + math.cos(a1) * r, 0.5 + math.sin(a1) * r, 0.5 + math.cos(a2) * r, 0.5 + math.sin(a2) * r, thick, color)
	end
end

-- procedural rune: 2–4 strokes walking a 3×4 grid
local function rune(parent, x, y, size, angle, r, color)
	local g = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(size, size),
		Rotation = angle,
		BackgroundTransparency = 1,
	}, parent)
	local function P(gx, gy)
		return 0.5 + (gx - 1) * 0.3, 0.5 + (gy - 1.5) * 0.28
	end
	for _ = 1, r:NextInteger(2, 4) do
		local gx, gy = r:NextInteger(0, 2), r:NextInteger(0, 3)
		for _ = 1, r:NextInteger(1, 3) do
			local nx = math.clamp(gx + r:NextInteger(-1, 1), 0, 2)
			local ny = math.clamp(gy + r:NextInteger(-1, 1), 0, 3)
			if nx ~= gx or ny ~= gy then
				local ax, ay = P(gx, gy)
				local bx, by = P(nx, ny)
				line(g, ax, ay, bx, by, 3, color)
			end
			gx, gy = nx, ny
		end
	end
	if r:NextNumber() < 0.4 then
		local cx, cy = P(r:NextInteger(0, 2), r:NextInteger(0, 3))
		local dot = ring(g, 0.2, 2, color)
		dot.Position = UDim2.fromScale(cx, cy)
	end
	return g
end

-- three nested rune circles; kind 0 = outer band, 1 = hexagram, 2 = eye
local function sigil(canvas, kind, seed)
	local r = Random.new(seed)
	local c = ORCHID
	if kind == 0 then
		ring(canvas, 0.975, 5, c)
		ring(canvas, 0.95, 2, c, 0.2)
		ring(canvas, 0.835, 2, c, 0.2)
		ring(canvas, 0.812, 5, c)
		ring(canvas, 1.0, 14, PURPLE, 0.75)
		for i = 0, 119 do
			local a = i / 120 * TAU
			local long = i % 5 == 0
			local r1, r2 = 0.475, long and 0.458 or 0.466
			line(canvas, 0.5 + math.cos(a) * r1, 0.5 + math.sin(a) * r1, 0.5 + math.cos(a) * r2, 0.5 + math.sin(a) * r2, long and 3 or 2, c)
		end
		for i = 0, 35 do
			local a = i / 36 * TAU
			rune(canvas, 0.5 + math.cos(a) * 0.442, 0.5 + math.sin(a) * 0.442, 0.05, math.deg(a) + 90, r, c)
		end
	elseif kind == 1 then
		ring(canvas, 0.775, 3, c, 0.35)
		ring(canvas, 0.735, 5, c)
		ring(canvas, 0.71, 2, c, 0.2)
		ring(canvas, 0.5, 4, c)
		ring(canvas, 0.475, 2, c, 0.2)
		polygon(canvas, 0.2375, 3, -math.pi / 2, 3, c)
		polygon(canvas, 0.2375, 3, math.pi / 2, 3, c)
		for i = 0, 5 do
			local a = i / 6 * TAU - math.pi / 2
			local d = ring(canvas, 0.045, 3, c)
			d.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.2375, 0.5 + math.sin(a) * 0.2375)
		end
		for i = 0, 19 do
			local a = i / 20 * TAU
			rune(canvas, 0.5 + math.cos(a) * 0.302, 0.5 + math.sin(a) * 0.302, 0.06, math.deg(a) + 90, r, c)
		end
	else
		ring(canvas, 0.33, 5, c)
		ring(canvas, 0.305, 2, c, 0.2)
		polygon(canvas, 0.1525, 4, 0, 3, c)
		polygon(canvas, 0.1525, 4, math.pi / 4, 3, c)
		ring(canvas, 0.15, 3, c)
		local eye = circle(canvas, 0.2)
		eye.Size = UDim2.fromScale(0.2, 0.085)
		new("UIStroke", { Thickness = 3, Color = c }, eye)
		disc(canvas, 0.045, HOT)
		for i = 0, 7 do
			local a = i / 8 * TAU
			line(canvas, 0.5 + math.cos(a) * 0.17, 0.5 + math.sin(a) * 0.17, 0.5 + math.cos(a) * 0.2, 0.5 + math.sin(a) * 0.2, 3, c)
		end
	end
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

-- black sphere + photon-ring billboard (core and orbs share this look)
local function voidBall(parent, diameter, glowStuds, lightRange)
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, Color = BLACK, Name = "Void" }, parent)
	new("Highlight", {
		Adornee = ball,
		FillColor = BLACK,
		FillTransparency = 0,
		OutlineColor = ORCHID,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	}, ball)
	local bb = new("BillboardGui", {
		Name = "PhotonRing",
		Adornee = ball,
		Size = UDim2.fromScale(glowStuds, glowStuds),
		LightInfluence = 0,
		Brightness = 2.6,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
	}, ball)
	local k = diameter / glowStuds
	disc(bb, 1, VIOLET, 0.93, 1)
	disc(bb, k * 1.6, PURPLE, 0.8, 2)
	disc(bb, k * 1.25, PURPLE, 0.45, 3)
	disc(bb, k * 1.1, HOT, 0, 4)
	if lightRange then
		new("PointLight", { Color = PURPLE, Range = lightRange, Brightness = 3, Shadows = false }, ball)
	end
	return ball, bb
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
	self.timers = { arc = 0, tether = 0.6, crackle = 0, flicker = 0 }
	self.bolts = {}
	self.waveCursor = 1

	local F = new("Folder", { Name = "UmbralSovereign_" .. character.Name })
	self.folder = F

	-- event-horizon core
	self.core, self.coreRing = voidBall(F, 2.9, 7, 24)
	self.core.Name = "Core"
	self.coreLight = self.core:FindFirstChildOfClass("PointLight")
	local a0 = new("Attachment", { Position = Vector3.new(0, 1.3, 0) }, self.core)
	local a1 = new("Attachment", { Position = Vector3.new(0, 40, 0) }, self.core)
	new("Beam", {
		Name = "Jet",
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = 1.3,
		Width1 = 0.15,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
		Color = cseq(0, HOT, 0.4, PURPLE, 1, VIOLET),
		Transparency = seq(0, 0, 0.6, 0.45, 1, 1),
		Texture = TEX_SPARK,
		TextureLength = 3,
		TextureSpeed = 2.4,
		Segments = 1,
	}, self.core)
	new("Beam", {
		Name = "JetGlow",
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = 4,
		Width1 = 0.6,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		Color = cseq(0, PURPLE, 1, DEEP),
		Transparency = seq(0, 0.6, 0.5, 0.85, 1, 1),
		Segments = 1,
	}, self.core)

	-- particles sucked into the horizon
	self.suck = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 9, Transparency = 1, Name = "Infall" }, F)
	new("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Texture = TEX_SPARK,
		Rate = 45,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(3.5, 6),
		Size = seq(0, 0.35, 1, 0),
		Squash = seq(0, 1.5, 1, 0),
		Color = cseq(0, PURPLE, 1, HOT),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		Transparency = seq(0, 1, 0.3, 0, 1, 0),
	}, self.suck)

	-- accretion disk (tilted, double-sided rings, doppler sweep via UIGradient)
	self.disk = part({ Size = Vector3.new(9.6, 0.05, 9.6), Transparency = 1, Name = "AccretionDisk" }, F)
	self.diskGrads = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local _, cv = surface(self.disk, face, 40, 3)
		for i = 0, 11 do
			local k = i / 11
			local col = k < 0.3 and HOT:Lerp(PURPLE, k / 0.3) or PURPLE:Lerp(DEEP, (k - 0.3) / 0.7)
			local rg = ring(cv, 0.36 + k * 0.62, math.max(2, 14 - i), col, 0.05 + k * 0.72)
			local stroke = rg:FindFirstChildOfClass("UIStroke")
			table.insert(self.diskGrads, new("UIGradient", {
				Transparency = seq(0, 0, 0.5, 0.55, 1, 0),
				Rotation = i * 23,
			}, stroke))
		end
	end

	-- rune halo behind the core, always facing the camera
	self.halo = new("BillboardGui", {
		Name = "SigilHalo",
		Adornee = self.core,
		Size = UDim2.fromScale(13, 13),
		StudsOffset = Vector3.new(0, 0, -2.6),
		LightInfluence = 0,
		Brightness = 1.4,
		ResetOnSpawn = false,
	}, self.core)
	self.haloA = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.halo)
	sigil(self.haloA, 0, 11)
	self.haloB = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
	}, self.halo)
	sigil(self.haloB, 1, 12)

	-- ground circles
	self.circles = {}
	for i, spec in { { 0, 0.12, 2.6 }, { 1, -0.2, 2.8 }, { 2, 0.35, 3.4 } } do
		local p = part({ Size = Vector3.new(16, 0.05, 16), Transparency = 1, Name = "RuneCircle" .. i }, F)
		local g, cv = surface(p, Enum.NormalId.Top, 40, spec[3])
		sigil(cv, spec[1], 100 + i)
		table.insert(self.circles, { part = p, gui = g, speed = spec[2], h = 0.06 + i * 0.02, bright = spec[3] })
	end
	self.floorGlow = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 14, 14),
		Color = VIOLET,
		Material = Enum.Material.Neon,
		Transparency = 0.86,
		Name = "FloorGlow",
	}, F)
	self.floorLight = new("PointLight", { Color = PURPLE, Range = 16, Brightness = 4, Shadows = false }, self.floorGlow)

	-- barrier dome
	self.dome = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * DOME_R * 2,
		Color = PURPLE,
		Material = Enum.Material.ForceField,
		Name = "Barrier",
	}, F)

	-- plasma orbs with trails
	self.orbs = {}
	for i = 1, 3 do
		local ball = voidBall(F, 1.1, 3.4)
		ball.Name = "Orb" .. i
		local t0 = new("Attachment", { Position = Vector3.new(0, 0.45, 0) }, ball)
		local t1 = new("Attachment", { Position = Vector3.new(0, -0.45, 0) }, ball)
		new("Trail", {
			Attachment0 = t0,
			Attachment1 = t1,
			Lifetime = 0.55,
			MinLength = 0.05,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 3,
			Color = cseq(0, HOT, 0.3, PURPLE, 1, DEEP),
			Transparency = seq(0, 0, 1, 1),
			WidthScale = seq(0, 1, 1, 0),
		}, ball)
		new("ParticleEmitter", {
			Texture = TEX_SPARK,
			Rate = 18,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(0.6, 1.8),
			SpreadAngle = Vector2.new(180, 180),
			Size = seq(0, 0.45, 1, 0),
			Color = cseq(0, HOT, 1, PURPLE),
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 3,
		}, ball)
		table.insert(self.orbs, { part = ball, ph = (i - 1) / 3 * TAU, i = i })
	end

	-- helix ribbons (trails on carriers that spiral up and down)
	self.helix = {}
	for i = 1, 4 do
		local c = part({ Size = Vector3.one * 0.2, Transparency = 1, Name = "Helix" .. i }, F)
		local h0 = new("Attachment", { Position = Vector3.new(0, 0.28, 0) }, c)
		local h1 = new("Attachment", { Position = Vector3.new(0, -0.28, 0) }, c)
		new("Trail", {
			Attachment0 = h0,
			Attachment1 = h1,
			Lifetime = 1.1,
			MinLength = 0.05,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2.5,
			Color = cseq(0, HOT, 0.25, PURPLE, 1, DEEP),
			Transparency = seq(0, 0, 0.6, 0.5, 1, 1),
			WidthScale = seq(0, 1, 1, 0.15),
		}, c)
		table.insert(self.helix, { part = c, ph = (i - 1) / 4 * TAU, dir = i % 2 == 0 and -1 or 1, off = (i - 1) * 0.25 })
	end

	-- obsidian shards
	self.shards = {}
	for i = 1, 14 do
		local s = part({
			Size = Vector3.new(0.32, 0.9, 0.32) * rr(0.7, 1.3),
			Color = Color3.fromRGB(78, 30, 170),
			Material = Enum.Material.Neon,
			Name = "Shard" .. i,
		}, F)
		table.insert(self.shards, {
			part = s,
			r = rr(2.6, 5.4),
			y = rr(1.2, 8.5),
			ph = rr(0, TAU),
			sp = rr(0.25, 0.6) * (rng:NextNumber() < 0.3 and -1 or 1),
			rx = rr(0, TAU),
		})
	end

	-- floating crown
	self.crown = {}
	for i = 0, 9 do
		local h = i % 2 == 1 and 0.42 or 0.75
		local s = part({ Size = Vector3.new(0.13, h, 0.13), Color = ORCHID, Material = Enum.Material.Neon, Name = "CrownSpike" }, F)
		table.insert(self.crown, { part = s, a = i / 10 * TAU, h = h })
	end

	-- particle hosts
	self.groundHost = part({ Size = Vector3.new(12, 0.2, 12), Transparency = 1, Name = "Motes" }, F)
	new("ParticleEmitter", {
		Name = "Motes",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SPARK,
		Rate = 55,
		Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 0.6, 0),
		Size = seq(0, 0.12, 0.5, 0.3, 1, 0),
		Color = cseq(0, PURPLE, 0.6, ORCHID, 1, HOT),
		Transparency = seq(0, 1, 0.15, 0, 0.8, 0.2, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		RotSpeed = NumberRange.new(-90, 90),
	}, self.groundHost)
	new("ParticleEmitter", {
		Name = "Smoke",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SMOKE,
		Rate = 7,
		Lifetime = NumberRange.new(4, 6.5),
		Speed = NumberRange.new(0.8, 1.8),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 0.4, 0),
		Size = seq(0, 2.5, 1, 8),
		Color = cseq(0, Color3.fromRGB(14, 3, 30), 1, Color3.fromRGB(6, 1, 14)),
		Transparency = seq(0, 1, 0.25, 0.45, 1, 1),
		LightEmission = 0,
		LightInfluence = 0,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
	}, self.groundHost)
	local feet = new("Attachment", { Name = "Feet" }, self.groundHost)
	new("ParticleEmitter", {
		Name = "Wisps",
		Texture = TEX_FIRE,
		Rate = 26,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(28, 28),
		Size = seq(0, 1.1, 1, 0),
		Color = cseq(0, ORCHID, 0.4, PURPLE, 1, DEEP),
		Transparency = seq(0, 0.2, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		Rotation = NumberRange.new(0, 360),
	}, feet)

	self.starHost = part({ Size = Vector3.new(14, 11, 14), Transparency = 1, Name = "Stars" }, F)
	new("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Texture = TEX_SPARK,
		Rate = 12,
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(0, 0),
		Size = seq(0, 0, 0.5, 1.3, 1, 0),
		Color = cseq(0, HOT, 1, ORCHID),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	}, self.starHost)

	self.burstHost = part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Transparency = 1, Name = "Burst" }, F)
	self.burst = new("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Texture = TEX_SPARK,
		Rate = 0,
		Lifetime = NumberRange.new(0.9, 1.8),
		Speed = NumberRange.new(14, 32),
		Drag = 3.5,
		Size = seq(0, 0.5, 1, 0),
		Squash = seq(0, 1.2, 1, 0),
		Color = cseq(0, HOT, 0.5, PURPLE, 1, VIOLET),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
	}, self.burstHost)

	-- shockwave pool
	self.waves = {}
	for i = 1, 3 do
		local p = part({ Size = Vector3.new(1, 0.05, 1), Transparency = 1, Name = "Shockwave" .. i }, F)
		local g, cv = surface(p, Enum.NormalId.Top, 12, 3)
		local r1 = ring(cv, 0.98, 6, HOT)
		local r2 = ring(cv, 0.9, 16, PURPLE, 0.55)
		g.Enabled = false
		local shell = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one,
			Color = ORCHID,
			Material = Enum.Material.ForceField,
			Transparency = 1,
			Name = "ShockShell" .. i,
		}, F)
		table.insert(self.waves, {
			part = p,
			gui = g,
			strokes = { r1:FindFirstChildOfClass("UIStroke"), r2:FindFirstChildOfClass("UIStroke") },
			shell = shell,
			age = 1,
			str = 1,
		})
	end

	-- lightning segment pool
	self.segs = {}
	for i = 1, 140 do
		table.insert(self.segs, part({
			Size = Vector3.new(0.14, 0.14, 1),
			Color = Color3.fromRGB(232, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 1,
			Name = "Bolt",
		}, F))
	end

	-- name tag
	self.tag = new("BillboardGui", {
		Name = "AuraTag",
		Adornee = self.head,
		Size = UDim2.fromScale(10, 2.3),
		StudsOffset = Vector3.new(0, 3.9, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 160,
		ResetOnSpawn = false,
	}, F)
	local odds = new("TextLabel", {
		Name = "Odds",
		Size = UDim2.fromScale(1, 0.28),
		BackgroundTransparency = 1,
		Font = Enum.Font.Michroma,
		Text = Aura.Odds,
		TextScaled = true,
		TextColor3 = HOT,
	}, self.tag)
	new("UIStroke", { Color = Color3.fromRGB(70, 20, 150), Thickness = 1.5 }, odds)
	local function nameLabel(color, z)
		local l = new("TextLabel", {
			Size = UDim2.fromScale(1, 0.7),
			Position = UDim2.fromScale(0, 0.3),
			BackgroundTransparency = 1,
			Font = Enum.Font.Bodoni,
			Text = string.upper(Aura.Name),
			TextScaled = true,
			TextColor3 = color,
			ZIndex = z,
		}, self.tag)
		return l
	end
	self.glitchA = nameLabel(Color3.fromRGB(255, 106, 241), 1)
	self.glitchB = nameLabel(Color3.fromRGB(127, 216, 255), 1)
	self.glitchA.TextTransparency, self.glitchB.TextTransparency = 1, 1
	local nm = nameLabel(Color3.new(1, 1, 1), 2)
	nm.Name = "Name"
	new("UIGradient", {
		Rotation = 90,
		Color = cseq(0, Color3.new(1, 1, 1), 0.35, Color3.fromRGB(246, 236, 255), 0.65, Color3.fromRGB(205, 168, 255), 1, Color3.fromRGB(130, 70, 255)),
	}, nm)
	new("UIStroke", { Color = Color3.fromRGB(26, 6, 52), Thickness = 2.5 }, nm)
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
			local m = pts[i]:Lerp(pts[i + 1], 0.5)
			table.insert(np, m + Vector3.new(rr(-off, off), rr(-off, off), rr(-off, off)))
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
	o.width = o.width or 0.16
	o.detail = o.detail or 4
	o.jag = o.jag or 0.2
	table.insert(self.bolts, o)
end

function Aura:_drawBolts(dt)
	local used = 0
	local segs = self.segs
	local function draw(pts, w, transp)
		for i = 1, #pts - 1 do
			used += 1
			local s = segs[used]
			if not s then
				return
			end
			local p0, p1 = pts[i], pts[i + 1]
			local len = (p1 - p0).Magnitude
			s.Size = Vector3.new(w, w, len + w * 0.6)
			s.CFrame = CFrame.lookAt((p0 + p1) * 0.5, p1)
			s.Transparency = transp
		end
	end
	for i = #self.bolts, 1, -1 do
		local b = self.bolts[i]
		b.age += dt
		if b.age > b.life then
			table.remove(self.bolts, i)
		else
			b.regen -= dt
			if b.regen <= 0 or not b.pts then
				b.regen = rr(0.04, 0.09)
				b.pts = boltPath(b.a(), b.b(), b.detail, b.jag)
				if b.sphere then
					for k, p in b.pts do
						b.pts[k] = b.sphere.c + (p - b.sphere.c).Unit * b.sphere.r
					end
				end
				b.branch = nil
				if b.branches then
					local j = math.floor(#b.pts * rr(0.3, 0.7))
					local s = b.pts[j]
					local dir = Vector3.new(rr(-1, 1), rr(-1, 1), rr(-1, 1))
					if dir.Magnitude > 0.01 then
						b.branch = boltPath(s, s + dir.Unit * (b.pts[1] - b.pts[#b.pts]).Magnitude * rr(0.15, 0.35), 3, 0.3)
					end
				end
			end
			local k = (1 - b.age / b.life) ^ 0.6
			local transp = 1 - k * rr(0.55, 1) * self.S
			draw(b.pts, b.width, transp)
			if b.branch then
				draw(b.branch, b.width * 0.6, math.min(1, transp + 0.2))
			end
		end
	end
	for i = used + 1, #segs do
		local s = segs[i]
		if s.Transparency ~= 1 then
			s.Transparency = 1
		end
	end
	return #self.bolts
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
	for _ = 1, (str > 1 and 4 or 2) do
		self:_strike()
	end
end

function Aura:_strike()
	local a = rr(0, TAU)
	local r = rr(3.5, 7)
	local base = self.base or Vector3.zero
	local endp = base + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r)
	self:_bolt({
		a = function()
			return self.core.CFrame.Position
		end,
		b = function()
			return endp
		end,
		life = rr(0.25, 0.4),
		width = 0.24,
		detail = 5,
		jag = 0.14,
		branches = true,
	})
end

-- returns true on frames where a heartbeat pulse fired
function Aura:Step(dt)
	local root = self.root
	if not root or not root.Parent then
		return false
	end
	self.t += dt
	local t = self.t
	local pulsed = false

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
			pulsed = true
		end
	end
	self.P *= math.exp(-dt * 2.8)
	local S, P = self.S, self.P
	local sc = math.max(S, 0.001)
	local visible = S > 0.01

	local rp = root.CFrame.Position
	local base = Vector3.new(rp.X, self.groundY(root), rp.Z)
	self.base = base
	local lift = (0.35 + math.sin(t * 1.3) * 0.12) * S

	-- core, disk, halo
	local coreP = base + Vector3.new(0, CORE_Y + math.sin(t * 0.9) * 0.15, 0)
	local coreS = 2.9 * sc * (1 + P * 0.06)
	self.core.Size = Vector3.one * coreS
	self.core.CFrame = CFrame.new(coreP)
	self.coreRing.Size = UDim2.fromScale(7 * sc, 7 * sc)
	self.coreLight.Brightness = (2.4 + P * 3) * S
	self.suck.CFrame = CFrame.new(coreP)
	self.disk.Size = Vector3.new(9.6 * sc, 0.05, 9.6 * sc)
	self.disk.CFrame = CFrame.new(coreP) * CFrame.Angles(0.3, 0, 0.12) * CFrame.Angles(0, t * 0.7, 0)
	for i, g in self.diskGrads do
		g.Rotation = (t * (60 - i * 2.5) + i * 23) % 360
	end
	self.halo.Enabled = visible
	self.halo.Size = UDim2.fromScale(13 * sc, 13 * sc)
	self.halo.Brightness = 1.4 * (1 + P)
	self.haloA.Rotation = -t * 5
	self.haloB.Rotation = t * 9

	-- ground circles
	for _, c in self.circles do
		c.part.Size = Vector3.new(16 * sc, 0.05, 16 * sc)
		c.part.CFrame = CFrame.new(base + Vector3.new(0, c.h, 0)) * CFrame.Angles(0, t * c.speed, 0)
		c.gui.Enabled = visible
		c.gui.Brightness = c.bright * (0.8 + 0.2 * math.sin(t * 2.3)) * (1 + P * 1.2)
	end
	self.floorGlow.Size = Vector3.new(0.05, 14 * sc, 14 * sc)
	self.floorGlow.CFrame = CFrame.new(base + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	self.floorGlow.Transparency = visible and (0.86 - P * 0.06) or 1
	self.floorLight.Brightness = (3.5 + P * 4) * S

	-- dome
	self.dome.Size = Vector3.one * DOME_R * 2 * sc * (1 + P * 0.03)
	self.dome.CFrame = CFrame.new(base + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0, t * 0.05, 0)
	self.dome.Transparency = visible and 0 or 1

	-- orbs
	local orbR = 1.1 * sc * (1 + P * 0.15)
	for _, o in self.orbs do
		local a = o.ph + t * 0.75
		local r = (3.5 + math.sin(t * 0.8 + o.i) * 0.35) * sc
		local y = (2.4 + math.sin(t * 1.4 + o.i * 2) * 0.55 + o.i * 0.35) * math.min(1, S * 1.2) + lift * 0.5
		o.part.Size = Vector3.one * orbR
		o.part.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
	end

	-- helix ribbons
	for _, h in self.helix do
		local a = h.ph + t * 1.7 * h.dir
		local k = 0.5 - 0.5 * math.cos((t * 0.33 + h.off) * TAU)
		local r = (2.6 + 0.9 * math.sin(k * math.pi) - k * 0.6) * sc
		h.part.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, 0.3 + k * 10.5 * math.min(1, S), math.sin(a) * r))
	end

	-- shards
	for _, s in self.shards do
		local a = s.ph + t * s.sp
		s.part.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * s.r * sc, s.y + math.sin(t * 1.1 + s.ph) * 0.4, math.sin(a) * s.r * sc))
			* CFrame.Angles(s.rx + t * 0.7, a * 2, math.pi / 4)
		s.part.Transparency = visible and 0 or 1
	end

	-- crown
	local head = self.head
	if head and head.Parent then
		local top = head.CFrame.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.45 + math.sin(t * 2) * 0.05, 0)
		for _, c in self.crown do
			local a = c.a + t * 0.5
			c.part.CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 0.72, c.h * 0.5, math.sin(a) * 0.72))
				* CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 0.18) * CFrame.Angles(0, math.pi / 4, 0)
			c.part.Transparency = visible and 0 or 1
		end
	end

	-- particle hosts
	self.groundHost.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0))
	self.starHost.CFrame = CFrame.new(base + Vector3.new(0, 6, 0))
	self.burstHost.CFrame = CFrame.new(base + Vector3.new(0, 2.5 + lift, 0))
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
			local fade = w.age
			w.gui.Enabled = w.age < 1
			w.part.Size = Vector3.new(1 + e * 26, 0.05, 1 + e * 26)
			w.part.CFrame = CFrame.new(base + Vector3.new(0, 0.1, 0))
			w.strokes[1].Transparency = fade
			w.strokes[2].Transparency = 0.55 + fade * 0.45
			w.shell.Size = Vector3.one * (2 + e * 22)
			w.shell.CFrame = CFrame.new(base + Vector3.new(0, 4.4, 0))
			w.shell.Transparency = 0.15 + fade * 0.85
		end
	end

	-- lightning schedule
	local tm = self.timers
	if S > 0.4 then
		tm.arc -= dt
		if tm.arc <= 0 then
			tm.arc = rr(0.12, 0.45)
			local c = base + Vector3.new(0, 4.4, 0)
			local d1 = Vector3.new(rr(-1, 1), rr(-0.15, 1), rr(-1, 1))
			if d1.Magnitude > 0.05 then
				d1 = d1.Unit
				local d2 = (d1 + Vector3.new(rr(-0.6, 0.6), rr(-0.6, 0.6), rr(-0.6, 0.6))).Unit
				local p1, p2 = c + d1 * DOME_R, c + d2 * DOME_R
				self:_bolt({
					a = function() return p1 end,
					b = function() return p2 end,
					life = rr(0.18, 0.4),
					width = 0.13,
					sphere = { c = c, r = DOME_R },
				})
			end
		end
		tm.tether -= dt
		if tm.tether <= 0 then
			tm.tether = rr(0.35, 1.1)
			local orb = self.orbs[rng:NextInteger(1, #self.orbs)].part
			self:_bolt({
				a = function() return self.core.CFrame.Position end,
				b = function() return orb.CFrame.Position end,
				life = rr(0.2, 0.45),
				width = 0.18,
				jag = 0.17,
				branches = true,
			})
		end
		tm.crackle -= dt
		if tm.crackle <= 0 then
			tm.crackle = rr(0.15, 0.5)
			local c = rp + Vector3.new(0, 0.2, 0)
			local p1 = c + Vector3.new(rr(-1.4, 1.4), rr(-1.8, 1.8), rr(-0.9, 0.9))
			local p2 = c + Vector3.new(rr(-1.4, 1.4), rr(-1.8, 1.8), rr(-0.9, 0.9))
			self:_bolt({
				a = function() return p1 end,
				b = function() return p2 end,
				life = rr(0.08, 0.18),
				width = 0.07,
				detail = 3,
				jag = 0.25,
			})
		end
	end
	self:_drawBolts(dt)

	-- tag + glitch
	self.tag.Enabled = visible
	local tr = 1 - clamp01(S)
	self.nameLabel.TextTransparency = tr
	self.oddsLabel.TextTransparency = tr
	local g = (t % 4.2) / 4.2
	local glitching = visible and g > 0.91 and g < 0.97
	self.glitchA.TextTransparency = glitching and 0.25 or 1
	self.glitchB.TextTransparency = glitching and 0.3 or 1
	if glitching then
		local j = math.floor(g * 60) % 2 == 0 and 1 or -1
		self.glitchA.Position = UDim2.new(0, -3 * j, 0.3, 0)
		self.glitchB.Position = UDim2.new(0, 3 * j, 0.3, 0)
	end

	return pulsed
end

function Aura:Destroy()
	self.folder:Destroy()
	self.root = nil
end

return Aura
