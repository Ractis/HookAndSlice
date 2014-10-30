
--------------------------------------------------------------------------------
-- AI_ObstacleManager
--------------------------------------------------------------------------------
if AI_ObstacleManager == nil then
	AI_ObstacleManager = class({})
	AI_ObstacleManager.observeDuration = 0.05	-- 20 FPS
end

local ABILITY_STATE_CASTING			= 1
local ABILITY_STATE_CAST_FAILURE	= 2
local ABILITY_STATE_CAST_SUCCESS	= 3

local OBSTACLE_INFLATE_RADIUS				= 64 + 8	-- cell size + hero's hull radius
local OBSTACLE_DIRECTIONAL_BACKSIDE_MARGIN	= 64*2
local OBSTACLE_DURATION_MIN					= 0.1

OBSTACLE_TYPE_DIRECTIONAL	= "obstacleDirectional"
OBSTACLE_TYPE_CIRCLE		= "obstacleCircle"
OBSTACLE_TYPE_QUADRANT		= "obstacleQuadrant"

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function AI_ObstacleManager:PreInitialize()
	self.vListToObserve =
	{
		-- THINKER
		["THINKER"] = {
			npc_dota_creature_basic_zombie_exploding	= ThinkerProfile_AcidSpray(),
			npc_dota_creature_minor_lich				= ThinkerProfile_ChainFrost(),	-- modifier_lich_chain_frost_thinker
			npc_dota_creature_tormented_soul			= ThinkerProfile_AoESpike(),	-- target_telegraph_fx / aoe_spike_thinker
			npc_dotahs_faerie_dragon					= ThinkerProfile_DreamCoil(),	-- modifier_dream_coil_thinker
		},

		-- NEUTRAL UNITS
		["NEUTRALS"] = {
			npc_dota_rattletrap_cog	= true,
		},

		npc_dota_rattletrap_cog = {
			AbilityProfile_Cog(),
		},

		-- Holdout creatures
		npc_dota_creature_basic_zombie_exploding = {
			AbilityProfile_PreAcidSpray(),
		},
		npc_dota_creature_slithereen = {
			creature_slithereen_crush	= AbilityProfile_Circle( 0, 350, 0.25 ),
		},
		npc_dota_creature_mini_roshan = {
			AbilityProfile_FireBreath( 0, nil ),
			AbilityProfile_FireBreath( -0.3, "proj" ),	-- Projectile delay
			AbilityProfile_FireBreath(  0.3, "pred"),	-- Prediction
		},

		-- DotaHS Creatures
		npc_dotahs_jakiro = {
			dotahs_creature_ice_path	= AbilityProfile_Directional( 1100, 150, 3.0 ),
			dotahs_creature_macropyre	= AbilityProfile_Directional( 900, 225, 4.0 ),
		},
		npc_dotahs_magnus = {
			dotahs_creature_skewer		= AbilityProfile_Directional( 750, 125, 0.75 ),
		},
		npc_dotahs_nevermore = {
			dotahs_creature_shadowraze1	= AbilityProfile_Circle( 200, 100--[[150]], 0.25 ),
			dotahs_creature_shadowraze2	= AbilityProfile_Circle( 450, 100--[[150]], 0.25 ),
			dotahs_creature_shadowraze3	= AbilityProfile_Circle( 700, 100--[[150]], 0.25 ),
		},
		npc_dotahs_nyxnyxnyx = {
			dotahs_creature_nyx_impale	= AbilityProfile_Directional( 700, 125, 0.5 ),
		},
		npc_dotahs_phoenix = {
			AbilityProfile_PhoenixSun(),	-- npc_dota_phoenix_sun
		},
		npc_dotahs_pudge = {
			dotahs_creature_meat_hook	= AbilityProfile_Directional( 1100, 100, 0.5 ),
		},
		npc_dotahs_tusk = {
			dotahs_creature_ice_shards	= AbilityProfile_Directional( 1800, 200, 1.75 ),
		},
	}

	-- Register event listener
