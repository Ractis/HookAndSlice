
require( "DotaHS_Common" )
require( "DotaHS_AI_BehaviorTree" )
require( "DotaHS_AI_StrategyManager" )
require( "DotaHS_AI_ObstacleManager" )
require( "DotaHS_AI_LocalGridNavMap" )
require( "DotaHS_AI_Objective" )
require( "DotaHS_ItemManager" )

require( "DotaHS_AI_Solvers" )

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
OBJECTIVE_TYPE_ENEMY					= "enemy"
OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE	= "pickupItemConsumable"
OBJECTIVE_TYPE_PICKUP_ITEM_EQUIPMENT	= "pickupItemEquipment"
OBJECTIVE_TYPE_TOMBSTONE				= "tombstone"
OBJECTIVE_TYPE_USE_SALVE				= "useSalve"
OBJECTIVE_TYPE_USE_CLARITY				= "useClarity"
OBJECTIVE_TYPE_LEADER					= "leader"

local vConsumableModifierMap = {
	item_dotahs_smoke_of_haste	= "modifier_smoke_of_haste",
	item_dotahs_smoke_of_bkb	= "modifier_smoke_of_bkb",
	item_dotahs_dust_of_silence	= "modifier_dust_of_silence",
}

local vPotionObjectiveClassesAsInjured = {
	AI_Objective_UsingHealingSalve,
	AI_Objective_UsingGreaterClarity,
}

--------------------------------------------------------------------------------
-- DEBUG CONSTANTS
--------------------------------------------------------------------------------
local AI_DEBUG_USING_CONSUMABLE	= false		-- More chance to use consumable

local vOrderTypeToOrderName = {
	[DOTA_UNIT_ORDER_NONE]					= "None",
	[DOTA_UNIT_ORDER_MOVE_TO_POSITION]		= "MoveTo",
	[DOTA_UNIT_ORDER_MOVE_TO_TARGET]		= "MoteTo",
	[DOTA_UNIT_ORDER_ATTACK_MOVE]			= "Attack",
	[DOTA_UNIT_ORDER_ATTACK_TARGET]			= "Attack",
	[DOTA_UNIT_ORDER_CAST_POSITION]			= "Cast",
	[DOTA_UNIT_ORDER_CAST_TARGET]			= "Cast",
	[DOTA_UNIT_ORDER_CAST_TARGET_TREE]		= "CastTree",
	[DOTA_UNIT_ORDER_CAST_NO_TARGET]		= "Cast",
	[DOTA_UNIT_ORDER_CAST_TOGGLE]			= "Toggle",
	[DOTA_UNIT_ORDER_HOLD_POSITION]			= "Hold",
	[DOTA_UNIT_ORDER_TRAIN_ABILITY]			= "TrainAbility",
	[DOTA_UNIT_ORDER_DROP_ITEM]				= "DropItem",
	[DOTA_UNIT_ORDER_GIVE_ITEM]				= "GiveItem",
	[DOTA_UNIT_ORDER_PICKUP_ITEM]			= "PickupItem",
	[DOTA_UNIT_ORDER_PICKUP_RUNE]			= "PickupRune",
	[DOTA_UNIT_ORDER_PURCHASE_ITEM]			= "PurchaseItem",
	[DOTA_UNIT_ORDER_SELL_ITEM]				= "SellItem",
	[DOTA_UNIT_ORDER_DISASSEMBLE_ITEM]		= "DisassembleItem",
	[DOTA_UNIT_ORDER_MOVE_ITEM]				= "MoveItem",
	[DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO]		= "CastToggleAuto",
	[DOTA_UNIT_ORDER_STOP]					= "Stop",
	[DOTA_UNIT_ORDER_TAUNT]					= "Taunt",
	[DOTA_UNIT_ORDER_BUYBACK]				= "Buyback",
	[DOTA_UNIT_ORDER_GLYPH]					= "Glyph",
	[DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH]	= "EjectItem",
	[DOTA_UNIT_ORDER_CAST_RUNE]				= "CastRune" ,
}

local vOrderTypeToColor = {
	[DOTA_UNIT_ORDER_MOVE_TO_POSITION]	= {0,1,0},
	[DOTA_UNIT_ORDER_MOVE_TO_TARGET]	= {0,1,0},
	[DOTA_UNIT_ORDER_ATTACK_MOVE]		= {1,0.5,0},
	[DOTA_UNIT_ORDER_ATTACK_TARGET]		= {1,0.5,0},
	[DOTA_UNIT_ORDER_CAST_POSITION]		= {1,0,1},
	[DOTA_UNIT_ORDER_PICKUP_ITEM]		= {1,1,0},
}

--------------------------------------------------------------------------------
-- FORWARD DECL
--------------------------------------------------------------------------------
if AI_BehaviorTreeBuilder == nil then
	AI_BehaviorTreeBuilder = class({})
end

if AI_FollowerBase == nil then
	AI_FollowerBase = class({})
	AI_FollowerBase.thinkDurationMin	= 0.05
	AI_FollowerBase.thinkDurationMax	= 0.1

	AI_FollowerBase.btreeBuilderClass	= AI_BehaviorTreeBuilder

	-- Hero specific properties
	AI_FollowerBase.unitClassname	= "INVALID Classname"
	AI_FollowerBase.unitShortname	= "INVALID Shortname"

	AI_FollowerBase.vAbilityNameList		= {}
	AI_FollowerBase.vAbilityUpgradeSequence	= {}

	AI_FollowerBase.vItemPropertyRating		= {}
end

