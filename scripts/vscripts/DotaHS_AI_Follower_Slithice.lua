
require( "DotaHS_AI_FollowerBase" )

--------------------------------------------------------------------------------
--
-- NOTES
--
-- Naga Siren
--   - Turn Rate : 0.5
--   - Turn time rate to 180 deg : 0.18 sec
--   - Movement Speed : 320
--   - MS * TurnTime180 = 57.6
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AI / Naga Siren
--------------------------------------------------------------------------------
if AI_Slithice == nil then
	AI_BehaviorTreeBuilder_NagaSiren = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Slithice = class({}, nil, AI_FollowerBase)

	AI_Slithice.btreeBuilderClass = AI_BehaviorTreeBuilder_NagaSiren

	-- Hero specific properties
	AI_Slithice.unitClassname	= "npc_dota_hero_naga_siren"
	AI_Slithice.unitShortname	= "NagaSiren"

	AI_Slithice.vAbilityNameList = {
		"naga_siren_mirror_image",			-- 1
		"naga_siren_ensnare",				-- 2
		"naga_siren_rip_tide",				-- 3
		"naga_siren_song_of_the_siren",		-- 4
		"naga_siren_song_of_the_siren_cancel",
		"attribute_bonus",
	}
	AI_Slithice.vAbilityUpgradeSequence = {
		3, 1, 3, 2, 3,
		4, 3, 1, 2, 1,
		4, 1, 2, 2, 6,
		4, 6, 6, 6, 6,
		6, 6, 6, 6, 6,
	}

	AI_Slithice.vItemPropertyRating = {
		damage	= 3,
		str		= 3,
		agi		= 5,
		int		= 1,
		as		= 3,
		armor	= 2,
		mr		= 2,
		hp		= 4,
		mana	= 1,
		hpreg	= 3,
		manareg	= 3,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
-- AI_Slithice
--------------------------------------------------------------------------------
function AI_Slithice:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_mirror_image				= unit:FindAbilityByName( "naga_siren_mirror_image" )
	self.ABILITY_ensnare					= unit:FindAbilityByName( "naga_siren_ensnare" )
	self.ABILITY_rip_tide					= unit:FindAbilityByName( "naga_siren_rip_tide" )
	self.ABILITY_song_of_the_siren			= unit:FindAbilityByName( "naga_siren_song_of_the_siren" )
	self.ABILITY_song_of_the_siren_cancel	= unit:FindAbilityByName( "naga_siren_song_of_the_siren_cancel" )
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Slithice:COND_SingingSirenSong()
	return self.entity:HasModifier( "modifier_naga_siren_song_of_the_siren_aura" )
end

--------------------------------------------------------------------------------
function AI_Slithice:COND_ReviveWithIllusions()
	return #self.vIllusions > 0
end

--------------------------------------------------------------------------------
function AI_Slithice:COND_ReadyForRipTide()
	if not self.ABILITY_rip_tide:IsFullyCastable() then
		return false
	end

	local ripTideRadius = 320

	local minimumTargets = 3
	local enemies = self:FindEnemiesInRange( ripTideRadius )

	-- Volatile
	--   Related to AbilityProfile_PreAcidSpray
	local volatileRadius = 250 + 50
	local castRipTideToVolatile = false
	for k,v in ipairs(enemies) do
		if v:GetUnitName() == "npc_dota_creature_basic_zombie_exploding" then
			if v:GetHealthPercent() < 25 then
				castRipTideToVolatile = true

				local friendsInRange = self:FriendlyHeroesInRange( volatileRadius, v:GetAbsOrigin() )
				if #friendsInRange > 0 then
					-- Danger to cast rip tide
					return false
				end
			end
		end
	end
	if castRipTideToVolatile then
		return true
	end

	-- Efficiency
	if #enemies >= minimumTargets then
		return true
	end

	return false
end

--------------------------------------------------------------------------------
function AI_Slithice:COND_CastMirrorImageForRevive()
	if not self.ABILITY_mirror_image:IsFullyCastable() then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Slithice:COND_CastSirenSongForRevive()
	--
	-- Check list :
	--   - Tombstone nearby?
	--   - Castable?
	--   - more than 50% players are dead?
	--   - Enemies nearby exist?
	--

	-- Close enough to tombstone?
	local tombstoneAcceptableRadius = 400
	local tombstone, tombstoneDist = AI_StrategyManager:GetNearestTombstone( self.entity )
	if tombstoneDist > tombstoneAcceptableRadius then
		-- Move to tombstone before cast siren song
		return false
	end

	-- Castable?
	if not self.ABILITY_song_of_the_siren:IsFullyCastable() then
		return false
	end

	-- 50% or more players dead?
	local nDead = AI_StrategyManager:GetNumTombstones()
	local deadPercent = nDead / DotaHS_NumPlayers() * 100
	if deadPercent < 50 then
		return false
	end

	-- Enemies nearby?
	local radius = 800
	local minEnemies = 3
	local enemies = self:FindEnemiesInRange( radius )
	if #enemies < minEnemies then
		return false
	end

	-- Sing!
	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Slithice:ACT_CollectIllusionsForRevive()
	self:_Log( "Collecting Markers for Reviving..." )

	local units = { unpack( self.vIllusions ) }
	table.insert( units, self.entity )
	-- Shuffle them
	for i=1, #units do
		local j = RandomInt( 1, #units )
		units[i], units[j] = units[j], units[i]
	end

	-- Tombstones nearby
	local tombstones = { unpack( AI_StrategyManager:GetAllTombstones() ) }
	table.sort( tombstones, function ( a, b )
		local distA = (self.entity:GetAbsOrigin() - a:GetAbsOrigin()):Length2D()
		local distB = (self.entity:GetAbsOrigin() - b:GetAbsOrigin()):Length2D()
		return distA < distB
	end )

	local orderTombstones
	local lastTombstoneIndex = math.min( #tombstones, 3 )
	if #tombstones >= 3 then
		orderTombstones = { 1, 2, 3, 2, 3, 3 }
	elseif #tombstones == 2 then
		orderTombstones = { 1, 2, 1, 2, 2, 2 }
	else
		orderTombstones = { 1, 1, 1, 1, 1, 1 }
	end

	-- Assign tombstone
	self:_Log( "Creating Orders of Reviving..." )
	self:_Log( "  Units owned : " .. #units )
	self:_Log( "  Tombstones nearby : " .. #tombstones )
	self:_Log( "  Last tombstone : " .. lastTombstoneIndex )
	self.reviveOrders = {}	-- array of { unit, target tombstone, last tombstone }
	for k,v in pairs(units) do
		local tombstoneIndex = orderTombstones[tonumber(k)]
		table.insert( self.reviveOrders, { v, tombstones[tombstoneIndex], tombstones[lastTombstoneIndex] } )
		self:_Log( "  [" .. k .. "] Units = " .. v:entindex() .. ", TombstoneIdx = " .. tombstoneIndex )
	end

	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_Slithice:ACT_StepMirrorImageRevive()
	while #self.reviveOrders > 0 do
		local currentOrder = self.reviveOrders[1]
		table.remove( self.reviveOrders, 1 )

		-- Validation
		local unit			= currentOrder[1]
		local tombstone		= currentOrder[2]
		local lastTombstone	= currentOrder[3]

		if IsValidEntity(unit) and unit:IsAlive() then
			if IsValidEntity(tombstone) then
				self:SetSelectedUnit( unit )
				self:CreateOrder( DOTA_UNIT_ORDER_PICKUP_ITEM, tombstone )
				if IsValidEntity(lastTombstone) then
					self:CreateOrder( DOTA_UNIT_ORDER_PICKUP_ITEM, lastTombstone, nil, nil, true )
				end
				self:SetSelectedUnit()
				return BH_SUCCESS
			end
		end
	end
	return BH_FAILURE
end

--------------------------------------------------------------------------------
function AI_Slithice:ACT_CastRipTide()
	self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_rip_tide )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_Slithice:ACT_CastMirrorImage()
	return self:GetCastingAbilityState( self.ABILITY_mirror_image, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_mirror_image )
	end )
end

--------------------------------------------------------------------------------
function AI_Slithice:ACT_CastSirenSong()
	return self:GetCastingAbilityState( self.ABILITY_song_of_the_siren, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_song_of_the_siren )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_NagaSiren:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )
	
	-- Modify
	self:InsertBefore( array, "Avoid Threats",	self:NODE_ReviveWithIllusions() )
	self:InsertBefore( array, "Avoid Threats",	self:NODE_RipTideToMobs() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_NagaSiren:NODE_ReviveWithIllusions()
	return Decorator_Cooldown( 20, SequenceNode( "Revive with Illusions", {
		ConditionNode( "Should Revive?", "COND_ShouldReviveFriend" ),
		ConditionNode( "Sleeping with fishes", "COND_SingingSirenSong" ),
		ConditionNode( "Ready?", "COND_ReviveWithIllusions" ),
		ActionNode( "Collect Markers", "ACT_CollectIllusionsForRevive" ),
		Action_Wait( 0.5 ),
		Decorator_ForceSuccess(
			Decorator_UntilFailure( SequenceNode( "Control One Unit", {
				ActionNode( "Select & Revive", "ACT_StepMirrorImageRevive" ),
				Action_WaitRandom( 0.65, 0.85 ),
			} ) )
		),
		Action_WaitRandom( 1, 1.5 ),
	} ) )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_NagaSiren:NODE_RipTideToMobs()
	return Decorator_Cooldown( 0.4, SequenceNode( "RipTide to Mobs", {
		ConditionNode( "Not In Channeling?", "COND_NotInChanneling" ),
		ConditionNode( "Ready?", "COND_ReadyForRipTide" ),
	--	Action_WaitRandom( 0.1, 0.25 ),
		ActionNode( "Cast RipTide", "ACT_CastRipTide" ),
	} ) )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_NagaSiren:ARRAY_ReviveStrats()
	local array = AI_BehaviorTreeBuilder.ARRAY_ReviveStrats( self )
	
	-- Modify
	self:InsertBefore( array, "Revive Solo", self:NODE_ReviveStrat_MirrorImage() )
	self:InsertBefore( array, "Revive Solo", self:NODE_ReviveStrat_SirenSong() )

	return array
end

function AI_BehaviorTreeBuilder_NagaSiren:NODE_ReviveStrat_MirrorImage()
	return SequenceNode( "Mirror Image", {
		ConditionNode( "Sleeping with fishes", "COND_SingingSirenSong" ),
		ConditionNode( "Ready?", "COND_CastMirrorImageForRevive" ),
		ActionNode( "Cast MirrorImage", "ACT_CastMirrorImage" ),
	} )
end

function AI_BehaviorTreeBuilder_NagaSiren:NODE_ReviveStrat_SirenSong()
	return SequenceNode( "Siren Song", {
		ConditionNode( "Ready?", "COND_CastSirenSongForRevive" ),
		ActionNode( "Cast SirenSong", "ACT_CastSirenSong" ),
	} )
end
