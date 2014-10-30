
require( "DotaHS_Common" )
require( "DotaHS_Quest" )
require( "DotaHS_SpawnManager" )
require( "DotaHS_SpawnDirector" )

--------------------------------------------------------------------------------
if MissionManager_RescueHostage == nil then
	MissionManager_RescueHostage = class({})
	MissionManager_RescueHostage.DeltaTime = 1.0
end

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function MissionManager_RescueHostage:PreInitialize()

	-- Inspect the map
	self._vHostageSpawnEntAry = self:_FindHostageSpawnEntities()
	
	-- Quests
	self._questReleasedHostages = CreateQuest( "ReleasedHostages" )
	self._subquestReleasedHostages = CreateSubquestOf( self._questReleasedHostages )
	Subquest_UpdateValue( self._subquestReleasedHostages, 0, 1 )

	self._questEscapedHostages = CreateQuest( "EscapedHostages" )
	self._subquestEscapedHostages = CreateSubquestOf( self._questEscapedHostages )
	Subquest_UpdateValue( self._subquestEscapedHostages, 0, 1 )

	-- CreateTimer
	DotaHS_CreateThink( "MissionManager_RescueHostage:OnUpdate", function ()
		self:OnUpdate()
		return MissionManager_RescueHostage.DeltaTime
	end )

	-- Register game event listeners
	ListenToGameEvent( 'entity_killed', Dynamic_Wrap(MissionManager_RescueHostage, "OnEntityKilled"), self )

end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function MissionManager_RescueHostage:Initialize( kv )

	self.vHostages				= {}	-- Array of hostage entities
	self.vHostagesArrested		= {}	-- Array of arrested hostage entities
	self.vHostagesReleasedOnce	= {}	-- Array of hostages that have been released at least once
	self.vPlayerPosition		= {}	-- PlayerID : PlayerPosition
	self.vPlayerHostages		= {}	-- PlayerID : [Array of Hostage entity]

	self.nTotalHostages			= 1
	self.nHostagesRemaining		= 1
	self.nHostagesReleasedOnce	= 0		-- Num of hostages thas have been released at least once

	-- Spawn Hostages
	local numHostagesToSpawn = DotaHS_GetDifficultyValue( kv.NumHostages )
	self:_RegisterHostages( self:_SpawnHostages( {unpack(self._vHostageSpawnEntAry)}, numHostagesToSpawn ) )

	-- Dynamic values
	self.vChangeMonsterPool				= kv.ChangeMonsterPool
	self.vChangeHordeIntervalReduction	= kv.ChangeHordeIntervalReduction

end

