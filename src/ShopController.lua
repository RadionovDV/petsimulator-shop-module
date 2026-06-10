local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local ShopConfig = require(ReplicatedFirst.ShopConfig)
local LoadingDisplay = require(ReplicatedStorage.UI.Components.LoadingDisplay)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")

local Remotes = ReplicatedStorage.Remotes

local ShopController = {}

local limitedPackQuantity = ShopConfig.LimitedPack.initialQuantity
local pendingLimitedQty = nil

local shopFrame = menuGui:WaitForChild("Shop")
local loadingFrame = shopFrame:WaitForChild("LoadingFrame")
local topBar = shopFrame:WaitForChild("TopBar")
local closeButton = topBar:WaitForChild("Frame"):WaitForChild("CloseButton")

local body = shopFrame:WaitForChild("Body")
local scrollingBody = body:WaitForChild("ScrollingBody")
local passesGrid = scrollingBody:WaitForChild("PassesGrid")
local coinsGrid = scrollingBody:WaitForChild("CoinsGrid")

local starterPack = scrollingBody:WaitForChild("StarterPackBoard")
local starterPackBody = starterPack:WaitForChild("Body")
local starterPackTitel = starterPackBody:WaitForChild("Titel")
local starterTimer = starterPackTitel:WaitForChild("ExpireLabel")
local starterBoardContent = starterPackBody:WaitForChild("BoardContent")
local starterActions = starterBoardContent:WaitForChild("Actions")
local starterPurchaseBtn = starterActions:WaitForChild("PurchaseButton")
local starterPriceFrame = starterPurchaseBtn:WaitForChild("Price")
local starterPriceLabel = starterPriceFrame:WaitForChild("PriceLabel")
local starterOldPriceFrame = starterActions:WaitForChild("OldPrice")
local starterOldPriceInner = starterOldPriceFrame:WaitForChild("Price")
local starterOldPriceLabel = starterOldPriceInner:WaitForChild("PriceLabel")

local limitedPackFrame = scrollingBody:WaitForChild("LimitedPackFrame")
local limitedPack = limitedPackFrame:WaitForChild("StarterPackBoard")
local limitedPackBody = limitedPack:WaitForChild("Body")
local limitedPackTitel = limitedPackBody:WaitForChild("Titel")
local limitedRemains = limitedPackTitel:WaitForChild("RemainsLabel")
local limitedBoardContent = limitedPackBody:WaitForChild("BoardContent")
local limitedActions = limitedBoardContent:WaitForChild("Actions")
local limitedPurchaseBtn = limitedActions:WaitForChild("PurchaseButton")
local limitedPriceFrame = limitedPurchaseBtn:WaitForChild("Price")
local limitedPriceLabel = limitedPriceFrame:WaitForChild("PriceLabel")

local passesGridFrame = passesGrid:WaitForChild("GridFrame")
local passesRow = passesGridFrame:WaitForChild("TilesRow")
local fastRollPass = passesRow:WaitForChild("FastRollPass")
local extraSlotPass = passesRow:WaitForChild("ExtraSlotPass")
local luckyRollPass = passesRow:WaitForChild("LuckyRollPass")

local coinsGridFrame = coinsGrid:WaitForChild("GridFrame")
local coinsRow1 = coinsGridFrame:WaitForChild("TilesRow1")
local coinsRow2 = coinsGridFrame:WaitForChild("TilesRow2")

local dailyGiftFrame = scrollingBody:WaitForChild("DailyGiftFrame")
local dailyGiftBoard = dailyGiftFrame:WaitForChild("StarterPackBoard")
local dailyGiftBody = dailyGiftBoard:WaitForChild("Body")
local dailyRedPoint = dailyGiftBoard:WaitForChild("RedPoint")
local dailyClimeBtn = dailyGiftBody:WaitForChild("ClimeButton")
local dailyClimedFrame = dailyGiftBody:WaitForChild("ClaimedFrame")
local dailyPriceFrame = dailyClimeBtn:WaitForChild("Price")
local dailyClaimText = dailyPriceFrame:WaitForChild("PriceLabel")
local dailyUnavailable = dailyClimeBtn:WaitForChild("Unavailable")
local dailyTitle = dailyGiftBody:WaitForChild("TitelLabel")