--------------------------------------------------------------------------------
-- AI_FollowerBase
--------------------------------------------------------------------------------
function AI_FollowerBase:constructor( unit )

	self:_Log( "Creating AI for " .. self.unitShortname )

	if unit:GetClassname() ~= self.unitClassname then
		self:_Log( "Wrong unit class for this AI" )
		return
	end

	--------------------------------------------------------------------------------
	-- Initialize
	--
	self.entity = unit
	self.entity:SetContextThink( "AIThink", function ()
		return self:AIThink()
	end, self.thinkDurationMin )
	self.virtualPlayerID = unit.DotaHS_FollowerBotID

	self.localNav = AI_LocalGridNavMap( self.entity )

	-- Owned units
	self.vIllusions			= {}
	self.vDominatedUnits	= {}

	--------------------------------------------------------------------------------
	-- Abilities
	--
	self.vAbilities = {}
	for _,v in ipairs(self.vAbilityNameList) do
		local ability = unit:FindAbilityByName( v )
		if ability then
			self.vAbilities[v] = ability
		else
			self:_Log( "Ability not found! name = " .. v )
		end
	end

	--------------------------------------------------------------------------------
	-- Items
	--
	self.vItemPropertyRatingNormalized = {}
	for k,v in pairs(self.vItemPropertyRating) do
		self.vItemPropertyRatingNormalized[k] = v / 3
	end

	ItemManager:CreateInventory( self.virtualPlayerID )

	--------------------------------------------------------------------------------
	-- Behavior
	--
	self.selectedUnit				= self.entity
	self.lastOrder					= {}
	self.lastLocomotionOrder		= {}
	self.lastTarget					= nil
	self.bLocomotionPaused			= false
	self.interruptedLocomotionOrder	= {}
	self.interruptedLocomotionTimer	= nil

	self.vObjectiveTypeToClass = self:GetObjectiveTypeToClassMap()
	self.vObjectives = {}
	for objectiveType, objectiveClass in pairs(self.vObjectiveTypeToClass) do
		self.vObjectives[objectiveType] = {}
	end
	self.vBestObjectives	= {}
	self.vBestScores		= {}
	self.vWorstScores		= {}

	-- Create the behavior tree
	local builder = self.btreeBuilderClass()
	self.btree = builder:Build()
	self.btree:SetContext( self )

	--------------------------------------------------------------------------------
	-- DEBUG
	--
	self.vOrderMarkers		= {}

	local nodesSet = {}
	for _,v in ipairs( builder:GetCollapsedNodes() ) do
		nodesSet[v] = true
	end
	self.vBtreeCollapsedNodes = nodesSet
	
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GetObjectiveTypeToClassMap()
	return {
		[OBJECTIVE_TYPE_ENEMY]					= AI_Objective_Enemy,
		[OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE]	= AI_Objective_PickupItem,
		[OBJECTIVE_TYPE_PICKUP_ITEM_EQUIPMENT]	= AI_Objective_PickupItem,
		[OBJECTIVE_TYPE_TOMBSTONE]				= AI_Objective_Tombstone,
		[OBJECTIVE_TYPE_USE_SALVE]				= AI_Objective_UsingHealingSalve,
		[OBJECTIVE_TYPE_USE_CLARITY]			= AI_Objective_UsingGreaterClarity,
		[OBJECTIVE_TYPE_LEADER]					= AI_Objective_Leader,
	}
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GetObjectiveTypesToShow()
	return {
	--	OBJECTIVE_TYPE_ENEMY,
	--	OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE,
	--	OBJECTIVE_TYPE_PICKUP_ITEM_EQUIPMENT,
	--	OBJECTIVE_TYPE_TOMBSTONE,
	--	OBJECTIVE_TYPE_USE_SALVE,
	--	OBJECTIVE_TYPE_USE_CLARITY,
	--	OBJECTIVE_TYPE_LEADER,
	}
end

--------------------------------------------------------------------------------
-- AIThink
--------------------------------------------------------------------------------
function AI_FollowerBase:AIThink()

	self.localNav:Update()

	-- Validate owned units
	self.vIllusions = DotaHS_TableFilter( self.vIllusions, function ( unit )
		if not IsValidEntity( unit ) or not unit:IsAlive() then
			self:_Log( "Removed an illusion. ID = " .. unit:entindex() )
			return false
		end
		return true
	end )

	local myTeam = self.entity:GetTeam()
	self.vDominatedUnits = DotaHS_TableFilter( self.vDominatedUnits, function ( unit )
		if not IsValidEntity( unit ) or not unit:IsAlive() or myTeam ~= unit:GetTeam() then
			self:_Log( "Removed a dominated unit. ID = " .. unit:entindex() )
			return false
		end
		return true
	end )

	-- Tick the behavior tree
	self:CollectAllObjectives()
	self.btree:Tick()

	-- DEBUG
	if Convars:GetInt( "dotahs_ai_debug_selected_bot" ) == self.virtualPlayerID then
		if Convars:GetBool( "dotahs_ai_debug_enable" ) then
			self:DebugDraw()
			self.bDebugDraw = true
		else
			DebugDrawClear()
			self:BeginPrint( 0 )
			self.bDebugDraw = false
		end
	end

	return RandomFloat( self.thinkDurationMin, self.thinkDurationMax )

end

--------------------------------------------------------------------------------
-- Debug Draw
--------------------------------------------------------------------------------
function AI_FollowerBase:DebugDraw()
	DebugDrawClear()

	for k,v in ipairs(self.vOrderMarkers) do
		if v:IsExpired() then
			table.remove( self.vOrderMarkers, k )	-- REMOVE IT!
		else
			v:DrawMarker()
		end
	end

	if self.locomotionMoveFrom and self.locomotionMoveTo and self:LocomotionTargetPosition() then
		DebugDrawLine( self.locomotionMoveFrom, self:LocomotionTargetPosition(), 0, 255, 0, true, 1.0 )
	end

	-- Draw status
	self:BeginPrint( 0 )--3 )
	self:Print( self.unitShortname .. " AI Status" )
	self:Print( "------------------------------" )

	-- Modifiers
	if Convars:GetBool( "dotahs_ai_debug_show_modifiers" ) then
		for i=1, self.entity:GetModifierCount() do
			local modifierName = self.entity:GetModifierNameByIndex(i-1)
			self:Print( "Modifier[" .. i .. "] : " .. modifierName )
		end
	end

	-- Current Active Ability
	local activeAbility = self.entity:GetCurrentActiveAbility()
	if activeAbility then
		if activeAbility:IsChanneling() then
			local channelTime = activeAbility:GetChannelTime()
			local channelElapsed = GameRules:GetGameTime() - activeAbility:GetChannelStartTime()
			local channelPercent = channelElapsed / channelTime * 100
			self:Print( "Active : " .. ("[%.0f%%] "):format(channelPercent) .. activeAbility:GetAbilityName() )
		else
			self:Print( "Active : " .. activeAbility:GetAbilityName() )
		end
	end
	self:Print( "Interruptible : " .. tostring( self:COND_ChannelingInterruptible() ) )
	self:Print( "Not In Channel : " .. tostring( self:COND_NotInChanneling() ) )
	self:Print( "Threat Found : " .. tostring( self:COND_ShouldAvoidThreatImmediately() ) )

	self:Print( "Wander Chance Factor : " .. self:CalculateWanderChanceFactor() )
	self:GET_RandomAroundBestPlayer()
	local bestPlayerName
	if self.vBestObjectives[OBJECTIVE_TYPE_LEADER] then
		bestPlayerName = self.vBestObjectives[OBJECTIVE_TYPE_LEADER].entity:GetUnitName()
	else
		bestPlayerName = "<NONE>"
	end
	self:Print( "Best Player to Follow : " .. bestPlayerName )

	self:Print( "------------------------------" )

	self:PrintBehaviorNode( self.btree )

	self:EndPrint()

	-- Objectives
	for _,objectiveType in ipairs( self:GetObjectiveTypesToShow() ) do
		local minScore = self.vWorstScores[objectiveType]
		local maxScore = self.vBestScores[objectiveType]
		for _,objective in pairs( self.vObjectives[objectiveType] ) do
			objective:UpdateHeatColor( minScore, maxScore )
			objective:DebugDraw()
		end 
	end

	-- Obstacle
	if Convars:GetBool( "dotahs_ai_debug_show_obstacles" ) then
		AI_ObstacleManager:DebugDraw()
	end

	-- LGC
	if Convars:GetBool( "dotahs_ai_debug_show_localgridnav" ) then
		self.localNav:DebugDraw()
	end
end

