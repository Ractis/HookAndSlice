
require( "DotaHS_ItemManager" )
require( "DotaHS_AI_StrategyManager" )

--------------------------------------------------------------------------------
-- Objectives for AI
--------------------------------------------------------------------------------
AI_Objective						= class({})
AI_Objective_Enemy					= class({}, nil, AI_Objective)
AI_Objective_Tombstone				= class({}, nil, AI_Objective)
AI_Objective_PickupItem				= class({}, nil, AI_Objective)
AI_Objective_UsingPotion			= class({}, nil, AI_Objective)
AI_Objective_UsingHealingSalve		= class({}, nil, AI_Objective_UsingPotion)
AI_Objective_UsingGreaterClarity	= class({}, nil, AI_Objective_UsingPotion)
AI_Objective_Leader					= class({}, nil, AI_Objective)

-- Objective Types :
--   - Using Item (Potion or NotPotion)
--     + Allies States
--       - IF Potion    then (EnemyIsFar > EnemyIsNear)
--       - IF NotPotion then (EnemyIsNear > EnemyIsFar)
--     + Efficiency
--       - If NotPotion then (5 players > 2 players in the AoE range)

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local vUnitNameToIntensityMap = {
	
}



--------------------------------------------------------------------------------
-- Objective : Base class
--------------------------------------------------------------------------------
AI_Objective.CONST_D_A = 128	-- range A
AI_Objective.CONST_D_B = 1000	-- range B
AI_Objective.CONST_D = -10.0 / ( math.log(AI_Objective.CONST_D_B - AI_Objective.CONST_D_A) - math.log(AI_Objective.CONST_D_A) )
AI_Objective.CONST_H = 3.2

--------------------------------------------------------------------------------
function AI_Objective:constructor( entity, AI )
	self.AI = AI
	self.entity = entity
	self.score = 0
	self.heatColor = Vector(0,0,0)
end

--------------------------------------------------------------------------------
function AI_Objective:IsValid()
	return IsValidEntity( self.entity )
end

--------------------------------------------------------------------------------
function AI_Objective:GetDistance()
	if not self:IsValid() then return 999999 end

	return ( self.AI.entity:GetAbsOrigin() - self.entity:GetAbsOrigin() ):Length2D()
end

--------------------------------------------------------------------------------
function AI_Objective:GetDistanceScore( distanceOrNil )
	--
	-- Distances :
	--   - Penalty Applied Distance
	--		=> Distance score
	--   - Distance from Allies (DotProduct it by Ally's forward direction!)
	--		=> Cooperative score
	--
	--
	-- Score D
	--   http://www.wolframalpha.com/input/?i=plot+max%28ln%28x-a%29-ln%28a%29%2C0%29+%2F+%28ln%28b-a%29-ln%28a%29%29*10%2C+x%3D0+to+1000%2C+a%3D128%2C+b%3D1000
	--     Negate it!
	--
	-- if Distance == RANGE B then SCORE = -10.0
	--
	local distance = distanceOrNil or self:GetDistance()
	return math.max( math.log(distance - AI_Objective.CONST_D_A) - math.log(AI_Objective.CONST_D_A), 0.0 ) * self.CONST_D
end

--------------------------------------------------------------------------------
function AI_Objective:GetHealthScore()
	local healthPercent = self.entity:GetHealthPercent()
	--
	-- ScoreH
	--   http://www.wolframalpha.com/input/?i=plot+min%28ln%28100%2B1%29-ln%28x%2B1%29%2C2.5%29%2C+x%3D0+to+100 
	--
	local score = math.log(100+1) - math.log(healthPercent+1)
	return math.min( score, 2.5 ) * AI_Objective.CONST_H
end

--------------------------------------------------------------------------------
function AI_Objective:UpdateHeatColor( min, max )
	-- http://stackoverflow.com/a/20792531
	local ratio = 2 * ( self.score - min ) / ( max - min )
	local b = math.max( 0, 255 * ( 1 - ratio ) )
	local r = math.max( 0, 255 * ( ratio - 1 ) )
	local g = 255 - b - r
	self.heatColor = Vector( r, g, b )
end

--------------------------------------------------------------------------------
function AI_Objective:DebugDraw()
	if not self:IsValid() then return end

	local origin = self.entity:GetAbsOrigin()
	if self.debugOffset then
		origin = origin + self.debugOffset
	end

	--------------------------------------------------------------------------------
	-- Draw Box
	--
	local r = 8
	local offset = 32
	local alpha = 0.5
	DebugDrawBox( origin + Vector( 0, 0, offset ),
				  Vector(-r,-r,-r),
				  Vector(r,r,r),
				  self.heatColor.x,
				  self.heatColor.y,
				  self.heatColor.z,
				  255*alpha,
				  1.0 )

	--------------------------------------------------------------------------------
	-- Draw Text
	--
	local text = table.concat( self:GetDebugTextLines(), "\n" )
	local offset = 160
	DebugDrawText( origin + Vector( 0, 0, offset ), text, true, 1.0 )
end

--------------------------------------------------------------------------------
function AI_Objective:GetDebugTextLines()
	return {}
end



--------------------------------------------------------------------------------
-- Objective : Enemy
--------------------------------------------------------------------------------
AI_Objective_Enemy.CONST_H = 3.2

--------------------------------------------------------------------------------
function AI_Objective_Enemy:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )

	self.intensityValue = vUnitNameToIntensityMap[entity:GetUnitName()] or 0
