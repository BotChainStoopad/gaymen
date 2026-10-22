--[[
	Roll cutscene + HUD for Umbral Sovereign.

		local cs = UmbralCutscene.new(playerGui, function() return camera.ViewportSize end)
		cs.onImpact = function() aura:Spawn() end
		cs:Play()
		RunService.RenderStepped:Connect(function(dt) cs:Step(dt) end)

	Timeline (seconds): 0 fade to black · 0.5 warp tunnel · 0.95 odds · heartbeats speed up ·
	1.0–4.4 the void rushes in · 4.4 impact flash + title slam · 7.4 done.
	Step only sets properties, so build.luau can run the whole timeline under Lune.
]]

local Cutscene = {}
Cutscene.__index = Cutscene

local TAU = math.pi * 2
local IMPACT = 4.4
local LENGTH = 7.4
local BEATS = { 0.7, 1.55, 2.2, 2.65, 3.0, 3.3, 3.55, 3.76, 3.94, 4.08, 4.2 }

local INK = Color3.fromRGB(241, 233, 255)
local DIM = Color3.fromRGB(168, 152, 204)
local ORCHID = Color3.fromRGB(228, 188, 255)
local PURPLE = Color3.fromRGB(160, 96, 255)
local VIOLET = Color3.fromRGB(112, 44, 235)
local DEEP = Color3.fromRGB(46, 10, 110)
local HOT = Color3.fromRGB(255, 236, 255)
local PANEL = Color3.fromRGB(12, 7, 24)

local rng = Random.new()
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function easeIn3(x)
	return clamp01(x) ^ 3
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
local function circle(parent, d, color, transp, z)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(d, d),
		BackgroundColor3 = color or Color3.new(),
		BackgroundTransparency = transp or 1,
		BorderSizePixel = 0,
		ZIndex = z or 1,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	return f
end

