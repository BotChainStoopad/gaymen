--[[
	Aerosphere — 1 in 2,000,000,000

	Frutiger Aero aura: a midday sun with a rainbow halo, glass bubbles with
	thin-film sheen, Vista-style aurora curtains and swoosh ribbons, a glossy
	water pool ringed with grass, glass butterflies, bokeh, clouds and ripples.
	Built only from Parts, Beams, Trails, ParticleEmitters and Surface/Billboard
	GUIs with textures that ship with the Roblox client.

		local aura = AeroAura.new(character, { parent = workspace.LocalAuras, groundY = fn })
		RunService.RenderStepped:Connect(function(dt) aura:Step(dt) end)
		aura:Hold() / aura:Spawn() / aura:Pulse(1) / aura:Destroy()

	Step never yields and only touches instance properties, so build.luau runs it under Lune.
]]

local Aura = {}
Aura.__index = Aura

Aura.Name = "Aerosphere"
Aura.Odds = "1 in 2,000,000,000"
Aura.Condition = "Clear Skies"
Aura.Lore = "Past the last cloud there is a morning that never ended. I bottled its light, its water and its wind, and carried them back down."

local TAU = math.pi * 2
local SUN_Y = 10.6
local POOL_R = 7.5
local BEAT = 3.4

local WHITE = Color3.new(1, 1, 1)
local CREAM = Color3.fromRGB(255, 251, 228)
local ICE = Color3.fromRGB(214, 246, 255)
local AQUA = Color3.fromRGB(70, 222, 255)
local SKY = Color3.fromRGB(80, 170, 255)
local BLUE = Color3.fromRGB(28, 104, 245)
local DEEP = Color3.fromRGB(10, 52, 170)
local LIME = Color3.fromRGB(168, 238, 66)
local LEAF = Color3.fromRGB(78, 196, 46)

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 96, 120)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 176, 70)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 244, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 244, 120)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 226, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(100, 130, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 120, 255)),
})
Aura.Rainbow = RAINBOW

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
local function disc(parent, d, color, transp, z)
	local f = circle(parent, d, z)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transp or 0
	return f
end
local function line(parent, x1, y1, x2, y2, thick, color, transp, z)
	local dx, dy = x2 - x1, y2 - y1
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, thick),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BackgroundTransparency = transp or 0,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
end
local function rainbowRing(parent, d, thick, transp, z)
	local f, s = ring(parent, d, thick, WHITE, transp, z)
	local g = new("UIGradient", { Color = RAINBOW }, s)
	return f, s, g
end

