
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_APHOTIC_SHIELD	= "aphoticShield"

--------------------------------------------------------------------------------
-- AI / Abaddon
--------------------------------------------------------------------------------
if AI_Abaddon == nil then
	AI_BehaviorTreeBuilder_Abaddon = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Abaddon = class({}, nil, AI_FollowerBase)

	AI_Abaddon.btreeBuilderClass = AI_BehaviorTreeBuilder_Abaddon

	-- Hero specific properties
	AI_Abaddon.unitClassname	= "npc_dota_hero_abaddon"
	AI_Abaddon.unitShortname	= "Abaddon"

	AI_Abaddon.vAbilityNameList = {
		"abaddon_death_coil",		-- 1
		"abaddon_aphotic_shield",	-- 2
		"abaddon_frostmourne",		-- 3
		"abaddon_borrowed_time",	-- 4
		"attribute_bonus",			-- 5
	}
	AI_Abaddon.vAbilityUpgradeSequence = {
		2, 1, 2, 3, 2,
		4, 2, 1, 1, 1,
		4, 3, 3, 3, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Abaddon.vItemPropertyRating = {
		damage	= 4,
		str		= 5,
		agi		= 1,
		int		= 1,
		as		= 2,
		armor	= 4,
		mr		= 3,
		hp		= 3,
		mana	= 2,
		hpreg	= 4,
		manareg	= 2,
		ms		= 2,
	}
end

--------------------------------------------------------------------------------
function AI_Abaddon:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_death_coil		= self.vAbilities["abaddon_death_coil"]
	self.ABILITY_aphotic_shield	= self.vAbilities["abaddon_aphotic_shield"]
end

--------------------------------------------------------------------------------
function AI_Abaddon:GetObjectiveTypeToClassMap()
	local types = AI_FollowerBase.GetObjectiveTypeToClassMap( self )

	-- Register additional objective types
	types[OBJECTIVE_TYPE_APHOTIC_SHIELD]	= AI_Objective_AphoticShield

	return types
end

--------------------------------------------------------------------------------
function AI_Abaddon:GetObjectiveTypesToShow()
	return { OBJECTIVE_TYPE_APHOTIC_SHIELD }
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Abaddon:COND_ReadyForDeathCoil()
	if not self.ABILITY_death_coil:IsFullyCastable() then
		return false
	end

	local range = self.ABILITY_death_coil:GetCastRange()
	local allies = self:FriendlyHeroesInRange( range )

	local lowestHealthPercent = 100
	local lowestHealthAlly = nil
	for _,v in ipairs(allies) do
		if v:entindex() ~= self.entity:entindex() then
			-- Other hero
			if v:IsAlive() then
				local healthPercent = v:GetHealthPercent()
				if healthPercent < lowestHealthPercent then
					lowestHealthPercent = healthPercent
					lowestHealthAlly = v
				end
			end
		end
	end

	if lowestHealthPercent > self.entity:GetHealthPercent() * 0.75 then
		return false
	end

	self.targetDeathCoil = lowestHealthAlly

	return true
end

--------------------------------------------------------------------------------
function AI_Abaddon:COND_ReadyForAphoticShield()
	if not self.ABILITY_aphotic_shield:IsFullyCastable() then
		return false
	end

	-- Collect objectives
	local range = self.ABILITY_aphotic_shield:GetCastRange()
	local allies = self:FriendlyHeroesInRange( range )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_APHOTIC_SHIELD, allies )

	-- Choose target
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_APHOTIC_SHIELD]

	if not objective or not objective:IsAcceptable() then
		return false
	end

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Abaddon:ACT_CastDeathCoil()
	if not self.targetDeathCoil:IsAlive() then
		return BH_FAILURE
	end

	return self:GetCastingAbilityState( self.ABILITY_death_coil, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.targetDeathCoil, self.ABILITY_death_coil )
	end )
end

--------------------------------------------------------------------------------
function AI_Abaddon:ACT_CastAphoticShield()
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_APHOTIC_SHIELD]
	if not objective:IsAcceptable() then
		return BH_FAILURE
	end

	return self:GetCastingAbilityState( self.ABILITY_aphotic_shield, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, objective.entity, self.ABILITY_aphotic_shield )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Abaddon:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_AphoticShield() )
	self:InsertBefore( array, "Combat", self:NODE_DeathCoil() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Abaddon:NODE_DeathCoil()
	return SequenceNode( "Death Coil", {
		ConditionNode( "Ready?", "COND_ReadyForDeathCoil" ),
		ActionNode( "Cast Death Coil", "ACT_CastDeathCoil" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Abaddon:NODE_AphoticShield()
	return SequenceNode( "Aphotic Shield", {
		ConditionNode( "Ready?", "COND_ReadyForAphoticShield" ),
		ActionNode( "Cast Aphotic Shield", "ACT_CastAphoticShield" ),
		Action_Wait( 0.25 ),
	} )
end





--------------------------------------------------------------------------------
-- Objective : AphoticShield
--------------------------------------------------------------------------------
AI_Objective_AphoticShield = class({}, nil, AI_Objective)

AI_Objective_AphoticShield.minimumEnemies = 3

--------------------------------------------------------------------------------
function AI_Objective_AphoticShield:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_AphoticShield:Evaluate()

	local radius = DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_aphotic_shield, "radius" )
	local enemies = self.AI:FindEnemiesInRange( radius, self.entity:GetAbsOrigin() )
	self.nEnemiesInRange = #enemies

	-- Reset
	self.scoreE = 0
	self.scoreH = 0

	-- Update
	if self:IsAcceptable() then
	--	self.scoreE = self.nEnemiesInRange
		self.scoreH = self:GetHealthScore()
		self.score = self.scoreE + self.scoreH
	else
		self.score = -999999
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_AphoticShield:IsAcceptable()
	if not self.entity:IsAlive()	then return false end
	if self.entity:IsMagicImmune()	then return false end

	if self.nEnemiesInRange < self.minimumEnemies then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Objective_AphoticShield:GetDebugTextLines()
	return { }
end
