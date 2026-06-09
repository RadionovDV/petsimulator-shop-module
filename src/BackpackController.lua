-- BackpackController.lua
-- Client-side backpack viewer. Uses ItemTile component to render pets.
-- Unequipped pets appear in ScrollingFrame, equipped pets appear in EquippedBoard.Tiles.
-- Clicking a tile equips (moves to EquippedBoard) or unequips (moves to ScrollingFrame).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local ItemTile = require(ReplicatedStorage.UI.Components.ItemTile)
local AudioController = require(ReplicatedStorage.AudioController)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local menuGui = playerGui:WaitForChild("MenuGui")
local backpackFrame = menuGui:WaitForChild("Backpack")
local body = backpackFrame:WaitForChild("Body")
local scrollingFrame = body:WaitForChild("ScrollingFrame")
local equippedBoard = body:WaitForChild("EquippedBoard")
local equippedTiles = equippedBoard:WaitForChild("Tiles")

local rarityOrder = {
	Divine = 1,
	Legendary = 2,
	Epic = 3,
	Rare = 4,
	Uncommon = 5,
	Common = 6,
}

local BackpackController = {}

-- Clears old tiles and re-renders all pets into their correct container.
-- Unequipped pets → ScrollingFrame, equipped pets → EquippedBoard.Tiles.
-- The ItemTile.Create factory already wires Activated to EquipPet/UnequipPet.
function BackpackController.Refresh()
	if not PlayerDataClient.hasLoaded() then
		return
	end

	local pets = PlayerDataClient.get("pets") or {}
	local equipped = PlayerDataClient.get("equippedPets") or {}
	local equippedSet = {}

	for _, pid in equipped do
		equippedSet[pid] = true
	end

	-- Clear both containers
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end
	for _, child in equippedTiles:GetChildren() do
		if child:IsA("ImageButton") then
			child:Destroy()
		end
	end

	-- Sort pets by rarity (rarest first)
	local sortedPetIds = {}
	for petId in pets do
		table.insert(sortedPetIds, petId)
	end
	table.sort(sortedPetIds, function(a, b)
		local ra = rarityOrder[pets[a].rarity] or 99
		local rb = rarityOrder[pets[b].rarity] or 99
		if ra == rb then
			return a < b
		end
		return ra < rb
	end)

	-- Render each pet into the correct container
	for _, petId in sortedPetIds do
		local isEquipped = equippedSet[petId]
		local tile = ItemTile.Create(petId, pets[petId], isEquipped)
		tile.Parent = if isEquipped then equippedTiles else scrollingFrame
	end
end

return BackpackController