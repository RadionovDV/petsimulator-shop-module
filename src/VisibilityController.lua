-- VisibilityController.lua
-- Shows/hides HUD elements based on owned upgrades in the upgrades dictionary.
-- Also checks permanentUpgrades so features survive rebirth.
-- Uses upgrades dict (not individual PlayerData flags) for reliable post-rebirth sync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gameplayGui = playerGui:WaitForChild("GameplayGui")

local VisibilityController = {}

-- Maps upgrade ID → { container, elementName } — lookup resolves at Refresh() time
local UPGRADE_MAP = {
	rocks_unlock = { gameplayGui.LeftSide, "Rocks" },
	shop = { gameplayGui.RightSide, "Shop" },
	rebirth = { gameplayGui.RightSide, "Rebirth" },
	index = { gameplayGui.RightSide, "Index" },
}

-- Reads the upgrades dictionary from PlayerData (reliable, always in sync).
-- Shows UI elements whose upgrade ID is present, hides the rest.
function VisibilityController.Refresh()
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local permanentUpgrades = PlayerDataClient.get("permanentUpgrades") or {}
	
	for upgradeId, path in UPGRADE_MAP do
		local uiElement = path[1]:FindFirstChild(path[2])
		if not uiElement then
			continue
		end
		uiElement.Visible = upgrades[upgradeId] == true or permanentUpgrades[upgradeId] == true
	end
end

return VisibilityController