--	ListenToGameEvent( "dota_non_player_used_ability", Dynamic_Wrap(AI_ObstacleManager, "OnNPCUsedAbility"), self )
	ListenToGameEvent( "npc_spawned",	Dynamic_Wrap(AI_ObstacleManager, "OnNPCSpawn"),		self)
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function AI_ObstacleManager:Initialize()
	self.vObstacleMap	= {}	-- entindex : obstacle
	self.vListenerList	= {}
	self.vForceFieldMap	= {}
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:Update()
	for k,v in pairs( self.vObstacleMap ) do
		if v:IsExpired() then
			self:RemoveObstacle(k)
		end
	end
	for k,v in pairs( self.vForceFieldMap ) do
		if v:IsExpired() then
			self:RemoveForceField(k)
		end
	end
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:GetOverlappingObstacles( bounds )
	local overlappings = {}
	for k,v in pairs( self.vObstacleMap ) do
		if v.bounds:Intersect( bounds ) then
			table.insert( overlappings, v )
		end
	end
	return overlappings
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:AddListener( listener )
	table.insert( self.vListenerList, listener )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:_DispatchEvent( callbackName, obstacle )
	for k,v in pairs( self.vListenerList ) do
		v[callbackName]( v, obstacle )
	end
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:OnNPCUsedAbility( event )
	DeepPrintTable( event )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:OnNPCSpawn( event )
	local unitSpawned = EntIndexToHScript( event.entindex )

--	self:_Log( "--------------------------------------------------")
--	self:_Log( unitSpawned:GetUnitName() .. " has spawned." )

	if unitSpawned:GetTeamNumber() ~= DOTA_TEAM_BADGUYS then
		if unitSpawned:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
			return
		end
		if not self.vListToObserve["NEUTRALS"][unitSpawned:GetUnitName()] then
			return
		end
		-- The team of this unit may become DOTA_TEAM_BADGUYS
	end
	if unitSpawned:IsPhantom() then
		return
	end

--	self:_Log( "--------------------------------------------------")
--	self:_Log( unitSpawned:GetUnitName() .. " has spawned." )
--	self:_Log( "Frame Count : " .. GetFrameCount() )
--	self:_Log( "Position : " .. tostring(unitSpawned:GetAbsOrigin()) )
--	self:_Log( "Classname is " .. unitSpawned:GetClassname() )
--	self:_Log( "TEAM is " .. unitSpawned:GetTeam() )
--	self:_Log( "Opposing Team is " .. unitSpawned:GetOpposingTeamNumber() )
--	local owner = unitSpawned:GetOwner()
--	if owner and owner.GetUnitName then
--		self:_Log( "Owner is " .. unitSpawned:GetOwner():GetUnitName() )
--	end

	-- Grab ability list
	local isThinker = unitSpawned:GetUnitName() == "npc_dota_thinker"
