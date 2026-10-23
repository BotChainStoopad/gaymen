--[[
	Roll cutscene + HUD for Hollowmourne, plus the heartbeat vignette and the
	lights-out flicker.

		local cs = HollowCutscene.new(playerGui, function() return camera.ViewportSize end, HollowAura)
		cs.onImpact = function() aura:Spawn() end
		cs:Play()
		RunService.RenderStepped:Connect(function(dt) cs:Step(dt) end)
		cs:Beat(1)      -- throb the screen edges red

	Timeline (seconds): 0 fade to black · 0.7 "Enter if you dare…" · 1.9 a red eye opens ·
	lightning flashes speed up with the heartbeat · 3.6 the eye rushes in · 4.4 red flash
	and the title · 7.4 done. Step only sets properties, so build.luau runs it under Lune.
]]

local Cutscene = {}
Cutscene.__index = Cutscene

local IMPACT = 4.4
local LENGTH = 7.4
local BEATS = { 0.9, 1.7, 2.35, 2.85, 3.2, 3.5, 3.75, 3.95, 4.1, 4.22, 4.32 }
local BOLTS = { 1.25, 2.6, 3.4, 3.9 }

local INK = Color3.fromRGB(255, 241, 236)
local DIM = Color3.fromRGB(201, 163, 155)
local BLOOD = Color3.fromRGB(225, 6, 0)
local EMBER = Color3.fromRGB(255, 74, 42)
local JOIN = Color3.fromRGB(59, 91, 255)
local PANEL = Color3.fromRGB(18, 3, 5)

