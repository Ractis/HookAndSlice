--[[
Dota RPG game mode
]]

require( "Util_Serialize" )
require( "ItemManager" )
require( "GridNavMap" )
require( "SpawnManager" )
require( "SpawnDirector" )
require( "Util_Quest" )
require( "MissionManager_RescueHostage" )

print( "Dota RPG game mode loaded." )

DEBUG = false

if DotaRPG == nil then
	DotaRPG = class({})
end

--------------------------------------------------------------------------------
-- PRECACHE
--------------------------------------------------------------------------------
function Precache( context )
	PrecacheResource( "particle", "particles/loots/loot_rare_starfall.vpcf", context )
	PrecacheItemByNameSync( "item_tombstone", context )
end

--------------------------------------------------------------------------------
-- ACTIVATE
--------------------------------------------------------------------------------
function Activate()
    GameRules.DotaRPG = DotaRPG()
    GameRules.DotaRPG:InitGameMode()
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function DotaRPG:InitGameMode()

	self:_ReadGameCongiguration()

	-- Initialize class members
	self._vPlayerInstanceMap = {}
	self._vPlayerLastValidPosition = {}		-- playerID : ValidPosition
	self.playerDataMap = {}

	-- Map Progress
	if not self._vGameConfiguration.NoLevelFlow then
		self._entMapProgress = CreateQuest( "MapProgress" )
		self._entMapProgressBar = CreateSubquestOf( self._entMapProgress )
		Subquest_UpdateValue( self._entMapProgressBar, 0, 1 )
	end

	-- Update game rules
	GameRules:SetSafeToLeave( true )
	GameRules:SetHeroSelectionTime( 30 )
	GameRules:SetPreGameTime( 10 )
	GameRules:SetHeroRespawnEnabled( false )
	GameRules:SetGoldTickTime( 60 )
	GameRules:SetGoldPerTick( 0 )
	GameRules:SetSameHeroSelectionEnabled( false )
	GameRules:SetTreeRegrowTime( 0 )

	local GameMode = GameRules:GetGameModeEntity()
	GameMode:SetRecommendedItemsDisabled( true )
	GameMode:SetTopBarTeamValuesVisible( false )
	GameMode:SetBuybackEnabled( false )

	print( "Difficulty = " .. GameRules:GetDifficulty() )
	print( "Custom Difficulty = " .. GameRules:GetCustomGameDifficulty() )
--	GameRules:SetCustomGameDifficulty( GameRules:GetDifficulty() )

	-- Register Game Events
	ListenToGameEvent( 'player_connect_full',			Dynamic_Wrap(DotaRPG, "OnPlayerConnectFull"),		self )
	ListenToGameEvent( 'entity_killed',					Dynamic_Wrap(DotaRPG, "OnEntityKilled"),			self )
	ListenToGameEvent( 'npc_spawned',					Dynamic_Wrap(DotaRPG, "OnNPCSpawn"),				self )
	ListenToGameEvent( 'game_rules_state_change',		Dynamic_Wrap(DotaRPG, "OnGameRulesStateChange"),	self )
--	ListenToGameEvent( 'dota_holdout_revive_complete',	Dynamic_Wrap(DotaRPG, "OnReviveComplete"),	self )

	-- Register Commands
	Convars:RegisterCommand( "dotarpg_select_hero", function ( _, heroName )
		self:SelectHero( Convars:GetCommandClient(), heroName )
	end, "Select your hero", 0 )

	Convars:RegisterCommand( "dotarpg_victory", function ( _ )
		-- force end the game
		GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
	end, "", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotarpg_revive_all", function ( _ )
		self:_RefreshPlayers()
	end, "", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotarpg_kill_player", function ( _, playerID )
		PlayerResource:GetSelectedHeroEntity( tonumber(playerID) ):ForceKill( true )
	end, "", FCVAR_CHEAT )

end

--------------------------------------------------------------------------------
function DotaRPG:_ReadGameCongiguration()
	print( "Loading game configurations..." )

	-- Load KV
	local kvDefault = LoadKeyValues( "scripts/maps/_Default.txt" )
	if not kvDefault then
		print( "  Not found : scripts/maps/_Default.txt" )
		kvDefault = {}
	end

	local kvMapSpecific = LoadKeyValues( "scripts/maps/" .. GetMapName() .. ".txt" )
	if not kvMapSpecific then
		print( "  Not found : scripts/maps/" .. GetMapName() .. ".txt" )
		kvMapSpecific = {}
	end

	-- Compose
	local kv = kvDefault
	for k,v in pairs( kvMapSpecific ) do
		kv[k] = v
	end

	-- Apply configurations
	self._fDefaultCooldownReduction		= tonumber( kv.DefaultCooldownReduction or 0 ) / 100
	self._fDefaultAdditionalHPRegen		= tonumber( kv.DefaultAdditionalHPRegen or 0 )
	self._fDefaultAdditionalManaRegen	= tonumber( kv.DefaultAdditionalManaRegen or 0 )

	self._vGameConfiguration	= kv
