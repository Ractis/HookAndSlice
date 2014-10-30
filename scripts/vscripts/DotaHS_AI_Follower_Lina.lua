
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--   - Use ULT ( need mana management )
--   - Prevent to cast Q and W at the same time
--

--------------------------------------------------------------------------------
-- AI / Lina
--------------------------------------------------------------------------------
if AI_Lina == nil then
	AI_BehaviorTreeBuilder_Lina = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Lina = class({}, nil, AI_FollowerBase)

	AI_Lina.btreeBuilderClass = AI_BehaviorTreeBuilder_Lina

	-- Hero specific properties
	AI_Lina.unitClassname	= "npc_dota_hero_lina"
	AI_Lina.unitShortname	= "Lina"

	AI_Lina.vAbilityNameList = {
		"lina_dragon_slave",
		"lina_light_strike_array",
		"lina_fiery_soul",
		"lina_laguna_blade",
		"attribute_bonus",
	}
	AI_Lina.vAbilityUpgradeSequence = {
		1, 2, 3, 2, 2,
		4, 2, 1, 1, 1,
		4, 3, 3, 3, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Lina.vItemPropertyRating = {
		damage	= 4,
		str		= 1,
		agi		= 1,
		int		= 5,
		as		= 2,
		armor	= 2,
		mr		= 2,
		hp		= 2,
		mana	= 4,
		hpreg	= 2,
		manareg	= 5,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
function AI_Lina:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_dragon_slave		= self.vAbilities["lina_dragon_slave"]
	self.ABILITY_light_strike_array	= self.vAbilities["lina_light_strike_array"]
	self.ABILITY_lina_laguna_blade	= self.vAbilities["lina_laguna_blade"]
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Lina:COND_ReadyForDragonSlave()
	if not self.ABILITY_dragon_slave:IsFullyCastable() then
		return false
	end

	-- Good direction found?
	local range = 1000
	local radius = 200
	local enemies = self:FindEnemiesInRange( range )

	if #enemies == 0 then
		return false
	end

	local dir, score = DotaHS_FindGoodDirection( self.entity:GetAbsOrigin(), range, radius, enemies )

	if not dir then
		return false
	end

--	local phi = math.atan2(dir.y,dir.x) / math.pi * 180
--	self:_Log( "Phi = " .. phi .. ", Best Score = " .. score )

	if score < 1.25 then
		return false
	end

	self.targetDragonSlave = self.entity:GetAbsOrigin() + dir * ( range / 2 )
	self.targetDragonSlave = self:RandomPositionInRange( self.targetDragonSlave, 75 )

	return true
end

--------------------------------------------------------------------------------
function AI_Lina:COND_ReadyForLightStrikeArray()
	if not self.ABILITY_light_strike_array:IsFullyCastable() then
		return false
	end

	-- Good position found?
	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_light_strike_array, "light_strike_array_aoe" )
	local enemies = self:FindEnemiesInRange( self.ABILITY_light_strike_array:GetCastRange() )
	local center, N = DotaHS_FindGoodCirclePosition( radius, enemies, self )

	if not center then
		return false
	end

	self.targetLightStrikeArray = self:RandomPositionInRange( center, 75 )

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Lina:ACT_CastDragonSlave()
	return self:GetCastingAbilityState( self.ABILITY_dragon_slave, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_POSITION, nil, self.ABILITY_dragon_slave, self.targetDragonSlave )
	end )
end

--------------------------------------------------------------------------------
function AI_Lina:ACT_CastLightStrikeArray()
	return self:GetCastingAbilityState( self.ABILITY_light_strike_array, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_POSITION, nil, self.ABILITY_light_strike_array, self.targetLightStrikeArray )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Lina:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_LightStrikeArray() )
	self:InsertBefore( array, "Flee", self:NODE_CastDragonSlave() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Lina:NODE_LightStrikeArray()
	return SequenceNode( "Light Strike Array", {
		ConditionNode( "Ready?", "COND_ReadyForLightStrikeArray" ),
		ActionNode( "Cast Light Strike Array", "ACT_CastLightStrikeArray" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Lina:NODE_CastDragonSlave()
	return SequenceNode( "Dragon Slave", {
		ConditionNode( "Ready?", "COND_ReadyForDragonSlave" ),
		ActionNode( "Cast Dragon Slave", "ACT_CastDragonSlave" ),
	} )
end