--	local isEmpty = unitSpawned:GetUnitName() == "" and unitSpawned:GetClassname() == "npc_dota_base"
	local abilitiesToObserve

	if not isThinker and not isEmpty then
		abilitiesToObserve = self.vListToObserve[unitSpawned:GetUnitName()]

	elseif isThinker then
		-- Grab thinker profile
		local owner = unitSpawned:GetOwner()
		local ownerName = owner:GetUnitName()
		local thinkerProfile = self.vListToObserve["THINKER"][ownerName]

		if not thinkerProfile then
			self:_Log( "Thinker Profiler not found. Owner = " .. ownerName )
			return
		end

		-- Apply thinker immediately
		thinkerProfile:Apply( unitSpawned, owner )

	else
		-- Empty?
	--	self:_Log( "This is an EMPTY UNIT. " )
		abilitiesToObserve = nil

	end

	if not abilitiesToObserve then
		return
	end

	-- Observe it
	local enemy = unitSpawned
	local abilityStateMap = {}

	enemy:SetContextThink( "UpdateObstacle", function ()
		if enemy:IsDominated() then
			return nil
		end
		if enemy:GetTeam() ~= DOTA_TEAM_BADGUYS then
			return nil
		end

		-- This is an empty unit!
		if isEmpty then
		--	for i=1, enemy:GetModifierCount() do
		--		AI_ObstacleManager:_Log( "MODIFIER[" .. i .. "] : " .. enemy:GetModifierNameByIndex( i-1 ) )
		--	end
			AI_ObstacleManager:_Log( "POS : " .. tostring( enemy:GetAbsOrigin() ) )
			return AI_ObstacleManager.observeDuration
		end

		-- For each abilities
		for k,abilityProfile in pairs( abilitiesToObserve ) do

			local ability = enemy:FindAbilityByName( tostring(k) )
			if ability then

				local abilityID = ability:entindex()

				if ability:IsInAbilityPhase() then

					self:AddOrUpdateObstacle( abilityID, abilityProfile, enemy )
					abilityStateMap[k] = ABILITY_STATE_CASTING

				elseif abilityStateMap[k] == ABILITY_STATE_CASTING then

					if ability:IsCooldownReady() then
						-- Failed
						AI_ObstacleManager:RemoveObstacle( abilityID )
					--	AI_ObstacleManager:_Log( "FAILURE : " .. k )
						abilityStateMap[k] = ABILITY_STATE_CAST_FAILURE
					else
						-- Succeeded
					--	AI_ObstacleManager:_Log( "SUCCESS : " .. k )
						abilityStateMap[k] = ABILITY_STATE_CAST_SUCCESS
					end

				end

			else
				-- Use profile to determine the state
			--	for i=1, enemy:GetModifierCount() do
			--		AI_ObstacleManager:_Log( "MODIFIER[" .. i .. "] : " .. enemy:GetModifierNameByIndex( i-1 ) )
			--	end

				if abilityProfile:IsActive( enemy ) then
					local abilityID = enemy:entindex()
					if abilityProfile.abilityIDSuffix then
						abilityID = abilityID .. abilityProfile.abilityIDSuffix
					end
					self:AddOrUpdateObstacle( abilityID, abilityProfile, enemy )
				end
			end
		end

		return AI_ObstacleManager.observeDuration
	end, AI_ObstacleManager.observeDuration )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:HasObstacle()
	return self:NumObstacles() > 0
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:NumObstacles()
	local n = 0
	for k,v in pairs( self.vObstacleMap ) do
		n = n + 1
	end
	return n
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:AddOrUpdateObstacle( abilityID, abilityProfile, caster )
	local obstacle = self.vObstacleMap[abilityID]
	if obstacle then
		if obstacle:ApproxEquals( caster:GetAbsOrigin(), caster:GetForwardVector() ) then
			-- Just refresh the timer
			obstacle:RefreshTimer()
			return
		else
			self:RemoveObstacle( abilityID )
		end
	end

	-- Create new
	obstacle = abilityProfile:CreateObstacle( caster )
	obstacle.caster = caster
	obstacle.casterID = caster:entindex()
	self.vObstacleMap[abilityID] = obstacle
	self:_DispatchEvent( "OnAddedObstacle", obstacle )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:RemoveObstacle( abilityID )
	local obstacle = self.vObstacleMap[abilityID]
	self.vObstacleMap[abilityID] = nil
	self:_DispatchEvent( "OnRemovedObstacle", obstacle )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:AddOrUpdateForceField( forceField )
	if self.vForceFieldMap[forceField.name] then
		-- Remove the old one
		self:RemoveForceField( forceField.name )
	end

	-- Add new
	self.vForceFieldMap[forceField.name] = forceField
	self:_DispatchEvent( "OnAddedForceField", forceField )
end

--------------------------------------------------------------------------------
function AI_ObstacleManager:RemoveForceField( forceFieldName )
	local forceField = self.vForceFieldMap[forceFieldName]
	self.vForceFieldMap[forceFieldName] = nil
	self:_DispatchEvent( "OnRemovedForceField", forceField )
end

--------------------------------------------------------------------------------
-- Debug draw
--------------------------------------------------------------------------------
function AI_ObstacleManager:DebugDraw()
	for k,v in pairs( self.vObstacleMap ) do
		v:DebugDraw()
	end
	for k,v in pairs( self.vForceFieldMap ) do
		v:DebugDraw()
	end
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function AI_ObstacleManager:_Log( text )
	print( "[AI/ObstacleManager] " .. text )
end

function AI_ObstacleManager:DumpModifiers( unit )
	for i=1, unit:GetModifierCount() do
		AI_ObstacleManager:_Log( "MODIFIER[" .. i .. "] : " .. unit:GetModifierNameByIndex( i-1 ) )
	end
end





--------------------------------------------------------------------------------
-- Bounding Box in Global Grid Space
--------------------------------------------------------------------------------
if AABB == nil then
	AABB = class({})
	AABB.EPSILON = 0.1
end

function AABB:constructor( minmax )
	self.centerX = 0
	self.centerY = 0
	self.extentX = 0
	self.extentY = 0
end

function AABB.CreateFromWorldMinMax( worldMinMax )
	return AABB.CreateFromGridMinMax( {
		GridNav:WorldToGridPosX( worldMinMax[1] ),
		GridNav:WorldToGridPosY( worldMinMax[2] ),
		GridNav:WorldToGridPosX( worldMinMax[3] ),
		GridNav:WorldToGridPosY( worldMinMax[4] ),
	} )