--------------------------------------------------------------------------------
-- Collect All Objectives
--------------------------------------------------------------------------------
function AI_FollowerBase:CollectAllObjectives()
	
	local senseRadius = 1000

	-- Enemies
	local enemies = self:FindEnemiesInRange( senseRadius )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_ENEMY, enemies )

	-- Items
	local ITEM_UPDATE_SKIPS = 10
	if not self.updateSkipsItem then
		self.updateSkipsItem = 0
	else
		self.updateSkipsItem = self.updateSkipsItem + 1
	end

	if self.updateSkipsItem >= ITEM_UPDATE_SKIPS then
		self.updateSkipsItem = 0

		local items = Entities:FindAllByClassnameWithin( "dota_item_drop", self.entity:GetAbsOrigin(), senseRadius )
		local items_consumables = {}
		local items_equipments = {}
		for k,v in pairs(items) do
			local item = v:GetContainedItem()
			if item.IsDotaHSItem then
				if item.IsDotaHSCurrency then
					-- Don't care about currency
				elseif item.IsDotaHSConsumable then
					table.insert( items_consumables, item )
				else
					table.insert( items_equipments, item )
				end
			else
				-- What's this?
				--   item_dotahs_inventory
				--   item_dotahs_modifiers_*
			--print( item:GetName() )
			end
		end

	--	self:_Log( "Found Consumable Items : " .. #items_consumables .. " / " .. #items )
	--	self:_Log( "Found Equipment  Items : " .. #items_equipments .. " / " .. #items )
		self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE, items_consumables )
		self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_PICKUP_ITEM_EQUIPMENT,  items_equipments )
	end

	-- Tombstone
--	self:COND_ShouldReviveFriend()

	-- Using Potion
--	self:COND_ShouldUsePotion()

	-- Leader
--	self:GET_RandomAroundBestPlayer()

end

--------------------------------------------------------------------------------
-- Register Units as Objectives ( Update and Evaluate all units )
--------------------------------------------------------------------------------
function AI_FollowerBase:RegisterUnitsAsObjectives( objectiveType, units )
	local objectiveClass = self.vObjectiveTypeToClass[objectiveType]

	local min = 999999
	local max = -999999

	local objectives = {}
	local best = nil

	for k,v in pairs(units) do
		local objective = objectiveClass( v, self )
		local score = objective:Evaluate()
		if score > max then
			best = objective
		end
		min = math.min( min, score )
		max = math.max( max, score )
		objectives[v:entindex()] = objective
	end

	-- Store
	self.vObjectives	[objectiveType]	= objectives
	self.vBestObjectives[objectiveType]	= best
	self.vBestScores	[objectiveType]	= max
	self.vWorstScores	[objectiveType]	= min
end



--------------------------------------------------------------------------------
-- CONTROLLED UNITS
--------------------------------------------------------------------------------
function AI_FollowerBase:AssignIllusion( unit )
	table.insert( self.vIllusions, unit )
	self:_Log( "Added an illusion. ID = " .. unit:entindex() )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:AssignDominatedUnit( unit )
	table.insert( self.vDominatedUnits, unit )
	self:_Log( "Added a dominated unit. ID = " .. unit:entindex() )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:SetSelectedUnit( unitOrNil )
	self.selectedUnit = unitOrNil or self.entity
--	self:_Log( "Changed selected unit to " .. self.selectedUnit:entindex() )
end



