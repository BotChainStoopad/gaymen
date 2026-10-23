--[[
	Equips Hollowmourne on every character. Swap this for your own roll logic:
	the client draws the aura for any character model whose "Aura" attribute is
	"Hollowmourne", and removes it when the attribute changes.
]]

local Players = game:GetService("Players")

local AURA = "Hollowmourne"

local function equip(character)
	character:SetAttribute("Aura", AURA)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(equip)
	if player.Character then
		equip(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