local gameplayGui = playerGui:WaitForChild("GameplayGui")
local rightSide = gameplayGui:WaitForChild("RightSide")
local shopButtonRedPoint = rightSide:WaitForChild("Shop"):WaitForChild("RedPoint")

local function _findCoinsTile(coinsRow, col)
	local name = "Coins" .. col
	return coinsRow:WaitForChild(name)
end

local function _findPriceLabel(tile)
	local priceLabel = tile:FindFirstChild("PriceLabel", true)
	if not priceLabel then
		return nil
	end
	return priceLabel
end

local function _formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

function ShopController.Init()
	local loadingDisplay = LoadingDisplay()
	loadingDisplay.Parent = loadingFrame
	loadingFrame.Visible = true
	
	ShopController._fetchProductPrices()

	starterPriceLabel.Text = tostring(ShopConfig.StarterPack.discountPrice)
	starterOldPriceLabel.Text = tostring(ShopConfig.StarterPack.originalPrice)
	limitedPriceLabel.Text = tostring(ShopConfig.LimitedPack.price)

	closeButton.Activated:Connect(function()
		shopFrame.Visible = false
	end)

	starterPurchaseBtn.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, ShopConfig.StarterPack.productId)
	end)

	limitedPurchaseBtn.Activated:Connect(function()
		MarketplaceService:PromptProductPurchase(player, ShopConfig.LimitedPack.productId)
	end)

	for _, passConfig in pairs(ShopConfig.GamePasses) do
		local frame = ShopController._getPassFrame(passConfig.perkId)
		if not frame then
			continue
		end
		local purchaseButton = frame:FindFirstChild("PurchaseButton", true)
		if not purchaseButton then
			continue
		end
		
		if RunService:IsStudio() then
			purchaseButton.Activated:Connect(function()
				Remotes.DevGamePassPurchase:FireServer(passConfig.productId)
			end)
		else
			purchaseButton.Activated:Connect(function()
				MarketplaceService:PromptGamePassPurchase(player, passConfig.productId)
			end)
		end
	end

	for _, coinConfig in ipairs(ShopConfig.Coins) do
		local row = coinConfig.row == 1 and coinsRow1 or coinsRow2
		local tile = _findCoinsTile(row, coinConfig.col)
		local purchaseButton = tile:FindFirstChild("PurchaseButton", true)
		if not purchaseButton then
			continue
		end
		purchaseButton.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(player, coinConfig.productId)
		end)
	end
	
	ShopController._startStarterTimer()
	ShopController._initDailyGift()
	ShopController._initLimitedQtySync()
	ShopController._initBoostSync()
	ShopController.Refresh()
	loadingFrame.Visible = false
end

function ShopController._fetchProductPrices()
	for _, coinConfig in ipairs(ShopConfig.Coins) do
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(coinConfig.productId, Enum.InfoType.Product)
		end)
		if success and info and info.PriceInRobux then
			local row = coinConfig.row == 1 and coinsRow1 or coinsRow2
			local tile = _findCoinsTile(row, coinConfig.col)
			local priceLabel = _findPriceLabel(tile)
			if priceLabel then
				priceLabel.Text = tostring(info.PriceInRobux)
			end
		end
	end

	for _, passConfig in pairs(ShopConfig.GamePasses) do
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(passConfig.productId, Enum.InfoType.GamePass)
		end)
		if success and info and info.PriceInRobux then
			local frame = ShopController._getPassFrame(passConfig.perkId)
			if frame then
				local priceLabel = _findPriceLabel(frame)
				if priceLabel then
					priceLabel.Text = tostring(info.PriceInRobux)
				end
			end
		end
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(ShopConfig.StarterPack.productId, Enum.InfoType.Product)
	end)
	if success and info and info.PriceInRobux then
		starterPriceLabel.Text = tostring(info.PriceInRobux)
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(ShopConfig.LimitedPack.productId, Enum.InfoType.Product)
	end)
	if success and info and info.PriceInRobux then
		limitedPriceLabel.Text = tostring(info.PriceInRobux)
	end
