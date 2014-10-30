
require( "DotaHS_Common" )

--------------------------------------------------------------------------------
-- AI_StrategyManager
--------------------------------------------------------------------------------
if AI_StrategyManager == nil then
	AI_StrategyManager = class({})
	AI_StrategyManager.deltaTime = 0.1
end

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function AI_StrategyManager:PreInitialize()
	-- Thinker
	DotaHS_CreateThink( "AI_StrategyManager:OnThink", function ()
		self:OnThink()
		return AI_StrategyManager.deltaTime
	end )

	-- Register game event listeners
	ListenToGameEvent( "entity_hurt",	Dynamic_Wrap(AI_StrategyManager, "OnEntityHurt"), self )
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function AI_StrategyManager:Initialize()
	-- Velocity
	self.vLastPosition	= {}
	self.vVelocity		= {}
	self.vIsMoving		= {}

	-- History
	self.vLastTime_Hurt		= {}	-- PlayerID : time
	self.vLastTime_Attack	= {}	-- PlayerID : time

	-- Players
	self.vNearestPlayerDistCache	= {}	-- PlayerID : distance
	self.vNearestPlayerDistTTL		= {}	-- PlayerID : time to live
	self.fNearestPlayerCacheDuration	= 0.25

	self.vNearestNonFollowerPlayerDistCache	= {}
	self.vNearestNonFollowerPlayerDistTTL	= {}

	-- Enemies
	self.vNearestEnemyDistCache		= {}	-- PlayerID : distance
	self.vNearestEnemyDistTTL		= {}	-- PlayerID : time to live
	self.fNearestEnemyDistCacheDuration	= 0.5

	-- Tombstone
	self.vTombstones	= {}
	self.fTombstoneCacheTTL = -999999
	self.fTombstoneCacheDuration = 0.5
end

--------------------------------------------------------------------------------
-- OnThink
--------------------------------------------------------------------------------
function AI_StrategyManager:OnThink()
	if not DotaHS_GlobalVars.bGameInProgress then
		return
	end

	-- Check speed
	local minimumSpeed = 150
	DotaHS_ForEachPlayer( function ( playerID, hero )
		if not hero then
			return
		end

		if self.vLastPosition[playerID] then
			-- Calculate velocity
			self.vVelocity[playerID] = ( hero:GetAbsOrigin() - self.vLastPosition[playerID] ) / AI_StrategyManager.deltaTime
			self.vIsMoving[playerID] = self.vVelocity[playerID]:Length2D() > minimumSpeed
		end

		self.vLastPosition[playerID] = hero:GetAbsOrigin()
	end )
end

--------------------------------------------------------------------------------
-- IsMoving
--------------------------------------------------------------------------------
function AI_StrategyManager:IsMoving( playerID )
	return self.vIsMoving[playerID]
end

--------------------------------------------------------------------------------
-- GetLastCombatTime
--------------------------------------------------------------------------------
function AI_StrategyManager:GetLastCombatTime( playerID )
	local timeHurt		= self.vLastTime_Hurt[playerID]
	local timeAttack	= self.vLastTime_Attack[playerID]
	if timeHurt and timeAttack then
		return math.max( timeHurt, timeAttack )
	else
		return timeHurt or timeAttack or 0
	end
end

--------------------------------------------------------------------------------
-- GetElapsedTimeFromLastCombat
--------------------------------------------------------------------------------
function AI_StrategyManager:GetElapsedTimeFromLastCombat( playerID )
	return GameRules:GetGameTime() - self:GetLastCombatTime( playerID )
end

--------------------------------------------------------------------------------
-- Get All Tombstones
--------------------------------------------------------------------------------
function AI_StrategyManager:GetAllTombstones()
	if self.fTombstoneCacheTTL < GameRules:GetGameTime() then
		-- Refresh the cache
		self.vTombstones = Entities:FindAllByClassname( "dota_item_tombstone_drop" )
		self.fTombstoneCacheTTL = GameRules:GetGameTime() + self.fTombstoneCacheDuration

	else
		-- Check tombstones
		for k,v in ipairs( self.vTombstones ) do
			if not IsValidEntity(v) then
				self:_Log( "Tombstone of Player[" .. v.DotaHS_PlayerID .. "] no longer exists." )
				table.remove( self.vTombstones, k )
			end
		end
	end

	return self.vTombstones
end

--------------------------------------------------------------------------------
-- Get Num of Tombstones
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNumTombstones()
	return #self:GetAllTombstones()
end

--------------------------------------------------------------------------------
-- Get Nearest Tombstone
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNearestTombstone( entity )
	local nearestDist = 999999
	local nearest
	for k,v in ipairs( self:GetAllTombstones() ) do
		if v:entindex() ~= entity:entindex() then
			local dist = (v:GetAbsOrigin() - entity:GetAbsOrigin()):Length2D()
			if dist < nearestDist then
				nearestDist = dist
				nearest = v
			end
		end
	end
	return nearest, nearestDist
end