end

--------------------------------------------------------------------------------
-- Apply Cooldown Reduction
--------------------------------------------------------------------------------
function DotaRPG:_ApplyCooldownReduction()

	----------------------------------------
	-- Apply cooldown reduction
	local reduction = self._fDefaultCooldownReduction

	for _,v in pairs(self._vPlayerInstanceMap) do
		local hero = v:GetAssignedHero()
		if hero then

		--	print( hero:GetUnitName() .. " has " .. hero:GetAbilityCount() .. " abilities." )

			for i=0, hero:GetAbilityCount()-1 do

				local ability = hero:GetAbilityByIndex(i)

				if ability then
				--	print( "  Ability[" .. i .. "] : " .. ability:GetAbilityName() )

					if ability:GetCooldownTimeRemaining() > 0 then
					--	local cdDefault = ability:GetCooldownTime()		-- ??
						local cdDefault = ability:GetCooldown( ability:GetLevel() - 1 )
						local cdReduced = cdDefault * ( 1.0 - reduction )
						local cdRemaining = ability:GetCooldownTimeRemaining()

						if cdRemaining > cdReduced then
							cdRemaining = cdRemaining - cdDefault * reduction

							ability:EndCooldown()
							ability:StartCooldown( cdRemaining )
						--[[
							print( "APPLY COOLDOWN REDUCTION : " )
							print( "  New Remaining : " .. cdRemaining )
							print( "  Reduced CD : " .. cdReduced )
							print( "  Default CD : " .. cdDefault )
							print( "  Ability Level : " .. ability:GetLevel() )
						--]]
						end
					end
				end
			end
		end
	end

	return 0.25
end

--------------------------------------------------------------------------------
-- Validate Player Movement
--------------------------------------------------------------------------------
function DotaRPG:_ValidatePlayerMovement()
	self:_ForEachPlayer( function ( playerID, hero )

		if not hero then return end

		if not self._vPlayerLastValidPosition[playerID] then
			-- Init
			self._vPlayerLastValidPosition[playerID] = hero:GetAbsOrigin()
			return
		end

		-- Moving through occupied blocks?
		local worldPos = hero:GetAbsOrigin()
		local gridIndex = GridNavMap:WorldPosToIndex( worldPos )
		local isBlocked = GridNavMap.vBlocked[gridIndex]
		if isBlocked then
			-- Wait
			return
		end

		-- Calculate cost
		local lastCost = GridNavMap:WorldPosToCost( self._vPlayerLastValidPosition[playerID] )
		local currentCost = GridNavMap:WorldPosToCost( worldPos )

		-- Validate
		local isValid = true
		local reason = ""
		if currentCost == nil then
			-- Not floodfilled block
			isValid = false
			reason = "Landed on block not floodfilled"
		else 
			local costDifference = math.abs( currentCost - lastCost )
			local blinkDistanceTolerance = 2000
			local blinkCostTolerance = GridNavMap:WorldUnitToCost( 2000 )
			if costDifference > blinkCostTolerance then
				-- Do not Shortcut!
				isValid = false
				reason = "Did shortcut"
			end

			-- Partition
			local lastPartition = GridNavMap:WorldPosToPartitionID( self._vPlayerLastValidPosition[playerID] )
			local currentPartition = GridNavMap:WorldPosToPartitionID( worldPos )

			if lastPartition ~= currentPartition then
				-- Check Graph
				local edgeName
				if lastPartition < currentPartition then
					edgeName = string.format( "%d:%d", lastPartition, currentPartition )
				else
					edgeName = string.format( "%d:%d", currentPartition, lastPartition )
				end

				local obstructionEnt = GridNavMap.vPartitionGraph[edgeName]
				if obstructionEnt:IsEnabled() then
					-- Not traversable between last partition and current partition
					isValid = false
					reason = "Door is not opened yet"
				end
			end
		end

		-- Update
		if not isValid then
			-- Move back
			FindClearSpaceForUnit( hero, self._vPlayerLastValidPosition[playerID], true )
			print( "PlayerID=" .. playerID .. " has been moved back : " .. reason )
		else
			self._vPlayerLastValidPosition[playerID] = worldPos
		end

	end )

	-- Spawn enemies in the range
	local currentPartyDist = SpawnManager:UpdatePlayersPosition( self._vPlayerLastValidPosition )

	-- Notify to the Mission Manager
	if type(self._vGameConfiguration.RescueHostage) == "table" then
		MissionManager_RescueHostage:UpdatePlayersPosition( self._vPlayerLastValidPosition )
	end

	-- Update progress bar
	if not self._vGameConfiguration.NoLevelFlow then
		local mapDist = GridNavMap.flMapDistance or 1
		Quest_UpdateValue( self._entMapProgress, math.floor( currentPartyDist ), math.floor( mapDist ) )
		Subquest_UpdateValue( self._entMapProgressBar, currentPartyDist, mapDist )
	end
	
	return 0.25
