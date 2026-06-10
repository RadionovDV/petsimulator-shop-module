local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local PetConfig = require(ReplicatedFirst.PetConfig)
local TableUtils = require(ReplicatedStorage.TableUtils)
local PlayerService = require(script.Parent.PlayerService)

local PetUtils = {}

function PetUtils.GrantPet(player, petType)
	local petConfig = PetConfig.Map[petType]
	if not petConfig then
		return false
	end

	PlayerService.WaitForLoad(player)

	local petCountNum = TableUtils.objLength(PlayerService.GetValue(player, "pets") or {})
	local petId = string.format("%s_%d", petType, petCountNum + 1)

	PlayerService.UpdateValue(player, "pets", function(pets)
		pets[petId] = {
			petType = petType,
			rarity = petConfig.rarity,
			damage = petConfig.damage,
			maxHp = petConfig.hp or 20,
			displayName = petConfig.displayName,
		}
		return pets
	end)

	return petId
end

return PetUtils