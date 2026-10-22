--[[
	Roll cutscene, glass HUD and lens flare for Aerosphere.

		local cs = AeroCutscene.new(playerGui, function() return camera.ViewportSize end, AeroAura)
		cs.onImpact = function() aura:Spawn() end
		cs:Play()
		RunService.RenderStepped:Connect(function(dt) cs:Step(dt) end)
		cs:Flare(sunScreenPos or nil, strength)   -- every frame

	Timeline (seconds): 0 fade to black · 0.5 aurora curtains open · 0.95 odds ·
	bubbles rise and chimes speed up · the sun swells · 4.4 white-out with a rainbow
	ring and the title · 7.4 done. Step only sets properties, so build.luau runs it under Lune.
]]

local Cutscene = {}
Cutscene.__index = Cutscene

local TAU = math.pi * 2
local IMPACT = 4.4
local LENGTH = 7.4
local CHIMES = { 0.7, 1.4, 2.0, 2.5, 2.9, 3.25, 3.55, 3.8, 4.0, 4.15, 4.27 }

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(8, 44, 112)
local ICE = Color3.fromRGB(214, 246, 255)
local AQUA = Color3.fromRGB(70, 222, 255)
local SKY = Color3.fromRGB(80, 170, 255)
local BLUE = Color3.fromRGB(28, 104, 245)
local DEEP = Color3.fromRGB(6, 30, 120)
local LIME = Color3.fromRGB(168, 238, 66)
local CREAM = Color3.fromRGB(255, 251, 228)

local function nunito(weight)
	return Font.new("rbxasset://fonts/families/Nunito.json", weight)
end

local rng = Random.new()
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function easeInOut(x)
	x = clamp01(x)
	return x < 0.5 and 4 * x * x * x or 1 - (-2 * x + 2) ^ 3 / 2
end

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
local function circle(parent, d, color, transp, z)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(d, d),
		BackgroundColor3 = color or WHITE,
		BackgroundTransparency = transp or 1,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	return f
end