local rng = Random.new()
local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function easeIn3(x)
	return clamp01(x) ^ 3
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
local function label(parent, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = INK,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in props do
		l[k] = v
	end
	return l
end
local function soot(parent, props, radius)
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, f)
	new("UIStroke", { Color = EMBER, Transparency = 0.45, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	return f
end
local function button(parent, text, order, width, primary)
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(width, 40),
		BackgroundColor3 = primary and JOIN or PANEL,
		BackgroundTransparency = primary and 0 or 0.2,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	if not primary then
		new("UIStroke", { Color = EMBER, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	end
	return b
end

function Cutscene.new(parentGui, getViewport, aura)
	aura = aura or require(script.Parent.HollowAura)
	local self = setmetatable({}, Cutscene)
	self.getViewport = getViewport
	self.playing = false
	self.t = 0
	self.beat = 0
	self.dim = 0

	local gui = new("ScreenGui", {
		Name = "HollowmourneUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.gui = gui

	-- heartbeat vignette: four edge bands of red that throb, and a black frame for lights-out
	self.vignette = {}
	for i, spec in {
		{ Vector2.new(0, 0), UDim2.fromScale(1, 0.3), 90 },
		{ Vector2.new(0, 1), UDim2.fromScale(1, 0.3), -90 },
		{ Vector2.new(0, 0), UDim2.fromScale(0.25, 1), 0 },
		{ Vector2.new(1, 0), UDim2.fromScale(0.25, 1), 180 },
	} do
		local f = new("Frame", {
			Name = "Vignette" .. i,
			AnchorPoint = spec[1],
			Position = UDim2.fromScale(spec[1].X, spec[1].Y),
			Size = spec[2],
			BackgroundColor3 = BLOOD,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, gui)
		new("UIGradient", { Rotation = spec[3], Transparency = seq(0, 0.1, 1, 1) }, f)
		table.insert(self.vignette, f)
	end
	self.lightsOut = new("Frame", {
		Name = "LightsOut",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, gui)

	---------------------------------------------------------------- HUD
	local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 }, gui)
	self.hud = hud
	new("UIPadding", { PaddingTop = UDim.new(0, 58), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, hud)

	local info = soot(hud, { Name = "Info", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(280, 300) })
	new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, info)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, info)
	label(info, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12), Text = "AURA COLLECTION", TextSize = 11, TextColor3 = EMBER, Font = Enum.Font.GothamBlack })
	local title = label(info, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 38), Text = aura.Name, TextSize = 38, Font = Enum.Font.GrenzeGotisch })
	new("UIStroke", { Color = Color3.fromRGB(120, 0, 0), Thickness = 1.5 }, title)
	label(info, { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 14), Text = string.upper(aura.Odds), TextSize = 12, TextColor3 = DIM, Font = Enum.Font.GothamBold })
	local cond = new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.fromRGB(10, 16, 50), BackgroundTransparency = 0.3, BorderSizePixel = 0 }, info)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, cond)
	new("UIStroke", { Color = Color3.fromRGB(90, 140, 255), Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cond)
	label(cond, { Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.1), Text = "REQUIRED CONDITIONS", TextSize = 10, TextColor3 = Color3.fromRGB(159, 182, 255), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold })
	label(cond, { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.45), Text = `During {aura.Condition}`, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GrenzeGotisch })
	label(info, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 96), Text = aura.Lore, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(240, 214, 207), LineHeight = 1.15 })

	local bar = new("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, hud)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
	self.replayButton = button(bar, "Replay Cutscene", 1, 160, true)
	self.skyButton = button(bar, "Blood Moon", 2, 120, false)
	self.hideButton = button(bar, "Hide UI", 3, 92, false)
	self.showButton = button(gui, "Show UI", 0, 92, true)
	self.showButton.AnchorPoint = Vector2.new(1, 1)
	self.showButton.Position = UDim2.new(1, -16, 1, -16)
	self.showButton.Visible = false
	self.showButton.ZIndex = 5

	---------------------------------------------------------------- cutscene
	local cs = new("Frame", { Name = "Cutscene", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 10 }, gui)
	self.cs = cs
	-- lightning lights a red sky behind everything for a few frames
	self.sky = new("Frame", { Name = "Sky", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLOOD, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 11 }, cs)
	new("UIGradient", { Rotation = 90, Color = cseq(0, Color3.fromRGB(255, 60, 30), 0.6, BLOOD, 1, Color3.fromRGB(40, 0, 0)) }, self.sky)
	-- treeline silhouette along the bottom, only visible while the sky flashes
	self.trees = new("Frame", { Name = "Trees", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.32), BackgroundTransparency = 1, ZIndex = 12 }, cs)
	new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.25), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 12 }, self.trees)
	local r = Random.new(31)
	for i = 0, 46 do
		local h = 0.35 + r:NextNumber() * 0.65
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(i / 46, 1),
			Size = UDim2.fromScale(0.006 + r:NextNumber() * 0.01, h),
			BackgroundColor3 = Color3.new(),
			BorderSizePixel = 0,
			Rotation = r:NextNumber(-6, 6),
			ZIndex = 12,
		}, self.trees)
		for b = 1, 3 do
			new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(i / 46, 1 - h * (0.4 + b * 0.15)),
				Size = UDim2.fromScale(0.012 + r:NextNumber() * 0.02, 0.012),
				Rotation = (b % 2 == 0 and -1 or 1) * (20 + r:NextNumber() * 40) + (b % 2 == 0 and 180 or 0),
				BackgroundColor3 = Color3.new(),
				BorderSizePixel = 0,
				ZIndex = 12,
			}, self.trees)
		end
	end

	-- the eye: a glowing slit that opens into an almond with a red iris and a slit pupil
	local eye = new("Frame", { Name = "Eye", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.3, 0.01), BackgroundTransparency = 1, ZIndex = 14 }, cs)
	self.eye = eye
	self.eyeScale = new("UIScale", { Scale = 1 }, eye)
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1.6, 0, 0, 6), BackgroundColor3 = BLOOD, BorderSizePixel = 0, ZIndex = 14 }, eye)
	new("UIGradient", { Transparency = seq(0, 1, 0.5, 0, 1, 1) }, glow)
	self.eyeGlow = glow
	local white = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 6, 6), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 15 }, eye)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, white)
	new("UIStroke", { Color = BLOOD, Thickness = 3 }, white)
	local iris = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 1.1), BackgroundColor3 = Color3.fromRGB(255, 40, 20), BorderSizePixel = 0, ZIndex = 16 }, white)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, iris)
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, iris)
	new("UIGradient", { Color = cseq(0, Color3.fromRGB(255, 200, 120), 0.5, Color3.fromRGB(255, 40, 20), 1, Color3.fromRGB(120, 0, 0)), Rotation = 90 }, iris)
	local pupil = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.18, 0.8), BackgroundColor3 = Color3.new(), BorderSizePixel = 0, ZIndex = 17 }, iris)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pupil)
	self.iris = iris

	self.dare = label(cs, { Name = "Dare", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.new(0.9, 0, 0, 60), Text = "Enter if you dare…", TextSize = 52, Font = Enum.Font.GrenzeGotisch, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 20 })
	self.dareStroke = new("UIStroke", { Color = BLOOD, Thickness = 2, Transparency = 1 }, self.dare)
	self.odds = label(cs, { Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.new(0.9, 0, 0, 30), Text = string.upper(aura.Odds), TextSize = 24, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 20 })
	self.oddsStroke = new("UIStroke", { Color = BLOOD, Thickness = 2, Transparency = 1 }, self.odds)

	self.flash = new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLOOD, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30 }, gui)
	new("UIGradient", { Color = cseq(0, Color3.fromRGB(80, 0, 0), 0.5, Color3.fromRGB(255, 110, 80), 1, Color3.fromRGB(80, 0, 0)) }, self.flash)
	local titleWrap = new("Frame", { Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 170), BackgroundTransparency = 1, ZIndex = 32 }, gui)
	self.titleScale = new("UIScale", { Scale = 1 }, titleWrap)
	self.title = label(titleWrap, { Size = UDim2.fromScale(1, 0.75), Text = aura.Name, TextScaled = true, Font = Enum.Font.GrenzeGotisch, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 33 })
	new("UIGradient", { Rotation = 90, Color = cseq(0, Color3.new(1, 1, 1), 0.4, Color3.fromRGB(255, 205, 190), 0.75, Color3.fromRGB(255, 80, 50), 1, Color3.fromRGB(190, 10, 0)) }, self.title)
	self.titleStroke = new("UIStroke", { Color = Color3.fromRGB(18, 0, 0), Thickness = 4, Transparency = 1 }, self.title)
	new("UITextSizeConstraint", { MaxTextSize = 130 }, self.title)
	self.sub = label(titleWrap, { Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(1, 0.18), Text = "H A S   F O U N D   Y O U", TextScaled = true, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 33 })
	self.subStroke = new("UIStroke", { Color = BLOOD, Thickness = 2, Transparency = 1 }, self.sub)
	new("UITextSizeConstraint", { MaxTextSize = 22 }, self.sub)

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
	self.bolt = 0
