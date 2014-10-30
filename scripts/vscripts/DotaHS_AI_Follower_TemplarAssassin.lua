
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--   - Check interruptible when cast Refraction
--

--------------------------------------------------------------------------------
-- AI / Templar Assassin
--------------------------------------------------------------------------------
if AI_TemplarAssassin == nil then
	AI_BehaviorTreeBuilder_TemplarAssassin = class({}, nil, AI_BehaviorTreeBuilder)

	AI_TemplarAssassin = class({}, nil, AI_FollowerBase)

	AI_TemplarAssassin.btreeBuilderClass = AI_BehaviorTreeBuilder_TemplarAssassin

	-- Hero specific properties
	AI_TemplarAssassin.unitClassname	= "npc_dota_hero_templar_assassin"
	AI_TemplarAssassin.unitShortname	= "Lanaya"

	AI_TemplarAssassin.vAbilityNameList = {
		"templar_assassin_refraction",
		"templar_assassin_meld",
		"templar_assassin_psi_blades",
		"templar_assassin_trap",			-- NOT LEARNABLE
		"templar_assassin_psionic_trap",	-- 5
		"attribute_bonus",					-- 6
	}
	AI_TemplarAssassin.vAbilityUpgradeSequence = {
		3, 1, 1, 2, 1,
		5, 1, 2, 2, 2,
		5, 3, 3, 3, 6,
		5, 6, 6, 6, 6,
		6, 6, 6, 6, 6,
	}

	AI_TemplarAssassin.vItemPropertyRating = {
		damage	= 4,
		str		= 2,
		agi		= 5,
		int		= 1,
		as		= 3,
		armor	= 2,
		mr		= 2,
		hp		= 3,
		mana	= 2,
		hpreg	= 2,
		manareg	= 4,
		ms		= 3,
	}
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_refraction		= self.vAbilities["templar_assassin_refraction"]
	self.ABILITY_meld			= self.vAbilities["templar_assassin_meld"]
	self.ABILITY_trap			= self.vAbilities["templar_assassin_trap"]
	self.ABILITY_psionic_trap	= self.vAbilities["templar_assassin_psionic_trap"]
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_TemplarAssassin:COND_ReadyForRefraction()
	if not self.ABILITY_refraction:IsFullyCastable() then
		return false
	end

	-- Enemy nearby exists
	local enemyDist = AI_StrategyManager:GetNearestEnemyDistance( self.virtualPlayerID )
	if enemyDist > 500 then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:COND_ReadyForTrap()
	if not self.ABILITY_trap:IsFullyCastable() then
		-- Got silenced
		return false
	end

	if not self.timeToActivateTrap then
		-- No active traps deployed
		return false
	end

	if self.timeToActivateTrap > GameRules:GetGameTime() then
		-- Wait
		return false
	end

	-- Activate the trap
	self.timeToActivateTrap = nil
	return true
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:COND_ReadyForPsionicTrap()
	if not self.ABILITY_psionic_trap:IsFullyCastable() then
		return false
	end

	-- Good position found ?
	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_trap, "trap_radius" )
	radius = radius * 0.75
	local enemies = self:FindEnemiesInRange( 1000 )
	local center, N = DotaHS_FindGoodCirclePosition( radius, enemies, self )

--	self:_Log( "Finding the target for Psionic Trap : maxN = " .. N )

	if not center then
		return false
	end

	self.targetPsionicTrap = self:RandomPositionInRange( center, 75 )

	return true
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_TemplarAssassin:ACT_AttackTarget()
	local castMeldAttack = true

	-- Check range
	local rangeToTarget = self.entity:GetRangeToUnit( self.targetAttack )
	if rangeToTarget > self.entity:GetAttackRange() then
		castMeldAttack = false
	end

	-- Check ability state
	if not self.ABILITY_meld:IsFullyCastable() then
		castMeldAttack = false
	end

	-- Act attack
	if castMeldAttack then
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_meld )
		return BH_RUNNING
	else
		self:CreateOrder( DOTA_UNIT_ORDER_ATTACK_TARGET, self.targetAttack )
		return BH_SUCCESS
	end
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:ACT_CastRefraction()
	self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_refraction )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:ACT_CastPsionicTrap()
	local s = self:GetCastingAbilityState( self.ABILITY_psionic_trap, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_POSITION, nil, self.ABILITY_psionic_trap, self.targetPsionicTrap )
	end )

	if s == BH_SUCCESS then
		-- Successfully deployed a trap
		self.timeToActivateTrap = GameRules:GetGameTime() + RandomFloat( 0.15, 0.4 )
	end

	return s
end

--------------------------------------------------------------------------------
function AI_TemplarAssassin:ACT_CastTrap()
	return self:GetCastingAbilityState( self.ABILITY_trap, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_trap )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_TemplarAssassin:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Avoid Threats",	self:NODE_Refraction() )
	self:InsertBefore( array, "Avoid Threats",	self:NODE_ActivateTrap() )
	self:InsertBefore( array, "Flee",			self:NODE_DeployTrap() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_TemplarAssassin:NODE_Refraction()
	return SequenceNode( "Refraction", {
		ConditionNode( "Ready?", "COND_ReadyForRefraction" ),
		ActionNode( "Cast Refraction", "ACT_CastRefraction" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_TemplarAssassin:NODE_ActivateTrap()
	return SequenceNode( "Activate Trap", {
		ConditionNode( "Ready?", "COND_ReadyForTrap" ),
		ActionNode( "Cast Trap", "ACT_CastTrap" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_TemplarAssassin:NODE_DeployTrap()
	return SequenceNode( "Deploy Trap", {
		ConditionNode( "Ready?", "COND_ReadyForPsionicTrap" ),
		ActionNode( "Cast Trap", "ACT_CastPsionicTrap" ),
	} )
end