local function surface(p, ppS, brightness)
	local g = new("SurfaceGui", {
		Face = Enum.NormalId.Top,
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
	self.rippleT = 0
	self.waveCursor = 1
	self.rippleCursor = 1

	local F = new("Folder", { Name = "Aerosphere_" .. character.Name })
	self.folder = F

	-- sun with sunburst and rainbow halo
	self.sun = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = CREAM, Material = Enum.Material.Neon, Name = "Sun" }, F)
	self.sunLight = new("PointLight", { Color = Color3.fromRGB(255, 246, 220), Range = 28, Brightness = 2, Shadows = false }, self.sun)
	self.sunGui = new("BillboardGui", {
		Name = "SunGlow",
		Adornee = self.sun,
		Size = UDim2.fromScale(14, 14),
		LightInfluence = 0,
		Brightness = 2.6,
		ResetOnSpawn = false,
	}, self.sun)
	disc(self.sunGui, 1, AQUA, 0.93, 1)
	disc(self.sunGui, 0.62, ICE, 0.78, 2)
	self.rays = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, self.sunGui)
	for i = 0, 15 do
		local a = i / 16 * TAU
		local L = i % 2 == 0 and 0.5 or 0.33
		local l = line(self.rays, 0.5, 0.5, 0.5 + math.cos(a) * L, 0.5 + math.sin(a) * L, i % 2 == 0 and 5 or 3, WHITE, 0, 3)
		new("UIGradient", { Transparency = seq(0, 0.1, 1, 1) }, l)
	end
	local _, _, g1 = rainbowRing(self.sunGui, 0.8, 6, 0.25, 4)
	local _, _, g2 = rainbowRing(self.sunGui, 0.88, 2, 0.55, 4)
	self.haloGrads = { g1, g2 }
	disc(self.sunGui, 0.36, WHITE, 0.35, 5)
	disc(self.sunGui, 0.22, WHITE, 0, 6)
	new("ParticleEmitter", {
		Name = "Glints",
		Texture = TEX_SPARK,
		Rate = 12,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = seq(0, 0.7, 1, 0),
		Color = cseq(0, WHITE, 1, AQUA),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
		Rotation = NumberRange.new(0, 360),
	}, self.sun)

	-- glass bubbles
	self.bubbles = {}
	for i = 1, 12 do
		local b = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one,
			Color = Color3.fromRGB(205, 242, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Reflectance = 0.25,
			Name = "Bubble" .. i,
		}, F)
		local bb = new("BillboardGui", {
			Name = "Gloss",
			Adornee = b,
			Size = UDim2.fromScale(1, 1),
			LightInfluence = 0,
			Brightness = 1.6,
			ResetOnSpawn = false,
		}, b)
		local _, rim = ring(bb, 0.98, 2, WHITE, 0.25, 1)
		new("UIGradient", { Transparency = seq(0, 1, 0.45, 0.85, 1, 0), Rotation = 45 }, rim)
		local _, _, film = rainbowRing(bb, 0.92, 3, 0.55, 2)
		local spec = disc(bb, 0.26, WHITE, 0.05, 3)
		spec.Position = UDim2.fromScale(0.33, 0.3)
		spec.Size = UDim2.fromScale(0.3, 0.2)
		spec.Rotation = -35
		local glint = disc(bb, 0.08, WHITE, 0, 3)
		glint.Position = UDim2.fromScale(0.66, 0.72)
		local bub = { part = b, gui = bb, film = film, ph = rr(0, TAU) }
		self:_resetBubble(bub, true)
		table.insert(self.bubbles, bub)
	end
	self.popHost = part({ Size = Vector3.one * 0.2, Transparency = 1, Name = "Pop" }, F)
	self.pop = new("ParticleEmitter", {
		Texture = TEX_SPARK,
		Rate = 0,
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Acceleration = Vector3.new(0, -8, 0),
		Size = seq(0, 0.35, 1, 0),
		Color = cseq(0, WHITE, 1, AQUA),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
	}, self.popHost)

	-- aurora curtains + swoosh ribbons share one host; attachment positions are world offsets
	self.host = part({ Size = Vector3.one * 0.2, Transparency = 1, Name = "LightHost" }, F)
	self.curtains = {}
	for i = 1, 14 do
		local a0 = new("Attachment", {}, self.host)
		local a1 = new("Attachment", {}, self.host)
		local beam = new("Beam", {
			Attachment0 = a0,
			Attachment1 = a1,
			Width0 = rr(2, 3.2),
			Width1 = rr(4, 6.5),
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2.2,
			Segments = 12,
			Color = cseq(0, BLUE, 0.3, AQUA, 0.65, LIME, 1, CREAM),
			Transparency = seq(0, 1, 0.12, 0.55, 0.55, 0.72, 1, 1),
		}, self.host)
		table.insert(self.curtains, { a0 = a0, a1 = a1, beam = beam, a = (i - 1) / 14 * TAU + rr(-0.15, 0.15), r = rr(6.2, 8), h = rr(14, 20), ph = rr(0, TAU) })
	end
	self.swooshes = {}
	for b = 1, 3 do
		for k = 1, 5 do
			local a0 = new("Attachment", {}, self.host)
			local a1 = new("Attachment", {}, self.host)
			local beam = new("Beam", {
				Attachment0 = a0,
				Attachment1 = a1,
				Width0 = 0.16 - k * 0.018,
				Width1 = 0.04,
				FaceCamera = true,
				LightEmission = 1,
				LightInfluence = 0,
				Brightness = 3,
				Segments = 24,
				Color = cseq(0, ICE, 0.5, AQUA, 1, SKY),
				Transparency = seq(0, 1, 0.2, 0.15 + k * 0.08, 0.8, 0.2 + k * 0.08, 1, 1),
			}, self.host)
			table.insert(self.swooshes, { a0 = a0, a1 = a1, beam = beam, bundle = b, k = k })
		end
	end

	-- glossy pool with rim rings
	self.pool = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, POOL_R * 2, POOL_R * 2),
		Color = Color3.fromRGB(70, 176, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.45,
		Name = "Pool",
	}, F)
	self.poolLight = new("PointLight", { Color = AQUA, Range = 16, Brightness = 2.5, Shadows = false }, self.pool)
	self.rim = part({ Size = Vector3.new(POOL_R * 2 + 1, 0.05, POOL_R * 2 + 1), Transparency = 1, Name = "PoolRim" }, F)
	local rimGui, rimCv = surface(self.rim, 30, 2.4)
	self.rimGui = rimGui
	ring(rimCv, 0.985, 10, AQUA, 0.35)
	ring(rimCv, 0.965, 3, WHITE, 0)
	ring(rimCv, 0.75, 2, WHITE, 0.65)
	ring(rimCv, 0.5, 2, WHITE, 0.75)
	self.rimSweep = {}
	for _, d in { 0.965, 0.75 } do
		local _, s = ring(rimCv, d, d > 0.9 and 6 or 4, WHITE, 0)
		table.insert(self.rimSweep, new("UIGradient", { Transparency = seq(0, 1, 0.42, 1, 0.5, 0, 0.58, 1, 1, 1) }, s))
	end

	-- ripples and pulse waves
	self.ripples = {}
	for i = 1, 5 do
		local p = part({ Size = Vector3.new(1, 0.05, 1), Transparency = 1, Name = "Ripple" .. i }, F)
		local g, cv = surface(p, 20, 2)
		local _, s1 = ring(cv, 0.96, 3, WHITE, 0)
		local _, s2 = ring(cv, 0.8, 2, AQUA, 0.3)
		g.Enabled = false
		table.insert(self.ripples, { part = p, gui = g, strokes = { s1, s2 }, age = 1, at = Vector3.zero })
	end
	self.waves = {}
	for i = 1, 3 do
		local p = part({ Size = Vector3.new(1, 0.05, 1), Transparency = 1, Name = "Wave" .. i }, F)
		local g, cv = surface(p, 10, 3)
		local _, s1, gr = rainbowRing(cv, 0.98, 8, 0)
		local _, s2 = ring(cv, 0.9, 3, WHITE, 0.2)
		g.Enabled = false
		local shell = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one,
			Color = ICE,
			Material = Enum.Material.Glass,
			Transparency = 1,
			Reflectance = 0.3,
			Name = "WaveShell" .. i,
		}, F)
		table.insert(self.waves, { part = p, gui = g, strokes = { s1, s2 }, grad = gr, shell = shell, age = 1, str = 1 })
	end

	-- grass ring
	self.grass = {}
	for i = 1, 84 do
		local h = rr(0.7, 1.9)
		local neon = rng:NextNumber() < 0.22
		local blade = part({
			Size = Vector3.new(0.13, h, 0.05),
			Color = neon and LIME or LEAF:Lerp(LIME, rng:NextNumber() * 0.6),
			Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			Name = "Blade",
		}, F)
		table.insert(self.grass, { part = blade, a = rr(0, TAU), r = rr(POOL_R + 0.4, POOL_R + 2.2), h = h, yaw = rr(0, TAU), lean = rr(-0.35, 0.35), ph = rr(0, TAU) })
	end

	-- glass butterflies
	self.flies = {}
	for i = 1, 4 do
		local body = part({ Size = Vector3.new(0.08, 0.08, 0.42), Color = WHITE, Material = Enum.Material.Neon, Name = "Butterfly" .. i }, F)
		local wings = {}
		for side = -1, 1, 2 do
			table.insert(wings, part({
				Size = Vector3.new(0.6, 0.04, 0.46),
				Color = i % 2 == 0 and AQUA or Color3.fromRGB(150, 236, 120),
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				Reflectance = 0.3,
				Name = side < 0 and "WingL" or "WingR",
			}, F))
		end
		local t0 = new("Attachment", { Position = Vector3.new(0, 0.12, 0) }, body)
		local t1 = new("Attachment", { Position = Vector3.new(0, -0.12, 0) }, body)
		new("Trail", {
			Attachment0 = t0,
			Attachment1 = t1,
			Lifetime = 0.7,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 2,
			Color = cseq(0, WHITE, 1, AQUA),
			Transparency = seq(0, 0.3, 1, 1),
			WidthScale = seq(0, 1, 1, 0),
		}, body)
		table.insert(self.flies, { body = body, wings = wings, ph = rr(0, TAU), r = rr(3.8, 5.8), y = rr(3, 7.5), sp = rr(0.35, 0.6) * (i % 2 == 0 and -1 or 1) })
	end

	-- bokeh: camera-facing discs on one host
	self.bokehHost = part({ Size = Vector3.one * 0.2, Transparency = 1, Name = "Bokeh" }, F)
	self.bokeh = {}
	local bokehCols = { AQUA, LIME, WHITE, ICE, CREAM, SKY }
	for i = 1, 30 do
		local s = rr(0.5, 1.8)
		local bb = new("BillboardGui", {
			Adornee = self.bokehHost,
			Size = UDim2.fromScale(s, s),
			LightInfluence = 0,
			Brightness = 1.6,
			ResetOnSpawn = false,
		}, self.bokehHost)
		local col = bokehCols[(i - 1) % #bokehCols + 1]
		local d = disc(bb, 1, col, 0.62)
		new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.45 }, d)
		table.insert(self.bokeh, { gui = bb, disc = d, a = rr(0, TAU), r = rr(2, 9), y = rr(0.5, 13), vy = rr(0.15, 0.5), ph = rr(0, TAU), w = rr(0.05, 0.2) })
	end

	-- crown halo over the head: small rainbow ring + glossy ring
	self.headHalo = new("BillboardGui", {
		Name = "HeadHalo",
		Size = UDim2.fromScale(2.6, 2.6),
		LightInfluence = 0,
		Brightness = 2.4,
		ResetOnSpawn = false,
	}, F)
	local _, _, hg = rainbowRing(self.headHalo, 0.86, 4, 0.15)
	ring(self.headHalo, 0.72, 2, WHITE, 0.2)
	self.headHaloGrad = hg

	-- particle hosts
	self.groundHost = part({ Size = Vector3.new(14, 0.2, 14), Transparency = 1, Name = "Ground" }, F)
	new("ParticleEmitter", {
		Name = "Sparkles",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SPARK,
		Rate = 40,
		Lifetime = NumberRange.new(2, 4),
		Speed = NumberRange.new(1.5, 4),
		SpreadAngle = Vector2.new(15, 15),
		Size = seq(0, 0.1, 0.5, 0.35, 1, 0),
		Color = cseq(0, AQUA, 0.5, WHITE, 1, LIME),
		Transparency = seq(0, 1, 0.15, 0, 1, 1),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
		RotSpeed = NumberRange.new(-90, 90),
	}, self.groundHost)
	new("ParticleEmitter", {
		Name = "Clouds",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Texture = TEX_SMOKE,
		Rate = 5,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(50, 50),
		Size = seq(0, 3, 1, 8),
		Color = cseq(0, WHITE, 1, ICE),
		Transparency = seq(0, 1, 0.3, 0.55, 1, 1),
		LightEmission = 0.35,
		LightInfluence = 0.4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-12, 12),
	}, self.groundHost)
	self.skyHost = part({ Size = Vector3.new(12, 0.2, 12), Transparency = 1, Name = "Sky" }, F)
	new("ParticleEmitter", {
		Name = "Droplets",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Bottom,
		Texture = TEX_SPARK,
		Rate = 14,
		Lifetime = NumberRange.new(1.5, 2.2),
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, -4, 0),
		Size = seq(0, 0.25, 1, 0.1),
		Squash = seq(0, -0.6, 1, -0.6),
		Color = cseq(0, ICE, 1, AQUA),
		Transparency = seq(0, 1, 0.1, 0.1, 1, 0.6),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 3,
	}, self.skyHost)
	self.burstHost = part({ Shape = Enum.PartType.Ball, Size = Vector3.one, Transparency = 1, Name = "Burst" }, F)
	self.burst = new("ParticleEmitter", {
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Texture = TEX_SPARK,
		Rate = 0,
		Lifetime = NumberRange.new(0.9, 1.7),
		Speed = NumberRange.new(12, 28),
		Drag = 3.5,
		Size = seq(0, 0.6, 1, 0),
		Color = RAINBOW,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 4,
		Rotation = NumberRange.new(0, 360),
	}, self.burstHost)

	-- name tag
	self.tag = new("BillboardGui", {
		Name = "AuraTag",
		Adornee = self.head,
		Size = UDim2.fromScale(9, 2.3),
		StudsOffset = Vector3.new(0, 4.1, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 160,
		ResetOnSpawn = false,
	}, F)
	local odds = new("TextLabel", {
		Name = "Odds",
		Size = UDim2.fromScale(1, 0.28),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold),
		Text = Aura.Odds,
		TextScaled = true,
		TextColor3 = WHITE,
	}, self.tag)
	new("UIStroke", { Color = DEEP, Thickness = 1.5 }, odds)
	local nm = new("TextLabel", {
		Name = "Name",
		Size = UDim2.fromScale(1, 0.72),
		Position = UDim2.fromScale(0, 0.28),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy),
		Text = Aura.Name,
		TextScaled = true,
		TextColor3 = WHITE,
	}, self.tag)
	-- the Aero gloss: bright top half, hard break, saturated bottom
	new("UIGradient", {
		Rotation = 90,
		Color = cseq(0, WHITE, 0.46, Color3.fromRGB(206, 246, 255), 0.54, Color3.fromRGB(64, 196, 255), 1, Color3.fromRGB(28, 120, 240)),
	}, nm)
	new("UIStroke", { Color = Color3.fromRGB(8, 56, 150), Thickness = 2.5 }, nm)
	self.nameLabel = nm
	self.oddsLabel = odds

	self.emitters = {}
	for _, d in F:GetDescendants() do
		if d:IsA("ParticleEmitter") and d ~= self.burst and d ~= self.pop then
			table.insert(self.emitters, d)
		end
	end

	F.Parent = opts.parent
	self:Step(0)
	return self
