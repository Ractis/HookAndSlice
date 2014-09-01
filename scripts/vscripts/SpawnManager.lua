
require( "Util_WeightTable" )
require( "Util_Difficulty" )

--------------------------------------------------------------------------------
if SpawnManager == nil then
	SpawnManager = class({})
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function SpawnManager:Initialize( kv )

	-- Read the configurations
	self._vBaseItemLevelPoolMap		= kv.BaseItemLevelPools or {}
	self._vMonsterPoolMap 			= kv.MonsterPools or {}
	self._flEnemySpawnCost			= GridNavMap:WorldUnitToCost( kv.EnemySpawnDistance )
	self._flHordeSpawnCost			= GridNavMap:WorldUnitToCost( kv.HordeSpawnDistance )
	self._nHordeGroupMin			= kv.HordeGroupMin or 2
	self._nHordeGroupMax			= kv.HordeGroupMax or 3
	self._nHordeSizeMin				= kv.HordeSizeMin or 5
	self._nHordeSizeMax				= kv.HordeSizeMax or 10
	self._nRareMonsterChance		= kv.RareMonsterChance or 0
	self._nMythicalMonsterChance	= kv.MythicalMonsterChance or 0
	self._flExpMultiplier			= kv.ExpMultiplier or 1

	self._vPrecachedUnits				= {}
	self._vUnitsToSpawnAfterPrecache	= {}
	self._vDesiredEnemiesToSpawnQueue	= {}

	self._bEnableSpawnDesiredEnemy = true

	self._posPlayerHead = nil
	self._posPlayerTail = nil

	-- Initialized by MainClass
	self.flHealthMultiplier = 1.0
	self.funcGetHeroEntities = nil

	local numMonsterPools = 0
	for k,v in pairs(self._vMonsterPoolMap) do
		numMonsterPools = numMonsterPools + 1
	end
	self:_Log( "Num MonsterPools : " .. numMonsterPools )

	-- Map tweak
	self:_MoveNeutralToDireTeam()

	-- Chests
	self._vChestEntAry = self:_FindChestEntities()
	self:_Log( "Num ChestSpawners : " .. #self._vChestEntAry )
	self:_SpawnChests( self._vChestEntAry, 0.5 )

	-- Register Commands
	Convars:RegisterCommand( "dotarpg_spawn_mobs", function ( _, numEnemies )
	 	self:SpawnRandom( numEnemies )
	end, "Spawn random enemies.", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotarpg_spawn_horde", function ( _, numEnemies )
	 	self:SpawnHorde( numEnemies )
	end, "Spawn random horde.", FCVAR_CHEAT )

	-- TEST
--	self:_DumpAllEntities()

--[[ test: WeightHorde
	self:DumpProbabilitiesFromPoolName( "monster_pool_8", false )
	self:DumpProbabilitiesFromPoolName( "monster_pool_8", true )
--]]

end

--------------------------------------------------------------------------------
function SpawnManager:SetEnableSpawnDesiredEnemies( bEnable )
	if self._bEnableSpawnDesiredEnemy == bEnable then
		return
	end

	self._bEnableSpawnDesiredEnemy = bEnable

	self:_Log( (bEnable and "Enabled" or "Disabled") .. " spawning desired enemies." )
end

--------------------------------------------------------------------------------
-- Spawn Desired Enemies
--------------------------------------------------------------------------------
function SpawnManager:UpdatePlayersPosition( vPlayerPosition )

	if not self._vDesiredEnemiesToSpawnQueue then
		-- Not initialized yet
		return 0
	end

	-- Find position of the leader
	local costHead = -999999
	local costTail = 999999
	local posHead, posTail

	for playerID, pos in pairs(vPlayerPosition) do
		local cost = GridNavMap:WorldPosToCost( pos )

		if cost > costHead then
			costHead = cost
			posHead = pos
		end
		if cost < costTail then
			costTail = cost
			posTail = pos
		end
	end

	local maxCostToSpawn = costHead + self._flEnemySpawnCost

	-- Try to spawn enemies in the spawn distance
	local queue = self._vDesiredEnemiesToSpawnQueue	-- alias
	while #queue > 0 do
		local data = queue[1]
		if data.cost > maxCostToSpawn then
			break
		end

		-- Lower than spawn distance
		if self._bEnableSpawnDesiredEnemy then
			self:_SpawnEnemyWithPrecache( data )
		end
		table.remove( queue, 1 )
	end

	-- Update members
	self._posPlayerHead = posHead
	self._posPlayerTail = posTail

	return GridNavMap:CostToWorldUnit( costHead )

end

--------------------------------------------------------------------------------
-- Generate Enemy List
--------------------------------------------------------------------------------
function SpawnManager:GenerateDesiredEnemiesToSpawn( numEnemies )

	self:_Log( "Generating Desired Enemies to Spawn .. Num : " .. numEnemies )

	for i=1, numEnemies do
		local data = self:_GenerateRandomEnemy()
		table.insert( self._vDesiredEnemiesToSpawnQueue, data )
	end

	-- Sort by Distance from start
	table.sort( self._vDesiredEnemiesToSpawnQueue, function ( a, b )
		return a.cost < b.cost
	end )

end

--------------------------------------------------------------------------------
-- SpawnRandom
--------------------------------------------------------------------------------
function SpawnManager:SpawnRandom( numEnemies )

	self:_Log( "SpawnRandom .. NumEnemies : " .. numEnemies )
	
	for i=1, numEnemies do
		local data = self:_GenerateRandomEnemy()
		self:_SpawnEnemyWithPrecache( data )
	end

end

--------------------------------------------------------------------------------
-- Add Horde
--------------------------------------------------------------------------------
function SpawnManager:SpawnHorde()

	self:_Log( "Spawning Horde .." )

	-- Calculate horde size
	local numGroups = RandomInt( self._nHordeGroupMin, self._nHordeGroupMax )
	local numEnemies = RandomInt( self._nHordeSizeMin, self._nHordeSizeMax )

	self:_Log( "  NumGroups : " .. numGroups )
	self:_Log( "  NumEnemies : " .. numEnemies )

	local groupNumEnemies = {}	-- groupIndex : numEnemies for this group
	do
		local modEnemies = numEnemies % numGroups
		local minEnemies = ( numEnemies - modEnemies ) / numGroups
		for i=1, numGroups do
			if i <= modEnemies then
				groupNumEnemies[i] = minEnemies + 1
			else
				groupNumEnemies[i] = minEnemies
			end
		end
	end

	self:_Log( "  Enemies for each group : " .. table.concat( groupNumEnemies, ", " ) )

	-- Grab goal entities
	local goalEntities

	if not self.funcGetHeroEntities then
		self:_Log( "Horde will have no goal entities." )
	else
		goalEntities = self.funcGetHeroEntities()
		self:_Log( "Num Goals for the Horde : " .. #goalEntities )
	end

	-- Find some SpawnPoint for Horde
	local cadidateBlockForHordeMap = GridNavMap:GenerateHordeProbabilityTree( self._posPlayerHead, self._posPlayerTail, self._flHordeSpawnCost, false )

	for i=1, numGroups do
		local x, y = cadidateBlockForHordeMap:ChooseRandom()

		-- test
		for j=1, groupNumEnemies[numGroups] do
			local data = self:_GenerateRandomEnemy( x, y, true )
			if goalEntities then
				-- Pick one goal from 'goalEntities'
				local selected = RandomFromWeights( goalEntities, function ( k, v )
					-- TODO: Weight by player's Health
					return 1
				end )

				data.goalEntity = goalEntities[selected]	-- Set the goal
			end
			self:_SpawnEnemyWithPrecache( data )
			-- TODO: need VALIDATE the position of the monster.
		end
	end

end

--------------------------------------------------------------------------------
function SpawnManager:_GenerateRandomEnemy( x, y, bHorde ) -- GridPos

	if x == nil or y == nil then
		-- Choose location
		x, y = GridNavMap.probabilityTree:ChooseRandom()
	end

	local spawnPosX = GridNav:GridPosToWorldCenterX( x )
	local spawnPosY = GridNav:GridPosToWorldCenterY( y )
	local spawnPos = Vector( spawnPosX, spawnPosY, 0 )

	-- Pick monster pool
	local poolName = GridNavMap:GridPosToPoolName( x, y )
	local pool = self._vMonsterPoolMap[poolName]

	if not poolName then
		self:_Log( "Valid poolName is not found" )
	elseif not pool then
		self:_Log( "MonsterPools[" .. poolName .. "] is not found" )
	end

	-- Pick monster
	local monsterName = "npc_dota_neutral_kobold"
	if pool then
		monsterName = RandomFromWeights( pool, function ( k, v )
			if type(v) ~= "table" then
				return v
			else
				if bHorde and v.WeightHorde then
					return GetValueByDifficulty( v.WeightHorde )
				end

				return GetValueByDifficulty( v.Weight )
			end
		end )
	end

	-- Out
	local data = {
		["monsterName"] = monsterName,
		["spawnPos"]	= spawnPos,
		["cost"]		= GridNavMap:WorldPosToCost( spawnPos ),	-- Distance from starting point
	}

	-- Additional data
	if pool then
		local extraData = pool[monsterName]
		if type(extraData) == "table" then
			data.intensity = extraData.Intensity or 0
		end
	end

	if self._vBaseItemLevelPoolMap[poolName] then
		data.baseItemLevel = self._vBaseItemLevelPoolMap[poolName]
	end

	return data

end

--------------------------------------------------------------------------------
function SpawnManager:_SpawnEnemyWithPrecache( data )
	local monsterName = data.monsterName

	-- Precache
	if self._vPrecachedUnits[monsterName] == nil then
		PrecacheUnitByNameAsync( monsterName, function( sg )
			if sg < 0 then print( "INVALID SG !!" ) end
			self._vPrecachedUnits[monsterName] = sg

			-- Spawn all
			if self._vUnitsToSpawnAfterPrecache[monsterName] then
				for _,v in ipairs(self._vUnitsToSpawnAfterPrecache[monsterName]) do
					-- Spawn
					self:_SpawnEnemy( v )
				end
			end

			self._vUnitsToSpawnAfterPrecache[monsterName] = nil
		end )

		self._vPrecachedUnits[monsterName] = -1
	end

	if self._vPrecachedUnits[monsterName] == -1 then
		if not self._vUnitsToSpawnAfterPrecache[monsterName] then
			self._vUnitsToSpawnAfterPrecache[monsterName] = {}
		end
		table.insert( self._vUnitsToSpawnAfterPrecache[monsterName], data )
	else
		-- Spawn
		self:_SpawnEnemy( data )
	end
end

--------------------------------------------------------------------------------
function SpawnManager:_SpawnEnemy( data )

	local unit = CreateUnitByName( data.monsterName, data.spawnPos, true, nil, nil, DOTA_TEAM_BADGUYS )
	unit:SetAngles( 0, RandomFloat( 0, 360 ), 0 )

	unit.DotaRPG_NumLootDice = 1
	unit.DotaRPG_Intensity = data.intensity
	unit.DotaRPG_ItemLevel = data.baseItemLevel or unit:GetLevel()

	-- Set goal
	if data.goalEntity then
		unit:SetInitialGoalEntity( data.goalEntity )
	end

	-- Apply tuning parameters
	unit:SetMaxHealth( unit:GetMaxHealth() * self.flHealthMultiplier )
	unit:SetDeathXP( unit:GetDeathXP() * self._flExpMultiplier )

	-- Make Monster as Rare/Mythical
	if RollPercentage( self._nRareMonsterChance ) then
		if RandomFloat( 0, 1 ) > 0.5 then
			unit:AddAbility( "dotarpg_haste" )
			local ability = unit:FindAbilityByName( "dotarpg_haste" )
			ability:SetLevel(1)
			unit:AddNewModifier( unit, nil, "modifier_phased", {} )
		else
			unit:AddAbility( "dotarpg_regen" )
			local ability = unit:FindAbilityByName( "dotarpg_regen" )
			ability:SetLevel(1)
		end
	end

end

--------------------------------------------------------------------------------
function SpawnManager:_MoveNeutralToDireTeam()

	local npcTable = Entities:FindAllByClassname( "npc_dota_creep_neutral" )

	self:_Log( #npcTable .. " neutral creeps found." )

	for _,v in pairs( npcTable ) do
		--self:_Log( v:GetUnitName() )
		v:SetTeam( DOTA_TEAM_BADGUYS )
	end

end

--------------------------------------------------------------------------------
function SpawnManager:_FindChestEntities()
	-- Collect pool entities in the map
	local chestEntAry = {}

	for _,v in pairs(Entities:FindAllByClassname( "info_target" )) do
		local entName = v:GetName()
		if string.find( entName, "chest" ) == 1 then
			table.insert( chestEntAry, v )
		end
	end

	return chestEntAry
end

--------------------------------------------------------------------------------
function SpawnManager:_SpawnChests( chestEntAry, probability )
	
	local numChestsSpawned = 0

	for _,v in pairs(chestEntAry) do
		if RandomFloat( 0, 1 ) < probability then
			local chest = CreateUnitByName( "npc_dotarpg_chest", v:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_BADGUYS )
			chest:SetAngles( 0, RandomFloat( 0, 360 ), 0 )
			chest.DotaRPG_NumLootDice = 6
			chest.IsDotaRPGChest = true

			numChestsSpawned = numChestsSpawned + 1
		end
	end

	self:_Log( numChestsSpawned .. " chests deployed in the map." )

end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function SpawnManager:_Log( text )
	print( "[SpawnManager] " .. text )
end

function SpawnManager:_DumpAllEntities()
	local ent = Entities:First()
	while ent ~= nil do
		self:_Log( ent:GetClassname() )
		ent = Entities:Next( ent )
	end
end

--------------------------------------------------------------------------------
-- TEST
--------------------------------------------------------------------------------
function SpawnManager:DumpProbabilitiesFromPoolName( poolName, bHorde, nSamples )

	nSamples = nSamples or 10000

	print( "----------------------------------------" )
	print( "Practical Probabilities" )
	print( "  poolName = " .. poolName )
	print( "  bHorde = " .. tostring(bHorde) )
	print( "  nSamples = " .. nSamples )
	print( "" )

	local counts = {}

	local pool = self._vMonsterPoolMap[poolName] or {}

	for k,v in pairs(pool) do
		counts[k] = 0
	end

	for i=1, nSamples do
		-- Pick monster
		local monsterName = RandomFromWeights( pool, function ( k, v )
			if type(v) ~= "table" then
				return v
			else
				if bHorde and v.WeightHorde then
					return GetValueByDifficulty( v.WeightHorde )
				end

				return GetValueByDifficulty( v.Weight )
			end
		end )

		if not monsterName then break end
		counts[monsterName] = counts[monsterName] + 1
	end

	for k,v in pairs(counts) do
		print( "  " .. k .. " : " .. v / nSamples * 100 .. "%" )
	end

	print( "----------------------------------------" )

end