-- Aero glass: translucent aqua, white gloss on the top half, soft white edge
local function glass(parent, props, radius)
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, f)
	new("UIGradient", {
		Rotation = 90,
		Color = cseq(0, Color3.fromRGB(236, 251, 255), 0.49, Color3.fromRGB(176, 228, 255), 0.51, Color3.fromRGB(96, 188, 255), 1, Color3.fromRGB(52, 140, 240)),
		Transparency = seq(0, 0.15, 0.49, 0.3, 0.51, 0.45, 1, 0.3),
	}, f)
	new("UIStroke", { Color = WHITE, Transparency = 0.25, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f
end

local function label(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		FontFace = nunito(Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in props do
		l[k] = v
	end
	return l
end

function Cutscene.new(parentGui, getViewport, aura)
	aura = aura or require(script.Parent.AeroAura)
	local self = setmetatable({}, Cutscene)
	self.getViewport = getViewport
	self.playing = false
	self.t = 0

	local gui = new("ScreenGui", {
		Name = "AerosphereUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.gui = gui

	---------------------------------------------------------------- lens flare (under everything)
	local flare = new("Frame", { Name = "LensFlare", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, gui)
	self.flare = flare
	self.flareGlare = circle(flare, 0, WHITE, 1, 1)
	self.flareGlare.Size = UDim2.fromOffset(260, 260)
	new("UIGradient", { Transparency = seq(0, 1, 0.3, 0.75, 0.5, 0.35, 0.7, 0.75, 1, 1), Color = cseq(0, AQUA, 0.5, WHITE, 1, AQUA) }, self.flareGlare)
	self.flareStreak = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(700, 3),
		BackgroundColor3 = ICE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, flare)
	new("UIGradient", { Transparency = seq(0, 1, 0.5, 0.2, 1, 1) }, self.flareStreak)
	self.ghosts = {}
	local ghostSpec = {
		{ 0.25, 46, AQUA, false },
		{ 0.45, 22, LIME, false },
		{ 0.62, 90, SKY, true },
		{ 0.8, 34, CREAM, false },
		{ 1.1, 140, AQUA, true },
		{ 1.35, 60, LIME, false },
		{ 1.6, 26, WHITE, false },
	}
	for _, g in ghostSpec do
		local c = circle(flare, 0, g[3], 1, 2)
		c.Size = UDim2.fromOffset(g[2], g[2])
		local stroke = g[4] and new("UIStroke", { Color = WHITE, Thickness = 3, Transparency = 1 }, c) or nil
		if stroke then
			new("UIGradient", { Color = aura.Rainbow }, stroke)
		end
		table.insert(self.ghosts, { frame = c, k = g[1], stroke = stroke, ring = g[4] })
	end

	---------------------------------------------------------------- HUD
	local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, gui)
	self.hud = hud
	new("UIPadding", {
		PaddingTop = UDim.new(0, 58),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, hud)

	local info = glass(hud, {
		Name = "Info",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(276, 300),
	}, 14)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, info)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, info)
	label(info, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 14), Text = "AURA COLLECTION", TextSize = 12, TextColor3 = INK })
	local title = label(info, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 34), Text = aura.Name, TextSize = 32, FontFace = nunito(Enum.FontWeight.Heavy) })
	new("UIGradient", { Rotation = 90, Color = cseq(0, WHITE, 0.48, ICE, 0.52, AQUA, 1, BLUE) }, title)
	new("UIStroke", { Color = INK, Thickness = 2 }, title)
	label(info, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), Text = string.upper(aura.Odds), TextSize = 13, TextColor3 = INK })
	local cond = glass(info, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 52) }, 10)
	label(cond, { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.08), Text = "REQUIRED CONDITIONS", TextSize = 11, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Center })
	label(cond, {
		Size = UDim2.new(1, 0, 0.45, 0),
		Position = UDim2.fromScale(0, 0.5),
		Text = `During {aura.Condition}`,
		TextSize = 17,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = nunito(Enum.FontWeight.ExtraBold),
	})
	label(info, {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 92),
		Text = aura.Lore,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = INK,
		FontFace = nunito(Enum.FontWeight.SemiBold),
		LineHeight = 1.1,
	})

	local bar = new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, hud)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	-- glossy Aqua pill buttons
	local function pill(parent, text, props)
		local b = new("TextButton", {
			Text = text,
			TextColor3 = WHITE,
			TextSize = 15,
			FontFace = nunito(Enum.FontWeight.ExtraBold),
			AutoButtonColor = true,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, parent)
		for k, v in props do
			b[k] = v
		end
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
		new("UIGradient", {
			Rotation = 90,
			Color = cseq(0, Color3.fromRGB(196, 238, 255), 0.48, Color3.fromRGB(110, 200, 255), 0.52, Color3.fromRGB(30, 132, 245), 1, Color3.fromRGB(70, 200, 255)),
		}, b)
		new("UIStroke", { Color = Color3.fromRGB(14, 78, 190), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		new("UIStroke", { Color = Color3.fromRGB(14, 60, 150), Thickness = 1.5, Transparency = 0.4 }, b)
		return b
	end
	self.replayButton = pill(bar, "Replay Cutscene", { LayoutOrder = 1, Size = UDim2.fromOffset(162, 40) })
	self.skyButton = pill(bar, "Aero Sky", { LayoutOrder = 2, Size = UDim2.fromOffset(118, 40) })
	self.hideButton = pill(bar, "Hide UI", { LayoutOrder = 3, Size = UDim2.fromOffset(96, 40) })
	self.showButton = pill(gui, "Show UI", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(96, 40),
		Visible = false,
		ZIndex = 4,
	})

	---------------------------------------------------------------- cutscene
	local cs = new("Frame", {
		Name = "Cutscene",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, gui)
	self.cs = cs
	local space = new("Frame", {
		Name = "Space",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = DEEP,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, cs)
	self.space = space
	new("UIGradient", { Rotation = 90, Color = cseq(0, Color3.fromRGB(2, 8, 30), 0.6, DEEP, 1, BLUE) }, space)

	-- light curtains: tall frames with vertical gradients, drifting sideways
	self.curtains = {}
	for i = 1, 16 do
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(i / 17, -0.1),
			Size = UDim2.fromScale(0.06 + rng:NextNumber() * 0.1, 1.05),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 11,
		}, space)
		new("UIGradient", {
			Rotation = 90,
			Color = cseq(0, CREAM, 0.3, LIME, 0.6, AQUA, 1, BLUE),
			Transparency = seq(0, 0.2, 0.55, 0.55, 0.85, 0.85, 1, 1),
		}, f)
		table.insert(self.curtains, { frame = f, x = i / 17, ph = rng:NextNumber() * TAU, w = f.Size.X.Scale })
	end
	-- the reflective floor + horizon line
	local floor = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.24),
		BackgroundColor3 = BLUE,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, space)
	new("UIGradient", { Rotation = 90, Color = cseq(0, Color3.fromRGB(60, 140, 255), 1, Color3.fromRGB(10, 50, 170)), Transparency = seq(0, 0.1, 1, 0.3) }, floor)
	self.horizon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.76),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = ICE,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, space)
	new("UIGradient", { Transparency = seq(0, 0.8, 0.5, 0, 1, 0.8) }, self.horizon)

	-- swoosh: a fan of thin lines that sweeps across
	self.swoosh = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.6),
		Size = UDim2.fromScale(0.9, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 14,
	}, space)
	self.swooshLines = {}
	for k = 1, 9 do
		local l = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5 + (k - 5) * 0.015),
			Size = UDim2.new(1, 0, 0, k % 3 == 0 and 3 or 2),
			BackgroundColor3 = ICE,
			BorderSizePixel = 0,
			ZIndex = 14,
		}, self.swoosh)
		new("UIGradient", { Transparency = seq(0, 1, 0.3, 0.35, 0.7, 0.5, 1, 1) }, l)
		table.insert(self.swooshLines, { frame = l, k = k })
	end

	-- rising bubbles
	self.bubbles = {}
	for i = 1, 22 do
		local s = 20 + rng:NextNumber() * 70
		local b = circle(space, 0, ICE, 0.85, 15)
		b.Size = UDim2.fromOffset(s, s)
		local st = new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.35 }, b)
		new("UIGradient", { Color = aura.Rainbow, Rotation = rng:NextNumber() * 360 }, st)
		local spec = circle(b, 0.3, WHITE, 0.1, 16)
		spec.Position = UDim2.fromScale(0.32, 0.3)
		spec.Size = UDim2.fromScale(0.34, 0.22)
		spec.Rotation = -35
		table.insert(self.bubbles, { frame = b, x = rng:NextNumber(), y = 1 + rng:NextNumber(), sp = 0.08 + rng:NextNumber() * 0.18, ph = rng:NextNumber() * TAU })
	end

	-- the sun that swells into the white-out
	local sun = new("Frame", {
		Name = "Sun",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.05, 0.05),
		BackgroundTransparency = 1,
		ZIndex = 17,
	}, space)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, sun)
	self.sun = sun
	circle(sun, 4, AQUA, 0.9, 17)
	circle(sun, 2.4, ICE, 0.75, 17)
	self.sunRing = circle(sun, 1.7, WHITE, 1, 18)
	local rs = new("UIStroke", { Color = WHITE, Thickness = 4, Transparency = 0.2 }, self.sunRing)
	self.sunRingGrad = new("UIGradient", { Color = aura.Rainbow }, rs)
	circle(sun, 1.2, WHITE, 0.3, 18)
	circle(sun, 0.8, WHITE, 0, 19)

	self.odds = label(cs, {
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.new(0.9, 0, 0, 36),
		Text = string.upper(aura.Odds),
		TextSize = 28,
		FontFace = nunito(Enum.FontWeight.ExtraBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 20,
	})
	self.oddsStroke = new("UIStroke", { Color = BLUE, Thickness = 2, Transparency = 1 }, self.odds)

	self.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(246, 252, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, gui)
	self.bigRing = circle(gui, 0, WHITE, 1, 31)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, self.bigRing)
	self.bigRingStroke = new("UIStroke", { Color = WHITE, Thickness = 14, Transparency = 1 }, self.bigRing)
	new("UIGradient", { Color = aura.Rainbow }, self.bigRingStroke)

	local titleWrap = new("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 160),
		BackgroundTransparency = 1,
		ZIndex = 32,
	}, gui)
	self.titleScale = new("UIScale", { Scale = 1 }, titleWrap)
	self.title = label(titleWrap, {
		Size = UDim2.fromScale(1, 0.74),
		Text = aura.Name,
		TextScaled = true,
		FontFace = nunito(Enum.FontWeight.Heavy),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 33,
	})
	new("UIGradient", { Rotation = 90, Color = cseq(0, WHITE, 0.47, ICE, 0.53, AQUA, 1, BLUE) }, self.title)
	self.titleStroke = new("UIStroke", { Color = INK, Thickness = 4, Transparency = 1 }, self.title)
	new("UITextSizeConstraint", { MaxTextSize = 120 }, self.title)
	self.sub = label(titleWrap, {
		Position = UDim2.fromScale(0, 0.78),
		Size = UDim2.fromScale(1, 0.2),
		Text = "has been rolled",
		TextScaled = true,
		FontFace = nunito(Enum.FontWeight.Bold),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 33,
	})
	self.subStroke = new("UIStroke", { Color = INK, Thickness = 2, Transparency = 1 }, self.sub)
	new("UITextSizeConstraint", { MaxTextSize = 24 }, self.sub)

	gui.Parent = parentGui
	return self
