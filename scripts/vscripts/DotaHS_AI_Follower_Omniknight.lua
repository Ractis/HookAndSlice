
require( "DotaHS_AI_FollowerBase" )

--
-- TODO:
--   - Repel + Revive
--


--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_PURIFICATION = "purification"

--------------------------------------------------------------------------------
-- AI / Omniknight
--------------------------------------------------------------------------------
if AI_Omniknight == nil then
	AI_BehaviorTreeBuilder_Omniknight = class({}, nil, AI_BehaviorTreeBuilder)

	AI_Omniknight = class({}, nil, AI_FollowerBase)

	AI_Omniknight.btreeBuilderClass = AI_BehaviorTreeBuilder_Omniknight

	-- Hero specific properties
	AI_Omniknight.unitClassname	= "npc_dota_hero_omniknight"
	AI_Omniknight.unitShortname	= "Omniknight"

	AI_Omniknight.vAbilityNameList = {
		"omniknight_purification",
		"omniknight_repel",
		"omniknight_degen_aura",
		"omniknight_guardian_angel",
		"attribute_bonus",
	}
	AI_Omniknight.vAbilityUpgradeSequence = {
		1, 2, 1, 3, 1,
		4, 1, 3, 3, 3,
		4, 2, 2, 2, 5,
		4, 5, 5, 5, 5,
		5, 5, 5, 5, 5,
	}

	AI_Omniknight.vItemPropertyRating = {
		damage	= 2,
		str		= 5,
		agi		= 1,
		int		= 2,
		as		= 2,
		armor	= 4,
		mr		= 3,
		hp		= 4,
		mana	= 2,
		hpreg	= 2,
		manareg	= 4,
		ms		= 2,
	}
end

--------------------------------------------------------------------------------
function AI_Omniknight:constructor( unit )
	AI_FollowerBase.constructor( self, unit )

	-- Abilities
	self.ABILITY_purification	= self.vAbilities["omniknight_purification"]
	self.ABILITY_repel			= self.vAbilities["omniknight_repel"]
	self.ABILITY_guardian_angel	= self.vAbilities["omniknight_guardian_angel"]
end

--------------------------------------------------------------------------------
function AI_Omniknight:GetObjectiveTypeToClassMap()
	local types = AI_FollowerBase.GetObjectiveTypeToClassMap( self )

	-- Register additional objective types
	types[OBJECTIVE_TYPE_PURIFICATION]	= AI_Objective_Purification

	return types
end

--------------------------------------------------------------------------------
function AI_Omniknight:GetObjectiveTypesToShow()
	return { OBJECTIVE_TYPE_PURIFICATION }
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_Omniknight:COND_ReadyForPurification()
	if not self.ABILITY_purification:IsFullyCastable() then
		return false
	end

	-- Collect objectives
	local allies = self:FriendlyHeroesInRange( 700 )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_PURIFICATION, allies )

	-- Choose target
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_PURIFICATION]

	if not objective or not objective:IsAcceptable() then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_Omniknight:COND_ReadyForRepel()
	if not self.ABILITY_repel:IsFullyCastable() then
		return false
	end

	-- Collect
	local allies = self:FriendlyHeroesInRange( self.ABILITY_repel:GetCastRange() )
	local minimumHealthPercent = 101
	local bestTarget = nil
	for _,v in ipairs(allies) do
		if not v:IsMagicImmune() then
			if self.localNav:GetStateByWorldPos( v:GetAbsOrigin() ) == LGC_STATE_DANGER then
				if v:GetHealthPercent() < minimumHealthPercent then
					minimumHealthPercent = v:GetHealthPercent()
					bestTarget = v
				end
			end
		end
	end

	if not bestTarget then
		return false
	end

	self.targetRepel = bestTarget

	return true
end