--------------------------------------------------------------------------------
-- Finalize
--------------------------------------------------------------------------------
function MissionManager_RescueHostage:Finalize()
	
	-- Clean up hostages
	for _,hostage in pairs( self.vHostages ) do
		if not hostage:IsNull() and hostage:IsAlive() then
			UTIL_RemoveImmediate( hostage )
		end
	end
	self.vHostages = {}

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_RegisterHostages( vHostages )
	
	self.vHostages = vHostages
	self.vHostagesArrested = {unpack(vHostages)}

	for k,hostage in pairs( vHostages ) do
		hostage.DotaHS_IsHostage = true
		hostage.DotaHS_HostageID = k

		hostage:FindAbilityByName( "dotahs_hostage_default" ):SetLevel(1)
		hostage:FindAbilityByName( "dotahs_hostage_arrested" ):SetLevel(1)
		hostage:FindAbilityByName( "dotahs_hostage_arrested" ):ToggleAbility()

		if not hostage:FindAbilityByName( "dotahs_hostage_arrested" ):GetToggleState() then
			self:_Log( "ARRESTED modifier is OFF !!" )
		end

	end

	self.nTotalHostages		= #vHostages
	self.nHostagesRemaining	= #vHostages
	self:_Log( "Registered hostages : Num = " .. #vHostages )

	self:_UpdateQuest()

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:UpdatePlayersPosition( vPlayerPosition )
	self.vPlayerPosition = vPlayerPosition
end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:OnUpdate()

	if not DotaHS_GlobalVars.bGameInProgress then
		return
	end
	
	-- Check to release arrested hostages
	for k,hostage in pairs( self.vHostagesArrested ) do

		local hostagePos	= hostage:GetAbsOrigin()
		local hostageID		= hostage.DotaHS_HostageID

		for playerID, playerPos in pairs( self.vPlayerPosition ) do

			local playerHero = DotaHS_PlayerIDToHeroEntity( playerID )
			local dist = ( hostagePos - playerPos ):Length2D()

			if dist < 300 and playerHero:IsAlive() then
				self:_Log( "A hostage has been released." )
				self:_Log( "  Hostage ID = " .. hostageID )
				self:_Log( "  Player  ID = " .. playerID )

				-- Hostage has been released by the player
				hostage:FindAbilityByName( "dotahs_hostage_arrested" ):ToggleAbility()

				if hostage:FindAbilityByName( "dotahs_hostage_arrested" ):GetToggleState() then
					self:_Log( "ARRESTED modifier is ON !!" )
				end

				-- Follow the player
				local hostagesFollowPlayer = self.vPlayerHostages[playerID]
				local target
				if hostagesFollowPlayer and #hostagesFollowPlayer > 0 then
					-- Already some hostages are following the player.
					target = hostagesFollowPlayer[#hostagesFollowPlayer]	-- Get the tail hostage
				else
					-- Follow the player
					self.vPlayerHostages[playerID] = {}
					target = playerHero
				end

				-- Add to hostage list of the player
				table.insert( self.vPlayerHostages[playerID], hostage )

				-- Execute follow command
				local order = {
					OrderType = DOTA_UNIT_ORDER_MOVE_TO_TARGET,
					UnitIndex = hostage:entindex(),
					TargetIndex = target:entindex(),
				}
				ExecuteOrderFromTable( order )

				-- Remove from arrested hostage list
				table.remove( self.vHostagesArrested, k )

				self:_UpdateQuest()

				-- Add to released hostage list
				if not self.vHostagesReleasedOnce[hostageID] then
					self.vHostagesReleasedOnce[hostageID] = hostage
					self.nHostagesReleasedOnce = self.nHostagesReleasedOnce + 1

					self:_OnUpdateHostagesReleasedOnce()
				end

				break	-- IMPORTANT!!!

			end

		end

	end

	-- Re-follow to the player
	for playerID,hostagesFollowPlayer in pairs( self.vPlayerHostages ) do
		if #hostagesFollowPlayer > 0 then

			-- Execute follow command
			local order = {
				OrderType = DOTA_UNIT_ORDER_MOVE_TO_TARGET,
				UnitIndex = hostagesFollowPlayer[1]:entindex(),
				TargetIndex = DotaHS_PlayerIDToHeroEntity( playerID ):entindex(),
			}
			ExecuteOrderFromTable( order )

		end

	end

	-- Check to complete the rescue
	local nHostagesRemainingCurrent = 0

	for k,hostage in pairs( self.vHostages ) do
		-- Is not escaped?
		if not hostage.DotaHS_IsEscaped then
			nHostagesRemainingCurrent = nHostagesRemainingCurrent + 1
		end
	end

	if nHostagesRemainingCurrent ~= self.nHostagesRemaining then
		self.nHostagesRemaining = nHostagesRemainingCurrent
		self:_UpdateQuest()

		self:_Log( self.nHostagesRemaining .. " hostages remaining." )
	end

	-- Complete mission
	if self.nHostagesRemaining <= 0 then
	--	self._questEscapedHostages:CompleteQuest()
		DotaHS_GlobalVars.bVictory = true
	end

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_OnUpdateHostagesReleasedOnce()
	self:_Log( self.nHostagesReleasedOnce .. " hostages have been released at least once." )

	-- Change the monster pool
	if self.vChangeMonsterPool then
		local list = self.vChangeMonsterPool[tostring(self.nHostagesReleasedOnce)]
		if list then
			for original, new in pairs( list ) do
				SpawnManager:ChangeMonsterPool( original, new )
			end
		end
	end

	-- Change horde interval
	if self.vChangeHordeIntervalReduction then
		local reduction = self.vChangeHordeIntervalReduction[tostring(self.nHostagesReleasedOnce)]
		if reduction then
			SpawnDirector:SetHordeIntervalReduction( tonumber(reduction) / 100 )
		end
	end
end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:OnEntityKilled( event )

	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if not killedUnit then
		return
	end

	if killedUnit:IsRealHero() then
		local playerID = DotaHS_HeroEntityToPlayerID( killedUnit )

		-- Check following hostages
		local hostagesFollowPlayer = self.vPlayerHostages[playerID]
		if hostagesFollowPlayer and #hostagesFollowPlayer > 0 then

			-- Re-arrest the hostages
			for _,hostage in ipairs( hostagesFollowPlayer ) do

				self:_Log( "A hostage has been arrested." )
				self:_Log( "  Hostage ID = " .. hostage.DotaHS_HostageID )
				self:_Log( "  Player  ID = " .. playerID )

				hostage:FindAbilityByName( "dotahs_hostage_arrested" ):ToggleAbility()

				if not hostage:FindAbilityByName( "dotahs_hostage_arrested" ):GetToggleState() then
					self:_Log( "ARRESTED modifier is OFF !!" )
				end

				-- Add to arrested hostage list
				table.insert( self.vHostagesArrested, hostage )

			end

			-- Remove the list
			self.vPlayerHostages[playerID] = nil

			self:_UpdateQuest()

		end
	end
end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_FindHostageSpawnEntities()
	-- Collect pool entities in the map
	local hostageSpawnEntAry = {}

	for _,v in pairs(Entities:FindAllByClassname( "info_target" )) do
		local entName = v:GetName()
		if string.find( entName, "hostage_spawn" ) == 1 then
			table.insert( hostageSpawnEntAry, v )
		end
	end

	return hostageSpawnEntAry
end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_SpawnHostages( hostageSpawnEntAry, numHostagesToSpawn )
	
	local vHostages = {}

	if #hostageSpawnEntAry < numHostagesToSpawn then
		self:_Log( "Spawners for hostages are too few!" )
		self:_Log( "  Num Spawners : " .. #hostageSpawnEntAry )
		self:_Log( "  Num Hostages : " .. numHostagesToSpawn )
		return {}
	end

	for i=1, numHostagesToSpawn do

		-- Choose a spawner
		local spawnerID = RandomInt( 1, #hostageSpawnEntAry )
		local spawnerEnt = hostageSpawnEntAry[spawnerID]

		table.remove( hostageSpawnEntAry, spawnerID )

		-- Spawn a hostage
		local hostage = CreateUnitByName( "npc_dotahs_hostage", spawnerEnt:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_GOODGUYS )
		hostage:SetAngles( 0, RandomFloat( 0, 360 ), 0 )

		table.insert( vHostages, hostage )

	end

	return vHostages

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_UpdateQuest()
	local releasedHostages = self.nTotalHostages - #self.vHostagesArrested
	Quest_UpdateValue( self._questReleasedHostages, releasedHostages, self.nTotalHostages )
	Subquest_UpdateValue( self._subquestReleasedHostages, releasedHostages, self.nTotalHostages )

	local escapedHostages = self.nTotalHostages - self.nHostagesRemaining
	Quest_UpdateValue( self._questEscapedHostages, escapedHostages, self.nTotalHostages )
	Subquest_UpdateValue( self._subquestEscapedHostages, escapedHostages, self.nTotalHostages )
end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:_Log( text )
	print( "[Mission/RescueHostage] " .. text )
end
