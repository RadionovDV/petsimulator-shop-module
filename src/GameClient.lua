-- GameClient.lua (LocalScript)
-- Client-side entry point. Waits for PlayerDataClient to load, then requires all controllers.
-- Subscribes to PlayerDataClient.updated Signal to keep UI in sync with server data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local module = script.Parent.Modules
local Remotes = ReplicatedStorage.Remotes

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local AudioController = require(ReplicatedStorage.AudioController)
local EconomyController = require(module.EconomyController)
local RollController = require(module.RollController)
local CombatController = require(module.CombatController)
local UpgradeController = require(module.UpgradeController)
local LocationController = require(module.LocationController)
local BackpackController = require(module.BackpackController)
local MenuController = require(module.MenuController)
local RebirthController = require(module.RebirthController)
local VisibilityController = require(module.VisibilityController)
local OfflineIncomeController = require(module.OfflineIncomeController)
local DailyRewardController = require(module.DailyRewardController)
local MicroRewardController = require(module.MicroRewardController)
local TutorialController = require(module.TutorialController)
local GameConfig = require(ReplicatedFirst.GameConfig)

PlayerDataClient.start()

if not PlayerDataClient.hasLoaded() then
	PlayerDataClient.loaded:Wait()
end

local GameClient = {
	Controllers = {
		EconomyController = EconomyController,
		RollController = RollController,
		CombatController = CombatController,
		UpgradeController = UpgradeController,
		LocationController = LocationController,
		BackpackController = BackpackController,
		RebirthController = RebirthController,
		OfflineIncomeController = OfflineIncomeController,
		DailyRewardController = DailyRewardController,
		MicroRewardController = MicroRewardController,
	},
}

-- React to any server-side data change and update relevant UI
PlayerDataClient.updated:Connect(function(valueName, value)
	if valueName == "coins" or valueName == "rocks" or valueName == "dice" then
		EconomyController.UpdateDisplay()
		UpgradeController.UpdateNotifications()
		RebirthController.Refresh()
	elseif valueName == "rebirthBonusLuck" or valueName == "luck" then
		EconomyController.UpdateDisplay()
	elseif valueName == "upgrades" then
		UpgradeController.UpdateNotifications()
		VisibilityController.Refresh()
		RollController.UpdateAutoRollVisibility()
	elseif valueName == "permanentUpgrades" then
		UpgradeController.UpdateNotifications()
		VisibilityController.Refresh()
		RollController.UpdateAutoRollVisibility()
	elseif valueName == "pets" then
		BackpackController.Refresh()
	elseif valueName == "equippedPets" then
		CombatController.SyncEquippedPets()
		BackpackController.Refresh()
	elseif valueName == "unlockedLocations" then
		LocationController.UpdateGateStates()
		RebirthController.Refresh()
	elseif valueName == "currentLocation" then

	elseif valueName == "rebirthCount" then
		RebirthController.Refresh()
		LocationController.Refresh()
		VisibilityController.Refresh()
		RollController.UpdateAutoRollVisibility(true)
	elseif valueName == "rocksUnlocked" or valueName == "shopUnlocked" or valueName == "indexUnlocked" or valueName == "rebirthUnlocked" then
		VisibilityController.Refresh()
	elseif valueName == "autoRollUnlocked" then
		RollController.UpdateAutoRollVisibility()
	elseif valueName == "dailyRewardDay" or valueName == "dailyRewardClaimed" then
		UpgradeController.UpdateNotifications()
	end
end)

-- Combat state sync from server
Remotes.SyncCombatState.OnClientEvent:Connect(function(data)
	CombatController.SyncCombatState(data)
end)

Remotes.PetDefeated.OnClientEvent:Connect(function(data)
	CombatController.OnPetDefeated(data.petId)
end)

Remotes.PetRevived.OnClientEvent:Connect(function(data)
	CombatController.OnPetRevived(data.petId)
end)

Remotes.EnemyDefeated.OnClientEvent:Connect(function(data)
	CombatController.OnEnemyDefeated(data.enemyId)
end)

-- Initial render after load
EconomyController.UpdateDisplay()
UpgradeController.UpdateNotifications()
BackpackController.Refresh()
CombatController.SyncEquippedPets()
LocationController.UpdateGateStates()
RebirthController.Refresh()
VisibilityController.Refresh()
RollController.UpdateAutoRollVisibility()

-- Start controllers that need event listeners
OfflineIncomeController.Start()
DailyRewardController.Start()
MicroRewardController.Start()
if GameConfig.enableTutorial then
	TutorialController.Start()
end

AudioController.PlayMusic("MainTheme2")

return GameClient