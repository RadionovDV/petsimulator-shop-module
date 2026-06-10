-- UpgradeConfig.lua
-- Defines the upgrade tree. Each upgrade has a cost, currency type, prerequisite,
-- effect type, and value. The tree branches from the first upgrades outward.
-- Effects: luck (multiplier), rollCooldown (reduction), maxEquipSlots (+), unlockAutoRoll, unlockRocks, enemyCount (+)
-- isPermanent: true => upgrade survives rebirth and becomes dimmed in the tree.

local StarterGui = game:GetService("StarterGui")
local board = StarterGui.MenuGui.Upgrade.Canvas.Board
local upgradeTileInstaller = board.UpgradeTileInstaller

local UpgradeConfig = {
	autoll = {
		cost = 60, currency = "coins", 
		effect = "unlockAutoRoll", value = true,
		displayName = "Auto Roll", description = "Automatically rolls pets",
		icon = "rbxassetid://108780071692774",
		isPermanent = true,
	},
	luck_1 = {
		cost = 100, 
		currency = "coins", 
		effect = "luck", 
		value = 1.1,
		requires = nil,
		displayName = "Luck I", 
		description = "Increases luck multiplier to 1.2x",
		icon = "rbxassetid://83955876596707",
	},
	luck_2 = {
		cost = 100, currency = "coins", 
		effect = "luck", value = 1.3,
		displayName = "Luck II", description = "Increases luck multiplier to 1.5x",
		icon = "rbxassetid://83955876596707",
	},
	luck_3 = {
		cost = 200, currency = "coins", 
		effect = "luck", value = 1.4,
		displayName = "Luck III", description = "Increases luck multiplier to 1.5x",
		icon = "rbxassetid://83955876596707",
	},
	luck_4 = {
		cost = 500, currency = "coins", 
		effect = "luck", value = 1.5,
		displayName = "Luck IV", description = "Increases luck multiplier to 1.5x",
		icon = "rbxassetid://83955876596707",
	},


	--shop = {
	--	cost = 200, currency = "coins", 
	--	effect = "unlockShop", value = true,
	--	displayName = "Shop", description = "Unlock shop for more benefits",
	--	icon = "rbxassetid://118554800883386",
	--	isPermanent = true,
	--},
	rollspeed_1 = {
		cost = 30, currency = "dice", 
		effect = "rollCooldown", value = -0.5,
		displayName = "Roll Speed I", description = "Reduces roll cooldown by 0.5s",
		icon = "rbxassetid://122184010309818",
	},
	rollspeed_2 = {
		cost = 100, currency = "dice", 
		effect = "rollCooldown", value = -0.3,
		displayName = "Roll Speed II", description = "Reduces roll cooldown by 0.3s",
		icon = "rbxassetid://122184010309818",
	},
	rollspeed_3 = {
		cost = 1000, currency = "dice", 
		effect = "rollCooldown", value = -0.2,
		displayName = "Roll Speed II", description = "Reduces roll cooldown by 0.3s",
		icon = "rbxassetid://122184010309818",
	},
	index = {
		cost = 1000, currency = "coins", 
		effect = "unlockIndex", value = true,
		displayName = "Index", description = "Find out how much is left",
		icon = "rbxassetid://118367980795800",
		isPermanent = true,
	},

	extraslot_1 = {
		cost = 80, currency = "coins", 
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot I", description = "+1 pet equip slot",
		icon = "rbxassetid://77560258643186",
	},
	extraslot_2 = {
		cost = 250, currency = "coins", 
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot II", description = "+1 pet equip slot",
		icon = "rbxassetid://77560258643186",
	},
	extraslot_3 = {
		cost = 800, currency = "coins", 
		effect = "maxEquipSlots", value = 1,
		displayName = "Extra Slot III", description = "+1 pet equip slot",
		icon = "rbxassetid://77560258643186",
	},
	rebirth = {
		cost = 400, currency = "coins", 
		effect = "unlockRebirth", value = true,
		displayName = "Rebirth", description = "Unlock rebirth for more benefits",
		icon = "rbxassetid://98256223082322",
		isPermanent = true,
	},

	moreenemies_1 = {
		cost = 20, currency = "coins", 
		effect = "enemyCount", value = 1,
		displayName = "More Enemies I", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
	},
	moreenemies_2 = {
		cost = 150, currency = "coins", 
		effect = "enemyCount", value = 1,
		displayName = "More Enemies II", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
	},
	moreenemies_3 = {
		cost = 500, currency = "coins", 
		effect = "enemyCount", value = 1,
		displayName = "More Enemies III", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
	},
	moreenemies_4 = {
		cost = 800, currency = "coins", 
		effect = "enemyCount", value = 1,
		displayName = "More Enemies IV", description = "+1 active enemy",
		icon = "rbxassetid://88395994860267",
	},

	rocks_unlock = {
		cost = 500, currency = "coins", 
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
		icon = "rbxassetid://110971351869251",
	},
	rocks_2 = {
		cost = 1000, currency = "coins", 
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
		icon = "rbxassetid://110971351869251",
	},
	rocks_3 = {
		cost = 2000, currency = "coins", 
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
		icon = "rbxassetid://110971351869251",
	},
	rocks_4 = {
		cost = 5000, currency = "coins", 
		effect = "unlockRocks", value = true,
		displayName = "Rocks Unlock", description = "Unlocks Rocks currency from enemies",
		icon = "rbxassetid://110971351869251",
	},

	-- Offline Income branch (4 tiers)
	offline_income_1 = {
		cost = 500, currency = "coins", 
		effect = "offlineIncome", value = true,
		displayName = "Bucket I", description = "Offline coin bucket unlocked",
		icon = "rbxassetid://72297198233257",
		isPermanent = true,
	},
	offline_income_2 = {
		cost = 1000, currency = "coins", 
		effect = "offlineIncome", value = true,
		displayName = "Rate I", description = "Faster coin accumulation",
		icon = "rbxassetid://72297198233257",
		isPermanent = true,
	},
	offline_income_3 = {
		cost = 2000, currency = "coins", 
		effect = "unlockRocks", value = true,
		displayName = "Bucket II", description = "Unlocks rock accumulation",
		icon = "rbxassetid://72297198233257",
		isPermanent = true,
	},
	offline_income_4 = {
		cost = 4000, currency = "coins", 
		effect = "offlineIncome", value = true,
		displayName = "Rate II", description = "Faster rock accumulation",
		icon = "rbxassetid://72297198233257",
		isPermanent = true,
	},

	-- Daily Rewards unlock node
	daily_reward_unlock = {
		cost = 2000, currency = "coins", 
		effect = "unlockDailyReward", value = true,
		displayName = "Daily 3", description = "Unlock daily reward system",
		icon = "rbxassetid://112259198133355",
		isPermanent = true,
	},
	daily_reward_level_1 = {
		cost = 4000, currency = "coins", 
		effect = "unlockDailyReward", value = true,
		displayName = "Daily 4", description = "Increase max combo to 4 days",
		icon = "rbxassetid://77474507152442",
		isPermanent = true,
	},
	daily_reward_level_2 = {
		cost = 6000, currency = "coins", 
		effect = "unlockDailyReward", value = true,
		displayName = "Daily 5", description = "Increase max combo to 5 days",
		icon = "rbxassetid://121640557651643",
		isPermanent = true,
	},
	daily_reward_level_3 = {
		cost = 8000, currency = "coins", 
		effect = "unlockDailyReward", value = true,
		displayName = "Daily 6", description = "Increase max combo to 6 days",
		icon = "rbxassetid://139363973667930",
		isPermanent = true,
	},
	daily_reward_level_4 = {
		cost = 10000, currency = "coins", 
		effect = "unlockDailyReward", value = true,
		displayName = "Daily 7", description = "Increase max combo to 7 days",
		icon = "rbxassetid://115665259404631",
		isPermanent = true,
	},

	-- Micro Rewards unlock node
	micro_reward_unlock = {
		cost = 1500, currency = "coins", 
		effect = "unlockMicroReward", value = true,
		displayName = "Micro Rewards", description = "Unlock time-gated micro rewards",
		icon = "rbxassetid://76179577512196",
		isPermanent = true,
	},
	micro_reward_level_1 = {
		cost = 3000, currency = "coins", 
		effect = "unlockMicroReward", value = true,
		displayName = "MR Level I", description = "Unlock 60 min reward tier",
		icon = "rbxassetid://76179577512196",
		isPermanent = true,
	},
	micro_reward_level_2 = {
		cost = 6000, currency = "coins", 
		effect = "unlockMicroReward", value = true,
		displayName = "MR Level II", description = "Unlock 120 min reward tier",
		icon = "rbxassetid://76179577512196",
		isPermanent = true,
	},

	-- Quest System unlock node
	--quest_system = {
	--	cost = 10000, currency = "coins", 
	--	effect = "unlockQuestSystem", value = true,
	--	displayName = "Quests", description = "Unlock quest system",
	--	icon = "rbxassetid://83829311871207",
	--	isPermanent = true,
	--},
}

local function setPosition(config)
	local tileInstances = upgradeTileInstaller:GetChildren()

	for _, tileInstance in upgradeTileInstaller:GetChildren() do
		if tileInstance:IsA("ImageButton") or tileInstance:IsA("CanvasGroup") then
			local tireConfig = config[tileInstance.Name]
			if not tireConfig then
				warn(`You need to add item {tileInstance.Name} to config`)
				continue
			end

			tireConfig.nodePosition = {
				x = tileInstance.Position.X.Offset, 
				y = tileInstance.Position.Y.Offset
			}


			tireConfig.requires = tileInstance:GetAttribute("requires")

		end
	end

	upgradeTileInstaller.Visible = false
end

local function buildUpgradeTree(config)
	local reverse = {}
	for id, _ in pairs(config) do
		reverse[id] = {}
	end

	for id, cfg in pairs(config) do
		if cfg.requires then
			if reverse[cfg.requires] then
				table.insert(reverse[cfg.requires], id)
			end
		end
	end

	for id, children in pairs(reverse) do
		if config[id].isPermanent and #children > 0 then
			config[id].children = children
		end
	end
end

setPosition(UpgradeConfig)
buildUpgradeTree(UpgradeConfig)

return UpgradeConfig
