--[[
	PetFollow · example LocalScript (put in StarterPlayerScripts)

	Spawns the local player's dragon, hovers it beside them, turns it to face
	where they're heading and feeds walk speed into the flight animation.
	Pets in simulator games are rendered client-side, so nothing here replicates.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local kit = ReplicatedStorage:WaitForChild("DragonPetKit")
local DragonPet = require(kit:WaitForChild("DragonPet"))

local VARIANT = "Classic" -- Classic · Frost · Inferno · Void · Golden · Rainbow
local SCALE = 0.75 -- 1 = ~6.5 studs tall with horns
local OFFSET = Vector3.new(3.5, 0.5, 3) -- right, up, behind (relative to the player)

local player = Players.LocalPlayer

local function spawnPet(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local pet = kit.Models:FindFirstChild(VARIANT .. "Dragon")
	pet = if pet then pet:Clone() else DragonPet.build(VARIANT)
	pet:ScaleTo(SCALE)
	pet:PivotTo(hrp.CFrame * CFrame.new(OFFSET))
	pet.Parent = workspace

	local anim = DragonPet.animate(pet)
	anim:Celebrate() -- little "hatched!" spin on spawn

	local current = pet:GetPivot()
	local facing = hrp.CFrame.LookVector

	local conn = RunService.RenderStepped:Connect(function(dt)
		local velocity = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local moving = velocity.Magnitude > 1
		anim:SetSpeed(math.clamp(velocity.Magnitude / humanoid.WalkSpeed, 0, 1))

		if moving then
			facing = facing:Lerp(velocity.Unit, 1 - math.exp(-dt * 8))
		end

		local flat = hrp.CFrame.Rotation
		local target = hrp.Position + flat:VectorToWorldSpace(OFFSET)
		local pos = current.Position:Lerp(target, 1 - math.exp(-dt * 9))
		current = CFrame.lookAt(pos, pos + Vector3.new(facing.X, 0, facing.Z))
		pet:PivotTo(current)
	end)

	humanoid.Died:Once(function()
		conn:Disconnect()
		anim:Destroy()
		pet:Destroy()
	end)
end

if player.Character then
	spawnPet(player.Character)
end
player.CharacterAdded:Connect(spawnPet)