end

--------------------------------------------------------------------------------
function AI_Objective_Enemy:Evaluate()
	-- 
	-- Score H = Health (Low > Full)
	-- Score A = Dangerous abilities are on Cooldown? (after 0-5sec > 5-?sec)
	-- Score I = Intensity level (BOSS? > Lich,Gyrocopter > Others)
	-- Score M = Modifiers (Regen > NONE > Haste)
	--
	-- Score C = Cooperative
	--
	self._healthPercent = self.entity:GetHealthPercent()

	self._scoreH = self:GetHealthScore()
	self._scoreI = self.intensityValue
	self._scoreD = self:GetDistanceScore()

	self.score = self._scoreH + self._scoreI + self._scoreD
	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_Enemy:GetDebugTextLines()
	return {
		self._healthPercent,
		("H=%.2f"):format( self._scoreH ),
		("I=%.2f"):format( self._scoreI ),
		("D=%.2f"):format( self._scoreD ),
		("%.2f"):format( self.score ),
	}
end



--------------------------------------------------------------------------------
-- Objective : Tombstone
--------------------------------------------------------------------------------
function AI_Objective_Tombstone:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )
end

--------------------------------------------------------------------------------
function AI_Objective_Tombstone:Evaluate()
	--
	-- Score O : Nearest distance to other tombstone
	-- Score E : Nearest distance to enemy (Using TENSION score instead is better)
	-- Score H : Current Health
	-- Score C : Time elapsed from last combat
	-- (Score T) : Time elapsed from death
	-- Score D : Distance from me
	--
	-- O + E*H*C + D ?
	--

	--
	-- Score O
	--
	local other, dist = AI_StrategyManager:GetNearestTombstone( self.entity )
	if other then
		self._distNearestOther = dist
		-- Closer > Farther
		self.scoreO = self:GetDistanceScore( self._distNearestOther )
		self.scoreO = self.scoreO * 0.65
	else
		self._distNearestOther = 0
		self.scoreO = 0
	end

	--
	-- Score E
	--
	self._enemyDist = AI_StrategyManager:GetNearestEnemyDistance( self.entity.DotaHS_PlayerID )
	-- Farther > Closer
	self.scoreE = -self:GetDistanceScore( self._enemyDist ) -- Negate
	self.scoreE = self.scoreE * 0.25--* 1.5

	--
	-- Score D
	--
	self.scoreD = self:GetDistanceScore()

	--
	-- Total Score
	--
	self.score = self.scoreO + self.scoreE + self.scoreD
	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_Tombstone:GetDebugTextLines()
	return {
		"Player[" .. self.entity.DotaHS_PlayerID .. "]",
		("Other=%.0f"):format( self._distNearestOther ),
		("Enemy=%.0f"):format( self._enemyDist ),
		("O=%.2f"):format( self.scoreO ),
		("E=%.2f"):format( self.scoreE ),
		("D=%.2f"):format( self.scoreD ),
		("%.2f"):format( self.score ),
	}
end



--------------------------------------------------------------------------------
-- Objective : PickupItem
--------------------------------------------------------------------------------
function AI_Objective_PickupItem:constructor( entity, AI )
	AI_Objective.constructor( self, entity:GetContainer(), AI )

	self.item = entity
	self.isConsumable = entity.IsDotaHSConsumable
	self._goldEfficiency = ItemManager:_EsitimateGoldEfficiency( entity, AI.ItemPropertyRating )
	self.scoreP = self._goldEfficiency / entity.DotaHS_GoldEfficiency
end

