--[[
	Builds UmbralSovereign.rbxl with Lune, after running the aura and the cutscene
	headlessly to catch bad properties and runtime errors.

		lune run roblox/UmbralSovereign/build.luau

	https://github.com/lune-org/lune (tested with 0.8.9)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

local dir = string.match(process.args[1] or "", "^(.-)/?$")
if dir == nil or dir == "" then
	dir = "roblox/UmbralSovereign"
end

-- Lune has no Random datatype; this covers the two methods the scripts use.
local LuneRandom = {}
LuneRandom.__index = LuneRandom
function LuneRandom.new(seed)
	local s = seed or os.clock() * 1e6
	return setmetatable({ s = math.floor(s) % 2147483647 + 1 }, LuneRandom)
end
function LuneRandom:_next()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function LuneRandom:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function LuneRandom:NextInteger(a, b)
	return math.min(b, a + math.floor(self:_next() * (b - a + 1)))
end

local env = {
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	Random = LuneRandom,
}
local function load(file)
	return luau.load(fs.readFile(`{dir}/{file}`), { debugName = file, environment = env })()
end

local Aura = load("UmbralAura.luau")
local Cutscene = load("UmbralCutscene.luau")
for _, f in { "AuraClient.client.luau", "AuraServer.server.luau" } do
	luau.compile(fs.readFile(`{dir}/{f}`)) -- syntax check
end

---------------------------------------------------------------- place
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = Instance.new("StarterPlayerScripts")
StarterPlayerScripts.Parent = StarterPlayer
StarterPlayer.CameraMaxZoomDistance = 80

local base = Instance.new("Part")
base.Name = "Baseplate"
base.Anchored = true
base.Locked = true
base.Size = Vector3.new(512, 20, 512)
base.CFrame = CFrame.new(0, -10, 0)
base.Color = Color3.fromRGB(91, 93, 105)
base.Material = Enum.Material.SmoothPlastic
base.TopSurface = Enum.SurfaceType.Studs
base.BottomSurface = Enum.SurfaceType.Smooth
base.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 0.5, 30)
spawn.Color = Color3.fromRGB(40, 16, 80)
spawn.Material = Enum.Material.SmoothPlastic
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace

-- R6 showcase dummy wearing the aura (drawn by the client script)
local function dummy(name, at)
	local m = Instance.new("Model")
	m.Name = name
	local turn = CFrame.new(at) * CFrame.Angles(0, math.pi, 0)
	local hood = Color3.fromRGB(23, 19, 31)
	local function limb(n, size, offset, color)
		local p = Instance.new("Part")
		p.Name = n
		p.Anchored = true
		p.Size = size
		p.CFrame = turn * CFrame.new(offset)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), hood)
	root.Transparency = 1
	root.CanCollide = false
	limb("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), hood)
	limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), hood)
	limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), hood)
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), Color3.fromRGB(12, 10, 18))
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), Color3.fromRGB(12, 10, 18))
	local head = limb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), Color3.fromRGB(29, 24, 40))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local hum = Instance.new("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
	m.PrimaryPart = root
	m:SetAttribute("Aura", Aura.Name)
	m.Parent = workspace
	return m
end
local showcase = dummy("Umbral Showcase", Vector3.new(0, 0, 0))

-- lighting: Future + eclipse defaults (the client tweens between eclipse and day)
Lighting.Technology = Enum.Technology.Future
Lighting.ClockTime = 0.3
Lighting.Brightness = 1
Lighting.Ambient = Color3.fromRGB(40, 18, 70)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 34, 110)
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
local sky = Instance.new("Sky")
sky.StarCount = 5000
sky.Parent = Lighting
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.38
atmo.Haze = 1.6
atmo.Color = Color3.fromRGB(96, 44, 170)
atmo.Decay = Color3.fromRGB(36, 10, 80)
atmo.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 1.5
bloom.Size = 40
bloom.Threshold = 0.85
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.TintColor = Color3.fromRGB(240, 226, 255)
cc.Saturation = 0.18
cc.Contrast = 0.16
cc.Parent = Lighting

-- scripts
local kit = Instance.new("Folder")
kit.Name = "UmbralSovereign"
for _, attr in { "MusicSoundId", "ImpactSoundId", "HeartbeatSoundId", "PulseSoundId" } do
	kit:SetAttribute(attr, "")
end
kit.Parent = ReplicatedStorage
for _, n in { "UmbralAura", "UmbralCutscene" } do
	local ms = Instance.new("ModuleScript")
	ms.Name = n
	ms.Source = fs.readFile(`{dir}/{n}.luau`)
	ms.Parent = kit
end
local server = Instance.new("Script")
server.Name = "AuraServer"
server.Source = fs.readFile(`{dir}/AuraServer.server.luau`)
server.Parent = ServerScriptService
local client = Instance.new("LocalScript")
client.Name = "AuraClient"
client.Source = fs.readFile(`{dir}/AuraClient.client.luau`)
client.Parent = StarterPlayerScripts

---------------------------------------------------------------- headless run
local emitted = 0
Aura.emit = function(_, n)
	emitted += n
end
local testFolder = Instance.new("Folder")
local aura = Aura.new(showcase, { parent = testFolder })
local pulses = 0
for _ = 1, 60 * 12 do
	if aura:Step(1 / 60) then
		pulses += 1
	end
end
aura:Hold()
for _ = 1, 30 do
	aura:Step(1 / 60)
end
aura:Spawn()
for _ = 1, 60 * 2 do
	aura:Step(1 / 60)
end
local count = #testFolder:GetDescendants()
assert(aura.S > 0.99, "aura never finished spawning")
assert(pulses >= 3, "heartbeat pulse did not fire")
assert(emitted > 0, "burst never emitted")
aura:Destroy()

local playerGui = Instance.new("Folder")
local impacts, beats, ended = 0, 0, false
local cs = Cutscene.new(playerGui, function()
	return roblox.Vector2.new(1280, 720)
end, Aura)
cs.onImpact = function()
	impacts += 1
end
cs.onBeat = function()
	beats += 1
end
cs.onEnd = function()
	ended = true
end
cs:SetHudVisible(true)
cs:Play()
for _ = 1, 60 * 8 do
	cs:Step(1 / 60)
end
assert(impacts == 1 and beats == 11 and ended, `cutscene timeline broken ({impacts} impacts, {beats} beats)`)
assert(cs.hud.Visible, "HUD not restored after cutscene")

fs.writeFile(`{dir}/UmbralSovereign.rbxl`, roblox.serializePlace(game))
print(`Aura: {count} instances, {pulses} pulses in 12s. Cutscene: {beats} beats, 1 impact. Wrote {dir}/UmbralSovereign.rbxl`)