end

function AABB.CreateFromGridMinMax( minmax )
	local bounds = AABB()
	bounds.centerX = ( minmax[3] + minmax[1] ) / 2
	bounds.centerY = ( minmax[4] + minmax[2] ) / 2
	bounds.extentX = minmax[3] - bounds.centerX
	bounds.extentY = minmax[4] - bounds.centerY
	return bounds
end

function AABB:__tostring()
	return ("Center = ( %.1f, %.1f ), Extents = ( %.1f, %.1f )"):format( self.centerX, self.centerY, self.extentX, self.extentY )
end

function AABB:Intersect( other )
	if math.abs( self.centerX - other.centerX ) > ( self.extentX + other.extentX + AABB.EPSILON ) then return false end
	if math.abs( self.centerY - other.centerY ) > ( self.extentY + other.extentY + AABB.EPSILON ) then return false end
	return true
end





--------------------------------------------------------------------------------
-- Ability Profiles
--------------------------------------------------------------------------------
AbilityProfile_Directional = class({})

function AbilityProfile_Directional:constructor( range, radius, duration )
	self.range		= range
	self.width		= radius * 2
	self.duration	= duration
end

function AbilityProfile_Directional:CreateObstacle( caster )
	return Obstacle_Directional( caster:GetAbsOrigin(), caster:GetForwardVector(), caster:GetRightVector(), self.range, self.width, self.duration )
end

--------------------------------------------------------------------------------
AbilityProfile_Circle = class({})

function AbilityProfile_Circle:constructor( range, radius, duration )
	self.range		= range
	self.radius		= radius
	self.duration	= duration
end

function AbilityProfile_Circle:CreateObstacle( caster )
	return Obstacle_Circle( caster:GetAbsOrigin(), caster:GetForwardVector(), self.range, self.radius, self.duration )
end

--------------------------------------------------------------------------------
AbilityProfile_PreAcidSpray = class({}, nil, AbilityProfile_Circle)

function AbilityProfile_PreAcidSpray:constructor()
	AbilityProfile_Circle.constructor( self, 0, 250, OBSTACLE_DURATION_MIN )
end

function AbilityProfile_PreAcidSpray:IsActive( caster )
	return caster:GetHealthPercent() < 25
end

--------------------------------------------------------------------------------
AbilityProfile_FireBreath = class({})

AbilityProfile_FireBreath.advanceProgress = 0

function AbilityProfile_FireBreath:constructor( advanceProgress, suffix )
	self.advanceProgress = advanceProgress
	self.abilityIDSuffix = suffix
end

function AbilityProfile_FireBreath:IsActive( caster )
	--
	-- CastPoint	= 1.3
	-- ChannelTime	= 2.3
	--
	-- CastRange = "500 600 700 800 900"
	--
	-- radius = 200
	-- speed ? = 1000
	-- rotation_angle = 90	-- anti-clockwise
	-- projectile_cound = 12
	--
	local ability = caster:FindAbilityByName( "creature_fire_breath" )
	if ability:IsInAbilityPhase() then
		return true
	end
	if ability:IsChanneling() then
		return true
	end
	return false
end

function AbilityProfile_FireBreath:_CalculateProgress( ability )
	if ability:IsChanneling() then
		local currentChannelTime = GameRules:GetGameTime() - ability:GetChannelStartTime()
		local channelDuration = 2.3
		return currentChannelTime / channelDuration
	else
		return 0.0
	end
end

function AbilityProfile_FireBreath:_CreateObstacleImpl( caster, ability, angle )
	local forward	= caster:GetForwardVector()
	local right		= caster:GetRightVector()
	local range		= ability:GetCastRange() + 64*2
	local width		= 200 + 64*2
	local duration	= 0.3

	forward	= RotatePosition( Vector(0,0,0), QAngle(0,angle,0), forward )
	right	= RotatePosition( Vector(0,0,0), QAngle(0,angle,0), right )

	return Obstacle_Directional( caster:GetAbsOrigin(), forward, right, range, width, duration )
end

function AbilityProfile_FireBreath:CreateObstacle( caster )
	local ability	= caster:FindAbilityByName( "creature_fire_breath" )

	local progress = self:_CalculateProgress( ability )
	progress = math.min( math.max( progress + self.advanceProgress, 0.0 ), 1.0 )
	local angle = ( progress - 0.5 ) * 90
	
	return self:_CreateObstacleImpl( caster, ability, angle )
