
require( "DotaHS_Common" )
require( "DotaHS_AI_StrategyManager" )
require( "DotaHS_AI_ObstacleManager" )

-- Followers
require( "DotaHS_AI_Follower_Slithice" )
require( "DotaHS_AI_Follower_Abaddon" )
require( "DotaHS_AI_Follower_Omniknight" )
require( "DotaHS_AI_Follower_Sven" )
require( "DotaHS_AI_Follower_Luna" )
require( "DotaHS_AI_Follower_TemplarAssassin" )
require( "DotaHS_AI_Follower_Enchantress" )
require( "DotaHS_AI_Follower_Kotl" )
require( "DotaHS_AI_Follower_Lina" )

--------------------------------------------------------------------------------
-- AI_FollowerBotManager
--------------------------------------------------------------------------------
if AI_FollowerBotManager == nil then
	AI_FollowerBotManager = class({})
	AI_FollowerBotManager.DeltaTime	= 0.1	-- 10FPS
end

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function AI_FollowerBotManager:PreInitialize()
	
	self._vPrecachedUnits = {}

	-- Load configuration
	self._vRegisteredFollowers = LoadKeyValues( "scripts/pools/FollowerBotList.txt" )
	self._vRegisteredFollowerCounts = { str = 0, agi = 0, int = 0 }
	for k,v in pairs( self._vRegisteredFollowers ) do
		local attr = v.attribute
		-- Increment
		self._vRegisteredFollowerCounts[attr] = self._vRegisteredFollowerCounts[attr] + 1
	end

	-- Register Think
	DotaHS_CreateThink( "AI_FollowerBotManager:OnUpdate", function ()
		self:OnUpdate()
		return AI_FollowerBotManager.DeltaTime
	end )

	-- Register Game Event Listener
	ListenToGameEvent( "npc_spawned",	Dynamic_Wrap(AI_FollowerBotManager, "OnNPCSpawn"),	self )

	-- Register Commands
	Convars:RegisterCommand( "dotahs_add_follower", function ( _, heroName )
		self:CreateFollower( heroName )
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_kill_all_followers", function ( _ )
		if self.vBotEntities then
			for _,v in pairs(self.vBotEntities) do
				if v:IsAlive() then
					v:ForceKill( false )
				end
			end
		end
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_approve_follower", function ( _, heroName, bApproved )
		FireGameEvent( "dotahs_follower_approved", {
			heroName = heroName,
			approved = (bApproved ~= "0"),
		} )
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_suggest_follower", function ( _, heroName )
		local heroLabel = self._vRegisteredFollowers[heroName].label
		local colorW = '\x0B'
		local color =  '\x0F'
		local msg = "Please add " .. color .. heroLabel .. colorW .. " Bot."
		Say( Convars:GetCommandClient(), msg, true )
	end, "", 0 )

	Convars:RegisterCommand( "dotahs_end_follower_vote", function ( _ )
		FireGameEvent( "dotahs_follower_vote_end", {} )
	end, "", 0 )

	-- Register Convars
	Convars:RegisterConvar( "dotahs_follower_selection_time",	   "30", "", 0 )
	Convars:RegisterConvar( "dotahs_ai_debug_enable",				"0", "", FCVAR_CHEAT )
	Convars:RegisterConvar( "dotahs_ai_debug_selected_bot",		  "201", "", FCVAR_CHEAT )
	Convars:RegisterConvar( "dotahs_ai_debug_show_modifiers",		"0", "", FCVAR_CHEAT )
	Convars:RegisterConvar( "dotahs_ai_debug_show_obstacles",		"1", "", FCVAR_CHEAT )
	Convars:RegisterConvar( "dotahs_ai_debug_show_localgridnav",	"0", "", FCVAR_CHEAT )

	-- Pre-Init dependencies
	AI_StrategyManager:PreInitialize()
	AI_ObstacleManager:PreInitialize()

end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function AI_FollowerBotManager:Initialize()
	
	self.vAIMap = {}
	self.vUnitNameToAI = {}
	self.vBotEntities = {}

	DotaHS_GlobalVars.nFollowers = 0
	DotaHS_GlobalVars.vFollowerEntityMap = {}

	-- Init dependencies
	AI_StrategyManager:Initialize()
	AI_ObstacleManager:Initialize()

	-- Update follower bot selection UI
	FireGameEvent( "dotahs_follower_info_begin", {
		numStr = self._vRegisteredFollowerCounts.str,
		numAgi = self._vRegisteredFollowerCounts.agi,
		numInt = self._vRegisteredFollowerCounts.int,
	} )

	for k,v in pairs( self._vRegisteredFollowers ) do
		FireGameEvent( "dotahs_follower_info", {
			heroName = k,
			attribute = v.attribute,
		} )
	end

	FireGameEvent( "dotahs_follower_info_end", {
		numPlayers = DotaHS_NumPlayers( true ),
		numMaxPlayers = 6,
		followerSelectionTime = Convars:GetInt( "dotahs_follower_selection_time" ),
	} )

end

