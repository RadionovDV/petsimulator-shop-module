-- CombatController.lua
-- Client-side combat visual manager.
-- Pets follow player freely (no orbit) and trigger on nearby enemies.
-- Enemies move independently using EnemyConfig values (no server position sync).
-- Procedural jumping: arc-based PivotTo every 0.7s with state-dependent height/distance.
-- Attack cycle: client decides target -> FireServer -> local jumpTo(0.25s) -> jumpBack(0.25s) -> cooldown -> repeat.
-- HP bars use BillboardGui.Fillbar.Filler.Size.X.Scale + CountLabel text.
-- No position sync to server. Server trusts client attack decisions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PlayerDataClient = require(ReplicatedStorage.PlayerData.PlayerDataClient)
local PetConfig = require(ReplicatedFirst.PetConfig)
local EnemyConfig = require(ReplicatedStorage.EnemyConfig)
local CombatConfig = require(ReplicatedStorage.CombatConfig)
local AudioController = require(ReplicatedStorage.AudioController)

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local healsBarTemplate = ReplicatedStorage.UI.Objects:WaitForChild("HealsBarGui")

local PET_DETECTION_RANGE = CombatConfig.PET_DETECTION_RANGE
local PET_ATTACK_RANGE = CombatConfig.PET_ATTACK_RANGE
local PET_MIN_FIGHT_DISTANCE = CombatConfig.PET_MIN_FIGHT_DISTANCE
local PET_FOLLOW_MAX = CombatConfig.PET_FOLLOW_MAX
local PET_FOLLOW_RETURN = CombatConfig.PET_FOLLOW_RETURN
local PET_FOLLOW_RADIUS_MIN = 2
local PET_FOLLOW_RADIUS_MAX = 5
local JUMP_INTERVAL = 0.7
local JUMP_DURATION = 0.7
local ATTACK_JUMP_DURATION = 0.25
local ATTACK_JUMP_HEIGHT = 2.0

local CombatController = {}

local petModels = {}
local enemyModels = {}
local heartbeatConn = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local RAY_UP_OFFSET = 3
local RAY_DOWN_DISTANCE = 60

local function _getGroundY(worldPos, blacklist)
	raycastParams.FilterDescendantsInstances = blacklist or {}
	local origin = worldPos + Vector3.new(0, RAY_UP_OFFSET, 0)
	local ray = Workspace:Raycast(origin, Vector3.new(0, -RAY_DOWN_DISTANCE, 0), raycastParams)
	if ray then
		return ray.Position.Y + 0.5
	end
	return worldPos.Y
end

local function _getJumpHeight(state, travelDist)
	if state == "Idle" then
		return 0.4
	elseif state == "Move" then
		local ratio = math.min(travelDist / 8, 1)
		return 0.6 + ratio * 0.6
	else
		return 1.4
	end
end

