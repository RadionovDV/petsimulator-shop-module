-- PetEquipService.lua
-- Server-authoritative pet equipment manager.
-- Validates ownership, slot availability, and duplicate checks for equip/unequip actions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local PlayerService = require(script.Parent.PlayerService)
local PetConfig = require(ReplicatedFirst.PetConfig)

local Remotes = ReplicatedStorage.Remotes

local PetEquipService = {}

function PetEquipService.Equip(player, petId)
	PlayerService.WaitForLoad(player)

	local pets = PlayerService.GetValue(player, "pets") or {}
	local equipped = PlayerService.GetValue(player, "equippedPets") or {}
	local maxSlots = PlayerService.GetValue(player, "maxEquipSlots") or 1

	-- Must own the pet
	if not pets[petId] then
		return
	end

	-- Must not already be equipped
	for _, pid in equipped do
		if pid == petId then
			return
		end
	end

	if #equipped >= maxSlots then
		local replaceId = nil
		local highestWeight = -math.huge
		for _, pid in equipped do
			local petData = pets[pid]
			if petData then
				local config = PetConfig.Map[petData.petType]
				if config and config.weight > highestWeight then
					highestWeight = config.weight
					replaceId = pid
				end
			end
		end
		if not replaceId then
			return
		end
		PlayerService.UpdateValue(player, "equippedPets", function(list)
			local newList = {}
			for _, pid in list do
				if pid ~= replaceId then
					table.insert(newList, pid)
				end
			end
			table.insert(newList, petId)
			return newList
		end)
		return
	end

	PlayerService.UpdateValue(player, "equippedPets", function(list)
		table.insert(list, petId)
		return list
	end)
end

function PetEquipService.Unequip(player, petId)
	PlayerService.WaitForLoad(player)

	local equipped = PlayerService.GetValue(player, "equippedPets") or {}

	local found = false
	for _, pid in equipped do
		if pid == petId then
			found = true
			break
		end
	end

	if not found then
		return
	end

	PlayerService.UpdateValue(player, "equippedPets", function(list)
		local newList = {}
		for _, pid in list do
			if pid ~= petId then
				table.insert(newList, pid)
			end
		end
		return newList
	end)
end

function PetEquipService.StartListening()
	Remotes.EquipPet.OnServerEvent:Connect(function(player, petId)
		PetEquipService.Equip(player, petId)
	end)

	Remotes.UnequipPet.OnServerEvent:Connect(function(player, petId)
		PetEquipService.Unequip(player, petId)
	end)
end

return PetEquipService