end

--------------------------------------------------------------------------------
AbilityProfile_PhoenixSun = class({})

function AbilityProfile_PhoenixSun:IsActive( caster )
	return caster:HasModifier( "modifier_phoenix_supernova_hiding" )
end

function AbilityProfile_PhoenixSun:CreateObstacle( caster )
	local ability = caster:FindAbilityByName( "dotahs_creature_supernova" )
	local radius = DotaHS_GetAbilitySpecialValue( ability, "aura_radius" )
	return Obstacle_Circle( caster:GetAbsOrigin(), Vector( 0, 0, 1 ), 0, radius, OBSTACLE_DURATION_MIN )
end

--------------------------------------------------------------------------------
AbilityProfile_Cog = class({})

function AbilityProfile_Cog:IsActive( cog )
--	print( "Cog - TEAM : " .. cog:GetTeam() )
--	for i=1, cog:GetModifierCount() do
--		print( "Cog - MODIFIER[" .. i .. "] : " .. cog:GetModifierNameByIndex( i-1 ) )
--	end
	
	if cog.cogX == nil then
		-- Calculate alignment of this cog
		local owner = cog:GetOwner()
		local dir = cog:GetAbsOrigin() - owner:GetAbsOrigin()
		dir.z = 0
		dir = dir:Normalized()

		if dir.x < -0.5 then
			cog.cogX = -1
		elseif dir.x > 0.5 then
			cog.cogX = 1
		else
			cog.cogX = 0
		end

		if dir.y <= -0.5 then
			cog.cogY = -1
		elseif dir.y >= 0.5 then
			cog.cogY = 1
		else
			cog.cogY = 0
		end

	--	print( "Cog - X=" .. cog.cogX .. ", Y=" .. cog.cogY )
	end

	return true
end

function AbilityProfile_Cog:CreateObstacle( cog )
	local radius = 225
	return Obstacle_Quadrant( cog:GetAbsOrigin(), Vector( cog.cogX, cog.cogY, 0 ), radius, OBSTACLE_DURATION_MIN  )
end





--------------------------------------------------------------------------------
-- Thinker Profiles
--------------------------------------------------------------------------------
ThinkerProfile_AcidSpray = class({})

function ThinkerProfile_AcidSpray:Apply( thinker, owner )
	local radius = 250
	local duration = 16 - 4
	local name = DoUniqueString( "AcidSpray" )
	AI_ObstacleManager:AddOrUpdateObstacle( name, AbilityProfile_Circle( 0, radius, duration ), owner )
end

--------------------------------------------------------------------------------
ThinkerProfile_ChainFrost = class({})

function ThinkerProfile_ChainFrost:Apply( thinker, owner )
	-- Have bounced?
	local ability = owner:FindAbilityByName( "creature_minor_chain_frost" )
	local cdRemaining = ability:GetCooldownTimeRemaining()
	local cdDefault = ability:GetCooldown( ability:GetLevel() - 1 )
	local isInitial = ( cdDefault - cdRemaining ) < 1e-2

--	print( "ChainFrost - Is initial? : " .. tostring( isInitial ) )

	-- Find close heroes
	local range = 750
	local jumpRange = 575

	if not isInitial then
		range = jumpRange
	end

	local nearestPlayers = FindUnitsInRadius( thinker:GetTeam(),
											  thinker:GetAbsOrigin(),
											  nil,
											  range,
											  DOTA_UNIT_TARGET_TEAM_ENEMY,
											  DOTA_UNIT_TARGET_HERO,
											  0,
											  FIND_CLOSEST,
											  false )

	if #nearestPlayers == 0 then
		print( "ChainFrost - Nearest player not found." )
		return
	end

	-- Attach separation operator
	local duration = 1.25

	if isInitial then
		-- Apply to all
		for _,v in ipairs(nearestPlayers) do
			AI_ObstacleManager:AddOrUpdateForceField( ForceField_UnitSeparation( v, owner, jumpRange, duration ) )
		end

	else
		-- Apply to two nearest
		if #nearestPlayers == 1 then
			print( "ChainFrost - Second nearest player not found." )
			return
		end

		AI_ObstacleManager:AddOrUpdateForceField( ForceField_UnitSeparation( nearestPlayers[1], owner, jumpRange, duration ) )
		AI_ObstacleManager:AddOrUpdateForceField( ForceField_UnitSeparation( nearestPlayers[2], owner, jumpRange, duration ) )

	end