-- bracket-cornered panel (the collection-screen look)
local function bracketed(parent, props)
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	new("UIStroke", { Color = ORCHID, Transparency = 0.85, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local h = new("Frame", {
			AnchorPoint = Vector2.new(c[1], c[2]),
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(10, 2),
			BackgroundColor3 = ORCHID,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, f)
		h.Name = "Bracket"
		new("Frame", {
			AnchorPoint = Vector2.new(c[1], c[2]),
			Position = UDim2.fromScale(c[1], c[2]),
			Size = UDim2.fromOffset(2, 10),
			BackgroundColor3 = ORCHID,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, f)
	end
	return f
end

local function label(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = INK,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in props do
		l[k] = v
	end
	return l
end

function Cutscene.new(parentGui, getViewport, aura)
	aura = aura or require(script.Parent.UmbralAura)
	local self = setmetatable({}, Cutscene)
	self.getViewport = getViewport
	self.playing = false
	self.t = 0
	self.onImpact = nil
	self.onBeat = nil
	self.onEnd = nil

	local gui = new("ScreenGui", {
		Name = "UmbralSovereignUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.gui = gui

	---------------------------------------------------------------- HUD
	local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.hud = hud
	new("UIPadding", {
		PaddingTop = UDim.new(0, 58),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, hud)

	local info = bracketed(hud, {
		Name = "Info",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(270, 300),
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, info)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, info)
	label(info, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12), Text = "AURA COLLECTION", TextSize = 11, TextColor3 = ORCHID, Font = Enum.Font.GothamBold })
	local title = label(info, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), Text = aura.Name, TextSize = 27, Font = Enum.Font.Bodoni })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(164, 107, 255)) }, title)
	label(info, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), Text = string.upper(aura.Odds), TextSize = 12, TextColor3 = DIM, Font = Enum.Font.GothamMedium })
	local cond = bracketed(info, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 52) })
	label(cond, { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.1), Text = "REQUIRED CONDITIONS", TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamMedium })
	label(cond, {
		Size = UDim2.new(1, 0, 0.45, 0),
		Position = UDim2.fromScale(0, 0.5),
		RichText = true,
		Text = `During <font color="#E4BCFF">{aura.Condition}</font>`,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.Bodoni,
	})
	label(info, {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 90),
		Text = aura.Lore,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(217, 204, 242),
		LineHeight = 1.15,
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
	local function button(text, order, width)
		local b = bracketed(bar, { LayoutOrder = order, Size = UDim2.fromOffset(width, 40) })
		local tb = new("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = INK,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			ZIndex = 4,
		}, b)
		return tb
	end
	self.replayButton = button("REPLAY CUTSCENE", 1, 160)
	self.skyButton = button("ECLIPSE SKY", 2, 124)
	self.hideButton = button("HIDE UI", 3, 92)
	self.showButton = bracketed(gui, {
		Name = "ShowUI",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(92, 40),
		Visible = false,
	})
	self.showButtonText = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "SHOW UI",
		TextColor3 = INK,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = 4,
	}, self.showButton)

	---------------------------------------------------------------- cutscene layers
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
	self.space = new("Frame", {
		Name = "Space",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		ZIndex = 10,
	}, cs)

	-- nebula swirl: big circles with rotating gradients
	self.nebula = {}
	for i = 1, 3 do
		local n = circle(self.space, 1.4 + i * 0.25, i == 2 and VIOLET or DEEP, 0.2, 11)
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, n)
		local g = new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, DEEP),
				ColorSequenceKeypoint.new(0.5, i == 2 and PURPLE or VIOLET),
				ColorSequenceKeypoint.new(1, DEEP),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.9),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.65, 0.9),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, n)
		table.insert(self.nebula, { frame = n, grad = g, speed = (i % 2 == 0 and -1 or 1) * (14 + i * 6) })
	end

	-- warp streaks
	self.streaks = {}
	for i = 1, 140 do
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = i % 3 == 0 and HOT or ORCHID,
			BorderSizePixel = 0,
			ZIndex = 12,
		}, self.space)
		table.insert(self.streaks, { frame = f, a = rng:NextNumber() * TAU, d = rng:NextNumber(), sp = 0.4 + rng:NextNumber() * 0.8 })
	end

	-- the void: black disc, photon ring, glow, flattened accretion band
	local void = new("Frame", {
		Name = "Void",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.02, 0.02),
		BackgroundTransparency = 1,
		ZIndex = 13,
	}, self.space)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, void)
	self.void = void
	circle(void, 3.2, VIOLET, 0.88, 13)
	circle(void, 2.1, PURPLE, 0.7, 13)
	local back = circle(void, 2.6, PURPLE, 1, 13)
	back.Size = UDim2.fromScale(3, 0.5)
	new("UIStroke", { Color = PURPLE, Thickness = 6, Transparency = 0.25 }, back)
	circle(void, 1.12, HOT, 0, 14)
	circle(void, 1, Color3.new(), 0, 15)
	local front = circle(void, 2.6, PURPLE, 1, 16)
	front.Size = UDim2.fromScale(2.6, 0.38)
	front.Position = UDim2.fromScale(0.5, 0.56)
	self.voidStroke = new("UIStroke", { Color = HOT, Thickness = 4, Transparency = 0 }, front)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.4),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.55, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Rotation = 90,
	}, self.voidStroke)
	self.voidScale = new("UIScale", { Scale = 1 }, void)

	self.odds = label(cs, {
		Name = "Odds",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 34),
		Text = string.upper(aura.Odds),
		TextSize = 26,
		Font = Enum.Font.Michroma,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 20,
	})
	self.oddsStroke = new("UIStroke", { Color = PURPLE, Thickness = 2, Transparency = 1 }, self.odds)

	self.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(246, 236, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, gui)

	local titleWrap = new("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 150),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, gui)
	self.titleScale = new("UIScale", { Scale = 1 }, titleWrap)
	self.title = label(titleWrap, {
		Size = UDim2.fromScale(1, 0.72),
		Text = string.upper(aura.Name),
		TextScaled = true,
		Font = Enum.Font.Bodoni,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 32,
	})
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(246, 236, 255)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(196, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 60, 240)),
		}),
	}, self.title)
	self.titleStroke = new("UIStroke", { Color = Color3.fromRGB(26, 6, 52), Thickness = 3, Transparency = 1 }, self.title)
	new("UITextSizeConstraint", { MaxTextSize = 110 }, self.title)
	self.sub = label(titleWrap, {
		Position = UDim2.fromScale(0, 0.76),
		Size = UDim2.fromScale(1, 0.2),
		Text = "H A S   B E E N   R O L L E D",
		TextScaled = true,
		Font = Enum.Font.Michroma,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 32,
	})
	new("UITextSizeConstraint", { MaxTextSize = 20 }, self.sub)

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
	for _, s in self.streaks do
		s.d = rng:NextNumber()
	end