--------------------------------------------------------------------------------
function AI_Omniknight:COND_ReadyForGuardianAngel()
	if not self.ABILITY_guardian_angel:IsFullyCastable() then
		return false
	end

	local radius = DotaHS_GetAbilitySpecialValue( self.ABILITY_guardian_angel, "radius" )

	-- Num enemies
	local numEnemies = #self:FindEnemiesInRange( radius + 200 )

	if numEnemies < 5 then
		return false
	end

	-- Chance to use
	local numPlayersAlive = DotaHS_NumPlayersAlive()
	local numInCombat = self:NumPlayersInCombat( radius )

	local percentToUse = math.max( numInCombat / numPlayersAlive - 0.5, 0 ) * 100

--	self:_Log( "Percent to use Guardian Angel = " .. percentToUse .. "%" )

	return RollPercentage( percentToUse )
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_Omniknight:ACT_CastPurification()
	local objective = self.vBestObjectives[OBJECTIVE_TYPE_PURIFICATION]
	if not objective:IsAcceptable() then
		return BH_FAILURE
	end

	return self:GetCastingAbilityState( self.ABILITY_purification, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, objective.entity, self.ABILITY_purification )
	end )
end

--------------------------------------------------------------------------------
function AI_Omniknight:ACT_CastRepel()
	return self:GetCastingAbilityState( self.ABILITY_repel, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.targetRepel, self.ABILITY_repel )
	end )
end

--------------------------------------------------------------------------------
function AI_Omniknight:ACT_CastGuardianAngel()
	return self:GetCastingAbilityState( self.ABILITY_guardian_angel, function ()
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, self.ABILITY_guardian_angel )
	end )
end



--------------------------------------------------------------------------------
-- Behavior Tree Builder
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Omniknight:ARRAY_DecisionMakingChildren()
	local array = AI_BehaviorTreeBuilder.ARRAY_DecisionMakingChildren( self )

	-- Modify
	self:InsertBefore( array, "Flee", self:NODE_GuardianAngel() )
	self:InsertBefore( array, "Flee", self:NODE_Purification() )
	self:InsertBefore( array, "Flee", self:NODE_Repel() )

	return array
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Omniknight:NODE_Purification()
	return SequenceNode( "Purification", {
		ConditionNode( "Ready?", "COND_ReadyForPurification" ),
		ActionNode( "Cast Purification", "ACT_CastPurification" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Omniknight:NODE_Repel()
	return SequenceNode( "Repel", {
		ConditionNode( "Ready?", "COND_ReadyForRepel" ),
		ActionNode( "Cast Repel", "ACT_CastRepel" ),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder_Omniknight:NODE_GuardianAngel()
	return Decorator_CooldownRandomAlsoFailure( 0.75, 1.25,
		SequenceNode( "Guardian Angel", {
			ConditionNode( "Ready?", "COND_ReadyForGuardianAngel" ),
			ActionNode( "Cast Guardian Angel", "ACT_CastGuardianAngel" ),
		} )
	)
end





--------------------------------------------------------------------------------
-- Objective : Purification
--------------------------------------------------------------------------------
AI_Objective_Purification = class({}, nil, AI_Objective)

AI_Objective_Purification.minimumEnemies = 3

--------------------------------------------------------------------------------
function AI_Objective_Purification:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_Purification:Evaluate()

	local radius = DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_purification, "radius" )
	local enemies = self.AI:FindEnemiesInRange( radius, self.entity:GetAbsOrigin() )
	self.nEnemiesInRange = #enemies

	-- Reset score
	self.scoreE = 0
	self.scoreH = 0

	-- Update score
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
function AI_Objective_Purification:IsAcceptable()
	if self.entity:IsMagicImmune() then
		return false
	end
	if not self.entity:IsAlive() then
		return false
	end

	if self.nEnemiesInRange >= self.minimumEnemies then
		return true
	end
	if self.entity:GetHealthDeficit() > DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_purification, "heal" ) then
		return true
	end
	return false
end

--------------------------------------------------------------------------------
function AI_Objective_Purification:GetDebugTextLines()
	return {
	--	"HEAL=" .. DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_purification, "heal" ),
	--	"RADIUS=" .. DotaHS_GetAbilitySpecialValue( self.AI.ABILITY_purification, "radius" ),
	}
end
