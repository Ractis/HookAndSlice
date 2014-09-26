
--------------------------------------------------------------------------------
-- GLOBAL VARIABLES
--------------------------------------------------------------------------------
if DotaHS_GlobalVars == nil then
	DotaHS_GlobalVars = class({})

	-- Initialize global variables
	DotaHS_GlobalVars.bGameInProgress	= false	-- Managed by DotaHS
	DotaHS_GlobalVars.bVictory			= false	-- Managed by DotaHS & MissionManager
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function DotaHS_CreateThink( name, thinkerFunc )
	GameRules:GetGameModeEntity():SetContextThink( name, thinkerFunc, 0.05 )
end

function DotaHS_ForEachPlayer( func --[[ playerID, hero ]] )
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			local hero = PlayerResource:GetSelectedHeroEntity( playerID )
			func( playerID, hero )
		--[[
			if PlayerResource:HasSelectedHero( playerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( playerID )
				func( playerID, hero )
			end
		--]]
		end
	end
end

function DotaHS_NumPlayers()
	local nPlayers = 0
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			nPlayers = nPlayers + 1
		end
	end
	return nPlayers
end

function DotaHS_RefreshPlayers()
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

function DotaHS_GetPartyDifficultyValue( soloData, gainData )
	local soloValue = DotaHS_GetDifficultyValue( soloData )
	local gainValue = DotaHS_GetDifficultyValue( gainData )
	return soloValue + gainValue * ( DotaHS_NumPlayers() - 1 )
end

function DotaHS_RandomFromWeights( array, funcWeight --[[ (k, v) : return weight ]] )
	local totalWeight = 0
	local selected

	for k,v in pairs( array ) do
		local weight = funcWeight( k, v )
		local r = RandomFloat( 0, totalWeight + weight )
		if r >= totalWeight then
			selected = k
		end
		totalWeight = totalWeight + weight
	end

	return selected
end
