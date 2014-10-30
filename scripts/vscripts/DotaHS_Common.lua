
--------------------------------------------------------------------------------
-- GLOBAL VARIABLES
--------------------------------------------------------------------------------
if DotaHS_GlobalVars == nil then
	DotaHS_GlobalVars = class({})

	-- Initialize global variables
	DotaHS_GlobalVars.bGameInProgress	= false	-- Managed by DotaHS
	DotaHS_GlobalVars.bVictory			= false	-- Managed by DotaHS & MissionManager

	DotaHS_GlobalVars.vFollowerEntityMap = {}	-- Managed by FollowerBotManager (playerID to entity)
	DotaHS_GlobalVars.nFollowers = 0			-- Managed by FollowerBotManager
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function DotaHS_CreateThink( name, thinkerFunc )
	GameRules:GetGameModeEntity():SetContextThink( name, thinkerFunc, 0.05 )
end

--------------------------------------------------------------------------------
function DotaHS_HeroEntityToPlayerID( hero )
	local playerID = hero:GetPlayerID()
	if playerID < 0 then
		-- Follower BOT
		playerID = hero.DotaHS_FollowerBotID
	end
	return playerID
end

--------------------------------------------------------------------------------
function DotaHS_PlayerIDToHeroEntity( playerID )
	local heroEntity

	-- Grab from PlayerResource
	heroEntity = PlayerResource:GetSelectedHeroEntity( playerID )

	-- Grab from Follower BOTs
	if not heroEntity then
		heroEntity = DotaHS_GlobalVars.vFollowerEntityMap[playerID]
	end

	if not heroEntity then
	--	print( "Valid hero entity not found. PlayerID = " .. playerID )
	end

	return heroEntity
end

--------------------------------------------------------------------------------
function DotaHS_ForEachPlayer( func --[[ playerID, hero ]] )
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			local hero = PlayerResource:GetSelectedHeroEntity( playerID )
			func( playerID, hero )
		end
	end

	for k,v in pairs(DotaHS_GlobalVars.vFollowerEntityMap) do
		func( DotaHS_HeroEntityToPlayerID(v), v )
	end
end

--------------------------------------------------------------------------------
function DotaHS_NumPlayers( bExcludeBots )
	local nPlayers = 0
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			if not PlayerResource:IsFakeClient( playerID ) then
				nPlayers = nPlayers + 1
			end
		end
	end
	if not bExcludeBots then
		nPlayers = nPlayers + DotaHS_GlobalVars.nFollowers
	end
	return nPlayers
end

--------------------------------------------------------------------------------
function DotaHS_NumPlayersAlive()
	local nPlayersTotal = 0
	local nPlayersAlive = 0
	DotaHS_ForEachPlayer( function ( playerID, hero )
		if not hero then return end
		nPlayersTotal = nPlayersTotal + 1
		if hero:IsAlive() then
			nPlayersAlive = nPlayersAlive + 1
		end
	end )
	return nPlayersAlive, nPlayersTotal
end

--------------------------------------------------------------------------------
function DotaHS_RefreshPlayers()
	DotaHS_ForEachPlayer( function ( playerID, hero )
		if not hero then return end
		if not hero:IsAlive() then
			hero:RespawnUnit()
		end
		hero:SetHealth( hero:GetMaxHealth() )
		hero:SetMana( hero:GetMaxMana() )
	end )
end

--------------------------------------------------------------------------------
function DotaHS_GetAbilitySpecialValue( ability, name )
	return ability:GetLevelSpecialValueFor( name, ability:GetLevel() )
end

--------------------------------------------------------------------------------
function DotaHS_GetDifficultyValue( value )
	local normal, hard, insane = string.match( value, "(%d+) (%d+) (%d+)" )
	if normal and hard and insane then
		local difficulty = GameRules:GetCustomGameDifficulty()
		if difficulty == 0 then
			return normal
		elseif difficulty == 1 then
			return hard
		else
			return insane
		end
	end

	return value
end

--------------------------------------------------------------------------------
function DotaHS_GetPartyDifficultyValue( soloData, gainData )
	local soloValue = DotaHS_GetDifficultyValue( soloData )
	local gainValue = DotaHS_GetDifficultyValue( gainData )
	return soloValue + gainValue * ( DotaHS_NumPlayers() - 1 )
end

--------------------------------------------------------------------------------
function DotaHS_RandomFromWeights( array, funcWeight --[[ (k, v) : return weight ]] )
	local totalWeight = 0
	local selected

	for k,v in pairs( array ) do
		local weight
		if funcWeight then
			weight = funcWeight( k, v )
		else
			weight = v
		end
		local r = RandomFloat( 0, totalWeight + weight )
		if r >= totalWeight then
			selected = k
		end
		totalWeight = totalWeight + weight
	end

	return selected
end

--------------------------------------------------------------------------------
function DotaHS_TableFilter( t, func )
	if not t then
		return {}
	end

	local result = {}

	for k,v in pairs(t) do
		if func( v ) then
			table.insert( result, v )
		end
	end

	return result
end
