local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local ShopConfig = require(ReplicatedFirst.ShopConfig)
local PlayerDataServer = require(ReplicatedStorage.PlayerData.PlayerDataServer)
local PetUtils = require(script.Parent.PetUtils)

local Remotes = ReplicatedStorage.Remotes

local ShopService = {}

local limitedPackStore = DataStoreService:GetDataStore(ShopConfig.LimitedPack.dataStoreName)
local limitedPackQuantity = ShopConfig.LimitedPack.initialQuantity

function ShopService.StartListening()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return ShopService._processReceipt(receiptInfo)
	end

	Remotes.DevGamePassPurchase.OnServerEvent:Connect(function(player, productId)
		if not RunService:IsStudio() then
			return
		end
		local devReceiptInfo = {
			CurrencySpent = 0,
			CurrencyType = Enum.CurrencyType.Robux,
			PlaceIdWherePurchased = 129668456888642,
			PlayerId = player.UserId,
			ProductId = productId,
			ProductPurchaseChannel = Enum.ProductPurchaseChannel.InExperience,
			PurchaseId = tostring(math.random()),
		}
		ShopService._processReceipt(devReceiptInfo)
	end)

	Remotes.ClaimDailyGift.OnServerEvent:Connect(function(player)
		ShopService._claimDailyGift(player)
	end)

	PlayerService.PlayerReady:Connect(function(player)
		ShopService._verifyDonateUpgrades(player)
		ShopService._syncLimitedQtyToPlayer(player)
		ShopService._syncBoostsToPlayer(player)
		ShopService._syncDailyGiftState(player)
	end)
end

function ShopService._verifyDonateUpgrades(player)
	local donateUpgrades = PlayerService.GetValue(player, "donateUpgrades") or {}
	local changed = false

	for _, passConfig in pairs(ShopConfig.GamePasses) do
		local perkId = passConfig.perkId
		if not donateUpgrades[perkId] then
			local owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passConfig.productId)
			end)
			if owns then
				donateUpgrades[perkId] = true
				changed = true
			end
		end
	end

	if changed then
		PlayerService.UpdateValue(player, "donateUpgrades", function()
			return donateUpgrades
		end)
	end
end

function ShopService._syncLimitedQtyToPlayer(player)
	Remotes.ShopUpdateLimitedQty:FireClient(player, limitedPackQuantity)
end

function ShopService._syncBoostsToPlayer(player)
	local luckExpiry = PlayerService.GetValue(player, "luckBoostExpiry") or 0
	local speedExpiry = PlayerService.GetValue(player, "speedBoostExpiry") or 0
	Remotes.ShopSyncBoosts:FireClient(player, luckExpiry, speedExpiry)
end

function ShopService._syncDailyGiftState(player)
	local lastClaim = PlayerService.GetValue(player, "shopDailyGift") or 0
	local isAvailable = (os.time() - lastClaim) >= ShopConfig.DailyGift.cooldownSeconds
	local nextAvailable = lastClaim + ShopConfig.DailyGift.cooldownSeconds
	Remotes.ShopDailyGiftState:FireClient(player, isAvailable, nextAvailable)
end

function ShopService._claimDailyGift(player)
	PlayerService.WaitForLoad(player)

	local lastClaim = PlayerService.GetValue(player, "shopDailyGift") or 0
	if os.time() - lastClaim < ShopConfig.DailyGift.cooldownSeconds then
		return
	end

	EconomyService.AddCoins(player, ShopConfig.DailyGift.coinsAmount)
	EconomyService.AddRocks(player, ShopConfig.DailyGift.rocksAmount)
	PlayerService.UpdateValue(player, "shopDailyGift", function()
		return os.time()
	end)

	local isAvailable = false
	local nextAvailable = os.time() + ShopConfig.DailyGift.cooldownSeconds
	Remotes.ShopDailyGiftState:FireClient(player, isAvailable, nextAvailable)
