-- EconomyService.lua
-- Server-authoritative currency management.
-- All operations use PlayerDataServer.updateValue for per-field atomic updates.
local PlayerService = require(script.Parent.PlayerService)

local EconomyService = {}

function EconomyService.AddCoins(player, amount)
	PlayerService.UpdateValue(player, "coins", function(old)
		return (old or 0) + amount
	end)
end

function EconomyService.SubtractCoins(player, amount)
	PlayerService.UpdateValue(player, "coins", function(old)
		if (old or 0) >= amount then
			return old - amount
		end
		return old
	end)
end

-- Checks if player can afford a given amount of a currency type (coins, rocks, dice)
function EconomyService.CanAfford(player, amount, currencyType)
	local current = PlayerService.GetValue(player, currencyType) or 0
	return current >= amount
end

function EconomyService.AddRocks(player, amount)
	if not PlayerService.GetValue(player, "rocksUnlocked") then
		return
	end
	PlayerService.UpdateValue(player, "rocks", function(old)
		return (old or 0) + amount
	end)
end

function EconomyService.AddDice(player, amount)
	PlayerService.UpdateValue(player, "dice", function(old)
		return (old or 0) + amount
	end)
end

function EconomyService.SubtractCurrency(player, amount, currencyType)
	PlayerService.UpdateValue(player, currencyType, function(old)
		if (old or 0) >= amount then
			return old - amount
		end
		return old
	end)
end

return EconomyService