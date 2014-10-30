
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--

--------------------------------------------------------------------------------
-- AI / Luna
--------------------------------------------------------------------------------
if AI_Luna == nil then
	AI_BehaviorTreeBuilder_Luna = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Luna = class({}, nil, AI_FollowerBase)

	AI_Luna.btreeBuilderClass = AI_BehaviorTreeBuilder_Luna

	-- Hero specific properties
	AI_Luna.unitClassname	= "npc_dota_hero_luna"
	AI_Luna.unitShortname	= "Luna"

	AI_Luna.vAbilityNameList = {
		"luna_lucent_beam",		-- 1
		"luna_moon_glaive",		-- 2
		"luna_lunar_blessing",	-- 3
		"luna_eclipse",			-- 4
		"attribute_bonus",		-- 5
	}
	AI_Luna.vAbilityUpgradeSequence = {
		3, 2, 3, 1, 3,
		4, 3, 2, 2, 2,
		4, 1, 1, 1, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Luna.vItemPropertyRating = {
		damage	= 5,
		str		= 2,
		agi		= 5,
		int		= 1,
		as		= 5,
		armor	= 2,
		mr		= 2,
		hp		= 2,
		mana	= 1,
		hpreg	= 3,
		manareg	= 2,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
function AI_Luna:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_lucent_beam	= self.vAbilities["luna_lucent_beam"]
	self.ABILITY_eclipse		= self.vAbilities["luna_eclipse"]
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Luna:COND_ReadyForEclipse()
	if not self.ABILITY_eclipse:IsFullyCastable() then
		return false
	end

	-- Num enemies
	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_eclipse, "radius" )
	radius = radius * 0.75
	local numEnemies = #self:FindEnemiesInRange( radius )

	if numEnemies < 7 then
		return false
	end

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Luna:ACT_CastEclipse()
	return self:GetCastingAbilityState( self.ABILITY_eclipse, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_eclipse )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Luna:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_Eclipse() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Luna:NODE_Eclipse()
	return Decorator_CooldownRandomAlsoFailure( 0.5, 1.0,
		SequenceNode( "Eclipse", {
			ConditionNode( "Ready?", "COND_ReadyForEclipse" ),
			ActionNode( "Cast Eclipse", "ACT_CastEclipse" ),
		} )
	)
end
