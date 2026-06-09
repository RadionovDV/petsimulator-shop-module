-- UpgradeController.lua
-- Client-side interactive upgrade tree board with pan and zoom.
-- Renders upgrade nodes inside MenuGui.Upgrade.Canvas.Board as cloned UpgradeTileButton templates.
-- Handles purchase requests via Remotes.PurchaseUpgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local UpgradeConfig = require(ReplicatedFirst.UpgradeConfig)
local mergeArraysUniqueOnly = require(ReplicatedStorage.mergeArraysUniqueOnly)
local AudioController = require(ReplicatedStorage.AudioController)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameplayGui = playerGui:WaitForChild("GameplayGui")
local menuGui = playerGui:WaitForChild("MenuGui")

-- Pre-fetch UI references at module top-level (project convention)
local upgradeWindow = menuGui:WaitForChild("Upgrade")
local canvas = upgradeWindow:WaitForChild("Canvas")
local board = canvas:WaitForChild("Board")
local uiScale = board:WaitForChild("UIScale")

-- HUD notification badge (red dot with count on the Upgrade button)
local bottomSide = gameplayGui:WaitForChild("BottomSide")
local upgradeHudFrame = bottomSide:WaitForChild("Upgrade")
local redPoint = upgradeHudFrame:WaitForChild("RedPoint")
local updateCountLabel = redPoint:WaitForChild("UpdateCountLabel")

-- Template for upgrade nodes, created by the user in ReplicatedStorage.UI.Objects
local itemTileTemplate = ReplicatedStorage.UI.Objects:WaitForChild("UpgradeTileButton")

local UpgradeController = {}

-- Tile background colors for each purchase status
local STATUS_COLORS = {
	owned     = Color3.fromRGB(74, 168, 230),
	buyable   = Color3.fromRGB(43, 43, 43),
	locked    = Color3.fromRGB(81, 0, 1),
	notenough = Color3.fromRGB(0, 0, 0),
	permanent = Color3.fromRGB(30, 30, 30),
}

local DRAG_THRESHOLD = 5
local hasRenderedOnce = false

function UpgradeController._isBranchComplete(upgradeId, ownedUpgrades)
	local branch = {}
	local tireConfig = UpgradeConfig[upgradeId]
	table.insert(branch, upgradeId)

	local function addParent(curConfig)
		local parentId = curConfig.requires
		if not parentId then
			return
		end

		local parentConfig = UpgradeConfig[parentId]
		if not parentConfig then
			return
		end

		if not parentConfig.isPermanent then
			return
		end

		table.insert(branch, parentId)
		addParent(parentConfig)
	end

	local function addChildren(curConfig)
		local childIds = curConfig.children
		if not childIds then
			return
		end

		for _, childId in childIds do
			local childConfig = UpgradeConfig[childId]
			if not childConfig then
				return
			end

			if not childConfig.isPermanent then
				return
			end

			table.insert(branch, childId)
			addChildren(childConfig)
		end
	end

	addParent(tireConfig)
	addChildren(tireConfig)

	local uniqueBranch = mergeArraysUniqueOnly(branch)
	local branchCompleted = true

	for _, checkUpgradeId in uniqueBranch do
		if not ownedUpgrades[checkUpgradeId] then
			branchCompleted = false
		end
	end

	return branchCompleted
end

function UpgradeController._getStatus(upgradeId, tireConfig, upgrades, permanentUpgrades, coins, dice)
	local combinedUpgrades = {}
	for id, _ in upgrades do combinedUpgrades[id] = true end
	for id, _ in permanentUpgrades do combinedUpgrades[id] = true end

	if tireConfig.isPermanent and UpgradeController._isBranchComplete(upgradeId, combinedUpgrades) then
		return "extinct"
	end

	if combinedUpgrades[upgradeId] then
		return "owned"
	end

	if tireConfig.requires and not combinedUpgrades[tireConfig.requires] then
		return "locked"
	end

	local balance = tireConfig.currency == "coins" and coins or dice
	if balance >= tireConfig.cost then
		return "buyable"
	end

	return "notenough"
end