--------------------------------------------------------------------------------
function AI_Objective_PickupItem:Evaluate()
	--
	-- IsConsumable? (Consumable > Equipments)??
	-- Score T = (Smaller count item > Larger count item)
	-- Networth (Higher gold > lower)
	-- Score P = Properties (AGI,AS,DMG > STR,INT,Mana...)
	--
	if self.isConsumable then
		self._scoreD = self:GetDistanceScore()
		self.score = self._scoreD
	else	-- is equipment
		self.score = self.scoreP
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_PickupItem:IsDesiredItem( minimumGrowth )
	local costGrowth = ItemManager:EstimateEquipmentCostGrowth( self.AI.virtualPlayerID, self.item )
	return costGrowth > minimumGrowth
end

--------------------------------------------------------------------------------
function AI_Objective_PickupItem:GetDebugTextLines()
	if self.isConsumable then
		return {
			("D=%.2f"):format( self._scoreD ),
			("%.2f"):format( self.score ),
		}
	else
		return {
			("GOLD=%0.1f"):format( self.item.DotaHS_GoldEfficiency ),
			("GOLD*P=%0.1f"):format( self._goldEfficiency ),
			("P=%.2f"):format( self.scoreP ),
			("%.2f"):format( self.score ),
		}
	end
end



--------------------------------------------------------------------------------
-- Objective : UsingPotion
--------------------------------------------------------------------------------
AI_Objective_UsingPotion.minNearestEnemyDist	= 300
AI_Objective_UsingPotion.minPercentage			= 35

AI_Objective_UsingHealingSalve.itemShortName	= "Salve"
AI_Objective_UsingHealingSalve.itemName			= "item_flask"
AI_Objective_UsingHealingSalve.modifierName		= "modifier_flask_healing"
AI_Objective_UsingHealingSalve.totalRegen		= 400
AI_Objective_UsingHealingSalve.debugOffset		= Vector( -50, 0, 0 )

AI_Objective_UsingGreaterClarity.itemShortName	= "Clarity"
AI_Objective_UsingGreaterClarity.itemName		= "item_greater_clarity"
AI_Objective_UsingGreaterClarity.modifierName	= "modifier_item_greater_clarity"
AI_Objective_UsingGreaterClarity.totalRegen		= 150
AI_Objective_UsingGreaterClarity.debugOffset	= Vector( 50, 0, 0 )

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )

	self._targetPlayerID = DotaHS_HeroEntityToPlayerID( self.entity )

	if self._targetPlayerID == AI.virtualPlayerID then
		-- Target is myself
		self._minDurationFromCombat = 1.0
	else
		-- Target is other player
		self._minDurationFromCombat = 3.0
	end

	--
	-- Properties need to be set for each potionType :
	--   - itemShortName (for DEBUG)
	--   - itemName
	--   - modifierName
	--   - totalRegen
	--
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:GetMaximumValue()
	-- override me
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:GetCurrentValue()
	-- override me
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:GetCurrentPercent()
	return self:GetCurrentValue() / self:GetMaximumValue() * 100
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:HasPotionModifier()
	return self.entity:HasModifier( self.modifierName )
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:Evaluate()

	local bUpdateAll = true
	local isAcceptable = self:IsAcceptable( bUpdateAll )

	--
	-- Score C : Num Charges (Larger > Smaller, 0 is Unacceptable)
	-- Score E : Efficiency Score (Lower HP/Mana > Higher HP/Mana)
	-- Score N : Nearest Enemy Distance (Far > Near)
	-- Score T : Elapsed time from last combat (Longer > Shorter)
	--
	-- Score D : Distance from Me
	--

	if not isAcceptable and not bUpdateAll then
		self.score = -999999
	else
		--
		-- Score C
		--   log(x*2) - log(x) = 0.693..
		--   0.693 * coeff = 10.0 in distance score
		--   coeff = 14.43
		--
		self.scoreC = math.log( self._numCharges )
		self.scoreC = self.scoreC * 14.43

		--
		-- Score E
		--   Just use ScoreH of ENEMY and multiply it
		--   1.0 in health score = 10.0 in distance score
		--   coeff = 10
		--
		self.scoreE = math.log(100+1) - math.log(self._currentPercent+1)
		self.scoreE = math.min( self.scoreE, 2.5 ) * AI_Objective_Enemy.CONST_H
		self.scoreE = self.scoreE * 10.0

		-- Score D
		self.scoreD = self:GetDistanceScore()

		-- Total score
		if isAcceptable then
			self.score = self.scoreC + self.scoreE + self.scoreD
		else
			self.score = -999999
		end
	end

	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:IsAcceptable( bUpdateAll )
	--
	-- Checklist :
	--   - Num Charges is greater than 0
	--   - Target is alive
	--   - NOT has modifier
	--   - Elapsed time from last combat
	--   - Current Health/Mana status
	--   - Nearest enemy distance
	--

	local isAcceptable = true

	-- Reset all
	self.item					= nil
	self._numCharges			= -1
	self._elapsedTimeLastCombat	= -1
	self._currentValue			= -1
	self._currentPercent		= -1
	self._nearestEnemyDist		= -1

	-- Check num charges
	self.item = ItemManager:GetItemInDotaInventory( self.AI.virtualPlayerID, self.itemName )
	if not self.item then
		-- This potion not found
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	self._numCharges = self.item and self.item:GetCurrentCharges() or 0
	if self._numCharges <= 0 then
		-- This potion not found
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	-- Check alive
	if not self.entity:IsAlive() then
		-- Target is dead
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	-- Cehck modifier
	if self:HasPotionModifier() then
		-- Currently under effect of this potion
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	-- Check elapsed time
	self._elapsedTimeLastCombat = AI_StrategyManager:GetElapsedTimeFromLastCombat( self._targetPlayerID )
	if self._elapsedTimeLastCombat < self._minDurationFromCombat then
		-- Not relaxed yet
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	-- Check current status
	local maxValue			= self:GetMaximumValue()
	self._currentValue		= self:GetCurrentValue()
	self._currentPercent	= self:GetCurrentPercent()

	if self._currentPercent > self.minPercentage then
		-- Higher percentage
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	if maxValue - self._currentValue < self.totalRegen then
		-- Not efficiency
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	-- Check nearest enemy
	self._nearestEnemyDist = AI_StrategyManager:GetNearestEnemyDistance( self._targetPlayerID )
	if self._nearestEnemyDist < self.minNearestEnemyDist then
		-- Detected an enemy nearby
		if not bUpdateAll then return false end
		isAcceptable = false
	end

	return isAcceptable
