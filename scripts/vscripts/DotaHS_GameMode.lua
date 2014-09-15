
--------------------------------------------------------------------------------
-- Hook & Slice GameMode
--------------------------------------------------------------------------------

require( "DotaHS_Common" )
require( "DotaHS_ItemManager" )
require( "DotaHS_GridNavMap" )
require( "DotaHS_SpawnManager" )
require( "DotaHS_SpawnDirector" )
require( "DotaHS_MissionManager_RescueHostage" )
require( "DotaHS_Quest" )

require( "Util_Serialize" )

local DEBUG = false

-- Game end states
local NOT_ENDED		= 0
local VICTORIOUS	= 1
local DEFEATED		= 2

--------------------------------------------------------------------------------
if DotaHS == nil then
	DotaHS = class({})
	DotaHS.DeltaTime = 0.25
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
function DotaHS:InitGameMode()

	self:_ReadGameConfiguration()

	-- Initialize class members
	self._vPlayerInstanceMap = {}
	self._vPlayerLastValidPosition = {}		-- playerID : ValidPosition
	self.playerDataMap = {}

	self._nGameEndState = NOT_ENDED
	self._vEnemies = {}		-- entindex : enemyUnit

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
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetTreeRegrowTime( 0 )

	local GameMode = GameRules:GetGameModeEntity()
	GameMode:SetRecommendedItemsDisabled( true )
	GameMode:SetTopBarTeamValuesVisible( false )
	GameMode:SetBuybackEnabled( false )

	print( "Difficulty = " .. GameRules:GetDifficulty() )
	print( "Custom Difficulty = " .. GameRules:GetCustomGameDifficulty() )
--	GameRules:SetCustomGameDifficulty( GameRules:GetDifficulty() )

	-- Register Game Events
	ListenToGameEvent( 'player_connect_full',			Dynamic_Wrap(DotaHS, "OnPlayerConnectFull"),	self )
	ListenToGameEvent( 'entity_killed',					Dynamic_Wrap(DotaHS, "OnEntityKilled"),			self )
	ListenToGameEvent( 'npc_spawned',					Dynamic_Wrap(DotaHS, "OnNPCSpawn"),				self )
	ListenToGameEvent( 'game_rules_state_change',		Dynamic_Wrap(DotaHS, "OnGameRulesStateChange"),	self )
--	ListenToGameEvent( 'dota_holdout_revive_complete',	Dynamic_Wrap(DotaHS, "OnReviveComplete"),		self )

	-- Register Thinker
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, DotaHS.DeltaTime )

	-- Register Commands
	Convars:RegisterCommand( "dotahs_select_hero", function ( _, heroName )
		self:SelectHero( Convars:GetCommandClient(), heroName )
	end, "Select your hero", 0 )

	Convars:RegisterCommand( "dotahs_victory", function ( _ )
		-- force end the game
		GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
	end, "", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotahs_revive_all", function ( _ )
		self:_RefreshPlayers()
	end, "", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotahs_kill_player", function ( _, playerID )
		PlayerResource:GetSelectedHeroEntity( tonumber(playerID) ):ForceKill( true )
	end, "", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotahs_vote_yes", function ( _ )
		self:_VoteRestartYes( Convars:GetCommandClient():GetPlayerID() )
	end, "", 0 )
	Convars:RegisterCommand( "dotahs_vote_no", function ( _ )
		self:_VoteRestartNo( Convars:GetCommandClient():GetPlayerID() )
	end, "", 0 )

	-- PreInitialize modules
	ItemManager:PreInitialize()
--	GridNavMap:PreInitialize( self._vGameConfiguration )	-- Do not init GridNavMap until the map has been completely loaded.
	SpawnManager:PreInitialize()
	SpawnDirector:PreInitialize()

	if type(self._vGameConfiguration.RescueHostage) == "table" then
		MissionManager_RescueHostage:PreInitialize()
	end

end

--------------------------------------------------------------------------------
function DotaHS:_ReadGameConfiguration()
	self:_Log( "Loading game configurations..." )

	-- Load KV
	local kvDefault = LoadKeyValues( "scripts/maps/_Default.txt" )
	if not kvDefault then
		self:_Log( "  Not found : scripts/maps/_Default.txt" )
		kvDefault = {}
	end

	local kvMapSpecific = LoadKeyValues( "scripts/maps/" .. GetMapName() .. ".txt" )
	if not kvMapSpecific then
		self:_Log( "  Not found : scripts/maps/" .. GetMapName() .. ".txt" )
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
	self._nStartingLevel				= tonumber( kv.StartingLevel or 1 )

	self._vGameConfiguration	= kv
