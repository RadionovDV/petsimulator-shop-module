local ShopConfig = {}

ShopConfig.Coins = {
	{ id = "coins_20K",    productId = 3603635799,  amount = 20000,    priceRobux = 39,  row = 1, col = 1 },
	{ id = "coins_300K",   productId = 3603639522,  amount = 300000,   priceRobux = 399, row = 1, col = 2 },
	{ id = "coins_1M",     productId = 3603639609,  amount = 1000000,  priceRobux = 799, row = 1, col = 3 },
	{ id = "coins_5M",     productId = 3603639677,  amount = 5000000,  priceRobux = 2999, row = 2, col = 1 },
	{ id = "coins_20M",    productId = 3603639777,  amount = 20000000, priceRobux = 8999, row = 2, col = 2 },
	{ id = "coins_50M",    productId = 3603639840,  amount = 50000000, priceRobux = 14999, row = 2, col = 3 },
}

ShopConfig.GamePasses = {
	extraSlot = {
		productId = 1871750595,
		perkId = "extraSlot",
		name = "Extra Slot",
		priceRobux = 149,
	},
	luckyRoll = {
		productId = 1869134548,
		perkId = "luckyRoll",
		name = "Lucky Roll",
		priceRobux = 999,
	},
	fastRoll = {
		productId = 1873162262,
		perkId = "fastRoll",
		name = "Fast Roll",
		priceRobux = 299,
	},
}

ShopConfig.StarterPack = {
	productId = 3603653259,
	coinsAmount = 30000,
	rocksAmount = 0,
	petType = "Rare_Boulder",
	luckBoostDuration = 30 * 60,
	speedBoostDuration = 15 * 60,
	validityHours = 12,
	discountPrice = 49,
	originalPrice = 99,
}

ShopConfig.LimitedPack = {
	productId = 3603653347,
	coinsAmount = 1500000,
	rocksAmount = 10000,
	petType = "Legendary_Gem",
	luckBoostDuration = 120 * 60,
	speedBoostDuration = 60 * 60,
	initialQuantity = 5000,
	price = 399,
	dataStoreName = "ShopGlobalData",
	dataStoreKey = "LimitedPackQuantity",
}

ShopConfig.DailyGift = {
	coinsAmount = 500,
	rocksAmount = 50,
	claimKey = "shopDailyGift",
	cooldownSeconds = 24 * 3600,
}

return ShopConfig