end

function Cutscene:SetHudVisible(on)
	self.hudWanted = on
	self.hud.Visible = on and not self.playing
	self.showButton.Visible = not on and not self.playing
end

function Cutscene:Play()
	self.playing = true
	self.t = 0
	self.fired = {}
	self.cs.Visible = true
	self.hud.Visible = false
	self.showButton.Visible = false
	self.cs.BackgroundTransparency = 1
	self.space.Visible = false
	for _, b in self.bubbles do
		b.y = 1 + rng:NextNumber()
	end
end

function Cutscene:_once(key, at, fn)
	if self.t >= at and not self.fired[key] then
		self.fired[key] = true
		fn()
	end
end

-- screen-space lens flare; pos is the sun's viewport position or nil when off-screen
function Cutscene:Flare(pos, strength)
	local vp = self.getViewport()
	local on = pos ~= nil and strength > 0.01 and not self.playing
	self.flare.Visible = on
	if not on then
		return
	end
	local cx, cy = vp.X * 0.5, vp.Y * 0.5
	local dx, dy = cx - pos.X, cy - pos.Y
	-- brighter when the sun is near the middle of the screen
	local centered = 1 - math.min(1, math.sqrt(dx * dx + dy * dy) / math.max(vp.Y, 1))
	local a = strength * (0.35 + 0.65 * centered)
	self.flareGlare.Position = UDim2.fromOffset(pos.X, pos.Y)
	self.flareGlare.BackgroundTransparency = 1 - a * 0.9
	self.flareStreak.Position = UDim2.fromOffset(pos.X, pos.Y)
	self.flareStreak.BackgroundTransparency = 1 - a * 0.8
	for _, g in self.ghosts do
		g.frame.Position = UDim2.fromOffset(pos.X + dx * 2 * g.k, pos.Y + dy * 2 * g.k)
		if g.ring then
			g.frame.BackgroundTransparency = 1 - a * 0.08
			g.stroke.Transparency = 1 - a * 0.45
		else
			g.frame.BackgroundTransparency = 1 - a * 0.22
		end
	end
