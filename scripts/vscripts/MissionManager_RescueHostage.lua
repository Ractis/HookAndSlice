
require( "Util_Quest" )
require( "timers" )

--------------------------------------------------------------------------------
if MissionManager_RescueHostage == nil then
	MissionManager_RescueHostage = class({})
end

--------------------------------------------------------------------------------
local DELTA_TIME = 0.25
local DELTA_TIME = 1

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function MissionManager_RescueHostage:Initialize()

	self.vHostages			= {}	-- Array of hostage entities
	self.vHostagesArrested	= {}	-- Array of arrestet hostage entities 
	self.vPlayerPosition	= {}	-- PlayerID : PlayerPosition
	self.vPlayerHostages	= {}	-- PlayerID : [Array of Hostage entity]

	self.nTotalHostages		= 1
	self.nHostagesRemaining	= 1

	-- Quests
	self._questReleasedHostages = CreateQuest( "ReleasedHostages" )
	self._subquestReleasedHostages = CreateSubquestOf( self._questReleasedHostages )
	Subquest_UpdateValue( self._subquestReleasedHostages, 0, 1 )

	self._questEscapedHostages = CreateQuest( "EscapedHostages" )
	self._subquestEscapedHostages = CreateSubquestOf( self._questEscapedHostages )
	Subquest_UpdateValue( self._subquestEscapedHostages, 0, 1 )

	-- CreateTimer
	Timers:CreateTimer( function ()
		self:_OnUpdate()
		return DELTA_TIME
	end )

	-- Register game event listeners
	ListenToGameEvent( 'entity_killed', Dynamic_Wrap(MissionManager_RescueHostage, "OnEntityKilled"), self )

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:RegisterHostages( vHostages )
	
	self.vHostages = vHostages
	self.vHostagesArrested = {unpack(vHostages)}

	for k,hostage in pairs( vHostages ) do
		hostage.DotaRPG_IsHostage = true
		hostage.DotaRPG_HostageID = k

		hostage:FindAbilityByName( "dotarpg_hostage_default" ):SetLevel(1)
		hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):SetLevel(1)
		hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):ToggleAbility()

		if not hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):GetToggleState() then
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
function MissionManager_RescueHostage:_OnUpdate()
	
	-- Check to release arrested hostages
	for k,hostage in pairs( self.vHostagesArrested ) do

		local hostagePos = hostage:GetAbsOrigin()

		for playerID, playerPos in pairs( self.vPlayerPosition ) do

			local playerHero = PlayerResource:GetSelectedHeroEntity( playerID )
			local dist = ( hostagePos - playerPos ):Length2D()

			if dist < 300 and playerHero:IsAlive() then
				self:_Log( "A hostage has been released." )
				self:_Log( "  Hostage ID = " .. hostage.DotaRPG_HostageID )
				self:_Log( "  Player  ID = " .. playerID )

				-- Hostage has been released by the player
				hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):ToggleAbility()

				if hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):GetToggleState() then
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
				TargetIndex = PlayerResource:GetSelectedHeroEntity( playerID ):entindex(),
			}
			ExecuteOrderFromTable( order )

		end

	end

	-- Check to complete the rescue
	local nHostagesRemainingCurrent = 0

	for k,hostage in pairs( self.vHostages ) do
		-- Is not escaped?
		if not hostage.DotaRPG_IsEscaped then
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
		GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
	end

end

--------------------------------------------------------------------------------
function MissionManager_RescueHostage:OnEntityKilled( event )

	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if not killedUnit then
		return
	end

	if killedUnit:IsRealHero() then
		local playerID = killedUnit:GetPlayerID()

		-- Check following hostages
		local hostagesFollowPlayer = self.vPlayerHostages[playerID]
		if hostagesFollowPlayer and #hostagesFollowPlayer > 0 then

			-- Re-arrest the hostages
			for _,hostage in ipairs( hostagesFollowPlayer ) do

				self:_Log( "A hostage has been arrested." )
				self:_Log( "  Hostage ID = " .. hostage.DotaRPG_HostageID )
				self:_Log( "  Player  ID = " .. playerID )

				hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):ToggleAbility()

				if not hostage:FindAbilityByName( "dotarpg_hostage_arrested" ):GetToggleState() then
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