end

--------------------------------------------------------------------------------
function DotaRPG:SelectHero( player, heroName )
	-- Grab playerID
	local playerID = player:GetPlayerID()

	-- Change hero
	if heroName == nil then return end

	print( "Replacing hero for player " .. playerID )
	local hero = PlayerResource:ReplaceHeroWith( playerID, heroName, 0, 0 )
	if hero == nil then return end

	-- Save player data
	self.playerDataMap[playerID].HeroName = heroName
	self:SavePlayerData( playerID )
end

--------------------------------------------------------------------------------
function DotaRPG:SavePlayerData( playerID )
	local steamID = PlayerResource:GetSteamAccountID( playerID )
	local filename = "player_" .. steamID
	KeyValuesToFile( self.playerDataMap[playerID], filename )
end

--------------------------------------------------------------------------------
function DotaRPG:OnPlayerConnectFull( event )

	-- Grab the entity index of this player
	local entIndex = event.index + 1
	local player = PlayerInstanceFromIndex( entIndex )

	table.insert( self._vPlayerInstanceMap, player )

if DEBUG then
	player:SetTeam( DOTA_TEAM_GOODGUYS )	-- Join to team
end--[[
	local playerID = player:GetPlayerID()	-- -1 when the player isn't yet on a team.

	local steamID = PlayerResource:GetSteamAccountID( playerID )

	-- Prepare the inventory
	ItemManager:CreateInventory( playerID )

	-- Load player data
	local filename = "player_" .. steamID
	local playerData = FileToKeyValues( filename )
	self.playerDataMap[playerID] = playerData or {}

	local hero
	if playerData ~= nil then
		-- Create hero for the player
--		print( "Creating hero for " .. steamID )
--		hero = CreateHeroForPlayer( playerData.HeroName, player )
	else
--		print( "Creating default hero for " .. steamID )
--		hero = CreateHeroForPlayer( "npc_dota_hero_wisp", player )
	end
--]]
	-- Test
--[[local modifierData = {
		bonus_movement = 100,
		bonus_mana = 1000,
		replenish_radius = 200,
		replenish_amount = 200,
	}
	hero:AddNewModifier( hero, nil, "modifier_item_dotarpg_weapon", modifierData )
--]]
end

--------------------------------------------------------------------------------
function DotaRPG:OnEntityKilled( event )
	
	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if not killedUnit then
		return
	end

	if killedUnit:IsRealHero() then
		local newItem = CreateItem( "item_tombstone", killedUnit, killedUnit )
		newItem:SetPurchaseTime( 0 )
		newItem:SetPurchaser( killedUnit )
		local tombstone = SpawnEntityFromTableSynchronous( "dota_item_tombstone_drop", {} )
		tombstone:SetContainedItem( newItem )
		tombstone:SetAngles( 0, RandomFloat( 0, 360 ), 0 )
		FindClearSpaceForUnit( tombstone, killedUnit:GetAbsOrigin(), true )
		return
	end

	-- Deploy loot
	if killedUnit.DotaRPG_NumLootDice then
		local itemLevel = killedUnit.DotaRPG_ItemLevel
		if killedUnit.IsDotaRPGChest then
			itemLevel = 3
		end
		--print( "ItemLevel = " .. itemLevel )

		for i=1, killedUnit.DotaRPG_NumLootDice do
			ItemManager:CreateLoot( killedUnit:GetAbsOrigin(), itemLevel )
		end
	end

end

--------------------------------------------------------------------------------
function DotaRPG:OnNPCSpawn( event )
	local unitSpawned = EntIndexToHScript( event.entindex )

	if unitSpawned:IsHero() then
		local playerID = unitSpawned:GetPlayerID()

		if PlayerResource:IsValidPlayerID( playerID ) then

			if not unitSpawned:HasItemInInventory( "item_dotarpg_inventory" ) then
				-- Add special items
				local itemInventory = CreateItem( "item_dotarpg_inventory", nil, nil )
				unitSpawned:AddItem( itemInventory )

				print( "Added InventoryToggleItem to " .. unitSpawned:GetClassname() )

				-- Modify base HP/Mana regen
				local baseHPRegen = unitSpawned:GetHealthRegen()
				local modifiedHPRegen = baseHPRegen + self._fDefaultAdditionalHPRegen
				unitSpawned:SetBaseHealthRegen( modifiedHPRegen )
				local baseManaRegen = unitSpawned:GetManaRegen()
				local modifiedManaRegen = baseManaRegen + self._fDefaultAdditionalManaRegen
				unitSpawned:SetBaseManaRegen( modifiedManaRegen )

				print( "Changed Base HPRegen : " .. modifiedHPRegen .. " from " .. baseHPRegen )
				print( "Changed Base ManaRegen : " .. modifiedManaRegen .. " from " .. baseManaRegen )

				-- TEST
				local item = CreateItem( "item_dotarpg_modifiers_damage", nil, nil )
			--	item:ApplyDataDrivenModifier( unitSpawned, unitSpawned, "dotarpg_damage_32768", {} )
				--unitSpawned:RemoveModifierByName( "dotarpg_damage_8" )
			end

		end
	end