end

function Cutscene:Step(dt)
	if not self.playing then
		return
	end
	self.t += dt
	local t = self.t
	local vp = self.getViewport()
	local W, H = math.max(vp.X, 1), math.max(vp.Y, 1)

	if t < 0.5 then
		self.cs.BackgroundTransparency = 1 - t / 0.5
	elseif t < IMPACT then
		self.cs.BackgroundTransparency = 0
		self.space.Visible = true
	end

	for i, c in CHIMES do
		self:_once("chime" .. i, c, function()
			self.kick = 1
			if self.onBeat then
				self.onBeat(i)
			end
		end)
	end
	self.kick = (self.kick or 0) * math.exp(-dt * 6)

	if t < IMPACT then
		local k = easeInOut((t - 0.5) / 3.9)
		local open = clamp01((t - 0.5) / 1.2)
		for _, c in self.curtains do
			c.frame.Position = UDim2.fromScale(c.x + math.sin(t * 0.6 + c.ph) * 0.02, -0.1)
			c.frame.Size = UDim2.fromScale(c.w * (0.8 + 0.3 * math.sin(t * 0.9 + c.ph)), 0.86 * open + 0.01)
			c.frame.BackgroundTransparency = 1 - open * (0.35 + 0.25 * math.sin(t * 1.3 + c.ph) + self.kick * 0.2)
		end
		self.horizon.BackgroundTransparency = 1 - open
		-- swoosh fan sweeps in from the left
		local sw = clamp01((t - 0.8) / 2.6)
		self.swoosh.Position = UDim2.fromScale(-0.2 + sw * 0.62, 0.62 - sw * 0.08)
		self.swoosh.Rotation = -28 + sw * 14
		for _, l in self.swooshLines do
			l.frame.Rotation = (l.k - 5) * (2 + sw * 2) + math.sin(t * 1.5 + l.k) * 1.5
			l.frame.BackgroundTransparency = 1 - open * 0.8
		end
		-- bubbles rise faster as the chimes speed up
		for _, b in self.bubbles do
			b.y -= dt * b.sp * (1 + k * 3)
			if b.y < -0.2 then
				b.y = 1.1
				b.x = rng:NextNumber()
			end
			b.frame.Position = UDim2.fromOffset((b.x + math.sin(t * 1.2 + b.ph) * 0.02) * W, b.y * H)
			b.frame.BackgroundTransparency = 1 - open * 0.18
		end
		-- sun swells
		local s = 0.04 + k * 0.32 + self.kick * 0.02
		self.sun.Size = UDim2.fromScale(s, s)
		self.sunRingGrad.Rotation = (t * 120) % 360
		local oa = clamp01((t - 0.95) / 0.8) * (1 - clamp01((t - 4.05) / 0.25))
		self.odds.TextTransparency = 1 - oa
		self.oddsStroke.Transparency = 1 - oa * 0.7
		self.odds.TextSize = 28 + self.kick * 3
		if t > 3.8 then
			self.flash.BackgroundTransparency = 1 - clamp01((t - 3.8) / 0.6) * 0.75
		end
	end

	self:_once("impact", IMPACT, function()
		self.space.Visible = false
		self.cs.BackgroundTransparency = 1
		self.flash.BackgroundTransparency = 0
		if self.onImpact then
			self.onImpact()
		end
	end)

	if t >= IMPACT then
		local u = t - IMPACT
		self.flash.BackgroundTransparency = clamp01(u / 1.1) ^ 0.6
		local rk = clamp01(u / 1.2)
		local rs = 0.1 + (1 - (1 - rk) ^ 3) * 1.8
		self.bigRing.Size = UDim2.fromScale(rs, rs)
		self.bigRingStroke.Transparency = rk
		self.bigRingStroke.Thickness = 18 * (1 - rk) + 2
		local s
		if u < 0.25 then
			s = 1.8 - 0.85 * (u / 0.25)
		elseif u < 0.55 then
			s = 0.95 + 0.07 * math.sin((u - 0.25) / 0.3 * math.pi)
		else
			s = 1 + (u - 0.55) * 0.03
		end
		self.titleScale.Scale = s
		local a = clamp01(u / 0.2) * (1 - clamp01((u - 2.2) / 0.6))
		self.title.TextTransparency = 1 - a
		self.titleStroke.Transparency = 1 - a
		local sa = clamp01((u - 0.35) / 0.4) * (1 - clamp01((u - 2.2) / 0.6))
		self.sub.TextTransparency = 1 - sa
		self.subStroke.Transparency = 1 - sa
	end

	if t >= LENGTH then
		self.playing = false
		self.cs.Visible = false
		self.flash.BackgroundTransparency = 1
		self.bigRingStroke.Transparency = 1
		self.title.TextTransparency = 1
		self.titleStroke.Transparency = 1
		self.sub.TextTransparency = 1
		self.subStroke.Transparency = 1
		self:SetHudVisible(self.hudWanted ~= false)
		if self.onEnd then
			self.onEnd()
		end
	end
end

Cutscene.Impact = IMPACT
Cutscene.Length = LENGTH

return Cutscene
