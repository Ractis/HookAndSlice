
-- Replace "HERO_NAME" and "HERO_INTERNAL_NAME"

require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_SPECIAL	= "special"

--------------------------------------------------------------------------------
-- AI / HERO_NAME
--------------------------------------------------------------------------------
if AI_HERO_NAME == nil then
	AI_BehaviorTreeBuilder_HERO_NAME = class({}, nil, AI_BehaviorTreeBuilder)

	AI_HERO_NAME = class({}, nil, AI_FollowerBase)

	AI_HERO_NAME.btreeBuilderClass = AI_BehaviorTreeBuilder_HERO_NAME

	-- Hero specific properties
	AI_HERO_NAME.unitClassname	= "npc_dota_hero_HERO_INTERNAL_NAME"
	AI_HERO_NAME.unitShortname	= "HERO_NAME"

	AI_HERO_NAME.vAbilityNameList = {
		"HERO_INTERNAL_NAME_ability1",	-- 1
		"HERO_INTERNAL_NAME_ability2",	-- 2
		"HERO_INTERNAL_NAME_ability3",	-- 3
		"HERO_INTERNAL_NAME_ability4",	-- 4
		"attribute_bonus",				-- 5
	}
	AI_HERO_NAME.vAbilityUpgradeSequence = {
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
	}

	AI_HERO_NAME.vItemPropertyRating = {
		damage	= 3,
		str		= 3,
		agi		= 3,
		int		= 3,
		as		= 3,
		armor	= 3,
		mr		= 3,
		hp		= 3,
		mana	= 3,
		hpreg	= 3,
		manareg	= 3,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
function AI_HERO_NAME:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_ability1	= self.vAbilities["HERO_INTERNAL_NAME_ability1"]
end

--------------------------------------------------------------------------------
function AI_HERO_NAME:GetObjectiveTypeToClassMap()
	local types = AI_FollowerBase.GetObjectiveTypeToClassMap( self )

	-- Register additional objective types
	types[OBJECTIVE_TYPE_SPECIAL]	= AI_Objective_Special

	return types
end

--------------------------------------------------------------------------------
function AI_HERO_NAME:GetObjectiveTypesToShow()
	return { OBJECTIVE_TYPE_SPECIAL }
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_HERO_NAME:COND_ReadyForAbility()
	if not self.ABILITY_ability1:IsFullyCastable() then
		return false
	end

	-- Collect objectives
	local enemies = self:FindEnemiesInRange( 1000 )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_SPECIAL, enemies )

	-- Choose target
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_SPECIAL]

	if not objective or not objective:IsAcceptable() then
		return false
	end

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_HERO_NAME:ACT_CastAbility()
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_SPECIAL]
	if not objective:IsAcceptable() then
		return BH_FAILURE
	end

	local s = self:GetCastingAbilityState( self.ABILITY_ability1, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, objective.entity, self.ABILITY_ability1 )
	end )

	if s == BH_SUCCESS then
		-- Success!
	end

	return s
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_HERO_NAME:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_Ability1() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_HERO_NAME:NODE_Ability1()
	return SequenceNode( "Ability", {
		ConditionNode( "Ready?", "COND_ReadyForAbility" ),
		ActionNode( "Cast Ability", "ACT_CastAbility" ),
		Action_Wait( 0.5 ),
	} )
end





--------------------------------------------------------------------------------
-- Objective : Special
--------------------------------------------------------------------------------
AI_Objective_Special = class({}, nil, AI_Objective)

--------------------------------------------------------------------------------
function AI_Objective_Special:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_Special:Evaluate()
	-- Reset
	self.scoreD = 0

	-- Update
	if self:IsAcceptable() then
		self.scoreD = self:GetDistanceScore()
		self.score = self.scoreD
	else
		self.score = -999999
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_Special:IsAcceptable()
	if not self.entity:IsAlive()	then return false end
	if self.entity:IsMagicImmune()	then return false end

	return true
end

--------------------------------------------------------------------------------
function AI_Objective_Special:GetDebugTextLines()
	return {
		("D=%0.1f"):format( self.scoreD ),
		("%.2f"):format( self.score ),
	}
end
