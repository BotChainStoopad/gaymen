--[[
	Builds Hollowmourne.rbxl with Lune, after running the aura and the cutscene
	headlessly to catch bad properties and runtime errors.

		lune run roblox/Hollowmourne/build.luau

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
	dir = "roblox/Hollowmourne"
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
	Font = roblox.Font,
}
local function load(file)
	return luau.load(fs.readFile(`{dir}/{file}`), { debugName = file, environment = env })()
end

local Aura = load("HollowAura.luau")
local Cutscene = load("HollowCutscene.luau")
for _, f in { "HollowClient.client.luau", "HollowServer.server.luau" } do
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
base.Color = Color3.fromRGB(46, 26, 24)
base.Material = Enum.Material.Ground
base.TopSurface = Enum.SurfaceType.Smooth
base.BottomSurface = Enum.SurfaceType.Smooth
base.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 0.5, 30)
spawn.Color = Color3.fromRGB(40, 6, 8)
spawn.Material = Enum.Material.Slate
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace

-- R6 showcase dummy wearing the aura (drawn by the client script)
local function dummy(name, at)
	local m = Instance.new("Model")
	m.Name = name
	local turn = CFrame.new(at) * CFrame.Angles(0, math.pi, 0)
	local hood = Color3.fromRGB(21, 21, 28)
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
	limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), Color3.fromRGB(11, 11, 16))
	limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), Color3.fromRGB(11, 11, 16))
	local head = limb("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), Color3.fromRGB(35, 32, 43))
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
local showcase = dummy("Hollow Showcase", Vector3.new(0, 0, 0))

-- graveyard scenery: crooked tombstones and dead trees
local scenery = Instance.new("Folder")
scenery.Name = "Scenery"
scenery.Parent = workspace
local stoneRng = LuneRandom.new(13)
local function piece(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = scenery
	return p
end
for i = 1, 22 do
	local a = i / 22 * math.pi * 2 + stoneRng:NextNumber(-0.1, 0.1)
	local r = stoneRng:NextNumber(16, 34)
	local h = stoneRng:NextNumber(2.2, 3.6)
	local cf = CFrame.new(math.cos(a) * r, h * 0.5 - 0.3, math.sin(a) * r)
		* CFrame.Angles(stoneRng:NextNumber(-0.15, 0.15), -a + math.pi / 2, stoneRng:NextNumber(-0.12, 0.12))
	piece("Tombstone", Vector3.new(1.8, h, 0.45), cf, Color3.fromRGB(70, 68, 74), Enum.Material.Slate)
	local top = piece("TombstoneTop", Vector3.new(0.45, 1.8, 1.8), cf * CFrame.new(0, h * 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(70, 68, 74), Enum.Material.Slate)
	top.Shape = Enum.PartType.Cylinder
	top.CFrame = cf * CFrame.new(0, h * 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
end
local function tree(at, height, rngT)
	local function branch(from, dir, len, thick, depth)
		local to = from + dir * len
		piece("Branch", Vector3.new(thick, thick, len), CFrame.lookAt((from + to) * 0.5, to), Color3.fromRGB(18, 10, 10), Enum.Material.Wood)
		if depth <= 0 then
			return
		end
		for _ = 1, 2 do
			local d = (dir + Vector3.new(rngT:NextNumber(-0.9, 0.9), rngT:NextNumber(0.1, 0.6), rngT:NextNumber(-0.9, 0.9))).Unit
			branch(to, d, len * 0.68, thick * 0.65, depth - 1)
		end
	end
	branch(at, Vector3.new(0, 1, 0), height, 1.1, 4)
end
for i = 1, 7 do
	local a = i / 7 * math.pi * 2 + 0.4
	local r = 42 + (i % 3) * 9
	tree(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), 7 + (i % 3) * 2, LuneRandom.new(100 + i))
end

-- lighting: Future + Blood Moon defaults (the client tweens to a plain baseplate on E)
Lighting.Technology = Enum.Technology.Future
Lighting.ClockTime = 0.2
Lighting.Brightness = 1.4
Lighting.Ambient = Color3.fromRGB(70, 12, 14)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 24, 24)
Lighting.ExposureCompensation = 0.2
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
local sky = Instance.new("Sky")
sky.MoonAngularSize = 32
sky.StarCount = 600
sky.Parent = Lighting
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.42
atmo.Haze = 2.2
atmo.Glare = 0.6
atmo.Color = Color3.fromRGB(170, 14, 10)
atmo.Decay = Color3.fromRGB(70, 0, 4)
atmo.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 1.2
bloom.Size = 36
bloom.Threshold = 0.88
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.TintColor = Color3.fromRGB(255, 196, 190)
cc.Saturation = 0.25
cc.Contrast = 0.2
cc.Parent = Lighting

-- scripts
local kit = Instance.new("Folder")
kit.Name = "Hollowmourne"
for _, attr in { "MusicSoundId", "ImpactSoundId", "HeartbeatSoundId", "PulseSoundId", "ThunderSoundId" } do
	kit:SetAttribute(attr, "")
end
kit.Parent = ReplicatedStorage
for _, n in { "HollowAura", "HollowCutscene" } do
	local ms = Instance.new("ModuleScript")
	ms.Name = n
	ms.Source = fs.readFile(`{dir}/{n}.luau`)
	ms.Parent = kit
end
local server = Instance.new("Script")
server.Name = "HollowServer"
server.Source = fs.readFile(`{dir}/HollowServer.server.luau`)
server.Parent = ServerScriptService
local client = Instance.new("LocalScript")
client.Name = "HollowClient"
client.Source = fs.readFile(`{dir}/HollowClient.client.luau`)
client.Parent = StarterPlayerScripts

---------------------------------------------------------------- headless run
local emitted = 0
Aura.emit = function(_, n)
	emitted += n
end
local testFolder = Instance.new("Folder")
local aura = Aura.new(showcase, { parent = testFolder })
local pulses, thunders = 0, 0
for _ = 1, 60 * 12 do
	local event = aura:Step(1 / 60)
	if event == "pulse" then
		pulses += 1
	elseif event == "thunder" then
		thunders += 1
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
assert(thunders >= 1, "no sky strike landed")
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
assert(impacts == 1 and beats == 11 and ended, `cutscene timeline broken ({impacts} impacts, {beats} heartbeats)`)
assert(cs.hud.Visible, "HUD not restored after cutscene")

cs:Beat(1)
cs:LightsOut()
for _ = 1, 60 do
	cs:Step(1 / 60)
end
assert(cs.lightsOut.BackgroundTransparency > 0.99, "lights never came back on")

fs.writeFile(`{dir}/Hollowmourne.rbxl`, roblox.serializePlace(game))
print(`Aura: {count} instances, {pulses} pulses in 12s. Cutscene: {beats} beats, 1 impact. Wrote {dir}/Hollowmourne.rbxl`)
