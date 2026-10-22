--[[
	Builds DragonPetKit.rbxmx (and preview data) by running DragonPet.luau under Lune.

		lune run roblox/DragonPet/build.luau

	https://github.com/lune-org/lune (tested with 0.8.9)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance

local dir = string.match(process.args[1] or "", "^(.-)/?$")
if dir == nil or dir == "" then
	dir = "roblox/DragonPet"
end

local function load(file: string)
	return luau.load(fs.readFile(`{dir}/{file}`), {
		debugName = file,
		environment = {
			Instance = roblox.Instance,
			Vector3 = roblox.Vector3,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			Enum = roblox.Enum,
		},
	})()
end

local DragonPet = load("DragonPet.luau")

-- Kit: ModuleScript + one prebuilt model per variant + example follow script
local kit = Instance.new("Folder")
kit.Name = "DragonPetKit"

local module = Instance.new("ModuleScript")
module.Name = "DragonPet"
module.Source = fs.readFile(`{dir}/DragonPet.luau`)
module.Parent = kit

local models = Instance.new("Folder")
models.Name = "Models"
models.Parent = kit

local names = {}
for name in DragonPet.Variants do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	DragonPet.build(name).Parent = models
end

local follow = Instance.new("LocalScript")
follow.Name = "PetFollow"
follow.Source = fs.readFile(`{dir}/PetFollow.client.luau`)
follow.Parent = kit

fs.writeFile(`{dir}/DragonPetKit.rbxmx`, roblox.serializeModel({ kit }, true))

-- Preview data: rest pose of the Classic model plus every palette
local function cf(c)
	return { c:GetComponents() }
end
local function col(c)
	return { math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255) }
end

local model = DragonPet.build("Classic")
local parts, index = {}, {}
for _, inst in model:GetDescendants() do
	if inst:IsA("BasePart") and inst.Name ~= "Root" then
		table.insert(parts, inst)
		index[inst] = #parts - 1
	end
end
index[model.PrimaryPart] = -1

local outParts, motors = {}, {}
for _, p in parts do
	local weld = p:FindFirstChildOfClass("Weld")
	table.insert(outParts, {
		name = p.Name,
		role = p:GetAttribute("Role"),
		eye = p:GetAttribute("EyeState"),
		size = { p.Size.X, p.Size.Y, p.Size.Z },
		cf = cf(p.CFrame),
		studs = p.TopSurface == roblox.Enum.SurfaceType.Studs,
		weldTo = weld and index[weld.Part0] or nil,
	})
	local motor = p:FindFirstChildOfClass("Motor6D")
	if motor then
		table.insert(motors, {
			name = motor.Name,
			part0 = index[motor.Part0],
			part1 = index[motor.Part1],
			c0 = cf(motor.C0),
			c1 = cf(motor.C1),
		})
	end
end

local palettes = {}
for _, name in names do
	local v = DragonPet.Variants[name]
	local pal = {}
	for role, c in v.Palette do
		pal[role] = col(c)
	end
	palettes[name] = { rarity = v.Rarity, palette = pal, neon = v.Neon or {}, rainbow = v.Rainbow or false }
end

local data = serde.encode("json", { root = cf(model.PrimaryPart.CFrame), parts = outParts, motors = motors, variants = palettes })
local template = fs.readFile(`{dir}/preview.template.html`)
local html = string.gsub(template, "__DRAGON_DATA__", function()
	return data
end)
fs.writeFile(`{dir}/preview.html`, html)

print(`Built {#names} variants, {#parts} parts per dragon, {#motors} motors.`)