function UpgradeController._renderUpgrades()
	-- --- 1.  Centre the cluster on the very first render  ---
	if not hasRenderedOnce then
		local canvasSize = canvas.AbsoluteSize
		if canvasSize.X > 0 and canvasSize.Y > 0 then
			board.Position = UDim2.fromOffset(
				math.floor(800),
				math.floor(400)
			)
		end
		hasRenderedOnce = true
	end

	-- --- 2.  Save current pan / zoom to restore after rebuild  ---
	local savedScale = uiScale.Scale
	local savedPos = UDim2.fromOffset(board.Position.X.Offset, board.Position.Y.Offset)

	-- --- 3.  Destroy old nodes (keep UIScale and any non-ImageButton children)  ---
	for _, child in board:GetChildren() do
		if child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end

	-- --- 4.  Read current player data  ---
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local permanentUpgrades = PlayerDataClient.get("permanentUpgrades") or {}
	local coins = PlayerDataClient.get("coins") or 0
	local dice = PlayerDataClient.get("dice") or 0

	-- --- 5.  Create a tile for every upgrade defined in config  ---

	for upgradeId, tireConfig in UpgradeConfig do
		local pos = tireConfig.nodePosition
		if not pos then continue end

		local status = UpgradeController._getStatus(upgradeId, tireConfig, upgrades, permanentUpgrades, coins, dice)

		-- Clone the template and position it in the Board
		local itemTile = itemTileTemplate:Clone()
		itemTile.Name = upgradeId
		itemTile.Position = UDim2.fromOffset(pos.x, pos.y)

		local tileButton = itemTile.TileButton
		local iconLabel = tileButton.IconLabel
		iconLabel.Image = tireConfig.icon

		local nameLabel = tileButton.NameLabel
		nameLabel.Text = tireConfig.displayName

		local priceLabel = tileButton.Price.PriceLabel
		local currencyImage = tileButton.Price.CurrencyImage

		if status == "extinct" then
			itemTile.GroupTransparency = 0.7
			tileButton.ImageColor3 = STATUS_COLORS.permanent
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			tileButton.Visible = true
			priceLabel.Text = ""
			currencyImage.Image = ""
		elseif status == "owned" then
			tileButton.ImageColor3 = STATUS_COLORS.owned
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			tileButton.Visible = true
			priceLabel.Text = ""
			currencyImage.Image = ""
		elseif status == "locked" then
			tileButton.ImageColor3 = STATUS_COLORS.locked
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			tileButton.Visible = false
			priceLabel.Text = "Locked"
			currencyImage.Image = ""
		elseif status == "notenough" then
			tileButton.ImageColor3 = STATUS_COLORS.notenough
			tileButton.Active = false
			tileButton.AutoButtonColor = false
			tileButton.Visible = true
			priceLabel.Text = tostring(tireConfig.cost)
			priceLabel.TextColor3 = Color3.fromRGB(120, 0, 0)
			currencyImage.Image = tireConfig.currency == "coins"
				and "rbxassetid://122995436726509"
				or "rbxassetid://132804116237326"
		else
			tileButton.ImageColor3 = STATUS_COLORS.buyable
			tileButton.Active = true
			tileButton.AutoButtonColor = true
			tileButton.Visible = true
			priceLabel.Text = tostring(tireConfig.cost)
			priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			currencyImage.Image = tireConfig.currency == "coins"
				and "rbxassetid://122995436726509"
				or "rbxassetid://132804116237326"

			tileButton.Activated:Connect(function()
				AudioController.Play("UI.Purchase")
				Remotes.PurchaseUpgrade:FireServer(upgradeId)
			end)
		end

		itemTile.Parent = board
	end

	-- --- 6.  Restore pan / zoom  ---
	board.Position = savedPos
	uiScale.Scale = savedScale
end

-- ============================================================================
-- INPUT HANDLING (Pan & Zoom)
-- ============================================================================

-- Attaches all input listeners once at module load.
function UpgradeController._setupInput()	
	local isDrag = false
	local startInputPosition = nil
	local prevOffsetX = 0
	local prevOffsetY = 0

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.UserInputType == Enum.UserInputType.Touch then
			isDrag = true
			prevOffsetX = 0
			prevOffsetY = 0
			startInputPosition = inputObject.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1
			or inputObject.UserInputType == Enum.UserInputType.Touch then
			isDrag = false

		end
	end)

	UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
		if isDrag then
			local inputOffsetRelative = startInputPosition - inputObject.Position
			local xOffsetRelative = board.Position.X.Offset - inputOffsetRelative.X + prevOffsetX
			local yOffsetRelative = board.Position.Y.Offset - inputOffsetRelative.Y + prevOffsetY

			board.Position = UDim2.fromOffset(xOffsetRelative, yOffsetRelative)

			prevOffsetX = inputOffsetRelative.X
			prevOffsetY = inputOffsetRelative.Y
		end
	end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Called from GameClient when PlayerDataClient fires updated() with
-- "upgrades", "coins", or "dice".
-- Updates the HUD notification badge and re-renders the upgrade tree.
function UpgradeController.UpdateNotifications()
	local upgrades = PlayerDataClient.get("upgrades") or {}
	local permanentUpgrades = PlayerDataClient.get("permanentUpgrades") or {}
	local coins = PlayerDataClient.get("coins") or 0
	local dice = PlayerDataClient.get("dice") or 0

	-- Count affordable upgrades for the red notification badge
	local count = 0
	for upgradeId, config in UpgradeConfig do
		if not config.nodePosition then continue end
		if upgrades[upgradeId] or permanentUpgrades[upgradeId] then
			continue
		end
		if config.requires and not upgrades[config.requires] then
			continue
		end
		local balance = config.currency == "coins" and coins or dice
		if balance >= config.cost then
			count += 1
		end
	end

	-- Count claimable Daily Reward
	local dailyRewardDay = PlayerDataClient.get("dailyRewardDay") or 1
	local dailyRewardClaimed = PlayerDataClient.get("dailyRewardClaimed") or {}

	if upgrades["daily_reward_unlock"] or permanentUpgrades["daily_reward_unlock"] then
		if not dailyRewardClaimed[dailyRewardDay] then
			count += 1
		end
	end

	-- Count claimable Micro Reward tiers
	local microRewardLastClaim = PlayerDataClient.get("microRewardLastClaim") or {}
	local microTiers = {
		{ upgradeId = "micro_reward_unlock", interval = 30 * 60, key = "tier1" },
		{ upgradeId = "micro_reward_level_1", interval = 60 * 60, key = "tier2" },
		{ upgradeId = "micro_reward_level_2", interval = 120 * 60, key = "tier3" },
	}
	for _, tier in microTiers do
		if upgrades[tier.upgradeId] or permanentUpgrades[tier.upgradeId] then
			local last = microRewardLastClaim[tier.key] or 0
			if os.time() - last >= tier.interval then
				count += 1
			end
		end
	end

	if count > 0 then
		redPoint.Visible = true
		updateCountLabel.Text = tostring(count)
	else
		redPoint.Visible = false
	end

	-- Re-render the tree
	UpgradeController._renderUpgrades()
end

-- ============================================================================
-- INIT
-- ============================================================================

UpgradeController._setupInput()

return UpgradeController