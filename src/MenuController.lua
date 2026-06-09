-- MenuController.lua
-- Centralized window manager. Maps bottom HUD buttons to their corresponding MenuGui windows.
-- Ensures only one window is open at a time. CloseButton closes the current window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(ReplicatedStorage.AudioController)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local menuGui = playerGui:WaitForChild("MenuGui")
local bottomSide = gameplayGui:WaitForChild("BottomSide")
local rightSide = gameplayGui:WaitForChild("RightSide")


local backpackButton = bottomSide:WaitForChild("Backpack") 
	and bottomSide.Backpack:WaitForChild("BackpackButton")
local upgradeButton = bottomSide:WaitForChild("Upgrade") 
	and bottomSide.Upgrade:WaitForChild("UpgradeButton")
local shopButton = rightSide:WaitForChild("Shop") 
	and rightSide.Shop:WaitForChild("ShopButton")
local rebirthButton = rightSide:WaitForChild("Rebirth") 
	and rightSide.Rebirth:WaitForChild("RebirthButton")
local indexButton = rightSide:WaitForChild("Index") 
	and rightSide.Index:WaitForChild("IndexButton")

local MenuController = {}

local windows = {
	Backpack = {
		button = backpackButton,
		window = menuGui:WaitForChild("Backpack"),
	},
	Upgrade = {
		button = upgradeButton,
		window = menuGui:WaitForChild("Upgrade"),
	},
	Shop = {
		button = shopButton,
		window = menuGui:WaitForChild("Shop"),
	},
	Rebirth = {
		button = rebirthButton,
		window = menuGui:WaitForChild("Rebirth"),
	},
	Index = {
		button = indexButton,
		window = menuGui:WaitForChild("Index"),
	},
}

local currentOpen = nil

for name, entry in windows do
	if not entry.window then
		continue
	end

	local closeButton = entry.window:FindFirstChild("CloseButton", true)
	local window = entry.window

	entry.button.Activated:Connect(function()
		if currentOpen == name then
			AudioController.Play("UI.Close")
			window.Visible = false
			currentOpen = nil
			return
		end

		if currentOpen and windows[currentOpen] and windows[currentOpen].window then
			windows[currentOpen].window.Visible = false
		end

		AudioController.Play("UI.ButtonClick")
		window.Visible = true
		currentOpen = name
	end)

	if closeButton then
		closeButton.Activated:Connect(function()
			AudioController.Play("UI.Close")
			window.Visible = false
			if currentOpen == name then
				currentOpen = nil
			end
		end)
	end
end

return MenuController