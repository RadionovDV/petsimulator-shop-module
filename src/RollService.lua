-- RollService.lua
-- Server-authoritative rolling system. Anti-spam via lastRollTime table.
-- On each roll: RNG determines pet → added to inventory → +1 dice → auto-equip if slot open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")


local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local RarityCalculator = require(ReplicatedStorage.RarityCalculator)
local TableUtils = require(ReplicatedStorage.TableUtils)
local GameConfig = require(ReplicatedFirst.GameConfig)
local PetConfig = require(ReplicatedFirst.PetConfig)

local Remotes = ReplicatedStorage.Remotes

local TUTORIAL_PETS = {
	PetConfig.List[1],
	PetConfig.List[2],
	PetConfig.List[4],
}

local lastRollTime = {}

local RollService = {}

local function _isTutorialRoll(player)
	local progress = PlayerService.GetValue(player, "tutorialProgress")
	if type(progress) ~= "table" then return true end
	local completed = progress.completed
	if type(completed) ~= "table" then return true end
	return not completed["EquipBest2"]
end

function RollService.Roll(player)
	PlayerService.WaitForLoad(player)

	local now = os.clock()
	local cooldown = PlayerService.GetValue(player, "rollCooldown") or 2

	if lastRollTime[player.UserId] and (now - lastRollTime[player.UserId]) < cooldown then
		return
	end
	lastRollTime[player.UserId] = now

	local luck = PlayerService.GetValue(player, "luck") or 1
	local rebirthLuck = PlayerService.GetValue(player, "rebirthBonusLuck") or 0
	local effectiveLuck = luck + rebirthLuck
	if GameConfig.superLuck then
		effectiveLuck = 1000000000
	end

	local petType, petData
	if _isTutorialRoll(player) then
		local dice = PlayerService.GetValue(player, "dice") or 0
		if dice < #TUTORIAL_PETS then
			local tutPet = TUTORIAL_PETS[dice + 1]
			petType = tutPet.id
			petData = tutPet
		else
			petType, petData = RarityCalculator.Roll(effectiveLuck)
		end
	else
		petType, petData = RarityCalculator.Roll(effectiveLuck)
	end
	
	local petCountNum = TableUtils.objLength(PlayerService.GetValue(player, "pets") or {})

	local petId = string.format("%s_%d", petType, petCountNum + 1)

	PlayerService.UpdateValue(player, "pets", function(pets)
		pets[petId] = {
			petType = petType,
			rarity = petData.rarity,
			damage = petData.damage,
			maxHp = petData.hp or 20,
			displayName = petData.displayName,
		}
		return pets
	end)

	PlayerService.UpdateValue(player, "dice", function(old)
		return (old or 0) + 1
	end)

	-- Auto-equip if slot available
	local equipped = PlayerService.GetValue(player, "equippedPets") or {}
	local maxSlots = PlayerService.GetValue(player, "maxEquipSlots") or 1
	
	local autoEquipped = false
	
	if #equipped < maxSlots then
		autoEquipped = true
		PlayerService.UpdateValue(player, "equippedPets", function(list)
			table.insert(list, petId)
			return list
		end)
	end

	Remotes.RollPet:FireClient(player, {
		petType = petType,
		petId = petId,
		rarity = petData.rarity,
		displayName = petData.displayName,
		damage = petData.damage,
		autoEquipped = autoEquipped,
	})
end

function RollService.StartListening()
	Remotes.RollPet.OnServerEvent:Connect(function(player)
		RollService.Roll(player)
	end)
end

return RollService