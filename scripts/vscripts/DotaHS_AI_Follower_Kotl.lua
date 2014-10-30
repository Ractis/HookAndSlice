
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--

--------------------------------------------------------------------------------
-- AI / Kotl
--------------------------------------------------------------------------------
if AI_Kotl == nil then
	AI_BehaviorTreeBuilder_Kotl = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Kotl = class({}, nil, AI_FollowerBase)

	AI_Kotl.btreeBuilderClass = AI_BehaviorTreeBuilder_Kotl

	-- Hero specific properties
	AI_Kotl.unitClassname	= "npc_dota_hero_keeper_of_the_light"
	AI_Kotl.unitShortname	= "Kotl"

	AI_Kotl.vAbilityNameList = {
		"keeper_of_the_light_illuminate",			-- 1
		"keeper_of_the_light_mana_leak",			-- 2
		"keeper_of_the_light_chakra_magic",			-- 3
		"keeper_of_the_light_recall",
		"keeper_of_the_light_blinding_light",
		"keeper_of_the_light_spirit_form",			-- 6
		"keeper_of_the_light_illuminate_end",
		"keeper_of_the_light_spirit_form_illuminate",
		"keeper_of_the_light_spirit_form_illuminate_end",
		"attribute_bonus",							-- 10
	}
	AI_Kotl.vAbilityUpgradeSequence = {
		1, 3, 1, 3, 1,
		6, 1, 3, 3, 2,
		6, 2, 2, 2, 10,
		6, 10, 10, 10, 10,
		10, 10, 10, 10, 10,
	}

	AI_Kotl.vItemPropertyRating = {
		damage	= 2,
		str		= 1,
		agi		= 1,
		int		= 5,
		as		= 3,
		armor	= 3,
		mr		= 3,
		hp		= 3,
		mana	= 4,
		hpreg	= 3,
		manareg	= 3,
		ms		= 2,
	}
end

--------------------------------------------------------------------------------
function AI_Kotl:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_illuminate				= self.vAbilities["keeper_of_the_light_illuminate"]
	self.ABILITY_spirit_form_illuminate	= self.vAbilities["keeper_of_the_light_spirit_form_illuminate"]
	self.ABILITY_chakra_magic			= self.vAbilities["keeper_of_the_light_chakra_magic"]
	self.ABILITY_blinding_light			= self.vAbilities["keeper_of_the_light_blinding_light"]
	self.ABILITY_spirit_form			= self.vAbilities["keeper_of_the_light_spirit_form"]
end

--------------------------------------------------------------------------------
function AI_Kotl:IsSpiritForm()
	return self.entity:HasModifier( "modifier_keeper_of_the_light_spirit_form" )
end

--------------------------------------------------------------------------------
function AI_Kotl:GetActiveIlluminateAbility()
	if self:IsSpiritForm() then
		return self.ABILITY_spirit_form_illuminate
	else
		return self.ABILITY_illuminate
	end
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Kotl:COND_ReadyForIlluminate()
	if not self:GetActiveIlluminateAbility():IsFullyCastable() then
		return false
	end

	-- Good direction found?
	local range = 1000	-- 1550
	local radius = 250	-- 350
	local enemies = self:FindEnemiesInRange( range )

	if #enemies == 0 then
		return false
	end

	local dir, score = DotaHS_FindGoodDirection( self.entity:GetAbsOrigin(), range, radius, enemies )

	if not dir then
		return false
	end

	if score < 2.25 then
		return false
	end

	self.targetIlluminate = self.entity:GetAbsOrigin() + dir * ( range / 2 )
	self.targetIlluminate = self:RandomPositionInRange( self.targetIlluminate, 75 )

	return true
end