--------------------------------------------------------------------------------
-- CONDITIONS
--------------------------------------------------------------------------------
function AI_FollowerBase:COND_HasAbilityPoints()
	return self.entity:GetAbilityPoints() > 0
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ChannelingInterruptible()
	local percentChannelAlmostFinish = 70
	local activeAbility = self.entity:GetCurrentActiveAbility()
	if activeAbility then
		if activeAbility:IsChanneling() then
			local channelTime = activeAbility:GetChannelTime()
			local channelElapsed = GameRules:GetGameTime() - activeAbility:GetChannelStartTime()
			local channelPercent = channelElapsed / channelTime * 100
			if channelPercent > percentChannelAlmostFinish then
				-- Keep channeling!
				return false
			end
		end
	end

	return true
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_NotInChanneling()
	local activeAbility = self.entity:GetCurrentActiveAbility()
	if activeAbility then
		if activeAbility:IsChanneling() then
			-- Keep channeling!
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldAvoidThreatImmediately()
	return self.localNav:GetCurrentState() == LGC_STATE_DANGER
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldReviveFriend()
	local tombstones = AI_StrategyManager:GetAllTombstones()
	if #tombstones == 0 then
		-- No ones dead
		return false
	end

	local activeAbility = self.entity:GetCurrentActiveAbility()
	if activeAbility and activeAbility:GetAbilityName() == "item_tombstone" then
		-- now reviving
		return false
	end

	-- Update tombstone objectives
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_TOMBSTONE, tombstones )

	-- Let's pick a tombstone!
	return RollPercentage( 100 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShoudUseConsumable()

--	self:_Log( "Checking Consumables... time = " .. GameRules:GetGameTime() )

	local consumableRange	= 1000
	local playersInRange	= self:FriendlyHeroesInRange( consumableRange )

	local numPlayersAlive	= DotaHS_NumPlayersAlive()
	local numPlayersInRange	= #playersInRange
	local ratioInRange		= numPlayersInRange / numPlayersAlive

	-- Checker
	local isGoodToUseConsumable = function ( consumableName, modifierName )

		if not ItemManager:GetItemInDotaInventory( self.virtualPlayerID, consumableName ) then
			-- The consumable does not exist in DotaInventory.
			return false
		end

		if self.entity:HasModifier( modifierName ) then
			-- Already under effect of this consumable
			return false
		end

		-- Calculate efficiency score
		local percentToUse = 0	-- about 1 tick per second

		if consumableName == "item_dotahs_smoke_of_haste" then

			-- Most players are moving?
			local numMoving = 0
			for _,unit in ipairs(playersInRange) do
				if not unit:HasModifier( modifierName ) then
					if AI_StrategyManager:IsMoving( DotaHS_HeroEntityToPlayerID( unit ) ) then
						numMoving = numMoving + 1
					end
				end
			end
		--	self:_Log( "Num Moving = " .. numMoving )

			percentToUse = math.max( numMoving / numPlayersAlive - 0.5, 0 ) * 10

		elseif consumableName == "item_dotahs_smoke_of_bkb" then

			-- Players in danger
			local numInDanger = 0
			for _,unit in ipairs(playersInRange) do
				if not unit:HasModifier( modifierName ) then
					if self.localNav:GetStateByWorldPos( unit:GetAbsOrigin() ) == LGC_STATE_DANGER then
						numInDanger = numInDanger + 1
					end
				end
			end
		--	self:_Log( "Num In Danger = " .. numInDanger )

			percentToUse = numInDanger / numPlayersAlive * 50

		elseif consumableName == "item_dotahs_dust_of_silence" then

			-- TODO: Take account of dangerous enemies
			-- Players in danger
			local numInDanger = 0
			for _,unit in ipairs(playersInRange) do
				if not unit:HasModifier( modifierName ) then
					if self.localNav:GetStateByWorldPos( unit:GetAbsOrigin() ) == LGC_STATE_DANGER then
						numInDanger = numInDanger + 1
					end
				end
			end

			percentToUse = numInDanger / numPlayersAlive * 25

		end

		return RollPercentage( percentToUse )

	end

	-- Loop over all consumable types
	local consumablesToUse = {}

	for k,v in pairs(vConsumableModifierMap) do
		if isGoodToUseConsumable( k, v ) then
			table.insert( consumablesToUse, k )
		end
	end

	-- Grabbed good consumables
	if #consumablesToUse > 0 then
		-- Select Random!
		self.bestConsumableName = consumablesToUse[ RandomInt( 1, #consumablesToUse ) ]
		return true
	end

	-- Best consumable not found.
	return false
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_InjuredOrUsingPotion()
	-- Check current health percent
	local healthPercent = self.entity:GetHealthPercent()
	if healthPercent < 22.5 then
		return true
	end

	-- Check potion states
	for _,objectiveClass in ipairs(vPotionObjectiveClassesAsInjured) do
		local objective = objectiveClass( self.entity, self )
		if objective:HasPotionModifier() and objective:GetCurrentPercent() < 95 then
			-- In effect of potion
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_NearbyEnemyExists()
	local radius = 600
	local enemies = self:FindEnemiesInRange( radius )
	if #enemies == 0 then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_Healing()
	local objective = AI_Objective_UsingHealingSalve( self.entity, self )
	if objective:HasPotionModifier() and objective:GetCurrentPercent() < 95 then
		-- In effect of salve
		return true
	end

	return false
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldUseSalveInFlee()
	if self.entity:HasModifier( "modifier_flask_healing" ) then
		return false
	end

	if not ItemManager:GetItemInDotaInventory( self.virtualPlayerID, "item_flask" ) then
		-- The consumable does not exist in DotaInventory.
		return false
	end

	if AI_StrategyManager:GetElapsedTimeFromLastCombat( self.virtualPlayerID ) < 2.0 then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldUseHasteInFlee()
	local item = ItemManager:GetItemInDotaInventory( self.virtualPlayerID, "item_dotahs_smoke_of_haste" )
	if not item then
		-- The consumable does not exist in DotaInventory.
		return false
	end

	if not item:IsCooldownReady() then
		-- Cooldown..
		return false
	end

	-- 0.5sec
	return RollPercentage( 25 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldFollowPlayer()
	local nearestPlayerDist = AI_StrategyManager:GetNearestNonFollowerPlayerDistance( self.virtualPlayerID )
	if nearestPlayerDist > 1600 then
		return true
	end

	return false
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ReadyForAttack()
	local radius = 0

	radius = self.entity:GetAcquisitionRange()

	-- Enemy nearby?
	local enemies = self:FindEnemiesInRange( radius )
	if #enemies == 0 then
		return false
	end

	-- Objective exists?
	if not self.vBestObjectives[OBJECTIVE_TYPE_ENEMY] then
		return false
	end

	-- Enemies found!
	self.targetAttack = self.vBestObjectives[OBJECTIVE_TYPE_ENEMY].entity

	return true
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldKiting()
	local radius = 300
	local enemies = self:FindEnemiesInRange( radius )
	local numEnemies = #enemies

	-- #ENEMY  1   2   3   4   5   6
	--         0% 20% 40% 60% (80%) max 70%
	local prob = ( numEnemies - 1 ) / 5
	prob = math.min( prob, 0.7 )
	return RandomFloat( 0, 1 ) < prob
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldMoveAroundTarget()
	return RollPercentage( 40 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldOrganizeInventory()
	local itemSlotPairToSwap = ItemManager:AI_GetItemSlotPairNeedToOrganize( self.virtualPlayerID )
	if itemSlotPairToSwap then
		self.itemSlotPairToSwap = itemSlotPairToSwap
		self:_Log( "Organizing inventory... : " .. itemSlotPairToSwap[1] .. " <=> " .. itemSlotPairToSwap[2] )
		return true
	end

	return false
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_ShouldUsePotion()
	-- Collect Objectives
	local senseRadius = 500
	local friends = self:FriendlyHeroesInRange( senseRadius )

	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_USE_SALVE,	friends )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_USE_CLARITY,	friends )

	-- Choose best potion
	if self.vBestScores[OBJECTIVE_TYPE_USE_SALVE] > self.vBestScores[OBJECTIVE_TYPE_USE_CLARITY] then
		self.bestPotion = self.vBestObjectives[OBJECTIVE_TYPE_USE_SALVE]
	else
		self.bestPotion = self.vBestObjectives[OBJECTIVE_TYPE_USE_CLARITY]
	end

	if not self.bestPotion or self.bestPotion.score < (-999999 + 1) then
		-- Best potion is also not acceptable
		return false
	end

	-- Roll
	return RollPercentage( 100 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_IsNotLargestConsumables()
	local myCount = ItemManager:GetNumConsumables( self.virtualPlayerID )
	local largestCount = ItemManager:GetLargestNumConsumables()

--	return myCount < largestCount
	return myCount < ( largestCount - RandomInt( 0, 3 ) )	-- Act random
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_FoundConsumable()
	return self.vBestObjectives[OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE] ~= nil
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_IsNotHighestEquipmentCost()
	local myCost = ItemManager:GetEquipmentCost( self.virtualPlayerID )
	local highestCost = ItemManager:GetHighestEquipmentCost()
	local EPSILON = 1e-3
	return ( highestCost - myCost ) > EPSILON
end

--------------------------------------------------------------------------------
function AI_FollowerBase:COND_FoundDesiredItem()
	local COST_STEP_MIN = 250
	local objectives = self.vObjectives[OBJECTIVE_TYPE_PICKUP_ITEM_EQUIPMENT]
	local desiredItemObjectives = {}
	for k,v in pairs(objectives) do
		if v:IsDesiredItem( COST_STEP_MIN ) then
			table.insert( desiredItemObjectives, v )
		end
	end

	if #desiredItemObjectives > 0 then
	--	self:_Log( ("%d desired items found."):format( #desiredItemObjectives ) )

		-- Find the best item for me
		local highestScoreP = 0
		local bestItemObjective
		for k,v in ipairs(desiredItemObjectives) do
			if v.scoreP > highestScoreP then
				highestScoreP = v.scoreP
				bestItemObjective = v
			end
		end

		self:_Log( "Update desired item to " .. bestItemObjective.item:GetClassname() )
		self.bestItemObjective = bestItemObjective

		return true
	end

	return false
end



--------------------------------------------------------------------------------
-- GETTERS
--------------------------------------------------------------------------------
function AI_FollowerBase:GET_NearestSafetyPosition()
	-- Do overrun
	local safetyPos = self.localNav:CalculateNearestSafetyPosition()
	if not safetyPos then return nil end

	return self:RandomPositionWithOvershoot( safetyPos, 200, 125 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GET_RetreatPosition()
	-- Simple Fleeing
--	return self:GET_PositionToKite()

	-- Find retreat using A*
	local friends = self:FriendlyHeroesInRange( FIND_UNITS_EVERYWHERE )
	for k,v in ipairs(friends) do
		if DotaHS_HeroEntityToPlayerID(v) == self.virtualPlayerID then
			-- Remove myself from the table
			table.remove( friends, k )
		end
	end
	local retreat = self.localNav:CalculateRetreatPosition( friends, self:FindEnemiesInRange( 600 ) )
	return self:RandomPositionWithOvershoot( retreat, 200, 200 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GET_PositionToKite()
	local radius = 600
	local distanceToKite = 300

	local enemies = self:FindEnemiesInRange( radius )
	local dangerousDir = Vector( 0, 0, 0 )
	for k,v in pairs( enemies ) do
		local dir = ( v:GetAbsOrigin() - self.entity:GetAbsOrigin() ):Normalized()
		dangerousDir = dangerousDir + dir
	end

	local posToKite = self.entity:GetAbsOrigin() - dangerousDir:Normalized() * distanceToKite

	return self:RandomPositionInRange( posToKite, 200 )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GET_PositionAroundTarget()
	if IsValidEntity( self.targetAttack ) then
		local targetToMe = self.targetAttack:GetAbsOrigin() - self.entity:GetAbsOrigin()

		local diffAngle = RandomFloat( -45, 45 )
		targetToMe = RotatePosition( Vector(0,0,0), QAngle(0,diffAngle,0), targetToMe )

		if targetToMe:Length2D() < 150 then
			local newRange = RandomFloat( 150, 200 )
			targetToMe = targetToMe:Normalized() * newRange
		end

		return self.targetAttack:GetAbsOrigin() + targetToMe
	end

	return nil -- Target is Invalid
end

--------------------------------------------------------------------------------
function AI_FollowerBase:GET_RandomAroundBestPlayer()
--	local nearestPlayer = self:NearestPlayer()
--	if not nearestPlayer then
--		return nil
--	end

	-- Collect objectives
	local friends = {}
	DotaHS_ForEachPlayer( function ( playerID, hero )
		if hero and IsValidEntity(hero) then
			if playerID ~= self.virtualPlayerID then
				table.insert( friends, hero )
			end
		end
	end )
	self:RegisterUnitsAsObjectives( OBJECTIVE_TYPE_LEADER, friends )

	if not self.vBestObjectives[OBJECTIVE_TYPE_LEADER] then
		-- No players found.
		return nil
	end

	local bestPlayer = self.vBestObjectives[OBJECTIVE_TYPE_LEADER].entity
	if not bestPlayer then
		return nil
	end

	return self:RandomPositionInRange( bestPlayer:GetAbsOrigin(), 100, 500 )
end



--------------------------------------------------------------------------------
-- PROBABILITIES
--------------------------------------------------------------------------------
function AI_FollowerBase:PROB_IdleBehavior()
	if AI_DEBUG_USING_CONSUMABLE then
		return { 0, 0, 1, 0 }
	end

	-- Calculate chance of wandering
	local wanderFactor = self:CalculateWanderChanceFactor()

	return {
		1 * wanderFactor,		-- Wander
		0.5,	-- Use Potion
		0.5,	-- Pickup Consumable
		1,		-- Pickup Equipment
	}
end



--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_UpgradeAbility()
	local abilityPoints = self.entity:GetAbilityPoints()

	if abilityPoints > 0 then
		local currentUnitLevel = self.entity:GetLevel()

		local numUpgrade = 1
		if abilityPoints > 5 then
			-- Now debugging!
			numUpgrade = 6
		end

		for i=1, numUpgrade do
			local unitLevel		= currentUnitLevel - abilityPoints + i
			local abilityIndex	= self.vAbilityUpgradeSequence[ unitLevel ]
			local abilityName	= self.vAbilityNameList[ abilityIndex ]
			local ability		= self.vAbilities[ abilityName ]
			if ability then
				self.entity:UpgradeAbility( ability )
				self:_Log( "UnitLevel = " .. unitLevel .. " : Ability Upgraded = " .. ability:GetAbilityName() )
			else
				-- Be caraful! HERO:UpgradeAbility( nil ) will cause CTD. @ Oct.24 2014
				self:_Log( "Ability to upgrade not found." )
			end
		end
	end

	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_InterruptCurrentLocomotion()
	if self.lastLocomotionOrder then
		self.interruptedLocomotionOrder = self.lastLocomotionOrder
		self.interruptedLocomotionTimer = GameRules:GetGameTime() + RandomFloat( 1.0, 1.5 )
	end
	self:CreateOrder( DOTA_UNIT_ORDER_HOLD_POSITION )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_ReviveSolo()
--	local target = AI_StrategyManager:GetNearestTombstone( self.entity )
	local target = self.vBestObjectives[OBJECTIVE_TYPE_TOMBSTONE].entity

	if not target or not IsValidEntity(target) then
		-- No tombstones exist
		return BH_FAILURE
	end

	self:CreateOrder( DOTA_UNIT_ORDER_PICKUP_ITEM, target )
	return BH_RUNNING
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_UseConsumable()
	local item = ItemManager:GetItemInDotaInventory( self.virtualPlayerID, self.bestConsumableName )
	if not item then
		return BH_FAILURE
	end

	self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, item )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_UseSalve()
	local item = ItemManager:GetItemInDotaInventory( self.virtualPlayerID, "item_flask" )
	if not item then
		return BH_FAILURE
	end

	self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.entity, item )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_UseSmokeOfHaste()
	local item = ItemManager:GetItemInDotaInventory( self.virtualPlayerID, "item_dotahs_smoke_of_haste" )
	if not item then
		return BH_FAILURE
	end

	self:CreateOrder( DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, item )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_AttackTarget()
	if not self.targetAttack then
		-- Target not found
		return BH_FAILURE
	end

	self:CreateOrder( DOTA_UNIT_ORDER_ATTACK_TARGET, self.targetAttack )

	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_OrganizeInventory()
	ItemManager:AI_OrganizeInventory( self.virtualPlayerID, self.itemSlotPairToSwap )
	self.itemSlotPairToSwap = nil
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_UsePotion()
	if not self.bestPotion.hasBeenIssued then
		-- Issue the order
		self:CreateOrder( DOTA_UNIT_ORDER_CAST_TARGET, self.bestPotion.entity, self.bestPotion.item )
		self.bestPotion.hasBeenIssued = true
	end

	if not self.bestPotion:IsAcceptable() then
		-- No longer acceptable
		self:CreateOrder( DOTA_UNIT_ORDER_STOP )
		return BH_FAILURE
	end

	return BH_RUNNING
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_PickupConsumable()
	self:CreateOrder( DOTA_UNIT_ORDER_PICKUP_ITEM, self.vBestObjectives[OBJECTIVE_TYPE_PICKUP_ITEM_CONSUMABLE].entity )
	return BH_SUCCESS
end

--------------------------------------------------------------------------------
function AI_FollowerBase:ACT_PickupDesiredItem()
	self:CreateOrder( DOTA_UNIT_ORDER_PICKUP_ITEM, self.bestItemObjective.entity )
	return BH_SUCCESS
end



--------------------------------------------------------------------------------
-- EVALUATE
--------------------------------------------------------------------------------
function AI_FollowerBase:CalculateWanderChanceFactor()
	local factor = 1.0

	local nearestEnemyDist = AI_StrategyManager:GetNearestEnemyDistanceFromParty( self.virtualPlayerID )
	if nearestEnemyDist < 300 then
		factor = factor * 8
	elseif nearestEnemyDist < 500 then
		factor = factor * 4
	end

	local nearestPlayerDist = AI_StrategyManager:GetNearestNonFollowerPlayerDistance( self.virtualPlayerID )
	if nearestPlayerDist > 1200 then
		factor = factor * 5
	elseif nearestPlayerDist > 700 then
		factor = factor * 2
	end

	return factor
end



--------------------------------------------------------------------------------
-- ABILITY
--------------------------------------------------------------------------------
function AI_FollowerBase:GetCastingAbilityState( ability, funcCreateOrder )
	if type(ability) == "string" then
		ability = self.vAbilities[ability]
	end

	if ability:IsFullyCastable() then
		-- Issue the order
		funcCreateOrder()
		return BH_RUNNING
	
	elseif ability:IsInAbilityPhase() then
		-- Casting
		return BH_RUNNING

	elseif ability:IsChanneling() then
		-- Channeling
		return BH_RUNNING

	elseif not ability:IsCooldownReady() then
		-- Casted successfully
		return BH_SUCCESS

	else
		-- Failed to cast
		return BH_FAILURE
	end
end



--------------------------------------------------------------------------------
-- ORDERS
--------------------------------------------------------------------------------
function AI_FollowerBase:CreateOrder( order, target, ability, position, queue )
	
	-- Don't pass OBJECTIVE to the target parameter!

	if target and not IsValidEntity(target) then
		-- The target is no longer exists
		return
	end

	local targetIndex	= target and target:entindex() or nil
	local abilityIndex	= ability and ability:entindex() or nil
	local unitIndex		= self.selectedUnit:entindex()

	-- Create a new order
	local newOrder = {
		UnitIndex		= unitIndex,
		OrderType		= order,
		TargetIndex		= targetIndex,
		AbilityIndex	= abilityIndex,
		Position		= position,
		Queue			= queue,
	}

	-- Are we executing this order already?
	local equals = function ( orderA, orderB )
		for k,v in pairs( orderA ) do
			if k == "Position" then
				if orderB.Position then
					if ( orderA.Position - orderB.Position ):Length2D() > 1e-3 then
						return false
					end
				else
					return false
				end

			elseif v ~= orderB[k] then
				return false
			end
		end
		return true
	end

	local repeatedlyIssueOrders = false
--	if order == DOTA_UNIT_ORDER_CAST_TARGET then
--		repeatedlyIssueOrders = true
--	end

	-- Check
	if not repeatedlyIssueOrders and equals( newOrder, self.lastOrder ) then
		return
	end

	if self.interruptedLocomotionTimer then
		local interruptedRemaining = self.interruptedLocomotionTimer - GameRules:GetGameTime()
		if interruptedRemaining > 0 then
			--self:_Log( "Interrupted Locomotion Remaining = " .. interruptedRemaining )
			if equals( newOrder, self.interruptedLocomotionOrder ) then
				--self:PrintOrder( "InterruptOrder", newOrder )
				return
			end
		end
	end

	-- Save locomotion states
	local targetType = nil
	local moveTo = nil
	local acceptableRadius = 0

	if order == DOTA_UNIT_ORDER_MOVE_TO_TARGET or
	   order == DOTA_UNIT_ORDER_ATTACK_TARGET or
	   order == DOTA_UNIT_ORDER_CAST_TARGET or
	   order == DOTA_UNIT_ORDER_PICKUP_ITEM then

		targetType = "unit"
		moveTo = target

		if order == DOTA_UNIT_ORDER_ATTACK_TARGET then
			acceptableRadius = self.entity:GetAttackRange()
		end

	elseif order == DOTA_UNIT_ORDER_MOVE_TO_POSITION or
		   order == DOTA_UNIT_ORDER_ATTACK_MOVE or
		   order == DOTA_UNIT_ORDER_CAST_POSITION then

		targetType = "position"
		moveTo = position
		moveTo.z = self.entity:GetAbsOrigin().z

	elseif order == DOTA_UNIT_ORDER_CAST_NO_TARGET or
		   order == DOTA_UNIT_ORDER_HOLD_POSITION or 
		   order == DOTA_UNIT_ORDER_STOP then
		-- Does not affect to any locomotion states

	else
		self:_Log( "!!! Not Registered Order Type !!!" )
		
	end

	if targetType then
		self.locomotionTargetType		= targetType
		self.locomotionMoveFrom			= self.entity:GetAbsOrigin()
		self.locomotionMoveTo			= moveTo
		self.locomotionAcceptableRadius = acceptableRadius
		self.lastLocomotionOrder		= newOrder
	end

	-- Execute order
	self:ExecuteOrder( newOrder )

end

--------------------------------------------------------------------------------
function AI_FollowerBase:ExecuteOrder( order )
	ExecuteOrderFromTable( order )
	self.lastOrder = order

	-- Debug
--	self:PrintOrder( "ExecuteOrder", order )

	if order.Position or order.TargetIndex then
		local position
		local bCircle = true
		if self.locomotionTargetType == "position" then
			position = self.locomotionMoveTo
		elseif self.locomotionTargetType == "unit" then
			position = self.locomotionMoveTo:GetAbsOrigin()
			bCircle = false
		end

		local color = vOrderTypeToColor[order.OrderType] or {0.75,0.75,0.75}

		-- Add a order marker
		table.insert( self.vOrderMarkers, OrderMarker( position, color, bCircle, self.entity ) )
	end
end

--------------------------------------------------------------------------------
function AI_FollowerBase:PrintOrder( msg, order )
	local text = msg .. " : Type=" .. vOrderTypeToOrderName[order.OrderType] .. ", "
	if order.Queue then
		text = "> " .. text
	end
	if order.TargetIndex then
		text = text .. "Target=" .. order.TargetIndex .. "(" ..  EntIndexToHScript(order.TargetIndex):GetName() .. "), "
	end
	if order.AbilityIndex then
		text = text .. "Ability=" .. order.AbilityIndex .. "(" .. EntIndexToHScript(order.AbilityIndex):GetAbilityName() .. "), "
	end
	if order.Position then
		text = text .. "Position=" .. ("(%.1f, %.1f)"):format(order.Position.x, order.Position.y) .. ", "
	end
	self:_Log( text )
end



--------------------------------------------------------------------------------
-- Locomotion
--------------------------------------------------------------------------------
function AI_FollowerBase:MoveTo( targetPosition, bDontInterrupt )
	local lastLocomotionOrder = self.lastLocomotionOrder
	self:CreateOrder( DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, nil, targetPosition )
	self:CreateOrder( DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil, nil, true )
	if not bDontInterrupt then
		self.lastLocomotionOrder = lastLocomotionOrder
	end
end

--------------------------------------------------------------------------------
function AI_FollowerBase:LocomotionTargetPosition()
	if self.locomotionTargetType == "unit" then
		local thisPos = self.entity:GetAbsOrigin()
		if IsValidEntity( self.locomotionMoveTo ) then
			self.lastLocomotionTargetUnitPosition = self.locomotionMoveTo:GetAbsOrigin()
		else
			return nil
		end
		local targetPos = self.lastLocomotionTargetUnitPosition
		local direction = targetPos - thisPos
		local dist = direction:Length2D()
		direction = direction:Normalized()

		if dist < self.locomotionAcceptableRadius then
			return thisPos
		else
			return targetPos - direction * self.locomotionAcceptableRadius
		end

	elseif self.locomotionTargetType == "position" then
		return self.locomotionMoveTo

	else
		return nil
	end
end



--------------------------------------------------------------------------------
-- Find
--------------------------------------------------------------------------------
function AI_FollowerBase:RandomPositionInRange( center, range, range2Optional )
	local randomVec
	if range2Optional then
		randomVec = RandomVector( RandomFloat( range, range2Optional ) )
	else
		randomVec = RandomVector( RandomFloat( 0, range ) )
	end

	return center + randomVec
end

--------------------------------------------------------------------------------
function AI_FollowerBase:RandomPositionWithOvershoot( target, overshootDist, overshootRadius )
	local targetDir = ( target - self.entity:GetAbsOrigin() ):Normalized()
	return self:RandomPositionInRange( target + targetDir * overshootDist, overshootRadius )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:FindEnemiesInRange( range, positionOrNil )
	-- DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES	= 16
	-- DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE			= 128
	-- DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED			= 524288
--	if not self.debugDotaUnitTargetFlag then
--		self.debugDotaUnitTargetFlag = true
--		print( "DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE = " .. DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE )
--		print( "DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES = " .. DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES )
--		print( "DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED = " .. DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED )
--	end

	local flags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
				+ DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE
				+ DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED

	local position = positionOrNil or self.entity:GetAbsOrigin()

	return FindUnitsInRadius( self.entity:GetTeam(),
							  position,
							  nil,
							  range,
							  DOTA_UNIT_TARGET_TEAM_ENEMY,
							  DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
							  flags,
							  0,
							  false )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:FriendlyHeroesInRange( range, positionOrNil )
	local position = positionOrNil or self.entity:GetAbsOrigin()
	return FindUnitsInRadius( self.entity:GetTeam(),
							  position,
							  nil,
							  range,
							  DOTA_UNIT_TARGET_TEAM_FRIENDLY,
							  DOTA_UNIT_TARGET_HERO,
							  DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
							  FIND_CLOSEST,
							  false )
end

--------------------------------------------------------------------------------
function AI_FollowerBase:NumPlayersInCombat( range )
	local playersInRange = self:FriendlyHeroesInRange( range )

	local numInCombat = 0

	for _,unit in ipairs(playersInRange) do
		if unit:IsAlive() then
			local playerID = DotaHS_HeroEntityToPlayerID( unit )
			local nearestEnemyDist		= AI_StrategyManager:GetNearestEnemyDistance( playerID )
			local elapsedFromLastCombat	= AI_StrategyManager:GetElapsedTimeFromLastCombat( playerID )

		--	self:_Log( "Player[" .. playerID .. "] : NearestEnemyDist = " .. nearestEnemyDist .. ", ElapsedFromLastCombat = " .. elapsedFromLastCombat )

			if nearestEnemyDist < 300 or elapsedFromLastCombat < 1.0 then
				numInCombat = numInCombat + 1
			end
		end
	end

	return numInCombat
end



--------------------------------------------------------------------------------
-- DEBUG
--------------------------------------------------------------------------------
function AI_FollowerBase:BeginPrint( offset )
--	UTIL_ResetMessageTextAll()
	UTIL_ResetMessageText( 1 )
	for i=1, offset do
		self:Print( "" )
	end
end

function AI_FollowerBase:Print( text, color )
	if not text then
		self:_Log( "Print : text is null!!!" )
		return
	end

	color = color or { 255, 255, 255, 255 }

--	UTIL_MessageTextAll( text, unpack( color ) )
	UTIL_MessageText( 1, text, unpack(color) )
end

function AI_FollowerBase:EndPrint()
end

--------------------------------------------------------------------------------
function AI_FollowerBase:PrintBehaviorNode( node, currentDepth )
	currentDepth = currentDepth or 0
	local isCollapsed = self.vBtreeCollapsedNodes[node.name]

	local row = string.rep( "\t", currentDepth )

	if isCollapsed then
		row = row .. "+++"
	end

	if node.prefix then
		row = row .. node.prefix .. " "
	end

	row = row .. ( node.children and "[" or "(" ) .. node.tag .. ( node.children and "]" or ")" ) .. " "

	if #node.description > 0 then
		row = row .. node.description
	else
		row = row .. node.name
	end

	self:Print( row, BehaviorStatusColorMap[node.status] )

	if node.children and not isCollapsed then
		for _,v in ipairs( node.children ) do
			self:PrintBehaviorNode( v, currentDepth + 1 )
		end
	end

	if node.decoratedNode then
		self:PrintBehaviorNode( node.decoratedNode, currentDepth + 1 )
	end
end



--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function AI_FollowerBase:_Log( text )
	print( "[AI/" .. self.unitShortname .. "] " .. text )
end





--------------------------------------------------------------------------------
--
-- Behavior Tree Builder
--
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:Build()
	return ParallelNode( "Root", {
		self:NODE_UpgradeAbility(),
		self:NODE_DecisionMaking(),
	} )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:GetCollapsedNodes()
	return {
		"Upgrade Ability",

		"Avoid Threats",
		"Revive Friend",
		"Using Consumable",
		"Flee",
		"Follow Player",
		"Combat",
		"Organize Inventory",
		"Idle",
			"Wander",
			"Pickup Consumable",
			"Pickup Equipment",
	}
end

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:InsertBefore( array, nodeName, nodeToInsert )
	for k,v in ipairs(array) do
		if self:GetNodeName( v ) == nodeName then
			table.insert( array, k, nodeToInsert )
			return
		end
	end

	DoScriptAssert( false, "INVALID node name!! name = " .. nodeName )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:GetNodeName( node )
	if not node.decoratedNode then
		return node.name
	else
		-- Decorator
		return self:GetNodeName( node.decoratedNode )
	end
end

--------------------------------------------------------------------------------
-- Root / Upgrade Ability
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_UpgradeAbility()
	return Decorator_Loop( -1,
		SequenceNode( "Upgrade Ability", {
			ConditionNode( "Has Ability Points?", "COND_HasAbilityPoints" ),
			Action_WaitRandom( 1.5, 3.0 ),
			ActionNode( "Upgrade Ability", "ACT_UpgradeAbility" ),
		} )
	)
end

--------------------------------------------------------------------------------
-- Root / Decision Making
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_DecisionMaking()
	return Decorator_Loop( -1,
		PrioritySelectorNode( "Decision Making", self:ARRAY_DecisionMakingChildren() )
	)
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:ARRAY_DecisionMakingChildren()
	return {
		self:NODE_AvoidThreats(),
		self:NODE_ReviveFriend(),
		self:NODE_UsingConsumable(),
		self:NODE_Flee(),
		self:NODE_FollowPlayer(),
		self:NODE_Combat(),
		self:NODE_OrganizeInventory(),
		self:NODE_Idle(),
	}
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Avoid Threats
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_AvoidThreats()
	return SequenceNode( "Avoid Threats", { 
		ConditionNode( "Channeling Interruptible?", "COND_ChannelingInterruptible" ),
		ConditionNode( "Threat Found?", "COND_ShouldAvoidThreatImmediately" ),
		ActionNode( "Interrupt Current Locomotion", "ACT_InterruptCurrentLocomotion" ),
		Action_MoveTo( "Safety Position", "GET_NearestSafetyPosition", true ),
		Action_Wait( 0.5 ),
	} )
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Revive Friend
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_ReviveFriend()
	return Decorator_CooldownRandom( 0.5, 1.0, SequenceNode( "Revive Friend", {
		ConditionNode( "Should Revive?", "COND_ShouldReviveFriend" ),
		PrioritySelectorNode( "Revive Strats", self:ARRAY_ReviveStrats() ),
	} ) )
end

--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:ARRAY_ReviveStrats()
	return {
		Decorator_ForceSuccess( SequenceNode( "Revive Solo", {
			ConditionNode( "Not In Channeling?", "COND_NotInChanneling" ),
			ActionNode( "Revive Best", "ACT_ReviveSolo" ),
		} ) ),
	}
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Using Consumable
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_UsingConsumable()
	return Decorator_CooldownRandomAlsoFailure( 0.75, 1.25,
		SequenceNode( "Using Consumable", {
			ConditionNode( "Should Use Consumable?", "COND_ShoudUseConsumable" ),
			ActionNode( "Use Consumable", "ACT_UseConsumable" ),
		} )
	)
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Flee
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_Flee()
	return SequenceNode( "Flee", {
		ConditionNode( "Injured or Healing?", "COND_InjuredOrUsingPotion" ),
		ConditionNode( "Enemy Nearby?", "COND_NearbyEnemyExists" ),
		Decorator_ForceSuccess( SelectorNode( "Flee Strats", {
			SequenceNode( "Healing", {
				ConditionNode( "Healing?", "COND_Healing" ),
			} ),
			SequenceNode( "Use Salve", {
				ConditionNode( "Use Salve?", "COND_ShouldUseSalveInFlee" ),
				ActionNode( "Heal", "ACT_UseSalve" ),
			} ),
			SequenceNode( "Use Haste", {
				ConditionNode( "Use Haste?", "COND_ShouldUseHasteInFlee" ),
				ActionNode( "Haste", "ACT_UseSmokeOfHaste" ),
			} ),
		} ) ),
		Action_MoveTo( "Retreat", "GET_RetreatPosition" ),
		Action_Wait( 0.5 ),
	} )
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Follow Player
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_FollowPlayer()
	return SequenceNode( "Follow Player", {
		ConditionNode( "Should Follow Player?", "COND_ShouldFollowPlayer" ),
		Action_MoveTo( "Random Around Player", "GET_RandomAroundBestPlayer" ),
		Action_Wait( 1.0 ),
	} )
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Combat
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_Combat()
	return SequenceNode( "Combat", {
		ConditionNode( "Ready for Attack?", "COND_ReadyForAttack" ),
		SequenceNode( "Attack", {
			ActionNode( "Attack to Target", "ACT_AttackTarget" ),
			Action_WaitRandom( 0.4, 0.5 ),
			SelectorNode( "Attack & Move", {
				SequenceNode( "Kiting", { 
					ConditionNode( "Do Kiting?", "COND_ShouldKiting" ),
					Action_Wait( 0.35 ),
					Action_MoveTo( "Safe Position", "GET_PositionToKite" ),
					Action_Wait( 0.3, 0.45 ),
				} ),
				SequenceNode( "Move Around", {
					ConditionNode( "Move Around? ", "COND_ShouldMoveAroundTarget" ),
					Action_Wait( 0.35 ),
					Action_MoveTo( "Around Target", "GET_PositionAroundTarget" ),
					Action_Wait( 0.3, 0.45 ),
				} ),
			} ),
		} ),
	} )
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Organize Inventory
--------------------------------------------------------------------------------
function AI_BehaviorTreeBuilder:NODE_OrganizeInventory()
	return Decorator_CooldownRandom( 0.5, 1.0, SequenceNode( "Organize Inventory", {
		ConditionNode( "Organize Inventory?", "COND_ShouldOrganizeInventory" ),
		Action_WaitRandom( 0.5, 1.0 ),
		ActionNode( "Do it!", "ACT_OrganizeInventory" ),
	} ) )
end

--------------------------------------------------------------------------------
-- Root / Decision Making / Idle
--------------------------------------------------------------------------------
function  AI_BehaviorTreeBuilder:NODE_Idle()
	return Decorator_CooldownRandom( 0.5, 3.0, ProbabilitySelectorNode( "Idle", "PROB_IdleBehavior", {
		SequenceNode( "Wander", {
			Action_WaitRandom( 0.5, 1.5 ),
			Action_MoveTo( "Random Around Player", "GET_RandomAroundBestPlayer" ),
		--	Action_WaitRandom( 0.5, 2.5 ),
		} ),
		SequenceNode( "Use Potion", {
			ConditionNode( "Should Use Potion?", "COND_ShouldUsePotion" ),
			ActionNode( "Use Potion", "ACT_UsePotion" ),
			Action_WaitRandom( 0.75, 1.25 ),
		} ),
		SequenceNode( "Pickup Consumable", {
			ConditionNode( "Largest is NOT me?", "COND_IsNotLargestConsumables" ),
			ConditionNode( "Found Consumable?", "COND_FoundConsumable" ),
			ActionNode( "Grab Consumable", "ACT_PickupConsumable" ),
			Action_WaitRandom( 1, 2 ),
		} ),
		SequenceNode( "Pickup Equipment", {
			ConditionNode( "Highest is NOT me?", "COND_IsNotHighestEquipmentCost" ),
			ConditionNode( "Found Desired Item?", "COND_FoundDesiredItem" ),
		--	Action_MoveTo( "Nearby Items", "GET_NearbyDesiredItem" ),
			ActionNode( "Grab Desired Item", "ACT_PickupDesiredItem" ),
			Action_WaitRandom( 1, 2 ),
		} ),
	} ) )
end





--------------------------------------------------------------------------------
--
-- OrderMarker for Debug
--
--------------------------------------------------------------------------------
OrderMarker = class({})
OrderMarker.duration = 0.75

function OrderMarker:constructor( position, color, bCircle, entity )
	self.position = GetGroundPosition( position, entity )
	self.position.z = self.position.z + 16
	self.expiredTime = GameRules:GetGameTime() + OrderMarker.duration
	self.vRgb = Vector( color[1]*255, color[2]*255, color[3]*255 )
	self.bCircle = bCircle
end

function OrderMarker:IsExpired()
	return self.expiredTime <= GameRules:GetGameTime()
end

function OrderMarker:DrawMarker()
	-- Inner
	local alpha = 1.0 * 255
	local radius = 8
	local color = ( Vector(255,255,255) + self.vRgb ) * 0.5

	if self.bCircle then
		DebugDrawCircle( self.position, color, alpha, radius, true, 1.0 )
	else
		DebugDrawBoxDirection( self.position, Vector(radius,radius,0)/-1.414, Vector(radius,radius,0)/1.414, Vector(1,1,0):Normalized(), color, alpha, 1.0 )
	end

	-- Outer
	local remainingTime = self.expiredTime - GameRules:GetGameTime()
	local t = remainingTime / OrderMarker.duration
	local v = ( 1.0 - t*t*t )	-- Cubic easing out
	radius = 32 * v
	alpha = 1.0-t
	color = self.vRgb

	if self.bCircle then
		DebugDrawCircle( self.position, color, alpha, radius, true, 1.0 )
	else
		DebugDrawBoxDirection( self.position, Vector(radius,radius,0)/-1.414, Vector(radius,radius,0)/1.414, Vector(1,1,0):Normalized(), color, alpha, 1.0 )
	end
end