end

function Cutscene:_once(key, at, fn)
	if self.t >= at and not self.fired[key] then
		self.fired[key] = true
		fn()
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
	local diag = math.sqrt(W * W + H * H) * 0.5

	-- fade to black, then open on the warp
	if t < 0.5 then
		self.cs.BackgroundTransparency = 1 - t / 0.5
	elseif t < IMPACT then
		self.cs.BackgroundTransparency = 0
		self.space.Visible = true
	end

	for i, b in BEATS do
		self:_once("beat" .. i, b, function()
			self.kick = 1
			if self.onBeat then
				self.onBeat(i)
			end
		end)
	end
	self.kick = (self.kick or 0) * math.exp(-dt * 7)

	if t < IMPACT then
		local k = easeIn3((t - 0.5) / 3.9)
		-- streaks
		for _, s in self.streaks do
			s.d += dt * s.sp * (0.12 + k * 2.6)
			if s.d > 1.1 then
				s.d -= 1.1
				s.a = rng:NextNumber() * TAU
			end
			local len = 4 + (k * 220 + 10) * s.d
			local r = s.d * diag + len * 0.5
			s.frame.Position = UDim2.fromOffset(W * 0.5 + math.cos(s.a) * r, H * 0.5 + math.sin(s.a) * r)
			s.frame.Size = UDim2.fromOffset(len, 1 + math.floor(s.d * 2.5))
			s.frame.Rotation = math.deg(s.a)
			s.frame.BackgroundTransparency = 1 - math.min(1, s.d * 1.8) * (0.45 + k * 0.55)
		end
		for _, n in self.nebula do
			n.grad.Rotation = (t * n.speed * (1 + k * 3)) % 360
			n.frame.BackgroundTransparency = 0.2 + 0.6 * (1 - clamp01((t - 0.5) / 1.5)) - self.kick * 0.1
		end
		-- void approaches
		local ck = easeInOut((t - 1.0) / 3.4)
		local px = 0.02 + ck * 0.34
		self.void.Size = UDim2.fromScale(px, px)
		self.voidScale.Scale = 1 + self.kick * 0.06
		self.voidStroke.Thickness = 2 + ck * 8
		self.void.Rotation = math.sin(t * 0.6) * 4 * k

		-- odds text
		local oa = clamp01((t - 0.95) / 0.8) * (1 - clamp01((t - 4.05) / 0.25))
		self.odds.TextTransparency = 1 - oa
		self.oddsStroke.Transparency = 1 - oa * 0.6
		self.odds.TextSize = 26 + self.kick * 3

		-- lightning flicker right before impact
		if t > 3.7 then
			self.flash.BackgroundTransparency = rng:NextNumber() < 0.35 and 1 - (0.12 + rng:NextNumber() * 0.28) or 1
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
		self.flash.BackgroundTransparency = clamp01(u / 0.9) ^ 0.6
		-- title slam: overshoot in, hold, drift out
		local s
		if u < 0.25 then
			s = 1.9 - 0.95 * (u / 0.25)
		elseif u < 0.55 then
			s = 0.95 + 0.07 * math.sin((u - 0.25) / 0.3 * math.pi)
		else
			s = 1 + (u - 0.55) * 0.03
		end
		self.titleScale.Scale = s
		local a = clamp01(u / 0.2) * (1 - clamp01((u - 2.2) / 0.6))
		self.title.TextTransparency = 1 - a
		self.titleStroke.Transparency = 1 - a
		self.sub.TextTransparency = 1 - clamp01((u - 0.35) / 0.4) * (1 - clamp01((u - 2.2) / 0.6))
	end

	if t >= LENGTH then
		self.playing = false
		self.cs.Visible = false
		self.flash.BackgroundTransparency = 1
		self.title.TextTransparency = 1
		self.titleStroke.Transparency = 1
		self.sub.TextTransparency = 1
		self:SetHudVisible(self.hudWanted ~= false)
		if self.onEnd then
			self.onEnd()
		end
	end
end

Cutscene.Impact = IMPACT
Cutscene.Length = LENGTH

return Cutscene