end

--------------------------------------------------------------------------------
-- When game state changes set state in script
function DotaRPG:OnGameRulesStateChange()
	local statesMap = {
		[DOTA_GAMERULES_STATE_DISCONNECT]		= "Disconnect",
		[DOTA_GAMERULES_STATE_GAME_IN_PROGRESS]	= "GameInProgress",
		[DOTA_GAMERULES_STATE_HERO_SELECTION]	= "HeroSelection",
		[DOTA_GAMERULES_STATE_INIT]				= "Init",
		[DOTA_GAMERULES_STATE_LAST]				= "Last",
		[DOTA_GAMERULES_STATE_POST_GAME]		= "PostGame",
		[DOTA_GAMERULES_STATE_PRE_GAME]			= "PreGame",
		[DOTA_GAMERULES_STATE_STRATEGY_TIME]	= "StrategyTime",
		[DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD]	= "WaitForPlayersToLoad",
	}

	local nNewState = GameRules:State_Get()
	print( "Entering Game State to [" .. nNewState .. "] " .. statesMap[nNewState] )

	if nNewState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		self._nPlayers = self:_NumPlayers()

		-- Initialize modules
		ItemManager:Initialize()
		GridNavMap:Initialize( self._vGameConfiguration )
		SpawnManager:Initialize( self._vGameConfiguration )
		SpawnDirector:Initialize( self._vGameConfiguration )

		SpawnManager.funcGetHeroEntities = function ()
			local heroes = {}
			self:_ForEachPlayer( function ( playerID, hero )
				if hero then
					table.insert( heroes, hero )
				end
			end )
			return heroes
		end

		for _,v in pairs(self._vPlayerInstanceMap) do
			local playerID = v:GetPlayerID()
			if playerID >= 0 then
				ItemManager:CreateInventory( playerID )
			end
		end

		-- RescueHostage gamemode
		if type(self._vGameConfiguration.RescueHostage) == "table" then
			MissionManager_RescueHostage:Initialize()
			MissionManager_RescueHostage:RegisterHostages( SpawnManager.vHostages )
		end

		-- Register Thinker
		local GameMode = GameRules:GetGameModeEntity()
		
		GameMode:SetContextThink( "DotaRPG:ApplyCooldownReduction", function ()
			return self:_ApplyCooldownReduction()
		end, 0.25 )
		GameMode:SetContextThink( "DotaRPG:ValidatePlayerMovement", function ()
			return self:_ValidatePlayerMovement()
		end, 0.25 )

		-- Test
		SpawnManager.flHealthMultiplier = 0.25 + 0.15 * self._nPlayers	-- 0.4, 0.65, 0.8, 0.95, 1.1
		local numEnemiesDesired = 70 + 40 * self._nPlayers -- 120, 160, 200, 240, 280
	--	SpawnManager:SpawnRandom( numEnemiesDesired )	
		SpawnManager:GenerateDesiredEnemiesToSpawn( numEnemiesDesired )

		if DEBUG then
			for i=1, 25 do
				ItemManager:CreateLoot( Vector(109, 157, 256+1) )
			end
		end
	end
end

--------------------------------------------------------------------------------
function DotaRPG:_RefreshPlayers()
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( nPlayerID ) == DOTA_TEAM_GOODGUYS then
			if PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if not hero:IsAlive() then
					hero:RespawnUnit()
				end
				hero:SetHealth( hero:GetMaxHealth() )
				hero:SetMana( hero:GetMaxMana() )
			end
		end
	end
end

--------------------------------------------------------------------------------
-- COMMAND LISTENERS
--------------------------------------------------------------------------------
function DotaRPG:OnCommand_SelectHero( cmd, heroName )
	self:SelectHero( Convars:GetCommandClient(), heroName )
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function DotaRPG:_ForEachPlayer( func --[[ playerID, hero ]] )
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			if PlayerResource:HasSelectedHero( playerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( playerID )
				func( playerID, hero )
			end
		end
	end
end

function DotaRPG:_NumPlayers()
	local nPlayers = 0
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			nPlayers = nPlayers + 1
		end
	end
	return nPlayers
end