--------------------------------------------------------------------------------
function AI_Kotl:COND_ReadyForChakraMagic()
	if not self.ABILITY_chakra_magic:IsFullyCastable() then
		return false
	end

	local range = self.ABILITY_chakra_magic:GetCastRange()
	local allies = self:FriendlyHeroesInRange( range )

	local lowestManaPercent = 100
	local lowestManaAlly = nil
	for _,v in ipairs(allies) do
		if v:entindex() ~= self.entity:entindex() then
			-- Other hero
			if v:IsAlive() then
				local manaPercent = v:GetManaPercent()
				if manaPercent < lowestManaPercent then
					lowestManaPercent = manaPercent
					lowestManaAlly = v
				end
			end
		end
	end

	if lowestManaPercent > self.entity:GetManaPercent() * 0.75 then
		lowestManaAlly = self.entity	-- Cast to myself
	end

	if lowestManaAlly:GetManaPercent() > 90 then
		return false
	end

	self.targetChakraMagic = lowestManaAlly

	return true
end

--------------------------------------------------------------------------------
function AI_Kotl:COND_ReadyForBlindingLight()
	if not self.ABILITY_blinding_light:IsFullyCastable() then
		return false
	end

	if not self:IsSpiritForm() then
		-- Can't cast this ability as normal form
		return false
	end

	-- Find good position
	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_blinding_light, "radius" )
	radius = radius * 0.75
	local enemies = self:FindEnemiesInRange( 1000 )
	local center, N = DotaHS_FindGoodCirclePosition( radius, enemies, self )

	if not center then
		return false
	end

	local minimumEnemies = 6
	if N < minimumEnemies then
		return false
	end

	self.targetBlindingLight = self:RandomPositionInRange( center, 75 )

	return true
end

--------------------------------------------------------------------------------
function AI_Kotl:COND_ReadyForSpiritForm()
	if not self.ABILITY_spirit_form:IsFullyCastable() then
		return false
	end

	if self:IsSpiritForm() then
		return false
	end

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Kotl:ACT_CastIlluminate()
	local ability = self:GetActiveIlluminateAbility()

	local s = self:GetCastingAbilityState( ability, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_POSITION, nil, ability, self.targetIlluminate )
	end )

	if self:IsSpiritForm() then
		return BH_SUCCESS
	else
		return s
	end
end

--------------------------------------------------------------------------------
function AI_Kotl:ACT_CastChakraMagic()
	if not self.targetChakraMagic:IsAlive() then
		return BH_FAILURE
	end

	return self:GetCastingAbilityState( self.ABILITY_chakra_magic, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.targetChakraMagic, self.ABILITY_chakra_magic )
	end )
end

--------------------------------------------------------------------------------
function AI_Kotl:ACT_CastBlindingLight()
	return self:GetCastingAbilityState( self.ABILITY_blinding_light, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_POSITION, nil, self.ABILITY_blinding_light, self.targetBlindingLight )
	end )
end

--------------------------------------------------------------------------------
function AI_Kotl:ACT_CastSpiritForm()
	return self:GetCastingAbilityState( self.ABILITY_spirit_form, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_spirit_form )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Kotl:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_SpiritForm() )
	self:InsertBefore( array, "Flee", self.NODE_Illuminate() )
	self:InsertBefore( array, "Flee", self.NODE_BlindingLight() )
	self:InsertBefore( array, "Flee", self.NODE_ChakraMagic() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Kotl:NODE_SpiritForm()
	return SequenceNode( "Spirit Form", {
		ConditionNode( "Ready?", "COND_ReadyForSpiritForm" ),
		ActionNode( "Cast Spirit Form", "ACT_CastSpiritForm" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Kotl:NODE_Illuminate()
	return Decorator_CooldownRandomAlsoFailure( 0.3, 0.6,
		SequenceNode( "Illuminate", {
			ConditionNode( "Ready?", "COND_ReadyForIlluminate" ),
			ActionNode( "Cast Illuminate", "ACT_CastIlluminate" ),
		} )
	)
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Kotl:NODE_BlindingLight()
	return Decorator_CooldownRandomAlsoFailure( 1, 1.5,
		SequenceNode( "Blinding Light", {
			ConditionNode( "Ready?", "COND_ReadyForBlindingLight" ),
			ActionNode( "Cast Blinding Light", "ACT_CastBlindingLight" ),
		} )
	)
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Kotl:NODE_ChakraMagic()
	return SequenceNode( "Chakra Magic", {
		ConditionNode( "Ready?", "COND_ReadyForChakraMagic" ),
		ActionNode( "Cast Chakra Magic", "ACT_CastChakraMagic" ),
	} )
end
