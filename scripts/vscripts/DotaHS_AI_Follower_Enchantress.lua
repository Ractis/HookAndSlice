
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--   - More good behavior to control enchanted creatures
--   - Make enable reviving by enchanted creatures
--

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_DOMINATE	= "dominate"

--------------------------------------------------------------------------------
-- AI / Enchantress
--------------------------------------------------------------------------------
if AI_Enchantress == nil then
	AI_BehaviorTreeBuilder_Enchantress = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Enchantress = class({}, nil, AI_FollowerBase)

	AI_Enchantress.btreeBuilderClass = AI_BehaviorTreeBuilder_Enchantress

	-- Hero specific properties
	AI_Enchantress.unitClassname	= "npc_dota_hero_enchantress"
	AI_Enchantress.unitShortname	= "Sproink"

	AI_Enchantress.vAbilityNameList = {
		"enchantress_untouchable",			-- 1
		"enchantress_enchant",				-- 2
		"enchantress_natures_attendants",	-- 3
		"enchantress_impetus",				-- 4
		"attribute_bonus",					-- 5
	}
	AI_Enchantress.vAbilityUpgradeSequence = {
		2, 3, 2, 1, 2,
		4, 2, 3, 1, 3,
		4, 1, 3, 1, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Enchantress.vItemPropertyRating = {
		damage	= 2,
		str		= 1,
		agi		= 1,
		int		= 5,
		as		= 4,
		armor	= 3,
		mr		= 2,
		hp		= 2,
		mana	= 3,
		hpreg	= 2,
		manareg	= 5,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
function AI_Enchantress:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_enchant			= self.vAbilities["enchantress_enchant"]
	self.ABILITY_natures_attendants	= self.vAbilities["enchantress_natures_attendants"]
	self.ABILITY_impetus			= self.vAbilities["enchantress_impetus"]
end

--------------------------------------------------------------------------------
function AI_Enchantress:GetObjectiveTypeToClassMap()
	local types = AI_FollowerBase.GetObjectiveTypeToClassMap( self )

	-- Register additional objective types
	types[OBJECTIVE_TYPE_DOMINATE]	= AI_Objective_Dominate

	return types
end

--------------------------------------------------------------------------------
function AI_Enchantress:GetObjectiveTypesToShow()
	return { OBJECTIVE_TYPE_DOMINATE }
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Enchantress:COND_ReadyForEnchant()
	if not self.ABILITY_enchant:IsFullyCastable() then
		return false
	end

	-- Collect objectives
	local enemies = self:FindEnemiesInRange( 1000 )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_DOMINATE, enemies )

	-- Choose target
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_DOMINATE]

	if not objective or not objective:IsAcceptable() then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Enchantress:COND_ReadyForNaturesAttendants()
	if not self.ABILITY_natures_attendants:IsFullyCastable() then
		return false
	end

	--
	-- Total heal amount : 300/500/700/900
	-- Radius : 275
	--
	local totalHeal = 100 + 200 * self.ABILITY_natures_attendants:GetLevel()
	local totalDeficit = 0

	local radiusPrimary		= 240
	local radiusSecondary	= 360
	local friends = self:FriendlyHeroesInRange( radiusSecondary )
	for k,v in ipairs(friends) do
		if v:IsAlive() then
			local dist = self.entity:GetRangeToUnit(v)
			local factor = 1.0 - ( dist - radiusPrimary ) / ( radiusSecondary - radiusPrimary )
			factor = math.min( math.max( factor, 0.0 ), 1.0 )	-- saturate

			totalDeficit = totalDeficit + v:GetHealthDeficit() * factor
		end
	end

	if totalDeficit < totalHeal then
		-- Not efficiency
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Enchantress:COND_HasDominatedUnits()
	return #self.vDominatedUnits > 0
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Enchantress:ACT_AttackTarget()
	-- Mana percent
	local manaPercent = self.entity:GetManaPercent()
	local chanceToImpetus = manaPercent

	-- Magic immune?
	if self.targetAttack:IsMagicImmune() then
		chanceToImpetus = 0
	end

	-- Ability state
	if not self.ABILITY_impetus:IsFullyCastable() then
		chanceToImpetus = 0
	end

	if RollPercentage( chanceToImpetus ) then
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.targetAttack, self.ABILITY_impetus )
	else
		self:CreateOrder( DOTA_UNIT_ORDER_ATTACK_TARGET, self.targetAttack )
	end

	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_Enchantress:ACT_CastEnchant()
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_DOMINATE]
	if not objective:IsAcceptable() then
		return BH_FAILURE
	end

	local s = self:GetCastingAbilityState( self.ABILITY_enchant, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, objective.entity, self.ABILITY_enchant )
	end )

	if s == BH_SUCCESS then
		-- Enchanted!
		self:AssignDominatedUnit( objective.entity )
	end

	return s