local function _findNearestEnemy(pos)
	local nearestId, nearestPos, nearestDist = nil, nil, math.huge
	for enemyId, entry in enemyModels do
		local dist = (entry.position - pos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestPos = entry.position
			nearestId = enemyId
		end
	end
	return nearestId, nearestPos, nearestDist
end

local function _findNearestAlivePet(pos)
	local nearestId, nearestPos, nearestDist = nil, nil, math.huge
	for petId, entry in petModels do
		if entry.isDefeated then continue end
		local dist = (entry.position - pos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestPos = entry.position
			nearestId = petId
		end
	end
	return nearestId, nearestPos, nearestDist
end

local function _applyJump(entry, dt, blacklist)
	entry.jumpTimer = entry.jumpTimer + dt
	if entry.jumpTimer >= JUMP_INTERVAL then
		entry.jumpTimer = entry.jumpTimer - JUMP_INTERVAL
		entry.jumpProgress = 0
		entry.jumpStart = Vector3.new(entry.position.X, _getGroundY(entry.position, blacklist), entry.position.Z)

		local state = entry.state
		local jumpEnd = entry.position
		local travelDist = 0

		if state == "Idle" then
			travelDist = 0
		elseif state == "Move" then
			travelDist = (entry.targetPos - entry.position).Magnitude
			jumpEnd = entry.position + (entry.targetPos - entry.position).Unit * math.min(travelDist, 6)
		elseif state == "Fight" then
			entry.fightDir = entry.fightDir or 1
			local hopDist = 2.5
			travelDist = hopDist
			jumpEnd = entry.position + entry.fightDirection * hopDist * entry.fightDir
			entry.fightDir = -entry.fightDir
		end

		entry.jumpEnd = Vector3.new(jumpEnd.X, _getGroundY(jumpEnd, blacklist), jumpEnd.Z)
		entry.jumpHeight = _getJumpHeight(state, travelDist)
	end

	if entry.jumpProgress < 1 then
		local speed = 1 / JUMP_DURATION
		entry.jumpProgress = math.min(entry.jumpProgress + dt * speed, 1)
		local t = entry.jumpProgress
		local pos = entry.jumpStart:Lerp(entry.jumpEnd, t)
		local yOffset = math.sin(t * math.pi) * entry.jumpHeight
		entry.position = Vector3.new(pos.X, pos.Y + yOffset, pos.Z)
	end
end

local function _randomPetOffset()
	local angle = math.random() * math.pi * 2
	local radius = PET_FOLLOW_RADIUS_MIN + math.random() * (PET_FOLLOW_RADIUS_MAX - PET_FOLLOW_RADIUS_MIN)
	return Vector3.new(
		math.cos(angle) * radius,
		math.random() * 2 - 1,
		math.sin(angle) * radius
	)
end

local function _processAttackPhase(entry, dt, blacklist)
	if not entry.attackPhase then return false end

	entry.jumpProgress = math.min(entry.jumpProgress + dt / ATTACK_JUMP_DURATION, 1)
	local t = entry.jumpProgress
	local pos = entry.jumpStart:Lerp(entry.jumpEnd, t)
	local yOffset = math.sin(t * math.pi) * ATTACK_JUMP_HEIGHT
	entry.position = Vector3.new(pos.X, entry.jumpStart.Y + yOffset, pos.Z)

	if entry.jumpProgress >= 1 then
		if entry.attackPhase == "jumpTo" then
			entry.attackPhase = "jumpBack"
			entry.jumpStart = Vector3.new(entry.position.X, _getGroundY(entry.position, blacklist), entry.position.Z)
			entry.jumpEnd = Vector3.new(entry.attackReturnPos.X, _getGroundY(entry.attackReturnPos, blacklist), entry.attackReturnPos.Z)
			entry.jumpProgress = 0
		elseif entry.attackPhase == "jumpBack" then
			entry.attackPhase = nil
			entry.jumpProgress = 1
		end
	end
	return true
end

local function _findAnimator(model)
	local animCtrl = model:FindFirstChildOfClass("AnimationController")
	if not animCtrl then return nil end
	return animCtrl:FindFirstChildOfClass("Animator")
end

function CombatController.SpawnPet(petType, petId)
	local modelTemplate = ReplicatedStorage:FindFirstChild("PetModels")
		and ReplicatedStorage.PetModels:FindFirstChild(petType)
	if not modelTemplate then
		return
	end

	local model = modelTemplate:Clone()
	model.Parent = Workspace

	local billboard = healsBarTemplate:Clone()
	billboard.Adornee = model.BillboardAttachment
	billboard.Parent = model
	local filler = billboard:FindFirstChild("Fillbar") and billboard.Fillbar:FindFirstChild("Filler")
	local countLabel = billboard:FindFirstChild("CountLabel")
	local animator = _findAnimator(model)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local spawnPos = rootPart and rootPart.Position or Vector3.new()

	local offset = _randomPetOffset()
	local initialPos = spawnPos + offset
	initialPos = Vector3.new(initialPos.X, _getGroundY(initialPos, character and {character} or {}), initialPos.Z)

	local petConfig = PetConfig.Map and PetConfig.Map[petType]
	local attackRate = petConfig and petConfig.attackRate or 1.0

	petModels[petId] = {
		model = model,
		animator = animator,
		state = "Idle",
		filler = filler,
		countLabel = countLabel,
		isDefeated = false,
		attackPhase = nil,
		attackReturnPos = Vector3.new(),
		hp = 0,
		maxHp = 0,
		position = initialPos,
		targetPos = initialPos,
		followOffset = offset,
		jumpTimer = 0,
		jumpProgress = 1,
		jumpStart = initialPos,
		jumpEnd = initialPos,
		jumpHeight = 0,
		fightDir = 1,
		attackRate = attackRate,
		attackCooldown = 0,
		petType = petType,
	}

	model:PivotTo(CFrame.new(initialPos))

	if not heartbeatConn then
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			CombatController._updateCombat(dt)
		end)
	end
end

function CombatController.RemovePet(petId)
	local entry = petModels[petId]
	if entry then
		entry.model:Destroy()
		petModels[petId] = nil
	end

	local petCount = 0
	for _ in petModels do petCount = petCount + 1 end
	local enemyCount = 0
	for _ in enemyModels do enemyCount = enemyCount + 1 end

	if petCount == 0 and enemyCount == 0 and heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

function CombatController.SyncEquippedPets()
	if not PlayerDataClient.hasLoaded() then
		return
	end

	local equipped = PlayerDataClient.get("equippedPets") or {}
	local allPets = PlayerDataClient.get("pets") or {}

	local newSet = {}
	for _, petId in equipped do
		newSet[petId] = true
	end

	for petId in petModels do
		if not newSet[petId] then
			CombatController.RemovePet(petId)
		end
	end

	for _, petId in equipped do
		if not petModels[petId] and allPets[petId] then
			CombatController.SpawnPet(allPets[petId].petType, petId)
		end
	end
end

function CombatController._updateCombat(dt)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local playerPos = rootPart.Position
	local blacklist = {character}

	for _, entry in petModels do
		if entry.model then
			table.insert(blacklist, entry.model)
		end
	end

	for _, entry in enemyModels do
		if entry.model then
			table.insert(blacklist, entry.model)
		end
	end

	-- Update pets
	for petId, entry in petModels do
		-- Cooldown tick
		entry.attackCooldown = math.max(0, entry.attackCooldown - dt)

		if entry.isDefeated then
			entry.jumpProgress = 1
			continue
		end

		if _processAttackPhase(entry, dt, blacklist) then
			local flatLook = Vector3.new(entry.jumpEnd.X - entry.position.X, 0, entry.jumpEnd.Z - entry.position.Z)
			if flatLook.Magnitude > 0.01 then
				entry.model:PivotTo(CFrame.lookAt(entry.position, entry.position + flatLook.Unit))
			end
			continue
		end

		local distToPlayer = (entry.position - playerPos).Magnitude
		local nearestEnemyId, nearestEnemyPos, distToEnemy = _findNearestEnemy(entry.position)

		if distToPlayer > PET_FOLLOW_MAX then
			entry.state = "Move"
			entry.targetPos = playerPos + entry.followOffset
		elseif nearestEnemyPos and distToEnemy < PET_DETECTION_RANGE then
			if distToEnemy <= PET_ATTACK_RANGE then
				entry.state = "Fight"
				local toEnemy = (nearestEnemyPos - entry.position).Unit
				local perpDir = Vector3.new(-toEnemy.Z, 0, toEnemy.X).Unit
				local side = ((petId:byte(1) or 0) % 2 == 0) and 1 or -1
				entry.fightDirection = (toEnemy + perpDir * side * 0.5).Unit
				entry.targetPos = nearestEnemyPos - entry.fightDirection * PET_MIN_FIGHT_DISTANCE

				-- Client-driven attack: fire server and start animation
				if entry.attackPhase == nil and entry.attackCooldown <= 0 and nearestEnemyId then
					AudioController.Play("Combat.Hit2")
					Remotes.PetAttack:FireServer({
						petId = petId,
						enemyId = nearestEnemyId,
						enemyPosition = { X = nearestEnemyPos.X, Y = nearestEnemyPos.Y, Z = nearestEnemyPos.Z },
					})
					entry.attackPhase = "jumpTo"
					entry.attackReturnPos = entry.position
					entry.jumpStart = entry.position
					entry.jumpEnd = nearestEnemyPos
					entry.jumpProgress = 0
					entry.attackCooldown = entry.attackRate
				end
			else
				entry.state = "Move"
				entry.targetPos = nearestEnemyPos
			end
		else
			local idealPos = playerPos + entry.followOffset
			local distToIdeal = (entry.position - idealPos).Magnitude
			if distToIdeal > 2 then
				entry.state = "Move"
				entry.targetPos = idealPos
			else
				entry.state = "Idle"
			end
		end

		_applyJump(entry, dt, blacklist)

		local lookDir = (entry.targetPos - entry.position).Magnitude > 0.1
			and (entry.targetPos - entry.position).Unit
			or (playerPos - entry.position).Unit
		if lookDir.Magnitude > 0 then
			local flatDir = Vector3.new(lookDir.X, 0, lookDir.Z)
			if flatDir.Magnitude > 0.01 then
				entry.model:PivotTo(CFrame.lookAt(entry.position, entry.position + flatDir.Unit))
			end
		end
	end

	-- Update enemies
	for enemyId, entry in enemyModels do
		-- Cooldown tick
		entry.attackCooldown = math.max(0, entry.attackCooldown - dt)

		if _processAttackPhase(entry, dt, blacklist) then
			entry.model:PivotTo(CFrame.lookAt(entry.position, entry.targetPos or playerPos))
			continue
		end

		local nearestPetId, nearestPetPos = _findNearestAlivePet(entry.position)
		local targetFollowPos = nearestPetPos or playerPos

		local distToTarget = (entry.position - targetFollowPos).Magnitude

		if distToTarget > entry.attackRange then
			entry.state = "Move"
			local direction = (targetFollowPos - entry.position).Unit
			local jumpDistance = math.min(entry.movementSpeed * 0.7, distToTarget - entry.attackRange + 1)
			entry.targetPos = entry.position + direction * jumpDistance
			entry.fightDirection = direction
		else
			entry.state = "Fight"
			entry.fightDirection = (entry.position - targetFollowPos).Unit
			local idealDist = math.max(entry.attackRange * 0.8, PET_MIN_FIGHT_DISTANCE)
			local targetPos = targetFollowPos + entry.fightDirection * idealDist
			entry.targetPos = targetPos

			-- Client-driven enemy attack: fire server and start animation
			if entry.attackPhase == nil and entry.attackCooldown <= 0 and nearestPetId then
				AudioController.Play("Combat.Hit2")
				Remotes.EnemyAttack:FireServer({ enemyId = enemyId, petId = nearestPetId })
				entry.attackPhase = "jumpTo"
				entry.attackReturnPos = entry.position
				entry.jumpStart = entry.position
				entry.jumpEnd = nearestPetPos
				entry.jumpProgress = 0
				entry.attackCooldown = entry.attackRate
			end
		end

		_applyJump(entry, dt, blacklist)

		if entry.position then
			entry.model:PivotTo(CFrame.lookAt(entry.position, targetFollowPos))
		end
	end
end

function CombatController.SyncCombatState(data)
	if not data then return end

	if data.clearAll then
		for _, entry in enemyModels do
			entry.model:Destroy()
		end
		enemyModels = {}

		local petCount = 0
		for _ in petModels do petCount = petCount + 1 end
		if petCount == 0 and heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		return
	end

	if data.newSpawns then
		for enemyId, spawnData in data.newSpawns do
			if enemyModels[enemyId] then continue end

			local template = ReplicatedStorage:FindFirstChild("EnemyModels")
				and ReplicatedStorage.EnemyModels:FindFirstChild(spawnData.type)
			if template then
				local model = template:Clone()
				model.Parent = Workspace

				local spawnPos = Vector3.new(
					spawnData.spawnPosition.X,
					spawnData.spawnPosition.Y,
					spawnData.spawnPosition.Z
				)
				local blacklist = player.Character and {player.Character} or {}
				spawnPos = Vector3.new(spawnPos.X, _getGroundY(spawnPos, blacklist), spawnPos.Z)
				model:PivotTo(CFrame.new(spawnPos))

				local billboard = healsBarTemplate:Clone()
				billboard.Adornee = model.BillboardAttachment
				billboard.Parent = model
				local filler = billboard:FindFirstChild("Fillbar") and billboard.Fillbar:FindFirstChild("Filler")
				local countLabel = billboard:FindFirstChild("CountLabel")
				local animator = _findAnimator(model)
				local config = EnemyConfig.Map[spawnData.type]

				if not heartbeatConn then
					heartbeatConn = RunService.Heartbeat:Connect(function(dt)
						CombatController._updateCombat(dt)
					end)
				end

				enemyModels[enemyId] = {
					model = model,
					animator = animator,
					state = "Move",
					filler = filler,
					countLabel = countLabel,
					attackPhase = nil,
					attackReturnPos = Vector3.new(),
					hp = 0,
					maxHp = 0,
					position = spawnPos,
					targetPos = spawnPos,
					jumpTimer = math.random() * 0.5,
					jumpProgress = 1,
					jumpStart = spawnPos,
					jumpEnd = spawnPos,
					jumpHeight = 0,
					fightDir = 1,
					fightDirection = Vector3.new(),
					enemyType = spawnData.type,
					attackRange = config and config.attackRange or 15,
					movementSpeed = config and config.movementSpeed or 8,
					attackRate = config and config.attackRate or 1,
					attackCooldown = 0,
				}
			end
		end
	end

	if data.enemies then
		for enemyId, eData in data.enemies do
			if not eData.isAlive then
				local entry = enemyModels[enemyId]
				if entry then
					entry.model:Destroy()
					enemyModels[enemyId] = nil
				end
			else
				local entry = enemyModels[enemyId]
				if entry then
					entry.hp = eData.hp
					entry.maxHp = eData.maxHp
					if entry.filler and entry.maxHp > 0 then
						entry.filler.Size = UDim2.new(entry.hp / entry.maxHp, 0, 1, 0)
					end
					if entry.countLabel then
						entry.countLabel.Text = string.format("%d/%d", entry.hp, entry.maxHp)
					end
				end
			end
		end
	end

	if data.pets then
		for petId, pData in data.pets do
			local entry = petModels[petId]
			if entry then
				entry.hp = pData.hp
				entry.maxHp = pData.maxHp
				if entry.filler and entry.maxHp > 0 then
					entry.filler.Size = UDim2.new(entry.hp / entry.maxHp, 0, 1, 0)
				end
				if entry.countLabel then
					entry.countLabel.Text = string.format("%d/%d", entry.hp, entry.maxHp)
				end
			end
		end
	end
end

function CombatController.OnPetDefeated(petId)
	local entry = petModels[petId]
	if entry then
		entry.isDefeated = true
		entry.attackPhase = nil
		entry.jumpProgress = 1
		for _, part in entry.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0.7
			end
		end
		if entry.filler then
			entry.filler.Size = UDim2.new(0, 0, 1, 0)
		end
		if entry.countLabel then
			entry.countLabel.Text = string.format("%d/%d", 0, entry.maxHp)
		end
	end
end

function CombatController.OnPetRevived(petId)
	local entry = petModels[petId]
	if entry then
		entry.isDefeated = false
		entry.attackPhase = nil
		entry.attackCooldown = 0
		for _, part in entry.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
		if entry.filler then
			entry.filler.Size = UDim2.new(1, 0, 1, 0)
		end
		if entry.countLabel then
			entry.countLabel.Text = string.format("%d/%d", entry.maxHp, entry.maxHp)
		end
	end
end

function CombatController.OnEnemyDefeated(enemyId)
	local entry = enemyModels[enemyId]
	if entry then
		entry.model:Destroy()
		enemyModels[enemyId] = nil
	end
end

function CombatController.GetNearestEnemyPosition(fromPos)
	local nearestPos, nearestDist = nil, math.huge
	for _, entry in enemyModels do
		local dist = (entry.position - fromPos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestPos = entry.position
		end
	end
	return nearestPos
end

player.CharacterAdded:Connect(function()
	for _, entry in petModels do
		entry.model:Destroy()
	end
	for _, entry in enemyModels do
		entry.model:Destroy()
	end
	local toRemove = {}
	for petId in petModels do toRemove[#toRemove + 1] = petId end
	for _, petId in toRemove do
		petModels[petId] = nil
	end
	enemyModels = {}
	CombatController.SyncEquippedPets()
end)

return CombatController