local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local AudioController = require(ReplicatedStorage.AudioController)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local coinsLabel = gameplayGui:WaitForChild("LeftSide")
	and gameplayGui.LeftSide:WaitForChild("Coins")
	and gameplayGui.LeftSide.Coins:WaitForChild("TextLabel")
local rocksLabel = gameplayGui:WaitForChild("LeftSide")
	and gameplayGui.LeftSide:WaitForChild("Rocks")
	and gameplayGui.LeftSide.Rocks:WaitForChild("TextLabel")
local states = gameplayGui:WaitForChild("States")
local luckState = states:WaitForChild("Luck")
local iconLuckState = luckState:WaitForChild("IconLabel")
local multLuckLabel = iconLuckState:WaitForChild("MultLabel")
local speedState = states:WaitForChild("Speed")
local iconSpeedState = speedState:WaitForChild("IconLabel")
local speedDiceLabel = iconSpeedState:WaitForChild("SpeedLabel")

local FormatNumber = require(ReplicatedStorage.FormatNumber)
local Remotes = ReplicatedStorage.Remotes

local boostIconTemplate = ReplicatedStorage.UI.Objects:WaitForChild("BoostIcon")

local EconomyController = {}

local luckBoostIcon = nil
local speedBoostIcon = nil
local boostThread = nil

function EconomyController._getLuckSum()
	if not PlayerDataClient.hasLoaded() then
		PlayerDataClient.loaded:Wait()
	end
	local luck = PlayerDataClient.get("luck") or 0
	local rebirthBonusLuck = PlayerDataClient.get("rebirthBonusLuck") or 0
	local totalLuck =  luck + rebirthBonusLuck
	
	local donateUpgrade = PlayerDataClient.get("donateUpgrades") or {}
	
	if donateUpgrade.luckyRoll then
		totalLuck = totalLuck * 2
	end
	return totalLuck
end

function EconomyController._getSpeedSum()
	if not PlayerDataClient.hasLoaded() then
		PlayerDataClient.loaded:Wait()
	end

	local rollCooldown = PlayerDataClient.get("rollCooldown") or 0
	local donateUpgrade = PlayerDataClient.get("donateUpgrades") or {}

	if donateUpgrade.fastRoll then
		rollCooldown = rollCooldown / 2
	end
	return rollCooldown
end

function EconomyController._getLuckBoostExpiry()
	if not PlayerDataClient.hasLoaded() then
		PlayerDataClient.loaded:Wait()
	end
	return PlayerDataClient.get("luckBoostExpiry") or 0
end

function EconomyController._getSpeedBoostExpiry()
	if not PlayerDataClient.hasLoaded() then
		PlayerDataClient.loaded:Wait()
	end
	
	return PlayerDataClient.get("speedBoostExpiry") or 0
end

function EconomyController.UpdateDisplay()
	coinsLabel.Text = FormatNumber.Format(PlayerDataClient.get("coins") or 0)
	rocksLabel.Text = FormatNumber.Format(PlayerDataClient.get("rocks") or 0)
	local luckSum = EconomyController._getLuckSum()
	local luckBoostExpiry = EconomyController._getLuckBoostExpiry()
	if luckBoostExpiry > os.time() then
		luckSum = luckSum * 2
	end
	
	multLuckLabel.Text = string.format("x%s", FormatNumber.Format(luckSum))
	
	local rollSum = EconomyController._getSpeedSum()
	local speedBoostExpiry = EconomyController._getSpeedBoostExpiry()
	if speedBoostExpiry > os.time() then
		rollSum = rollSum / 2
	end
	speedDiceLabel.Text = `{rollSum} s`
end

function EconomyController.AnimateCoin(amount, screenPosition)
	local coin = Instance.new("ImageLabel")
	coin.Size = UDim2.new(0, 30, 0, 30)
	coin.Position = UDim2.new(0, screenPosition.X - 15, 0, screenPosition.Y - 15)
	coin.BackgroundTransparency = 1
	coin.Image = "rbxassetid://122995436726509"
	coin.ZIndex = 100
	coin.Parent = gameplayGui

	local targetPos = coinsLabel.AbsolutePosition
	local target = UDim2.new(0, targetPos.X, 0, targetPos.Y)

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(coin, tweenInfo, { Position = target })
	tween:Play()
	tween.Completed:Connect(function()
		coin:Destroy()
		EconomyController.UpdateDisplay()
	end)
end

function EconomyController._updateBoostIcon(boostType)
	local expiry = boostType == "Luck"
		and EconomyController._getLuckBoostExpiry()
		or EconomyController._getSpeedBoostExpiry()
	local now = os.time()
	local active = expiry > now

	local icon = boostType == "Luck" and luckBoostIcon or speedBoostIcon
	local anchor = boostType == "Luck" and luckState or speedState

	if active and not icon then
		icon = boostIconTemplate:Clone()
		icon.Name = boostType .. "BoostIcon"
		icon.Parent = states
		if boostType == "Luck" then
			icon.IconLabel.Image = "rbxassetid://83955876596707"
			luckBoostIcon = icon
		else
			icon.IconLabel.Image = "rbxassetid://122184010309818"
			speedBoostIcon = icon
		end
	elseif not active and icon then
		icon:Destroy()
		if boostType == "Luck" then
			luckBoostIcon = nil
		else
			speedBoostIcon = nil
		end
		return
	end

	if icon and icon.IconLabel.ExpireLabel then
		local remaining = math.max(0, expiry - now)
		icon.IconLabel.ExpireLabel.Text = string.format("%d:%02d",
			math.floor(remaining / 60),
			remaining % 60)
	end
end

function EconomyController.StartBoostIcons()
	if boostThread then
		return
	end
	boostThread = task.spawn(function()
		while true do
			EconomyController._updateBoostIcon("Luck")
			EconomyController._updateBoostIcon("Speed")
			task.wait(1)
		end
	end)
end

Remotes.EnemyDefeated.OnClientEvent:Connect(function(data)
	local camera = workspace.CurrentCamera
	local screenPos = camera:WorldToScreenPoint(data.position)
	if screenPos then
		EconomyController.AnimateCoin(data.coinsAmount or 0, Vector2.new(screenPos.X, screenPos.Y))
	end
end)

EconomyController.StartBoostIcons()

return EconomyController