end

--------------------------------------------------------------------------------
function AI_Enchantress:ACT_CastNaturesAttendants()
	return self:GetCastingAbilityState( self.ABILITY_natures_attendants, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_natures_attendants )
	end )
end

--------------------------------------------------------------------------------
function AI_Enchantress:ACT_MoveDominatedUnits()
	local targetPosition = self:RandomPositionInRange( self.entity:GetAbsOrigin(), 150, 300 )
	for _,v in ipairs( self.vDominatedUnits ) do
		self:SetSelectedUnit( v )
	--	self:CreateOrder( DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, nil, targetPosition )
		self:CreateOrder( DOTA_UNIT_ORDER_ATTACK_MOVE, nil, nil, targetPosition )
	end

	self:SetSelectedUnit( nil )

	return BH_SUCCESS
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Enchantress:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_NaturesAttendants() )
	self:InsertBefore( array, "Flee", self:NODE_Enchant() )
	self:InsertBefore( array, "Combat", self:NODE_MoveDominatedUnits() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Enchantress:NODE_NaturesAttendants()
	return SequenceNode( "Natures Attendants", {
		ConditionNode( "Ready?", "COND_ReadyForNaturesAttendants" ),
		ActionNode( "Cast Nature's Attendants", "ACT_CastNaturesAttendants" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Enchantress:NODE_Enchant()
	return SequenceNode( "Enchant", {
		ConditionNode( "Ready?", "COND_ReadyForEnchant" ),
		ActionNode( "Cast Enchant", "ACT_CastEnchant" ),
		Action_Wait( 0.5 ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Enchantress:NODE_MoveDominatedUnits()
	return Decorator_CooldownRandom( 3.0, 5.0, SequenceNode( "Move Dominated Units", {
		ConditionNode( "Has Dominated Units?", "COND_HasDominatedUnits" ),
		Action_WaitRandom( 0.2, 0.4 ),
		ActionNode( "Move", "ACT_MoveDominatedUnits" ),
		Action_Wait( 0.15 ),
	} ) )
end





--------------------------------------------------------------------------------
-- Objective : Dominate
--------------------------------------------------------------------------------
AI_Objective_Dominate = class({}, nil, AI_Objective_Enemy)

AI_Objective_Dominate.minimumHealthPercent = 20

--------------------------------------------------------------------------------
function AI_Objective_Dominate:constructor( entity, AI )
	AI_Objective_Enemy.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_Dominate:Evaluate()
	-- Reset
	self.scoreD = 0

	-- Update
	if not self:IsAcceptable() then
		self.score = -999999
	else
		self.scoreD = self:GetDistanceScore()
		self.score = self.scoreD
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_Dominate:IsAcceptable()
	if self.entity:IsAncient()		then return false end
--	if self.entity:IsDominated()	then return false end
	if self.entity:IsHero()			then return false end
	if self.entity:IsIllusion()		then return false end
	if self.entity:IsMagicImmune()	then return false end
	if self.entity:IsTower()		then return false end
	if self.entity:IsUnselectable()	then return false end

	if self.entity:GetHealthPercent() <= AI_Objective_Dominate.minimumHealthPercent then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Objective_Dominate:GetDebugTextLines()
	return {
		("D=%0.1f"):format( self.scoreD ),
		("%.2f"):format( self.score ),
	}
end
