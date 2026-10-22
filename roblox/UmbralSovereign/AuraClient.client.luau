--[[
	Builds and animates Umbral Sovereign on every character whose model has the
	attribute Aura = "Umbral Sovereign" (the server sets it; the showcase dummy has it
	saved). All VFX are local parts, so they cost no network traffic.

	Keys: R replay cutscene · E toggle Eclipse sky · H hide UI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local kit = ReplicatedStorage:WaitForChild("UmbralSovereign")
local Aura = require(kit:WaitForChild("UmbralAura"))
local Cutscene = require(kit:WaitForChild("UmbralCutscene"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local folder = Instance.new("Folder")
folder.Name = "LocalAuras"
folder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(root)
	rayParams.FilterDescendantsInstances = { root.Parent, folder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), rayParams)
	return hit and hit.Position.Y or root.Position.Y - 3
end

---------------------------------------------------------------- lighting
local effects = {
	bloom = Lighting:FindFirstChildOfClass("BloomEffect"),
	cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect"),
	atmo = Lighting:FindFirstChildOfClass("Atmosphere"),
}
local DAY = {
	Lighting = { ClockTime = 14.5, Ambient = Color3.fromRGB(70, 70, 80), OutdoorAmbient = Color3.fromRGB(128, 128, 140), Brightness = 2.2, ExposureCompensation = 0 },
	bloom = { Intensity = 0.9, Size = 28, Threshold = 0.95 },
	cc = { TintColor = Color3.new(1, 1, 1), Saturation = 0.05, Contrast = 0.05, Brightness = 0 },
	atmo = { Density = 0.3, Haze = 0, Glare = 0, Color = Color3.fromRGB(199, 199, 199), Decay = Color3.fromRGB(106, 112, 125) },
}
local ECLIPSE = {
	Lighting = { ClockTime = 0.3, Ambient = Color3.fromRGB(40, 18, 70), OutdoorAmbient = Color3.fromRGB(70, 34, 110), Brightness = 1, ExposureCompensation = 0.15 },
	bloom = { Intensity = 1.5, Size = 40, Threshold = 0.85 },
	cc = { TintColor = Color3.fromRGB(240, 226, 255), Saturation = 0.18, Contrast = 0.16, Brightness = 0.02 },
	atmo = { Density = 0.38, Haze = 1.6, Glare = 0, Color = Color3.fromRGB(96, 44, 170), Decay = Color3.fromRGB(36, 10, 80) },
}
local eclipse = true
local function applySky(preset, time)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, preset.Lighting):Play()
	for key, props in preset do
		local target = effects[key]
		if target then
			TweenService:Create(target, info, props):Play()
		end
	end
end
applySky(ECLIPSE, 0)

---------------------------------------------------------------- optional audio
-- Paste your own audio ids into these attributes on ReplicatedStorage.UmbralSovereign.
local function sound(attr, props)
	local id = kit:GetAttribute(attr)
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	for k, v in props do
		s[k] = v
	end
	s.Parent = script
	return s
end
local music = sound("MusicSoundId", { Looped = true, Volume = 0.5 })
local impactSfx = sound("ImpactSoundId", { Volume = 1 })
local beatSfx = sound("HeartbeatSoundId", { Volume = 0.8 })
local pulseSfx = sound("PulseSoundId", { Volume = 0.35 })

---------------------------------------------------------------- auras
local auras = {}
local NAME = Aura.Name

local function detach(model)
	local a = auras[model]
	if a then
		auras[model] = nil
		a:Destroy()
	end
end

local cs = Cutscene.new(player:WaitForChild("PlayerGui"), function()
	return camera.ViewportSize
end, Aura)
cs:SetHudVisible(true)

local played = false
local function playCutscene()
	if cs.playing then
		return
	end
	local mine = player.Character and auras[player.Character]
	if mine then
		mine:Hold()
	end
	if music then
		music.Volume = 0.15
	end
	cs:Play()
end

local function attach(model)
	if auras[model] or model:GetAttribute("Aura") ~= NAME then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 10)
	local head = model:WaitForChild("Head", 10)
	if not root or not head or not model.Parent or auras[model] then
		return
	end
	local a = Aura.new(model, { parent = folder, groundY = groundY })
	auras[model] = a
	if model == player.Character and not played then
		played = true
		if music then
			music:Play()
		end
		playCutscene()
	end
end

local function watch(model)
	if not model:IsA("Model") then
		return
	end
	task.spawn(attach, model)
	model:GetAttributeChangedSignal("Aura"):Connect(function()
		if model:GetAttribute("Aura") == NAME then
			task.spawn(attach, model)
		else
			detach(model)
		end
	end)
end
for _, m in workspace:GetChildren() do
	watch(m)
end
workspace.ChildAdded:Connect(watch)
workspace.ChildRemoved:Connect(detach)

---------------------------------------------------------------- cutscene hooks
local fovKick, shake = 0, 0
cs.onBeat = function()
	if beatSfx then
		beatSfx:Play()
	end
end
cs.onImpact = function()
	local mine = player.Character and auras[player.Character]
	if mine then
		mine:Spawn()
	end
	if impactSfx then
		impactSfx:Play()
	end
	fovKick = 22
	shake = 0.45
end
cs.onEnd = function()
	if music then
		TweenService:Create(music, TweenInfo.new(2), { Volume = 0.5 }):Play()
	end
end

---------------------------------------------------------------- HUD
local function setHud(on)
	cs:SetHudVisible(on)
end
local function toggleSky()
	eclipse = not eclipse
	applySky(eclipse and ECLIPSE or DAY, 1.2)
	cs.skyButton.Text = eclipse and "ECLIPSE SKY" or "DAYLIGHT"
end
cs.replayButton.Activated:Connect(playCutscene)
cs.skyButton.Activated:Connect(toggleSky)
cs.hideButton.Activated:Connect(function()
	setHud(false)
end)
cs.showButtonText.Activated:Connect(function()
	setHud(true)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		playCutscene()
	elseif input.KeyCode == Enum.KeyCode.E then
		toggleSky()
	elseif input.KeyCode == Enum.KeyCode.H then
		setHud(not cs.hud.Visible)
	end
end)

---------------------------------------------------------------- loop
local baseFov = camera.FieldOfView
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 0.05)
	cs:Step(dt)
	for model, a in auras do
		if not model.Parent then
			detach(model)
		elseif a:Step(dt) then
			if model == player.Character then
				shake = math.max(shake, 0.07)
				if pulseSfx then
					pulseSfx:Play()
				end
			end
		end
	end
end)

-- camera punch runs after the default camera so it never fights it
RunService:BindToRenderStep("UmbralSovereignCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	fovKick *= math.exp(-dt * 3)
	shake *= math.exp(-dt * 5)
	camera.FieldOfView = baseFov + fovKick
	if shake > 0.002 then
		local r = Random.new()
		camera.CFrame += Vector3.new(r:NextNumber(-1, 1), r:NextNumber(-1, 1), r:NextNumber(-1, 1)) * shake
	end
end)
