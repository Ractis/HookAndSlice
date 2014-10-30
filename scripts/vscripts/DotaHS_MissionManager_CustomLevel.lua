
require( "DotaHS_Common" )
require( "DotaHS_ItemManager" )
require( "DotaHS_GridNavMap" )
require( "DotaHS_SpawnManager" )
require( "DotaHS_SpawnDirector" )

--------------------------------------------------------------------------------
if MissionManager_CustomLevel == nil then
	MissionManager_CustomLevel = class({})
end

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function MissionManager_CustomLevel:PreInitialize( gameConfig )
	
	self._bufferMap = {}	-- PlayerID : Array of buffer
	self._kvMap = {}		-- PlayerID : KV

	self._globalConfig = gameConfig

	local customLevelConfig = gameConfig.CustomLevel

	-- Collect areas
	self._areas = {}
	for k,v in pairs(customLevelConfig.Areas) do
		self._areas[tonumber(k)] = v
	end
	self:_Log( #self._areas .. " test areas found." )

	-- Find StartEnt of Areas
	self._startEntMap = {}

	for _,v in pairs(Entities:FindAllByClassname( "info_target" )) do
		local entName = v:GetName()
		for areaID,area in pairs( self._areas ) do
			if entName == area.StartFrom then
				self._startEntMap[areaID] = v
				self:_Log( "StartEntity for Area[" .. areaID .. "] found." )
				break
			end
		end
	end

	-- Register Commands
	Convars:RegisterCommand( "dotahs_custom_level_buffer", function ( _, packet )
		self:_AddToBuffer( Convars:GetCommandClient():GetPlayerID(), packet )
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_custom_level_buffer_end", function ( _ )
		self:_EndBuffer( Convars:GetCommandClient():GetPlayerID() )
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_play_custom_level", function ( _, areaID, difficulty )
		self:_PlayLevel( Convars:GetCommandClient():GetPlayerID(), tonumber(areaID), tonumber(difficulty) )
	end, "", 0 )

end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function MissionManager_CustomLevel:Initialize( globalKV )

	FireGameEvent( "dotahs_show_leveleditor", {} )

end

--------------------------------------------------------------------------------
-- Play the CustomLevel
--------------------------------------------------------------------------------
function MissionManager_CustomLevel:_PlayLevel( playerID, areaID, difficulty )
	
	if DotaHS_GlobalVars.bGameInProgress then
		self:_Log( "Game In Progress. PlayLevel Request has been denied." )
		return
	end

	-- Grab the Start Entity
	local startEnt = self._startEntMap[areaID]

	if not startEnt then
		self:_Log( "StartEntity for Area[" .. areaID .. "] is not found." )
		return
	end

	-- Calculate NumMonsterPools
	local levelData = self._kvMap[playerID]

	local nMonsterPools = 0
	for k,v in pairs(levelData.MonsterPools) do
		nMonsterPools = nMonsterPools + 1
	end

	-- Merge level data
	local config = {}

	for k,v in pairs( self._globalConfig ) do
		config[k] = v	-- Shallow copy
	end
	for k,v in pairs( levelData ) do
		config[k] = v	-- Merge
	end

	config.AutoSplitPoolBy = nMonsterPools

	if self._areas[areaID].DesiredEnemyDensity then
		local oldDensity = config.DesiredEnemyDensity
		local newDensity = oldDensity * self._areas[areaID].DesiredEnemyDensity
		self:_Log( "EnemyDensity has been modified to " .. newDensity .. " from " .. oldDensity )
		config.DesiredEnemyDensity = newDensity
	else
		self:_Log( "EnemyDensity for this area not found." )
	end

	--DeepPrintTable( self._globalConfig )

	-- Set difficulty
	GameRules:SetCustomGameDifficulty( difficulty )

	-- Initialize modules
	GridNavMap:Initialize( config, startEnt )
	SpawnManager:Initialize( config )
	SpawnDirector:Initialize( config )

	DotaHS_GlobalVars.bGameInProgress = true
	FireGameEvent( "dotahs_hide_leveleditor", {} )

	-- Teleport to the Testing Area
	DotaHS_RefreshPlayers()
	DotaHS_ForEachPlayer( function ( playerID, hero )
		FindClearSpaceForUnit( hero, startEnt:GetAbsOrigin(), true )
	--	PlayerResource:SetCameraTarget( playerID, hero )

		for i=hero:GetLevel(), config.StartingLevel-1 do
			hero:HeroLevelUp( false )
		end
	end )
	SendToConsole( "dota_camera_center" )

end

--------------------------------------------------------------------------------
-- Buffer
--------------------------------------------------------------------------------
function MissionManager_CustomLevel:_AddToBuffer( playerID, packet )
	
	if not self._bufferMap[playerID] then
		self._bufferMap[playerID] = {}
	end

	if self._kvMap[playerID] then
		self._kvMap[playerID] = nil
	end

	table.insert( self._bufferMap[playerID], packet )

end

function MissionManager_CustomLevel:_EndBuffer( playerID )
	
	if not self._bufferMap[playerID] then
		self:_Log( "INVALID BUFFER! PlayerID = " .. playerID )
		return
	end

	local str = table.concat( self._bufferMap[playerID] )
	self._bufferMap[playerID] = nil

	str = str:gsub( "'", '"' )

	-- Save KV file
	local timestamp = GetSystemDate() .. "-" .. GetSystemTime()
	timestamp = timestamp:gsub(":",""):gsub("/","")

	local steamID = PlayerResource:GetSteamAccountID( playerID )

	local fileName = "addons/dotahs_custom_level/" .. timestamp .. "_player_" .. steamID .. ".txt"

	InitLogFile( fileName, "" )
	AppendToLogFile( fileName, str )

	self:_Log( "Wrote KV file to " .. fileName )

	-- Load KV file
	local kv = LoadKeyValues( fileName )
--	print( str )
	self:_Log( "BufferSize = " .. #str .. ", PlayerID = " .. playerID )
	DeepPrintTable( kv )

	self._kvMap[playerID] = kv

	-- Play this LEVEL
--	self:_PlayLevel( 1, kv )

end

--------------------------------------------------------------------------------
-- UTILS
--------------------------------------------------------------------------------
function MissionManager_CustomLevel:_Log( text )
	print( "[Mission/CustomLevel] " .. text )
end