end

--------------------------------------------------------------------------------
-- OnThink
--------------------------------------------------------------------------------
function DotaHS:OnThink()

	if GameRules:State_Get() < DOTA_GAMERULES_STATE_STRATEGY_TIME then
		return DotaHS.DeltaTime
	end

	if self._nGameEndState == NOT_ENDED then
		self:_CheckForDefeat()
		self:_CheckForVictory()
	end

	-- Safe guard catching any state that may exist beyond DOTA_GAMERULES_STATE_POST_GAME
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end

	self:_ApplyCooldownReduction()
	self:_ValidatePlayerMovement()

	return DotaHS.DeltaTime

end

--------------------------------------------------------------------------------
-- Apply Cooldown Reduction
--------------------------------------------------------------------------------
function DotaHS:_ApplyCooldownReduction()

	----------------------------------------
	-- Apply cooldown reduction
	local reduction = self._fDefaultCooldownReduction

	DotaHS_ForEachPlayer( function ( playerID, hero )

		if not hero then return end

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

	end )
end

--------------------------------------------------------------------------------
-- Validate Player Movement
--------------------------------------------------------------------------------
function DotaHS:_ValidatePlayerMovement()
	DotaHS_ForEachPlayer( function ( playerID, hero )

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

end

--------------------------------------------------------------------------------
function DotaHS:_CheckForDefeat()
	local nDeadHeroes = 0

	DotaHS_ForEachPlayer( function ( playerID, hero )
		if hero and not hero:IsAlive() then
			nDeadHeroes = nDeadHeroes + 1
		end
	end )

	if nDeadHeroes == DotaHS_NumPlayers() and DotaHS_NumPlayers() > 0 then
		-- Defeated!
		self:_Log( "Defeated" )

		self._nGameEndState = DEFEATED
		self:_ShowEndScreen()

		return true
	end

	return false
end

--------------------------------------------------------------------------------
function DotaHS:_CheckForVictory()
	if DotaHS_GlobalVars.bVictory then
		self:_Log( "Victory" )

		self._nGameEndState = DEFEATED
		GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )

		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- Restart vote
--------------------------------------------------------------------------------
function DotaHS:_ShowEndScreen()

	FireGameEvent( "dotahs_restart_vote_begin", {} )
--	PauseGame( true )

	self._vVotes = {}	-- PlayerID : vote
	self._nRestartVoteYes	= 0
	self._nRestartVoteNo	= 0

end


function DotaHS:_VoteRestartYes( playerID )
	if self._nGameEndState == NOT_ENDED then
		self:_Log( "Game is not ended! Player[" .. playerID .. "] can't vote at the moment." )
		return
	end
	if self._vVotes[playerID] ~= nil then
		self:_Log( "Player[" .. playerID .. "] has already voted." )
		return
	end
	if PlayerResource:GetTeam( playerID ) ~= DOTA_TEAM_GOODGUYS then
		self:_Log( "Player[" .. playerID .. "] is not in the party." )
		return
	end

	self:_Log( "Player[" .. playerID .. "] voted YES" )

	self._vVotes[playerID] = true
	self._nRestartVoteYes = self._nRestartVoteYes + 1

	FireGameEvent( "dotahs_restart_vote", { wantRestart = true } )

	self:_CheckRestartVotes()
end


function DotaHS:_VoteRestartNo( playerID )
	if self._nGameEndState == NOT_ENDED then
		self:_Log( "Game is not ended! Player[" .. playerID .. "] can't vote at the moment." )
		return
	end
	if self._vVotes[playerID] ~= nil then
		self:_Log( "Player[" .. playerID .. "] has already voted." )
		return
	end
	if PlayerResource:GetTeam( playerID ) ~= DOTA_TEAM_GOODGUYS then
		self:_Log( "Player[" .. playerID .. "] is not in the party." )
		return
	end

	self:_Log( "Player[" .. playerID .. "] voted NO" )

	self._vVotes[playerID] = false
	self._nRestartVoteNo = self._nRestartVoteNo + 1

	FireGameEvent( "dotahs_restart_vote", { wantRestart = false } )

	self:_CheckRestartVotes()
end


function DotaHS:_CheckRestartVotes()
	if ( self._nRestartVoteYes + self._nRestartVoteNo ) == DotaHS_NumPlayers() then
		if self._nRestartVoteYes == DotaHS_NumPlayers() then
			self:_RestartGame()
		else
			-- Exit game
			GameRules:MakeTeamLose( DOTA_TEAM_GOODGUYS )
		end

		FireGameEvent( "dotahs_restart_vote_end", {} )
	end