--------------------------------------------------------------------------------
-- Finalize
--------------------------------------------------------------------------------
function AI_FollowerBotManager:Finalize()
	DotaHS_GlobalVars.nFollowers = 0
	DotaHS_GlobalVars.vFollowerEntityMap = {}
	
	for k,v in ipairs(self.vBotEntities) do
		UTIL_RemoveImmediate( v )
	end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------
function AI_FollowerBotManager:OnUpdate()
	if DotaHS_GlobalVars.bGameInProgress then
		AI_ObstacleManager:Update()
	end
end

--------------------------------------------------------------------------------
-- Create New Bot
--------------------------------------------------------------------------------
function AI_FollowerBotManager:CreateFollower( heroName )
--	if not self.bFakeClientsCreated then
--		SendToServerConsole( "dota_create_fake_clients" )
--		self.bFakeClientsCreated = true
--	end

	local vHeroNameToBotClass = {
		naga_siren			= AI_Slithice,
		abaddon				= AI_Abaddon,
		omniknight			= AI_Omniknight,
		sven				= AI_Sven,
		luna				= AI_Luna,
		templar_assassin	= AI_TemplarAssassin,
		enchantress			= AI_Enchantress,
		keeper_of_the_light	= AI_Kotl,
		lina				= AI_Lina,

		-- TEST
		wisp		= AI_DummyTombstone,
	}

	local botUnitName = "npc_dota_hero_" .. heroName
	local botClass = vHeroNameToBotClass[heroName]

	if not botClass then
		self:_Log( "Invalid heroName : " .. heroName )
		return
	end

	-- Create Impl
	local createImpl = function ()
		local startEnt = Entities:FindByClassname( nil, "info_player_start_goodguys" )
		local spawnPos = startEnt:GetAbsOrigin()
		local randomOffsets = RandomVector( RandomFloat( 100, 175 ) )

	--	local playerID = DotaHS_NumPlayers( true ) + DotaHS_GlobalVars.nFollowers
	--	local entity = CreateHeroForPlayer( botUnitName, PlayerResource:GetPlayer( playerID ) )
		local entity = CreateUnitByName( botUnitName, spawnPos + randomOffsets, true, nil, nil, DOTA_TEAM_GOODGUYS )
		local playerID = DotaHS_GlobalVars.nFollowers + 200 + 1
		entity.DotaHS_FollowerBotID = playerID
		entity.DotaHS_IsFollowerBot = true
	--	entity:SetPlayerID( playerID )	-- may cause CTD

		DotaHS_GlobalVars.nFollowers = DotaHS_GlobalVars.nFollowers + 1
		DotaHS_GlobalVars.vFollowerEntityMap[playerID] = entity

		local AI = botClass( entity )
		self.vAIMap[playerID] = AI
		self.vUnitNameToAI[botUnitName] = AI
		table.insert( self.vBotEntities, entity )

		self:_Log( "New follower has arrived! ID=[" .. playerID .. "], unitName=" .. botUnitName )
	end

	-- Precache
	if self._vPrecachedUnits[botUnitName] == nil then
		self:_Log( "Precaching : " .. botUnitName )
		PrecacheUnitByNameAsync( botUnitName, function ( sg )
			self._vPrecachedUnits[botUnitName] = sg
			createImpl()
		end )
	else
		-- Already cached
		createImpl()
	end

--	SendToServerConsole( "dota_bot_disable 1" )
--	SendToServerConsole( "dota_create_unit " .. botUnitName )
end

--------------------------------------------------------------------------------
-- OnNPCSpawn
--------------------------------------------------------------------------------
function AI_FollowerBotManager:OnNPCSpawn( event )
	local unitSpawned = EntIndexToHScript( event.entindex )

	--------------------------------------------------------------------------------
	-- Assign Illusions
	--
	if unitSpawned:GetTeamNumber() == DOTA_TEAM_GOODGUYS and unitSpawned:IsIllusion() then
		local owner = unitSpawned:GetOwner()
		if not owner then
			-- owned by BOT
			self:_Log( "An illusion has spawned. Name = " .. unitSpawned:GetUnitName() )

			-- Assign the Followe AI
			local AI = self.vUnitNameToAI[unitSpawned:GetUnitName()]
			if AI then
				unitSpawned.DotaHS_FollowerBotID = AI.entity.DotaHS_FollowerBotID
				unitSpawned.DotaHS_IsFollowerBot = true
				AI:AssignIllusion( unitSpawned )
			else
				-- Owner bot not found
				self:_Log( "  But the owner bot not found." )
			end
		end
	end

end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function AI_FollowerBotManager:_Log( text )
	print( "[AI/FollowerBotManager] " .. text )
end





--------------------------------------------------------------------------------
-- AI / Dummy
--------------------------------------------------------------------------------
AI_DummyFollower = class({})

function AI_DummyFollower:constructor( unit )
end

--------------------------------------------------------------------------------
AI_DummyTombstone = class({})

function AI_DummyTombstone:constructor( unit )
	unit:ForceKill( false )
end