end

-- throb the frame edges red (heartbeats in the world and in the cutscene)
function Cutscene:Beat(str)
	self.beat = math.max(self.beat, str or 1)
end

-- lights cut out for a moment
function Cutscene:LightsOut()
	self.dim = 1
end

function Cutscene:_once(key, at, fn)
	if self.t >= at and not self.fired[key] then
		self.fired[key] = true
		fn()
	end
end

function Cutscene:Step(dt)
	self.beat *= math.exp(-dt * 3.5)
	for _, v in self.vignette do
		v.BackgroundTransparency = 1 - self.beat * 0.55
	end
	if self.dim > 0 then
		self.dim = math.max(0, self.dim - dt * 1.6)
		local d = self.dim > 0.5 and (rng:NextNumber() < 0.3 and 0.5 or 0.92) or self.dim * 1.6
		self.lightsOut.BackgroundTransparency = 1 - d
	end
	if not self.playing then
		return
	end
	self.t += dt
	local t = self.t

	if t < 0.5 then
		self.cs.BackgroundTransparency = 1 - t / 0.5
	elseif t < IMPACT then
		self.cs.BackgroundTransparency = 0
	end
	for i, b in BEATS do
		self:_once("beat" .. i, b, function()
			self:Beat(0.8)
			if self.onBeat then
				self.onBeat(i)
			end
		end)
	end
	for i, b in BOLTS do
		self:_once("bolt" .. i, b, function()
			self.bolt = 1
			if self.onThunder then
				self.onThunder(i)
			end
		end)
	end

	if t < IMPACT then
		self.bolt *= math.exp(-dt * 7)
		local fl = self.bolt * (rng:NextNumber() < 0.3 and 0.4 or 1)
		self.sky.BackgroundTransparency = 1 - fl * 0.9
		self.trees.Visible = fl > 0.05
		-- text
		local da = clamp01((t - 0.7) / 0.7) * (1 - clamp01((t - 2) / 0.3))
		self.dare.TextTransparency = 1 - da
		self.dareStroke.Transparency = 1 - da * 0.7
		local oa = clamp01((t - 2.2) / 0.7) * (1 - clamp01((t - 4.1) / 0.25))
		self.odds.TextTransparency = 1 - oa
		self.oddsStroke.Transparency = 1 - oa * 0.7
		-- eye opens, blinks once, then rushes in
		local open = clamp01((t - 1.9) / 0.6)
		if t > 3.05 and t < 3.2 then
			open = 0.05
		end
		local lunge = easeIn3((t - 3.6) / 0.8)
		self.eye.Size = UDim2.fromScale(0.3, 0.008 + open * 0.13)
		self.eyeScale.Scale = 1 + self.beat * 0.04 + lunge * 3.5
		self.eyeGlow.BackgroundTransparency = 1 - math.min(1, 0.3 + open)
		self.iris.Visible = open > 0.15
	end

	self:_once("impact", IMPACT, function()
		self.cs.BackgroundTransparency = 1
		self.sky.BackgroundTransparency = 1
		self.eye.Size = UDim2.fromScale(0.3, 0.01)
		self.flash.BackgroundTransparency = 0
		if self.onImpact then
			self.onImpact()
		end
	end)
	if t >= IMPACT then
		self.cs.Visible = false
		local u = t - IMPACT
		self.flash.BackgroundTransparency = clamp01(u / 1) ^ 0.6
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
		local sa = clamp01((u - 0.35) / 0.4) * (1 - clamp01((u - 2.2) / 0.6))
		self.sub.TextTransparency = 1 - sa
		self.subStroke.Transparency = 1 - sa
	end

	if t >= LENGTH then
		self.playing = false
		self.cs.Visible = false
		self.flash.BackgroundTransparency = 1
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