--------------------------------------------------------------------------------
-- GetNearestPlayerDistance
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNearestPlayerDistance( playerID )
	local cacheTTL = self.vNearestPlayerDistTTL[playerID]
	if not cacheTTL or cacheTTL < GameRules:GetGameTime() then

		-- Find nearest player
		local nearestDist = 999999
		local playerUnit = DotaHS_PlayerIDToHeroEntity( playerID )
		if not playerUnit then
			return nearestDist
		end
		local playerPos = playerUnit:GetAbsOrigin()

		DotaHS_ForEachPlayer( function ( otherPlayerID, otherHero )
			if otherHero and IsValidEntity( otherHero ) then
				if otherPlayerID ~= playerID then
					local dist = (otherHero:GetAbsOrigin() - playerPos):Length2D()
					nearestDist = math.min( nearestDist, dist )
				end
			end
		end )

		-- Upcate cache
		self.vNearestPlayerDistCache[playerID] = nearestDist
		self.vNearestPlayerDistTTL[playerID] = GameRules:GetGameTime() + self.fNearestPlayerCacheDuration
	end

	return self.vNearestPlayerDistCache[playerID]
end

--------------------------------------------------------------------------------
-- GetNearestNonFollowerPlayerDistance
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNearestNonFollowerPlayerDistance( playerID )
	local cacheTTL = self.vNearestNonFollowerPlayerDistTTL[playerID]
	if not cacheTTL or cacheTTL < GameRules:GetGameTime() then

		-- Find nearest player
		local nearestDist = 999999
		local playerUnit = DotaHS_PlayerIDToHeroEntity( playerID )
		if not playerUnit then
			return nearestDist
		end
		local playerPos = playerUnit:GetAbsOrigin()

		DotaHS_ForEachPlayer( function ( otherPlayerID, otherHero )
			if otherHero and IsValidEntity( otherHero ) then
				if otherPlayerID ~= playerID then
					-- Is Non Follower?
					if not otherHero.DotaHS_IsFollowerBot then
						local dist = (otherHero:GetAbsOrigin() - playerPos):Length2D()
						nearestDist = math.min( nearestDist, dist )
					end
				end
			end
		end )

		-- Upcate cache
		self.vNearestNonFollowerPlayerDistCache[playerID] = nearestDist
		self.vNearestNonFollowerPlayerDistTTL[playerID] = GameRules:GetGameTime() + self.fNearestPlayerCacheDuration
	end

	return self.vNearestNonFollowerPlayerDistCache[playerID]
end

--------------------------------------------------------------------------------
-- GetNearestEnemyDistance
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNearestEnemyDistance( playerID )
	local cacheTTL = self.vNearestEnemyDistTTL[playerID]
	if not cacheTTL or cacheTTL < GameRules:GetGameTime() then
		
		-- Find nearest enemy
		local findingRange = 1000
		local playerPos = DotaHS_PlayerIDToHeroEntity( playerID ):GetAbsOrigin()

		local enemies = FindUnitsInRadius( DOTA_TEAM_GOODGUYS,
										   playerPos,
										   nil,
										   findingRange,
										   DOTA_UNIT_TARGET_TEAM_ENEMY,
										   DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
										   DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
										   FIND_CLOSEST,
										   false )

		local nearestDist
		if #enemies > 0 then
			nearestDist = ( enemies[1]:GetAbsOrigin() - playerPos ):Length2D()
		else
			nearestDist = findingRange * 1.5
		end

		-- Update cache
		self.vNearestEnemyDistCache[playerID] = nearestDist
		self.vNearestEnemyDistTTL[playerID] = GameRules:GetGameTime() + self.fNearestEnemyDistCacheDuration
	end

	return self.vNearestEnemyDistCache[playerID]
end

--------------------------------------------------------------------------------
-- GetNearestEnemyDistanceFromParty
--------------------------------------------------------------------------------
function AI_StrategyManager:GetNearestEnemyDistanceFromParty( excludePlayerID )
	local nearest = 999999
	DotaHS_ForEachPlayer( function ( playerID, hero )
		if hero and IsValidEntity( hero ) then
			if playerID ~= excludePlayerID then
				local dist = self:GetNearestEnemyDistance( playerID )
				nearest = math.min( nearest, dist )
			end
		end
	end )
	return nearest
end

--------------------------------------------------------------------------------
-- Event Listeners
--------------------------------------------------------------------------------
function AI_StrategyManager:OnEntityHurt( event )
	-- entindex_killed		: long
	-- entindex_attacker	: long
	-- entindex_inflictor	: long
	-- damagebits			: long
	local unitHurted	= EntIndexToHScript( event.entindex_killed )
	local unitAttacker
	if event.entindex_attacker then
		EntIndexToHScript( event.entindex_attacker )
	end
	
	-- Is Player or Follower?
	if unitHurted and unitHurted:GetTeamNumber() == DOTA_TEAM_GOODGUYS and unitHurted:IsRealHero() then
		-- Update LastTime
		local playerID = DotaHS_HeroEntityToPlayerID( unitHurted )
		self.vLastTime_Hurt[playerID] = GameRules:GetGameTime()
	--	self:_Log( "PlayerID[" .. playerID .. "] has taken damage." )
	end

	if unitAttacker and unitAttacker:GetTeamNumber() == DOTA_TEAM_GOODGUYS and unitAttacker:IsRealHero() then
		-- Update LastTime
		local playerID = DotaHS_HeroEntityToPlayerID( unitAttacker )
		self.vLastTime_Attack[playerID] = GameRules:GetGameTime()
	--	self:_Log( "PlayerID[" .. playerID .. "] has attacked." )
	end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function AI_StrategyManager:_Log( text )
	print( "[AI/StrategyManager] " .. text )
end