end

--------------------------------------------------------------------------------
function AI_Objective_UsingPotion:GetDebugTextLines()
	return {
		self.itemShortName,
		("Elapsed=%.1f"):format( self._elapsedTimeLastCombat ),
		("Val=%d"):format( self._currentValue ),
		("Pct=%.0f"):format( self._currentPercent ),
		("Enemy=%.0f"):format( self._nearestEnemyDist ),
		("C=%0.1f"):format( self.scoreC ),
		("E=%0.1f"):format( self.scoreE ),
		("D=%0.1f"):format( self.scoreD ),
		("%.2f"):format( self.score ),
	}
end



--------------------------------------------------------------------------------
-- Objective : UsingHealingSalve
--------------------------------------------------------------------------------
function AI_Objective_UsingHealingSalve:GetMaximumValue()
	return self.entity:GetMaxHealth()
end

--------------------------------------------------------------------------------
function AI_Objective_UsingHealingSalve:GetCurrentValue()
	return self.entity:GetHealth()
end

--------------------------------------------------------------------------------
-- Objective : UsingGreaterClarity
--------------------------------------------------------------------------------
function AI_Objective_UsingGreaterClarity:GetMaximumValue()
	return self.entity:GetMaxMana()
end

--------------------------------------------------------------------------------
function AI_Objective_UsingGreaterClarity:GetCurrentValue()
	return self.entity:GetMana()
end



--------------------------------------------------------------------------------
-- Objective : Leader to follow
--------------------------------------------------------------------------------
function AI_Objective_Leader:constructor( entity, AI )
	AI_Objective.constructor( self, entity, AI )

	self._playerID = DotaHS_HeroEntityToPlayerID( entity )
end

--------------------------------------------------------------------------------
function AI_Objective_Leader:Evaluate()
	--
	-- Score N : Nearest Enemy Distance (far < NEAR)
	-- Score T : Elapsed time from last combat (longer < SHORTER)
	-- Score D : Distance from Me (NEAR > far)
	--

	--
	-- Score H
	--
	self._nearestEnemyDist = AI_StrategyManager:GetNearestEnemyDistance( self._playerID )
	self.scoreH = self:GetDistanceScore( self._nearestEnemyDist )
	self.scoreH = self.scoreH * 1.10

	--
	-- Score D
	--
	self.scoreD = self:GetDistanceScore()

	--
	-- Score P : Preferred?
	--
	if self.entity.DotaHS_IsFollowerBot then
		self.scoreP = -1000
	else
		self.scoreP = 0
	end

	--
	-- Total score
	--
	self.score = self.scoreH + self.scoreD + self.scoreP
	return self.score
end

--------------------------------------------------------------------------------
function AI_Objective_Leader:GetDebugTextLines()
	return {
		("Enemy=%.0f"):format( self._nearestEnemyDist ),
		("H=%0.1f"):format( self.scoreH ),
		("D=%0.1f"):format( self.scoreD ),
		("P=%0.0f"):format( self.scoreP ),
		("%.2f"):format( self.score ),
	}
end
