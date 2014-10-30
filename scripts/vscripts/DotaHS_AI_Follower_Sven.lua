
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_STORM_BOLT	= "stormBolt"

--------------------------------------------------------------------------------
-- AI / Sven
--------------------------------------------------------------------------------
if AI_Sven == nil then
	AI_BehaviorTreeBuilder_Sven = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Sven = class({}, nil, AI_FollowerBase)

	AI_Sven.btreeBuilderClass = AI_BehaviorTreeBuilder_Sven

	-- Hero specific properties
	AI_Sven.unitClassname	= "npc_dota_hero_sven"
	AI_Sven.unitShortname	= "Sven"

	AI_Sven.vAbilityNameList = {
		"sven_storm_bolt",		-- 1
		"sven_great_cleave",	-- 2
		"sven_warcry",			-- 3
		"sven_gods_strength",	-- 4
		"attribute_bonus",		-- 5
	}
	AI_Sven.vAbilityUpgradeSequence = {
		3, 2, 1, 3, 3,
		4, 3, 2, 2, 2,
		4, 1, 1, 1, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Sven.vItemPropertyRating = {
		damage	= 5,
		str		= 5,
		agi		= 1,
		int		= 1,
		as		= 3,
		armor	= 3,
		mr		= 3,
		hp		= 3,
		mana	= 3,
		hpreg	= 2,
		manareg	= 2,
		ms		= 2,
	}
end

--------------------------------------------------------------------------------
function AI_Sven:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_storm_bolt		= self.vAbilities["sven_storm_bolt"]
	self.ABILITY_warcry			= self.vAbilities["sven_warcry"]
	self.ABILITY_gods_strength	= self.vAbilities["sven_gods_strength"]
end

--------------------------------------------------------------------------------
function AI_Sven:GetObjectiveTypeToClassMap()
	local types = AI_FollowerBase.GetObjectiveTypeToClassMap( self )

	-- Register additional objective types
	types[OBJECTIVE_TYPE_STORM_BOLT]	= AI_Objective_StormBolt

	return types
end

--------------------------------------------------------------------------------
function AI_Sven:GetObjectiveTypesToShow()
	return { OBJECTIVE_TYPE_STORM_BOLT }
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Sven:COND_ReadyForStormBolt()
	if not self.ABILITY_storm_bolt:IsFullyCastable() then
		return false
	end

	-- Find enemies in the cast range
	local range = self.ABILITY_storm_bolt:GetCastRange()
	local enemies = self:FindEnemiesInRange( range )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_STORM_BOLT, enemies )

	-- Choose target
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_STORM_BOLT]

	if not objective or not objective:IsAcceptable() then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Sven:COND_ReadyForWarcry()
	if not self.ABILITY_warcry:IsFullyCastable() then
		return false
	end

	-- Chance to use
	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_warcry, "warcry_radius" )
	local numPlayersAlive = DotaHS_NumPlayersAlive()
	local numInCombat = self:NumPlayersInCombat( radius )

	local percentToUse = math.max( numInCombat / numPlayersAlive - 0.5, 0 ) * 100

	return RollPercentage( percentToUse )
end

--------------------------------------------------------------------------------
function AI_Sven:COND_ReadyForGodsStrength()
	if not self.ABILITY_gods_strength:IsFullyCastable() then
		return false
	end

	-- Num enemies nearby
	local numEnemies = #self:FindEnemiesInRange( 500 )

	if numEnemies < 5 then
		return false
	end

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Sven:ACT_CastStormBolt()
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_STORM_BOLT]
	if not objective:IsAcceptable() then
		return BH_FAILURE
	end

	return self:GetCastingAbilityState( self.ABILITY_storm_bolt, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, objective.entity, self.ABILITY_storm_bolt )
	end )
end

--------------------------------------------------------------------------------
function AI_Sven:ACT_CastWarcry()
	return self:GetCastingAbilityState( self.ABILITY_warcry, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_warcry )
	end )
end

--------------------------------------------------------------------------------
function AI_Sven:ACT_CastGodsStrength()
	return self:GetCastingAbilityState( self.ABILITY_gods_strength, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_gods_strength )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Sven:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_StormBolt() )
	self:InsertBefore( array, "Flee", self:NODE_Warcry() )
	self:InsertBefore( array, "Combat", self:NODE_GodsStrength() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Sven:NODE_StormBolt()
	return SequenceNode( "Storm Bolt", {
		ConditionNode( "Ready?", "COND_ReadyForStormBolt" ),
		ActionNode( "Cast Storm Bolt", "ACT_CastStormBolt" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Sven:NODE_Warcry()
	return Decorator_CooldownRandomAlsoFailure( 0.75, 1.25,
		SequenceNode( "Warcry", {
			ConditionNode( "Ready?", "COND_ReadyForWarcry" ),
			ActionNode( "Cast Warcry", "ACT_CastWarcry" ),
		} )
	)
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Sven:NODE_GodsStrength()
	return SequenceNode( "Gods Strength", {
		ConditionNode( "Ready?", "COND_ReadyForGodsStrength" ),
		ActionNode( "Cast Gods Strength", "ACT_CastGodsStrength" ),
	} )
end





--------------------------------------------------------------------------------
-- Objective : Storm Bolt
--------------------------------------------------------------------------------
AI_Objective_StormBolt = class({}, nil, AI_Objective)

AI_Objective_StormBolt.minimumEnemies = 3

--------------------------------------------------------------------------------
function AI_Objective_StormBolt:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_StormBolt:Evaluate()

	local radius = DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_storm_bolt, "bolt_aoe" )
	local enemies = self.AI:FindEnemiesInRange( radius, self.entity:GetAbsOrigin() )
	self.nEnemiesInRange = #enemies

	-- Reset
	self.scoreE = 0
	self.scoreD = 0

	-- Update
	if self:IsAcceptable() then
		self.scoreE = self.nEnemiesInRange * 10
		self.scoreD = self:GetDistanceScore()
		self.score = self.scoreE + self.scoreD
	else
		self.score = -999999
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_StormBolt:IsAcceptable()
	if not self.entity:IsAlive()	then return false end
	if self.entity:IsMagicImmune()	then return false end

	if self.nEnemiesInRange < self.minimumEnemies then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Objective_StormBolt:GetDebugTextLines()
	return { }
end