end

function Aura:_resetBubble(b, init)
	b.a = rr(0, TAU)
	b.r = rr(2.2, 6.4)
	b.y = init and rr(0.5, 12) or rr(0.3, 1.5)
	b.vy = rr(0.45, 1.1)
	b.size = rr(0.8, 2.3)
	b.age = init and 1 or 0
	b.w = rr(0.12, 0.35) * (rng:NextNumber() < 0.5 and -1 or 1)
	b.life = rr(0.6, 1)
end

function Aura:_ripple(at, big)
	local r = self.ripples[self.rippleCursor]
	self.rippleCursor = self.rippleCursor % #self.ripples + 1
	r.age = 0
	r.at = at
	r.big = big
end

---------------------------------------------------------------------------
-- public
---------------------------------------------------------------------------
function Aura:Hold()
	self.held = true
	self.spawning = false
	self.S = 0
	self.P = 0
end

function Aura:Spawn()
	self.held = false
	self.spawning = true
	self.spawnT = 0
	self.beat = 2.2
	self:Pulse(1.4)
	Aura.emit(self.burst, 140)
end

function Aura:Pulse(str)
	str = str or 1
	local w = self.waves[self.waveCursor]
	self.waveCursor = self.waveCursor % #self.waves + 1
	w.age = 0
	w.str = str
	self.P = math.max(self.P, str)
	Aura.emit(self.burst, math.floor(45 * str))
	for _, b in self.bubbles do
		b.kick = 1
	end
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
	self.P *= math.exp(-dt * 2.6)
	local S, P = self.S, self.P
	local sc = math.max(S, 0.001)
	local visible = S > 0.01

	local rp = root.CFrame.Position
	local base = Vector3.new(rp.X, self.groundY(root), rp.Z)
	self.base = base

	-- sun
	local sunP = base + Vector3.new(0, SUN_Y + math.sin(t * 0.8) * 0.2, 0)
	self.sun.Size = Vector3.one * 2.4 * sc * (1 + P * 0.12)
	self.sun.CFrame = CFrame.new(sunP)
	self.sun.Transparency = visible and 0 or 1
	self.sunGui.Enabled = visible
	self.sunGui.Size = UDim2.fromScale(14 * sc * (1 + P * 0.2), 14 * sc * (1 + P * 0.2))
	self.sunGui.Brightness = 2.6 + P * 2
	self.rays.Rotation = t * 6
	for i, g in self.haloGrads do
		g.Rotation = (t * (i == 1 and 40 or -55)) % 360
	end
	self.sunLight.Brightness = (2 + P * 2) * S

	-- pool + rim
	self.pool.Size = Vector3.new(0.08, POOL_R * 2 * sc, POOL_R * 2 * sc)
	self.pool.CFrame = CFrame.new(base + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	self.pool.Transparency = visible and 0.35 or 1
	self.poolLight.Brightness = (2.5 + P * 3) * S
	self.rim.Size = Vector3.new((POOL_R * 2 + 1) * sc, 0.05, (POOL_R * 2 + 1) * sc)
	self.rim.CFrame = CFrame.new(base + Vector3.new(0, 0.1, 0))
	self.rimGui.Enabled = visible
	self.rimGui.Brightness = 2.4 * (1 + P)
	for i, g in self.rimSweep do
		g.Rotation = (t * (i == 1 and 50 or -70)) % 360
	end

	-- ripples: a small one every ~0.8 s, scattered over the pool
	self.rippleT -= dt
	if visible and self.rippleT <= 0 then
		self.rippleT = rr(0.5, 1.1)
		local a, r = rr(0, TAU), rr(0, POOL_R - 2)
		self:_ripple(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), false)
	end
	for _, r in self.ripples do
		if r.age < 1 then
			r.age = math.min(1, r.age + dt / 1.6)
			local e = easeOut3(r.age)
			r.gui.Enabled = r.age < 1 and visible
			local s = 0.4 + e * 4.2
			r.part.Size = Vector3.new(s, 0.05, s)
			r.part.CFrame = CFrame.new(base + r.at + Vector3.new(0, 0.12, 0))
			r.strokes[1].Transparency = 0.1 + r.age * 0.9
			r.strokes[2].Transparency = 0.3 + r.age * 0.7
		end
	end

	-- pulse waves
	for _, w in self.waves do
		if w.age < 1 then
			w.age = math.min(1, w.age + dt / 1.4)
			local e = easeOut3(w.age)
			w.gui.Enabled = w.age < 1
			local s = 1 + e * 30
			w.part.Size = Vector3.new(s, 0.05, s)
			w.part.CFrame = CFrame.new(base + Vector3.new(0, 0.14, 0))
			w.strokes[1].Transparency = w.age
			w.strokes[2].Transparency = 0.2 + w.age * 0.8
			w.grad.Rotation = (t * 90) % 360
			w.shell.Size = Vector3.one * (2 + e * 20)
			w.shell.CFrame = CFrame.new(base + Vector3.new(0, 4.4, 0))
			w.shell.Transparency = 0.55 + w.age * 0.45
		end
	end

	-- aurora curtains sway like Vista light
	self.host.CFrame = CFrame.new(base)
	for _, c in self.curtains do
		local a = c.a + t * 0.06 + math.sin(t * 0.3 + c.ph) * 0.08
		local r = c.r * sc
		c.a0.Position = Vector3.new(math.cos(a) * r, 0.2, math.sin(a) * r)
		local top = r * 1.25 + math.sin(t * 0.5 + c.ph) * 0.8
		c.a1.Position = Vector3.new(math.cos(a + 0.12) * top, c.h * math.min(1, S), math.sin(a + 0.12) * top)
		c.beam.CurveSize0 = math.sin(t * 0.7 + c.ph) * 2.2
		c.beam.CurveSize1 = math.cos(t * 0.55 + c.ph) * 2.2
		c.beam.Brightness = (2.2 + P * 1.8) * (0.75 + 0.25 * math.sin(t * 1.3 + c.ph))
		c.beam.Enabled = visible
	end

	-- swooshes: three bundles of five ribbons sweeping around the player
	for _, s in self.swooshes do
		local ph = (s.bundle - 1) / 3 * TAU + t * 0.45
		local spread = (s.k - 3) * 0.09
		local r0, r1 = 5.2 * sc, 3.2 * sc
		s.a0.Position = Vector3.new(math.cos(ph) * r0, 0.6 + spread, math.sin(ph) * r0)
		s.a1.Position = Vector3.new(math.cos(ph + 2.3) * r1, (8 + s.bundle * 1.2) * math.min(1, S) + spread * 3, math.sin(ph + 2.3) * r1)
		s.beam.CurveSize0 = 5 + s.k * 0.45 + math.sin(t * 0.9 + s.bundle) * 0.8
		s.beam.CurveSize1 = -2.5 - s.k * 0.3
		s.beam.Enabled = visible
	end

	-- bubbles rise, wobble and pop
	for _, b in self.bubbles do
		b.age = math.min(1, b.age + dt * 1.5)
		b.y += b.vy * dt
		b.a += b.w * dt
		local kick = b.kick or 0
		b.kick = kick * math.exp(-dt * 4)
		if b.y > 13 or (b.y > 4 and rng:NextNumber() < dt * 0.04) then
			self.popHost.CFrame = b.part.CFrame
			if visible then
				Aura.emit(self.pop, 14)
			end
			self:_resetBubble(b, false)
		end
		local wob = 1 + math.sin(t * 3.1 + b.ph) * 0.04 + kick * 0.15
		local size = b.size * easeOut3(b.age) * sc * wob
		local r = b.r * sc * (1 + kick * 0.2)
		local pos = base + Vector3.new(math.cos(b.a) * r + math.sin(t + b.ph) * 0.3, b.y, math.sin(b.a) * r)
		b.part.Size = Vector3.new(size, size * (1 - (wob - 1) * 0.6), size)
		b.part.CFrame = CFrame.new(pos)
		b.part.Transparency = visible and 0.5 or 1
		b.gui.Enabled = visible
		b.gui.Size = UDim2.fromScale(size, size)
		b.gui.StudsOffset = Vector3.new(0, 0, size * 0.52)
		b.film.Rotation = (t * 60 + b.ph * 57) % 360
	end

	-- grass sways
	local gust = math.sin(t * 0.9) * 0.15
	for _, g in self.grass do
		local r = g.r * sc
		local at = base + Vector3.new(math.cos(g.a) * r, 0, math.sin(g.a) * r)
		local sway = g.lean + gust + math.sin(t * 2.2 + g.ph) * 0.12 + P * 0.25
		g.part.CFrame = CFrame.new(at) * CFrame.Angles(0, g.yaw, 0) * CFrame.Angles(sway, 0, 0) * CFrame.new(0, g.h * 0.5 * math.min(1, S), 0)
		g.part.Transparency = visible and 0 or 1
	end

	-- butterflies
	for _, f in self.flies do
		local a = f.ph + t * f.sp
		local pos = base + Vector3.new(math.cos(a) * f.r * sc, f.y + math.sin(t * 1.7 + f.ph) * 0.8, math.sin(a * 1.3) * f.r * sc)
		local vel = Vector3.new(-math.sin(a) * f.r, math.cos(t * 1.7 + f.ph) * 0.8, math.cos(a * 1.3) * f.r * 1.3) * f.sp
		local cf = vel.Magnitude > 0.01 and CFrame.lookAt(pos, pos + vel) or CFrame.new(pos)
		local flap = math.sin(t * 15 + f.ph) * 0.95
		f.body.CFrame = cf
		f.body.Transparency = visible and 0 or 1
		for i, w in f.wings do
			local side = i == 1 and -1 or 1
			w.CFrame = cf * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.32, 0, 0)
			w.Transparency = visible and 0.2 or 1
		end
	end

	-- bokeh drift
	self.bokehHost.CFrame = CFrame.new(base)
	for _, b in self.bokeh do
		b.y += b.vy * dt
		if b.y > 14 then
			b.y = 0.5
		end
		local a = b.a + t * b.w
		b.gui.StudsOffsetWorldSpace = Vector3.new(math.cos(a) * b.r * sc, b.y, math.sin(a) * b.r * sc)
		b.gui.Enabled = visible
		b.disc.BackgroundTransparency = 0.62 + 0.3 * (0.5 + 0.5 * math.sin(t * 1.4 + b.ph)) - P * 0.25
	end

	-- head halo
	local head = self.head
	if head and head.Parent then
		self.headHalo.Adornee = head
		self.headHalo.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y * 0.5 + 0.9 + math.sin(t * 2) * 0.08, 0)
	end
	self.headHalo.Enabled = visible
	self.headHaloGrad.Rotation = (t * 80) % 360

	-- particle hosts
	self.groundHost.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0))
	self.skyHost.CFrame = CFrame.new(base + Vector3.new(0, 13, 0))
	self.burstHost.CFrame = CFrame.new(base + Vector3.new(0, 3, 0))
	local emitOn = S > 0.5
	for _, e in self.emitters do
		if e.Enabled ~= emitOn then
			e.Enabled = emitOn
		end
	end

	-- tag
	self.tag.Enabled = visible
	local tr = 1 - clamp01(S)
	self.nameLabel.TextTransparency = tr
	self.oddsLabel.TextTransparency = tr

	return pulsed
end

function Aura:Destroy()
	self.folder:Destroy()
	self.root = nil
end

return Aura