end

function ShopController._getPassFrame(perkId)
	if perkId == "fastRoll" then
		return fastRollPass
	elseif perkId == "extraSlot" then
		return extraSlotPass
	elseif perkId == "luckyRoll" then
		return luckyRollPass
	end
	return nil
end

function ShopController._startStarterTimer()
	task.spawn(function()
		while true do
			local firstJoinTime = PlayerDataClient.get("firstJoinTime") or 0
			local claimed = PlayerDataClient.get("starterPackClaimed") or false

			if claimed then
				starterPack.Visible = false
				return
			end

			if firstJoinTime == 0 then
				task.wait(1)
				continue
			end

			local elapsed = os.time() - firstJoinTime
			local maxSeconds = ShopConfig.StarterPack.validityHours * 3600
			local remaining = maxSeconds - elapsed

			if remaining <= 0 then
				starterTimer.Text = "Expired"
				starterPurchaseBtn.Visible = false
				starterOldPriceFrame.Visible = false
				return
			end
			
			print(remaining)
			starterTimer.Text = _formatTime(remaining)
			task.wait(1)
		end
	end)
end

function ShopController._initLimitedQtySync()
	Remotes.ShopUpdateLimitedQty.OnClientEvent:Connect(function(qty)
		ShopController.UpdateLimitedQty(qty)
	end)
	if pendingLimitedQty then
		ShopController.UpdateLimitedQty(pendingLimitedQty)
		pendingLimitedQty = nil
	end
end

function ShopController.UpdateLimitedQty(qty)
	limitedPackQuantity = qty
	limitedRemains.Text = string.format("%d/%d", qty, ShopConfig.LimitedPack.initialQuantity)
	if qty <= 0 then
		limitedPurchaseBtn.Visible = false
	else
		limitedPurchaseBtn.Visible = true
	end
end

function ShopController._initBoostSync()
	Remotes.ShopSyncBoosts.OnClientEvent:Connect(function(luckExpiry, speedExpiry)
		ShopController._updateBoostState(luckExpiry, speedExpiry)
	end)
end

function ShopController._updateBoostState(luckExpiry, speedExpiry)
	-- Кэш на клиенте для EconomyController
	ShopController._cachedLuckBoost = luckExpiry
	ShopController._cachedSpeedBoost = speedExpiry
end

function ShopController._initDailyGift()
	dailyClimeBtn.Activated:Connect(function()
		Remotes.ClaimDailyGift:FireServer()
	end)

	Remotes.ShopDailyGiftState.OnClientEvent:Connect(function(isAvailable, nextAvailable)
		dailyUnavailable.Visible = not isAvailable
		dailyClimeBtn.Visible = isAvailable
		dailyClimedFrame.Visible = not isAvailable
		dailyRedPoint.Visible = isAvailable
		shopButtonRedPoint.Visible = isAvailable
		if not isAvailable then
			local remaining = math.max(0, nextAvailable - os.time())
			dailyClaimText.Text = _formatTime(remaining)
		else
			dailyClaimText.Text = "Claim"
		end
	end)
end

function ShopController.Refresh()
	local donateUpgrades = PlayerDataClient.get("donateUpgrades") or {}

	for _, passConfig in pairs(ShopConfig.GamePasses) do
		local tile = ShopController._getPassFrame(passConfig.perkId)
		local tileInfo = tile:WaitForChild("Info")
		local purchaseButton = tileInfo:WaitForChild("PurchaseButton")
		local claimedLabel = tileInfo:WaitForChild("ClaimedLabel")
		
		local owned = donateUpgrades[passConfig.perkId] == true
		
		claimedLabel.Visible = owned
		purchaseButton.Visible = not owned
	end
end

Remotes.ShopUpdateLimitedQty.OnClientEvent:Connect(function(qty)
	if ShopController.UpdateLimitedQty then
		ShopController.UpdateLimitedQty(qty)
	else
		pendingLimitedQty = qty
	end
end)

return ShopController