end

--------------------------------------------------------------------------------
-- Restart the game
--------------------------------------------------------------------------------
function DotaHS:_RestartGame()

	-- Clean up enemies
	for _,unit in pairs(self._vEnemies) do
		if not unit:IsNull() and unit:IsAlive() then
			UTIL_RemoveImmediate( unit )
		end
	end
	self._vEnemies = {}

	-- Clean up pickups
	while GameRules:NumDroppedItems() > 0 do
		local item = GameRules:GetDroppedItem( 0 )
		UTIL_RemoveImmediate( item )
	end

	-- Finalize modules
	if type(self._vGameConfiguration.RescueHostage) == "table" then
		MissionManager_RescueHostage:Finalize()
	end
	self._vPlayerLastValidPosition = {}

	DotaHS_GlobalVars.bGameInProgress	= false
	DotaHS_GlobalVars.bVictory			= false
	
	self._nGameEndState = NOT_ENDED

	GameRules:ResetDefeated()
	GameRules:ResetToHeroSelection()
end

--------------------------------------------------------------------------------
function DotaHS:SelectHero( player, heroName )
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
function DotaHS:SavePlayerData( playerID )
	local steamID = PlayerResource:GetSteamAccountID( playerID )
	local filename = "player_" .. steamID
	KeyValuesToFile( self.playerDataMap[playerID], filename )
end

--------------------------------------------------------------------------------
function DotaHS:OnPlayerConnectFull( event )

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
	hero:AddNewModifier( hero, nil, "modifier_item_dotahs_weapon", modifierData )
--]]
end

--------------------------------------------------------------------------------
function DotaHS:OnEntityKilled( event )
	
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
	if killedUnit.DotaHS_NumLootDice then
		local itemLevel = killedUnit.DotaHS_ItemLevel
		if killedUnit.IsDotaHSChest then
			itemLevel = 3
		end
		--print( "ItemLevel = " .. itemLevel )

		for i=1, killedUnit.DotaHS_NumLootDice do
			ItemManager:CreateLoot( killedUnit:GetAbsOrigin(), itemLevel )
		end
	end

	-- Remove from enemy list
	self._vEnemies[killedUnit:entindex()] = nil

end

--------------------------------------------------------------------------------
function DotaHS:OnNPCSpawn( event )
	local unitSpawned = EntIndexToHScript( event.entindex )

	if unitSpawned:IsRealHero() then
		local playerID = unitSpawned:GetPlayerID()

		if PlayerResource:IsValidPlayerID( playerID ) then

			-- Starting level
			for i=1, self._nStartingLevel-1 do
				unitSpawned:HeroLevelUp( false )
			end

			-- Add DotaHS Item
			if not unitSpawned:HasItemInInventory( "item_dotahs_inventory" ) then
				-- Add special items
				local itemInventory = CreateItem( "item_dotahs_inventory", nil, nil )
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
				local item = CreateItem( "item_dotahs_modifiers_damage", nil, nil )
			--	item:ApplyDataDrivenModifier( unitSpawned, unitSpawned, "dotahs_damage_32768", {} )
				--unitSpawned:RemoveModifierByName( "dotahs_damage_8" )
			end

		end
	end

	if unitSpawned:GetTeamNumber() == DOTA_TEAM_BADGUYS and not unitSpawned:IsPhantom() then
		self._vEnemies[unitSpawned:entindex()] = unitSpawned
	end
end

--------------------------------------------------------------------------------
-- When game state changes set state in script
function DotaHS:OnGameRulesStateChange()
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

	--------------------------------------------------------------------------------
	-- STRATEGY TIME
	--
	if nNewState == DOTA_GAMERULES_STATE_STRATEGY_TIME then

		-- Initialize modules
		ItemManager:Initialize()
		GridNavMap:Initialize( self._vGameConfiguration )
		SpawnManager:Initialize( self._vGameConfiguration )
		SpawnDirector:Initialize( self._vGameConfiguration )

		-- RescueHostage gamemode
		if type(self._vGameConfiguration.RescueHostage) == "table" then
			MissionManager_RescueHostage:Initialize( self._vGameConfiguration.RescueHostage )
		end

		-- Begin the game
		DotaHS_GlobalVars.bGameInProgress = true

		if DEBUG then
			for i=1, 25 do
				ItemManager:CreateLoot( Vector(109, 157, 256+1) )
			end
		end
	end
end

--------------------------------------------------------------------------------
function DotaHS:_RefreshPlayers()
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
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function DotaHS:_Log( text )
	print( "[Hook & Slice] " .. text )
end
