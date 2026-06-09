-- PlayerService.lua
-- Server-side entry point for player data management.
-- Starts PlayerDataServer with the default data schema, then fires PlayerReady
-- via Signal for each player whose data has finished loading.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local PlayerDataServer = require(ReplicatedStorage.PlayerData.PlayerDataServer)
local Signal = require(ReplicatedStorage.Signal)
local GameConfig = require(ReplicatedFirst.GameConfig)

local PlayerService = {}

local DEFAULT_DATA = {
	coins = 0,
	rocks = 0,
	dice = 0,
	pets = {},
	equippedPets = {},
	maxEquipSlots = 2,
	upgrades = {},
	unlockedLocations = { "Location1" },
	currentLocation = "Location1",
	rollCooldown = 2,
	luck = 1,
	autoRollUnlocked = false,
	rocksUnlocked = false,
	shopUnlocked = false,
	indexUnlocked = false,
	rebirthUnlocked = false,
	rebirthCount = 0,
	rebirthBonusLuck = 0,
	enemyCount = 1,
	enemyKills = 0,
	permanentUpgrades = {},
	dailyRewardDay = 1,
	dailyRewardClaimed = {},
	dailyRewardLastSeen = 0,
	dailyRewardNextAvailable = 0,
	microRewardLastClaim = {},
	offlineIncomeLastSeen = 0,
	offlineIncomeWarned = 0,
	questProgress = { stage = 1, parts = {0, 0, 0} },
	tutorialProgress = {},
}

if GameConfig.isCheat then
	DEFAULT_DATA.coins = 30000
	DEFAULT_DATA.rocks = 5000
	DEFAULT_DATA.dice = 5000
end

PlayerService.DEFAULT_DATA = DEFAULT_DATA

-- Fires with (player) once the player's data is fully loaded and ready
PlayerService.PlayerReady = Signal.new()

function PlayerService.Start()
	PlayerDataServer.start(DEFAULT_DATA)

	-- Handle existing players already in the server
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataServer.waitForDataLoadAsync(player)
			PlayerService.PlayerReady:Fire(player)
		end)
	end

	-- Handle players who join later
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerDataServer.waitForDataLoadAsync(player)
			PlayerService.PlayerReady:Fire(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataServer.onPlayerRemovingAsync(player)
	end)
end

function PlayerService.GetValue(player, key)
	return PlayerDataServer.getValue(player, key)
end

function PlayerService.UpdateValue(player, key, transform)
	PlayerDataServer.updateValue(player, key, transform)
end

function PlayerService.WaitForLoad(player)
	if not PlayerDataServer.hasLoaded(player) then
		PlayerDataServer.waitForDataLoadAsync(player)
	end
end

return PlayerService