end

--------------------------------------------------------------------------------
ThinkerProfile_AoESpike = class({})

function ThinkerProfile_AoESpike:Apply( thinker, owner )
	local ability = owner:FindAbilityByName( "creature_aoe_spikes" )
	local radius = DotaHS_GetAbilitySpecialValue( ability, "impact_radius" )
	local duration = 2.0
	local name = "AoESpike_" .. owner:entindex()
	AI_ObstacleManager:AddOrUpdateObstacle( name, AbilityProfile_Circle( 0, radius, duration ), thinker )
end

--------------------------------------------------------------------------------
ThinkerProfile_DreamCoil = class({})

function ThinkerProfile_DreamCoil:Apply( thinker, owner )
	local ability = owner:FindAbilityByName( "dotahs_creature_dream_coil" )
	local coilRadius = DotaHS_GetAbilitySpecialValue( ability, "coil_radius" )

	-- Find coiled units
	local dreamCoiledUnits = FindUnitsInRadius( thinker:GetTeam(),
												thinker:GetAbsOrigin(),
												nil,
												coilRadius,
												DOTA_UNIT_TARGET_TEAM_ENEMY,
												DOTA_UNIT_TARGET_HERO,
												0,
												0,
												false )

	print( "DreamCoil - " .. #dreamCoiledUnits .. " dream coiled units found." )

	if #dreamCoiledUnits == 0 then
		-- Not found
		return
	end

	local map = {}
	for k,v in ipairs(dreamCoiledUnits) do
		map[v:entindex()] = true
	end

	AI_ObstacleManager:AddOrUpdateForceField( ForceField_DreamCoil( thinker, owner, map ) )
end





--------------------------------------------------------------------------------
--
-- ForceFields
--
--------------------------------------------------------------------------------
ForceFieldBase = class({})

function ForceFieldBase:constructor( name, entity, radius, duration )
	self.name		= name
	self.entity		= entity
	self.entityID	= entity:entindex()
	self.radius		= radius + OBSTACLE_INFLATE_RADIUS

	self.timeToExpire = GameRules:GetGameTime() + duration
end

function ForceFieldBase:IsExpired()
	return self.timeToExpire <= GameRules:GetGameTime()
end

function ForceFieldBase:FilterUnit( unit )
	if unit:entindex() == self.entityID then
		-- myself
		return false
	end
	return true
end

function ForceFieldBase:CalculateForce( unit )
	if not IsValidEntity( self.entity ) then
		return nil
	end
	if unit:entindex() == self.entityID then
		-- myself
		return nil
	end

	local relativePos = unit:GetAbsOrigin() - self.entity:GetAbsOrigin()
	relativePos.z = 0
	local dist = relativePos:Length2D()

	if dist <= 0 or dist > self.radius then
		return nil
	end

	return self:CalculateForceImpl( relativePos )
end

function ForceFieldBase:CalculateForceImpl( relativePos )
	print( "[AI/ForceField] CalculateForceImpl is not implemented." )
end

function ForceFieldBase:DebugDraw()
	if not IsValidEntity( self.entity ) then
		return
	end

	-- Draw Circle
	DebugDrawCircle( self.entity:GetAbsOrigin(), Vector( 255, 128, 0 ), 0.0, self.radius, true, 1.0 )
end

--------------------------------------------------------------------------------
-- ForceField / UnitSeparation
--------------------------------------------------------------------------------
ForceField_UnitSeparation = class({}, nil, ForceFieldBase)

function ForceField_UnitSeparation:constructor( unitAttached, caster, radius, duration )
	local unitAttachedID	= unitAttached:entindex()
	local casterID			= caster:entindex()

	local name = "Separation_" .. unitAttachedID .. "_" .. casterID

	ForceFieldBase.constructor( self, name, unitAttached, radius, duration )
end

function ForceField_UnitSeparation:CalculateForceImpl( relativePos )
	return relativePos:Normalized()
end

--------------------------------------------------------------------------------
-- ForceField / DreamCoil
--------------------------------------------------------------------------------
ForceField_DreamCoil = class({}, nil, ForceFieldBase)
ForceField_DreamCoil.coilBreakRadiusMin = 600 - OBSTACLE_INFLATE_RADIUS		-- Range to caution

function ForceField_DreamCoil:constructor( coil, puck, dreamCoiledUnitMap )
	local name = "DreamCoil_" .. puck:entindex()

	-- coil_duration		= "6.0 6.0 6.0"
	-- coil_radius			= "375 375 375"
	-- coil_break_radius	= "600 600 600"
	local radius = 600-- + OBSTACLE_INFLATE_RADIUS

	ForceFieldBase.constructor( self, name, coil, radius, 6.0 )

	self.dreamCoiledUnitMap = dreamCoiledUnitMap
end

function ForceField_DreamCoil:FilterUnit( unit )
	return self.dreamCoiledUnitMap[unit:entindex()]
end

function ForceField_DreamCoil:CalculateForce( unit )
	local isCoiled = unit:HasModifier( "modifier_puck_coiled" )
	if not isCoiled then
		return nil
	end

	return ForceFieldBase.CalculateForce( self, unit )
end

function ForceField_DreamCoil:CalculateForceImpl( relativePos )
	local radius = relativePos:Length2D()
	if radius < self.coilBreakRadiusMin then
		return nil
	end

	-- Pull back to center of the coil
	local magniture = 50
	local dir = -relativePos:Normalized()
	return dir * magniture
end

function ForceField_DreamCoil:DebugDraw()
	if not IsValidEntity( self.entity ) then
		return
	end

	-- Draw Circle
	DebugDrawCircle( self.entity:GetAbsOrigin(), Vector( 255, 128, 0 ), 0.0, self.radius, true, 1.0 )
	DebugDrawCircle( self.entity:GetAbsOrigin(), Vector( 128, 64, 0 ), 0.0, self.coilBreakRadiusMin, true, 1.0 )
end





--------------------------------------------------------------------------------
--
-- Obstacles
--
--------------------------------------------------------------------------------
local ObstacleBase = class({})

function ObstacleBase:constructor( type, origin, direction, duration )
	self.type		= type
	self.origin		= origin
	self.direction	= direction
	self.duration	= duration

	self:RefreshTimer()
end

function ObstacleBase:SetWorldMinMax( minmax )
	self.worldMinMax = minmax
	self.bounds = AABB.CreateFromWorldMinMax( minmax )
end

function ObstacleBase:RefreshTimer()
	self.timeToExpire = GameRules:GetGameTime() + self.duration
end

function ObstacleBase:IsExpired()
	return self.timeToExpire <= GameRules:GetGameTime()
end

function ObstacleBase:ApproxEquals( origin, direction )
	local lengthOrigin = ( self.origin - origin ):Length2D()
	local lengthDirection = ( self.direction - direction ):Length2D()	-- ok?
	return lengthOrigin < 1e-5 and lengthDirection < 1e-5
end

function ObstacleBase:DebugDraw()
	-- override me
	self:DebugDrawAABB()
end

function ObstacleBase:DebugDrawAABB()
	DebugDrawBox( Vector( 0, 0, self.origin.z ), Vector( self.worldMinMax[1], self.worldMinMax[2], 0 ), Vector( self.worldMinMax[3], self.worldMinMax[4], 0 ), 255, 255, 255, 0, 1.0 )
end



--------------------------------------------------------------------------------
-- Obstacle / Directional
--------------------------------------------------------------------------------
Obstacle_Directional = class({}, nil, ObstacleBase)

function Obstacle_Directional:constructor( origin, direction, right, range, width, duration )
	ObstacleBase.constructor( self, OBSTACLE_TYPE_DIRECTIONAL, origin, direction, duration )

	range = range + OBSTACLE_INFLATE_RADIUS * 2 + OBSTACLE_DIRECTIONAL_BACKSIDE_MARGIN
	width = width + OBSTACLE_INFLATE_RADIUS * 2
	
	self.right = right
	self.range = range
	self.width = width

	local halfRange = range/2
	local halfWidth = width/2

	self.boxCenter = origin + direction * ( halfRange - OBSTACLE_DIRECTIONAL_BACKSIDE_MARGIN )
	self.boxMin = Vector( -halfRange, -halfWidth, 0 )
	self.boxMax = Vector(  halfRange,  halfWidth, 0 )
	self.boxColor = Vector( 0, 255, 255 )

	local corners = {
		self.boxCenter - direction * halfRange - right * halfWidth,
		self.boxCenter + direction * halfRange - right * halfWidth,
		self.boxCenter + direction * halfRange + right * halfWidth,
		self.boxCenter - direction * halfRange + right * halfWidth,
	}
	local minmax = { 999999, 999999, -999999, -999999 }
	for _,corner in ipairs(corners) do
		minmax[1] = math.min( minmax[1], corner.x )
		minmax[2] = math.min( minmax[2], corner.y )
		minmax[3] = math.max( minmax[3], corner.x )
		minmax[4] = math.max( minmax[4], corner.y )
	end

	local gridCorners = {}
	for i=1, #corners do
		gridCorners[i] = {
			x = GridNav:WorldToGridPosX( corners[i].x ),
			y = GridNav:WorldToGridPosY( corners[i].y ),
		}
	end

	self:SetWorldMinMax( minmax )

	self.corners = gridCorners
end

function Obstacle_Directional:DebugDraw()
	-- Draw OBB
	DebugDrawBoxDirection( self.boxCenter, self.boxMin, self.boxMax, self.direction, self.boxColor, 1.0, 1.0 )
	-- Draw AABB
--	self:DebugDrawAABB()
	-- Draw Right Direction
--	DebugDrawLine( self.boxCenter, self.boxCenter + self.right * self.width/2, 255, 255, 255, false, 1.0 ) 
end

--------------------------------------------------------------------------------
-- Obstacle / Circle
--------------------------------------------------------------------------------
Obstacle_Circle = class({}, nil, ObstacleBase)

function Obstacle_Circle:constructor( origin, direction, range, radius, duration )
	ObstacleBase.constructor( self, OBSTACLE_TYPE_CIRCLE, origin, direction, duration )

	radius = radius + OBSTACLE_INFLATE_RADIUS
	local center = origin + direction * range

	local minmax = {
		center.x - radius,
		center.y - radius,
		center.x + radius,
		center.y + radius,
	}
	self:SetWorldMinMax( minmax )

	self.circleRadius = radius
	self.circleCenter = center
	self.circleColor = Vector( 0, 255, 255 )
end

function Obstacle_Circle:DebugDraw()
	-- Draw Circle
	DebugDrawCircle( self.circleCenter, self.circleColor, 0.0, self.circleRadius, true, 1.0 )
	-- Draw AABB
--	self:DebugDrawAABB()
end

--------------------------------------------------------------------------------
-- Obstacle / Quadrant
--------------------------------------------------------------------------------
Obstacle_Quadrant = class({}, nil, ObstacleBase)

function Obstacle_Quadrant:constructor( origin, direction, radius, duration )
	ObstacleBase.constructor( self, OBSTACLE_TYPE_QUADRANT, origin, direction, duration )

--	origin = origin + direction * -OBSTACLE_INFLATE_RADIUS
	radius = radius + OBSTACLE_INFLATE_RADIUS-- * 2
	local vertex = direction:Normalized() * radius

	local corners = {
		origin,
		origin + RotatePosition( Vector(0,0,0), QAngle(0,-45,0), vertex ),
		origin + vertex,
		origin + RotatePosition( Vector(0,0,0), QAngle(0, 45,0), vertex ),
	}
	local minmax = { 999999, 999999, -999999, -999999 }
	for _,corner in ipairs(corners) do
		minmax[1] = math.min( minmax[1], corner.x )
		minmax[2] = math.min( minmax[2], corner.y )
		minmax[3] = math.max( minmax[3], corner.x )
		minmax[4] = math.max( minmax[4], corner.y )
	end

	local gridCorners = {}
	for i=1, #corners do
		gridCorners[i] = {
			x = GridNav:WorldToGridPosX( corners[i].x ),
			y = GridNav:WorldToGridPosY( corners[i].y ),
		}
	end

	self:SetWorldMinMax( minmax )

	self.corners = gridCorners
	self.vertices = corners
end

function Obstacle_Quadrant:DebugDraw()
	-- Draw Quadrant
	self:_DrawLine( 1, 2 )
	self:_DrawLine( 1, 3 )
	self:_DrawLine( 1, 4 )
	self:_DrawLine( 2, 3 )
	self:_DrawLine( 3, 4 )
	-- Draw AABB
--	self:DebugDrawAABB()
end

function Obstacle_Quadrant:_DrawLine( i1, i2 )
	DebugDrawLine( self.vertices[i1], self.vertices[i2], 0, 255, 255, true, 1.0 )
end
