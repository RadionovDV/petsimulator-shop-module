-- UpgradeService.lua
-- Server-authoritative upgrade purchase system. Validates prerequisites, affordability,
-- and applies effects via per-field PlayerDataServer updates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local UpgradeConfig = require(ReplicatedFirst.UpgradeConfig)

local Remotes = ReplicatedStorage.Remotes

local UpgradeService = {}

function UpgradeService.Purchase(player, upgradeId)
	PlayerService.WaitForLoad(player)

	local config = UpgradeConfig[upgradeId]
	if not config then
		warn(string.format("Unknown upgrade: %s", upgradeId))
		return
	end

	-- Reject if already owned
	local owned = PlayerService.GetValue(player, "upgrades") or {}
	if owned[upgradeId] then
		return
	end

	-- Reject if permanently owned (survived rebirth)
	local permanentUpgrades = PlayerService.GetValue(player, "permanentUpgrades") or {}
	if permanentUpgrades[upgradeId] then
		return
	end

	-- Check prerequisite upgrade
	if config.requires and not owned[config.requires] then
		return
	end

	-- Validate affordability
	if not EconomyService.CanAfford(player, config.cost, config.currency) then
		return
	end

	-- Deduct currency
	EconomyService.SubtractCurrency(player, config.cost, config.currency)

	-- Mark the upgrade as purchased
	PlayerService.UpdateValue(player, "upgrades", function(list)
		list[upgradeId] = true
		return list
	end)

	if config.isPermanent then
		PlayerService.UpdateValue(player, "permanentUpgrades", function(list)
			list[upgradeId] = true
			return list
		end)
	end

	-- Apply the upgrade's effect to the relevant stat
	if config.effect == "luck" then
		PlayerService.UpdateValue(player, "luck", function()
			return config.value
		end)
	elseif config.effect == "rollCooldown" then
		PlayerService.UpdateValue(player, "rollCooldown", function(old)
			return math.max(0.1, (old or 2) + config.value)
		end)
	elseif config.effect == "maxEquipSlots" then
		PlayerService.UpdateValue(player, "maxEquipSlots", function(old)
			return (old or 1) + config.value
		end)
	elseif config.effect == "unlockAutoRoll" then
		PlayerService.UpdateValue(player, "autoRollUnlocked", function()
			return true
		end)
	elseif config.effect == "unlockRocks" then
		PlayerService.UpdateValue(player, "rocksUnlocked", function()
			return true
		end)
	elseif config.effect == "unlockShop" then
		PlayerService.UpdateValue(player, "shopUnlocked", function()
			return true
		end)
	elseif config.effect == "unlockIndex" then
		PlayerService.UpdateValue(player, "indexUnlocked", function()
			return true
		end)
	elseif config.effect == "unlockRebirth" then
		PlayerService.UpdateValue(player, "rebirthUnlocked", function()
			return true
		end)
	elseif config.effect == "enemyCount" then
		PlayerService.UpdateValue(player, "enemyCount", function(old)
			return (old or 1) + config.value
		end)
		-- Re-spawn enemies with the new count
		local CombatService = require(script.Parent.CombatService)
		CombatService.SpawnEnemiesForPlayer(player)
	end
	-- offlineIncome, unlockDailyReward, unlockMicroReward, unlockQuestSystem effects
	-- are no-ops: the upgrade is already recorded in the `upgrades` dict above.

	if config.effect == "unlockMicroReward" then
		local MicroRewardService = require(script.Parent.MicroRewardService)
		MicroRewardService.onUpgradePurchased(player)
	end

	if config.effect == "unlockDailyReward" then
		local DailyRewardService = require(script.Parent.DailyRewardService)
		DailyRewardService.onUpgradePurchased(player)
	end
end

function UpgradeService.StartListening()
	Remotes.PurchaseUpgrade.OnServerEvent:Connect(function(player, upgradeId)
		UpgradeService.Purchase(player, upgradeId)
	end)
end

return UpgradeService