end

function ShopService._applyBoosts(player, packType)
	local config = packType == "starterPack" and ShopConfig.StarterPack or ShopConfig.LimitedPack
	local now = os.time()

	if config.luckBoostDuration and config.luckBoostDuration > 0 then
		PlayerService.UpdateValue(player, "luckBoostExpiry", function(old)
			local current = old or 0
			if current < now then
				current = now
			end
			return current + config.luckBoostDuration
		end)
	end

	if config.speedBoostDuration and config.speedBoostDuration > 0 then
		PlayerService.UpdateValue(player, "speedBoostExpiry", function(old)
			local current = old or 0
			if current < now then
				current = now
			end
			return current + config.speedBoostDuration
		end)
	end
end

function ShopService._processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	PlayerService.WaitForLoad(player)

	local purchaseHistory = PlayerService.GetValue(player, "purchaseHistory") or {}
	if purchaseHistory[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	local product = ShopService._findProduct(productId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productType = product.type
	local granted = false

	if productType == "coins" then
		EconomyService.AddCoins(player, product.amount)
		granted = true
	elseif productType == "gamepass" then
		PlayerService.UpdateValue(player, "donateUpgrades", function(t)
			t[product.perkId] = true
			return t
		end)
		granted = true
	elseif productType == "starterPack" then
		local firstJoinTime = PlayerService.GetValue(player, "firstJoinTime") or 0
		local elapsed = os.time() - firstJoinTime
		local maxSeconds = ShopConfig.StarterPack.validityHours * 3600

		if firstJoinTime == 0 or elapsed > maxSeconds then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local alreadyClaimed = PlayerService.GetValue(player, "starterPackClaimed") or false
		if alreadyClaimed then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		EconomyService.AddCoins(player, ShopConfig.StarterPack.coinsAmount)
		EconomyService.AddRocks(player, ShopConfig.StarterPack.rocksAmount)
		PetUtils.GrantPet(player, ShopConfig.StarterPack.petType)
		ShopService._applyBoosts(player, "starterPack")
		PlayerService.UpdateValue(player, "starterPackClaimed", function()
			return true
		end)
		granted = true
	elseif productType == "limitedPack" then
		local success, newQty = pcall(function()
			return limitedPackStore:UpdateAsync(ShopConfig.LimitedPack.dataStoreKey, function(oldValue)
				local current = oldValue or ShopConfig.LimitedPack.initialQuantity
				if current <= 0 then
					return nil
				end
				return current - 1
			end)
		end)

		if not success or newQty == nil then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		EconomyService.AddCoins(player, ShopConfig.LimitedPack.coinsAmount)
		EconomyService.AddRocks(player, ShopConfig.LimitedPack.rocksAmount)
		PetUtils.GrantPet(player, ShopConfig.LimitedPack.petType)
		ShopService._applyBoosts(player, "limitedPack")
		limitedPackQuantity = newQty
		Remotes.ShopUpdateLimitedQty:FireAllClients(newQty)
		granted = true
	end

	if granted then
		purchaseHistory[receiptInfo.PurchaseId] = true
		PlayerService.UpdateValue(player, "purchaseHistory", function()
			return purchaseHistory
		end)

		task.spawn(function()
			PlayerDataServer.saveDataAsync(player)
		end)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService._findProduct(productId)
	for _, coinConfig in ipairs(ShopConfig.Coins) do
		if coinConfig.productId == productId then
			return { type = "coins", amount = coinConfig.amount }
		end
	end

	for _, passConfig in pairs(ShopConfig.GamePasses) do
		if passConfig.productId == productId then
			return { type = "gamepass", perkId = passConfig.perkId }
		end
	end

	if ShopConfig.StarterPack.productId == productId then
		return { type = "starterPack" }
	end

	if ShopConfig.LimitedPack.productId == productId then
		return { type = "limitedPack" }
	end

	return nil
end

return ShopService