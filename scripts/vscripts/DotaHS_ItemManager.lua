
require( "DotaHS_Common" )
require( "DotaHS_Math" )

--------------------------------------------------------------------------------
-- FORWARD DECL
--------------------------------------------------------------------------------
if ItemManager == nil then
	ItemManager = class({})
	ItemManager.DeltaTime = 0.1
end

if ItemProperties == nil then
	ItemProperties = class({})
end

local DynamicWeightPool	= {}	-- Class
local DropOddsPool		= {}	-- Class



--------------------------------------------------------------------------------
--
-- ItemManager class
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function ItemManager:PreInitialize()

	self:LoadWeightPools()

	-- Register Think
	DotaHS_CreateThink( "ItemManager:ObserveDotaInventory", function ()
		self:ObserveDotaInventory()
		return ItemManager.DeltaTime
	end )

	DotaHS_CreateThink( "ItemManager:CheckRestorePlayerItems", function ()
		self:CheckRestorePlayerItems()
		return ItemManager.DeltaTime
	end )


	-- Register game events
	self:_AddEventListener( "dota_item_picked_up",	"OnItemPickedUp" )
--	self:_AddEventListener( "dota_item_used",		"OnItemUsed" )	-- BROKEN
	self:_AddEventListener( "entity_killed",		"OnEntityKilled" )

	-- Register Commands
	Convars:RegisterCommand( "dotahs_inventory_swap",
	function ( _, slotname1, slotname2 )
		self:InventorySwap( Convars:GetCommandClient(), slotname1, slotname2 )
	end,
	"Swap inventory items", 0 )

	Convars:RegisterCommand( "dotahs_inventory_drop",
	function ( _, slotname )
		ItemManager:InventoryDrop( Convars:GetCommandClient(), slotname )
	end,
	"Drop inventory item", 0 )

	Convars:RegisterCommand( "dotahs_drop_loot_from_pool",
	function ( _, itemPoolName, numDrops, currentLevel )
		local player = Convars:GetCommandClient()
		local heroUnit = PlayerResource:GetSelectedHeroEntity( player:GetPlayerID() )

		numDrops = numDrops or 1
		currentLevel = currentLevel or 100
		for i=1, tonumber(numDrops) do
			self:_CreateLootFromPool( heroUnit:GetAbsOrigin(), tonumber(currentLevel), itemPoolName )
		end
	end,
	"Drop loot from item pool.", FCVAR_CHEAT )
	
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function ItemManager:Initialize()

	FireGameEvent( "dotahs_clear_all_items", {} )

	self._vItemMap = {}					-- ItemID : ItemEntity
	self._vPlayerHSInventoryMap = {}	-- PlayerID : [ SlotName : ItemID ]
	self._vPlayerDotaInventoryMap = {}	-- PlayerID : [ ItemID : CurrentCharges ]
	self._vPlayerKilled = {}			-- PlayerID : TRUE

	ItemProperties:Initialize()

	-- Create all players inventory
	DotaHS_ForEachPlayer( function ( playerID, hero )
		ItemManager:CreateInventory( playerID )	
	end )
	
end

--------------------------------------------------------------------------------
-- LoadWeightPools
--------------------------------------------------------------------------------
function ItemManager:LoadWeightPools()

	self:_Log( "Loading weight pools..." )

	self._vListDefMap = {}
	self._vItemPoolMap = {}

	local filePath = "scripts/pools/AllItemDefinitions.txt"
	local definitionList = LoadKeyValues( filePath )

	for k,v in pairs(definitionList) do

		local listType = v.Type or "ItemPool"

		if listType == "ListDef" then
			-- Create new list definition
			self._vListDefMap[k] = DropOddsPool( k )

		elseif listType == "ItemPool" then
			-- Create new item pool
			self._vItemPoolMap[k] = DynamicWeightPool( k )

		else
			self:_Log( "Invalid list type : " .. listType .. " - " .. k )
		end

	end

end

--------------------------------------------------------------------------------
-- CreateInventory
--------------------------------------------------------------------------------
function ItemManager:CreateInventory( playerID )
	self._vPlayerHSInventoryMap[playerID] = {}
	self._vPlayerDotaInventoryMap[playerID] = {}

	self:_Log( "Created inventory for PlayerID:" .. playerID )
end

--------------------------------------------------------------------------------
-- Swap in the Inventory
--------------------------------------------------------------------------------
function ItemManager:InventorySwap( player, slotName1, slotName2 )
	local playerID = player:GetPlayerID()
	local isEquipment1 = self:_isEquipmentSlot( slotName1 )
	local isEquipment2 = self:_isEquipmentSlot( slotName2 )
	local isConsumable1 = self:_isConsumableSlot( slotName1 )
	local isConsumable2 = self:_isConsumableSlot( slotName2 )

	self:_Log( "Swapping items..." )
	self:_Log( "  PlayerID : " .. playerID )
	self:_Log( "  Slot 1 : " .. slotName1 )
	self:_Log( "  Slot 2 : " .. slotName2 )

	local inventory = self._vPlayerHSInventoryMap[playerID]
	local slot1ItemOld = self._vItemMap[ inventory[slotName1] ]	-- Slot 1 contains at least one item
	local slot2ItemOld
	if inventory[slotName2] then
		slot2ItemOld = self._vItemMap[ inventory[slotName2] ]
	end

	-- Swap
	inventory[slotName1], inventory[slotName2] = inventory[slotName2], inventory[slotName1]

	-- Update item modifiers
	local heroUnit = PlayerResource:GetSelectedHeroEntity( playerID )

	if isEquipment1 ~= isEquipment2 then
		local slotItemOldE
		local slotItemOldNotE

		if isEquipment1 then
			slotItemOldE    = slot1ItemOld
			slotItemOldNotE = slot2ItemOld
		else
			slotItemOldE    = slot2ItemOld
			slotItemOldNotE = slot1ItemOld
		end

		-- Disable modifiers
		if slotItemOldE ~= nil then
			ItemProperties:DetachFrom( heroUnit, slotItemOldE )
		end
		-- Enable modifiers
		if slotItemOldNotE ~= nil then
			ItemProperties:AttachTo( heroUnit, slotItemOldNotE )
		end
	end

	if isConsumable1 ~= isConsumable2 then
		local slotItemOldC
		local slotItemOldNotC

		if isConsumable1 then
			slotItemOldC	= slot1ItemOld
			slotItemOldNotC	= slot2ItemOld
		else
			slotItemOldC	= slot2ItemOld
			slotItemOldNotC	= slot1ItemOld
		end

		local dotaInventory = self._vPlayerDotaInventoryMap[playerID]

		-- Remove item from dota2 inventory
		if slotItemOldC ~= nil then
			dotaInventory[slotItemOldC:entindex()] = nil
			heroUnit:DropItemAtPositionImmediate( slotItemOldC, Vector( 999999, 999999, 999999 ) )
		end

		-- Add item to dota2 inventory
		if slotItemOldNotC ~= nil then
			heroUnit:AddItem( slotItemOldNotC )
			dotaInventory[slotItemOldNotC:entindex()] = slotItemOldNotC:GetCurrentCharges()
		end
	end

	-- Fire event to client
	local eventData = { ["playerID"] = playerID }

	local fireEvent = function ( eventName, item, slotName )
		eventData.itemID = item:GetEntityIndex()
		eventData.slotName = slotName
		FireGameEvent( eventName, eventData )
	end

	fireEvent( "dotahs_remove_item_from_slot", slot1ItemOld, slotName1 )
	if slot2ItemOld ~= nil then 
		fireEvent( "dotahs_remove_item_from_slot", slot2ItemOld, slotName2 )
		fireEvent( "dotahs_add_item_to_slot", slot2ItemOld, slotName1 )
	else
		self:_Log( "    " .. slotName2 .. " is empty" )
	end
	fireEvent( "dotahs_add_item_to_slot", slot1ItemOld, slotName2 )
end

--------------------------------------------------------------------------------
-- Drop a item from the Inventory
--------------------------------------------------------------------------------
function ItemManager:InventoryDrop( player, slotName )
	local playerID = player:GetPlayerID()
	local isEquipment = self:_isEquipmentSlot( slotName )
	local isConsumable = self:_isConsumableSlot( slotName )

	self:_Log( "Dropping a item..." )
	self:_Log( "  PlayerID : " .. playerID )
	self:_Log( "  Slot Name : " .. slotName )

	local inventory = self._vPlayerHSInventoryMap[playerID]
	local heroUnit = PlayerResource:GetSelectedHeroEntity( playerID )

	-- Remove from the inventory
	local dropItem = self._vItemMap[ inventory[slotName] ]
	inventory[slotName] = nil

	-- Update item modifiers
	if isEquipment then
		ItemProperties:DetachFrom( heroUnit, dropItem )
	end

	if isConsumable then
		local dotaInventory = self._vPlayerDotaInventoryMap[playerID]
		dotaInventory[dropItem:entindex()] = nil
		heroUnit:DropItemAtPositionImmediate( dropItem, Vector( 999999, 999999, 999999 ) )
	end

	-- Drop the item on the ground
	local dropLocation = heroUnit:GetAbsOrigin()
	dropLocation = dropLocation + RandomVector( RandomFloat( 25, 150 ) )

	CreateItemOnPositionSync( dropLocation, dropItem )

	self:_Log( string.format( "Dropped %q at ", dropItem:GetAbilityName() ) .. tostring(dropLocation) )

	-- Fire event to client
	local eventData = {
		["playerID"] = playerID,
		["itemID"]	 = dropItem:GetEntityIndex(),
		["slotName"] = slotName,
	}

	FireGameEvent( "dotahs_remove_item_from_slot", eventData )
	FireGameEvent( "dotahs_dropped_item", eventData )

end

--------------------------------------------------------------------------------
-- CreateLoot
--------------------------------------------------------------------------------
function ItemManager:CreateLoot( spawnPoint, currentLevel, listDef )

	currentLevel = currentLevel or 0
	listDef = listDef or "ListDef_DefaultLoot"
	
	-- Choose item template
	local dropOddsPool = self._vListDefMap[listDef]

	for _,itemPoolName in pairs(dropOddsPool:ItemPoolsForDrop()) do
		self:_CreateLootFromPool( spawnPoint, currentLevel, itemPoolName )
	end	

end


function ItemManager:_CreateLootFromPool( spawnPoint, currentLevel, itemPoolName )

	local name, data = self:_PickItemTemplateFromPool( itemPoolName, currentLevel )

	-- Generate new item from template
	local newItemProperties = {}

	if data.Properties then
		for propertyName, propertyRange in pairs(data.Properties) do
			newItemProperties[propertyName] = self:_GenerateRNG( propertyRange )
		end
	end

	-- item info
	local isEnableAutoPickup = data.EnableAutoPickup and data.EnableAutoPickup > 0 or false

	-- Spawn
	local item = self:CreateItem( name, spawnPoint, isEnableAutoPickup )

	item.IsDotaHSItem = true
	item.DotaHS_Category				= data.Type
	item.DotaHS_BaseProperties			= newItemProperties
	item.DotaHS_AdditionalProperties	= {}

	if data.Charges then
		item:SetCurrentCharges( self:_GenerateRNG( data.Charges ) )
	end

end


function ItemManager:_PickItemTemplateFromPool( poolName, currentLevel )
	
	local pool = self._vItemPoolMap[poolName]
	if pool == nil then
		self:_Log( "Pool name = " .. poolName .. " : Not found" )
		return
	end

	local name, data = pool:ChooseRandom( currentLevel )

	if self._vItemPoolMap[name] then
		-- Item pool in item pool
		return self:_PickItemTemplateFromPool( name, currentLevel )
	else
		-- Real item
		return name, data
	end

end


function ItemManager:_GenerateRNG( rangeString )
	local minVal, maxVal = string.match( rangeString, "(%d+) (%d+)" )
	return RandomInt( tonumber(minVal), tonumber(maxVal) )
end

--------------------------------------------------------------------------------
-- CreateItem
--
-- Refs :
--   CHoldoutGameMode:CheckForLootItemDrop
--   CHoldoutGameRound:_CheckForGoldBagDrop
--------------------------------------------------------------------------------
function ItemManager:CreateItem( itemName, spawnPoint, isEnableAutoPickup )

	local newItem = CreateItem( itemName, nil, nil )

	newItem:SetPurchaseTime( 0 )

	if newItem:GetShareability() == ITEM_FULLY_SHAREABLE then
		newItem:SetStacksWithOtherOwners( true )
	end

	-- Spawn
	local dropTarget = spawnPoint + RandomVector( RandomFloat( 50, 350 ) )
	CreateItemOnPositionSync( spawnPoint, newItem )
	newItem:LaunchLoot( isEnableAutoPickup, 300 --[[ height ]], 0.75, dropTarget )

	-- TEST
--	local particleID = ParticleManager:CreateParticle( "particles/loots/loot_rare_starfall.vpcf", PATTACH_ABSORIGIN_FOLLOW, newItem )

	self:_Log( string.format( "Created %q", itemName ) )
--	self:_Log( string.format( "Created %q at ", itemName ) .. tostring(spawnPoint) )

	-- Store to our map
	self._vItemMap[newItem:GetEntityIndex()] = newItem

	return newItem

end

--------------------------------------------------------------------------------
-- EVENT LISTENERS
--------------------------------------------------------------------------------
function ItemManager:ObserveDotaInventory()

	if not self._vPlayerDotaInventoryMap then
		return
	end

	local ITEM_CHANGE_CHARGES = -1

	for playerID, dotaInventory in pairs(self._vPlayerDotaInventoryMap) do

		local player = PlayerResource:GetPlayer( playerID )
		local heroUnit = player:GetAssignedHero()

		if heroUnit then

			local itemsForCheck = {}	-- itemID : Charges
			for itemID, charges in pairs(dotaInventory) do
				itemsForCheck[itemID] = charges
			end

			-- Check items dropped / consumed by the player
			for i=0, 5 do
				local item = heroUnit:GetItemInSlot(i)
				if item ~= nil then
					local itemID = item:entindex()
					-- Check charges of the item
					if not itemsForCheck[itemID] then
						-- This is special item for DotaHS
					elseif itemsForCheck[itemID] == item:GetCurrentCharges() then
						itemsForCheck[itemID] = nil
					else
						itemsForCheck[itemID] = ITEM_CHANGE_CHARGES
					end
				end
			end

			for itemID, state in pairs(itemsForCheck) do
				if state ~= ITEM_CHANGE_CHARGES then
					-- Item manually dropped
					local itemDropped = self._vItemMap[itemID]
					local isValidItem = IsValidEntity( itemDropped )
					if isValidItem then
						self:_Log( itemDropped:GetAbilityName() .. " has been dropped from the DOTA inventory by the player." )
					else
						self:_Log( "ItemID = " .. itemID .. " is no longer exists in the game." )
					end

					-- Remove from the inventory
					dotaInventory[itemID] = nil

					local slotNameForDroppedItem
					for slotName, itemIDInSlot in pairs(self._vPlayerHSInventoryMap[playerID]) do
						if itemIDInSlot == itemID then
							slotNameForDroppedItem = slotName
						end
					end

					if not slotNameForDroppedItem then
						self:_Log( "Slot for the dropped item (ID=" .. itemID .. ") is not found in the inventory." )
					else

						self._vPlayerHSInventoryMap[playerID][slotNameForDroppedItem] = nil

						if isValidItem then
							self:_Log( string.format( "Dropped %q from DOTA inventory", itemDropped:GetAbilityName() ) )
						else
							self:_Log( string.format( "Removed item (ID=%d) from DOTA inventory", itemID ) )
						end

						-- Fire event to client
						local eventData = {
							["playerID"] = playerID,
							["itemID"]	 = itemID,
							["slotName"] = slotNameForDroppedItem,
						}

						FireGameEvent( "dotahs_remove_item_from_slot", eventData )
						FireGameEvent( "dotahs_dropped_item", eventData )

					end

				else
					-- Need update charges of the item
					local item = self._vItemMap[itemID]
					local charges = item:GetCurrentCharges()

					self:_Log( "Updating itemCharges of " .. item:GetAbilityName() .. " : " .. dotaInventory[itemID] .. " to " .. charges )

					dotaInventory[itemID] = charges

					-- Fire event to client
					local eventData = {
						["itemID"]	 	= itemID,
						["itemCharges"] = charges,
					}

					FireGameEvent( "dotahs_change_item_charges", eventData )
				end
			end

		end
	end

end

--------------------------------------------------------------------------------
function ItemManager:CheckRestorePlayerItems()
	if not self._vPlayerKilled then
		return
	end
	
	for playerID, bPopped in pairs( self._vPlayerKilled ) do
		if bPopped then
			local hero = PlayerResource:GetSelectedHeroEntity( playerID )
			if hero then
				if hero:IsAlive() then
					-- Revived
					ItemProperties:RestorePlayerItems( hero )
					self._vPlayerKilled[playerID] = nil
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
function ItemManager:OnItemPickedUp( event )
	local itemName	= event.itemname
	local playerID	= event.PlayerID
	local itemID	= event.ItemEntityIndex
	local item		= EntIndexToHScript( itemID )
	local hero		= EntIndexToHScript( event.HeroEntityIndex )

	self:_Log( "Player " .. playerID .. " picked up " .. event.itemname )

	if not item.IsDotaHSItem then
		return
	end

	local inventory = self._vPlayerHSInventoryMap[playerID]

	-- Check stackable
	if item:GetInitialCharges() > 0 then

		local itemStackTo
		for k,v in pairs(inventory) do
			local itemInSlot = self._vItemMap[v]
			if itemInSlot:GetAbilityName() == item:GetAbilityName() then
				itemStackTo = itemInSlot
			end
		end

		-- Do stack
		if itemStackTo then
			self:_Log( "Stacking " .. item:GetAbilityName() )
			itemStackTo:SetCurrentCharges( itemStackTo:GetCurrentCharges() + 1 )

			-- Kill the item
			self._vItemMap[item:entindex()] = nil
			item:Kill()

			-- Fire event
			local eventData = {
				["itemID"]		= itemStackTo:entindex(),
				["itemCharges"]	= itemStackTo:GetCurrentCharges(),
			}

			FireGameEvent( "dotahs_change_item_charges", eventData )

			return
		end

	end

	-- Check inventory space
	local numBackpackSlots = 15
	local emptySlotName

	for i = 0, numBackpackSlots-1 do
		local slotName = "slot_backpack_" .. i
		if inventory[slotName] == nil then
			emptySlotName = slotName
			break
		end
	end

	if emptySlotName == nil then
		self:_Log( "Player " .. playerID .. " has no inventory space" )
		hero:DropItemAtPositionImmediate( item, hero:GetAbsOrigin() )
		return
	end

	-- Attach to the slot
	inventory[emptySlotName] = itemID
	self:_Log( string.format( "The item has been added to %q", emptySlotName ) )

	-- Then remove the item from the dota inventory
--	hero:RemoveItem( item )	-- This func removes also the entity of item
	hero:DropItemAtPositionImmediate( item, Vector( 999999, 999999, 999999 ) )
		-- Should we make invisible this item? SetScale( 1e-5 )?

	-- Fire event to clients
	local eventData = {
		["playerID"]		= playerID,
		["itemID"]			= event.ItemEntityIndex,
		["itemName"]		= itemName,
		["itemCategory"]	= item.DotaHS_Category,
		["itemLevel"]		= 1,
		["itemRarity"]		= 0,
		["itemCharges"]		= item:GetCurrentCharges(),
		["itemBaseProperties"]			= self:_SerializeItemProperties(item.DotaHS_BaseProperties),
		["itemAdditionalProperties"]	= self:_SerializeItemProperties(item.DotaHS_AdditionalProperties),
	}
	FireGameEvent( "dotahs_pickedup_item", eventData )

	eventData = {
		["playerID"]	= playerID,
		["itemID"]		= event.ItemEntityIndex,
		["slotName"]	= emptySlotName,
	}
	FireGameEvent( "dotahs_add_item_to_slot", eventData )

--	for i = 0, hero:GetModifierCount() - 1 do
--		print( "MODIFIER : " .. hero:GetModifierNameByIndex(i) )
--	end
end

--------------------------------------------------------------------------------
function ItemManager:OnItemUsed( event )
	self:_Log( "Item used : " )
	DeepPrint(event)
end

--------------------------------------------------------------------------------
function ItemManager:OnEntityKilled( event )

	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if not killedUnit then
		return
	end
	if not killedUnit:IsRealHero() then
		return
	end

	self._vPlayerKilled[killedUnit:GetPlayerID()] = true

end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function ItemManager:_AddEventListener( eventType, listenerName )
	ListenToGameEvent( eventType, Dynamic_Wrap( ItemManager, listenerName ), self )
end

function ItemManager:_Log( text )
	print( "[ItemManager] " .. text )
end

function ItemManager:_SerializeItemProperties( properties )
	-- JSON-like
	local str = ""

	for k,v in pairs(properties) do
		str = str .. k .. ":" .. tostring(v) .. ","
	end

	return str
end

function ItemManager:_isEquipmentSlot( slotName )
	return ( string.find( slotName, "slot_equipment" ) ~= nil )
end

function ItemManager:_isConsumableSlot( slotName )
	return ( string.find( slotName, "slot_consumable" ) ~= nil )
end





--------------------------------------------------------------------------------
--
--	ItemProperties class
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------
function ItemProperties:Initialize()
	self._vUnitMap = nil
	self._vItemMap = nil	-- These items will be destroyed?
end

--------------------------------------------------------------------------------
-- AttachTo
--------------------------------------------------------------------------------
function ItemProperties:AttachTo( unit, item )
	self:_Log( "Attaching modifiers of " .. item:GetAbilityName() )

	self:_AttachTo_Impl( unit, item.DotaHS_BaseProperties )
	self:_AttachTo_Impl( unit, item.DotaHS_AdditionalProperties )
end

function ItemProperties:_AttachTo_Impl( unit, properties )
	for k,v in pairs(properties) do
		local propertyKey = string.lower(k)
		local currentValue = self:_GetPropertyValue( unit, propertyKey )
		local newValue = currentValue + v
		self:_UpdateModifiers( unit, propertyKey, currentValue, newValue )
		self:_SetPropertyValue( unit, propertyKey, newValue )
	end
end

--------------------------------------------------------------------------------
-- DetachFrom
--------------------------------------------------------------------------------
function ItemProperties:DetachFrom( unit, item )
	self:_Log( "Detaching modifiers of " .. item:GetAbilityName() )

	self:_DetachFrom_Impl( unit, item.DotaHS_BaseProperties )
	self:_DetachFrom_Impl( unit, item.DotaHS_AdditionalProperties )
end

function ItemProperties:_DetachFrom_Impl( unit, properties )
	for k,v in pairs(properties) do
		local propertyKey = string.lower(k)
		local currentValue = self:_GetPropertyValue( unit, propertyKey )
		local newValue = currentValue - v
		self:_UpdateModifiers( unit, propertyKey, currentValue, newValue )
		self:_SetPropertyValue( unit, propertyKey, newValue )
	end
end

--------------------------------------------------------------------------------
-- Restore
--------------------------------------------------------------------------------
function ItemProperties:RestorePlayerItems( unit )
	self:_Log( "Restoring modifiers for " .. unit:GetClassname() )

	for k,v in pairs(self:_GetPropertyMap( unit )) do
		self:_UpdateModifiers( unit, k, v, 0 )
		self:_UpdateModifiers( unit, k, 0, v )
	end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------
function ItemProperties:_UpdateModifiers( unit, propertyKey, current, new )
	
	-- Construct bitset
	local currentBit	= self:_ConstructBitsetFromInt( current )
	local newBit		= self:_ConstructBitsetFromInt( new )

	-- Loop over bits
	for k,v in ipairs( self:_GetPow2Table() ) do
		if currentBit[k] ~= newBit[k] then
			if not currentBit[k] then
				-- Add modifier
				self:_AddModifier( unit, propertyKey, v )
			else
				-- Remove modifier
				self:_RemoveModifier( unit, propertyKey, v )
			end
		end
	end

end

--------------------------------------------------------------------------------
function ItemProperties:_ConstructBitsetFromInt( value )
	local bit = {}
	local pow2Table = self:_GetPow2Table()

	for i=ItemProperties.nMaxBits, 1, -1 do
		if value >= pow2Table[i] then
			value = value - pow2Table[i]
			bit[i] = true
		else
			bit[i] = false
		end
	end

	return bit
end

--------------------------------------------------------------------------------
function ItemProperties:_AddModifier( unit, propertyKey, value )
	-- Generate name
	local itemName = "item_dotahs_modifiers_" .. propertyKey
	local modifierName = "dotahs_" .. propertyKey .. "_" .. value

	-- Grab datadriven item
	local item = ItemProperties:_GetItem( itemName )
	if not item then
		return
	end

	-- Apply modifier
	item:ApplyDataDrivenModifier( unit, unit, modifierName, {} )
end

--------------------------------------------------------------------------------
function ItemProperties:_RemoveModifier( unit, propertyKey, value )
	-- Generate name
	local modifierName = "dotahs_" .. propertyKey .. "_" .. value

	-- Remove modifier
	unit:RemoveModifierByName( modifierName )
end

--------------------------------------------------------------------------------
-- Getter and Setter
--------------------------------------------------------------------------------
function ItemProperties:_GetPropertyMap( unit )
	if not self._vUnitMap then
		self._vUnitMap = {}			-- unitEntity : propertyMap
	end

	if not self._vUnitMap[unit] then
		self._vUnitMap[unit] = {}	-- propertyKey : peropertyValue
	end

	-- Grab property map
	return self._vUnitMap[unit]
end

--------------------------------------------------------------------------------
function ItemProperties:_GetPropertyValue( unit, propertyKey )
	-- Grab property value
	return self:_GetPropertyMap(unit)[propertyKey] or 0
end

--------------------------------------------------------------------------------
function ItemProperties:_SetPropertyValue( unit, propertyKey, propertyValue )
	self:_GetPropertyMap(unit)[propertyKey] = propertyValue
end

--------------------------------------------------------------------------------
ItemProperties.nMaxBits = 16

--------------------------------------------------------------------------------
function ItemProperties:_GetPow2Table()
	if not self._vPow2Table then
		self._vPow2Table = {}

		for i=1, ItemProperties.nMaxBits do
			self._vPow2Table[i] = 2 ^ (i-1)
		end
	end

	return self._vPow2Table
end

--------------------------------------------------------------------------------
--[[
function ItemProperties:_GetReversePow2Table()
	if not self._vReversePow2Table then
		self._vReversePow2Table = {}

		for i=1, ItemProperties.nMaxBits do
			self._vReversePow2Table[i] = 2 ^ (ItemProperties.nMaxBits-i)
		end
	end

	return self._vReversePow2Table
end
--]]

--------------------------------------------------------------------------------
function ItemProperties:_GetItem( itemName )
	if not self._vItemMap then
		self._vItemMap = {}		-- Item Name : Item entity
	end

	if not self._vItemMap[itemName] then
		local newItem = CreateItem( itemName, nil, nil )
		if not newItem then
			self:_Log( itemName .. " not found." )
			return nil
		end
		self._vItemMap[itemName] = newItem
	end

	return self._vItemMap[itemName]
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function ItemProperties:_Log( text )
	print( "[ItemProperties] " .. text )
end





--------------------------------------------------------------------------------
--
--	DynamicWeightPool class
--
--------------------------------------------------------------------------------
function DynamicWeightPool:new( kvFileName )
	local o = {}
	setmetatable( o, { __index = DynamicWeightPool } )
	o:__init( kvFileName )
	return o
end

setmetatable( DynamicWeightPool, { __call = DynamicWeightPool.new } )

--------------------------------------------------------------------------------
function DynamicWeightPool:__init( kvFileName )

	self._name = kvFileName

	-- Load the file
	print( "Generating weight pool from " .. kvFileName )

	local filePath = "scripts/pools/" .. kvFileName .. ".txt"
	local kv = LoadKeyValues( filePath )
	if kv == nil then
		print( "  Couldn't load KV file : " .. filePath )
		return
	end

	self._pool = kv

	-- Number of items
	local n = 0
	for k,v in pairs( self._pool ) do
		n = n + 1
	end
	self._numItems = n

	print( "  Num items : " .. self._numItems )

end

--------------------------------------------------------------------------------
function DynamicWeightPool:ChooseRandom( currentLevel )
	
	local selected = DotaHS_RandomFromWeights( self._pool, function ( k, v )
		return self:_CalculateWeight( v, currentLevel )
	end)

	return selected, self._pool[selected]

end

--------------------------------------------------------------------------------
function DynamicWeightPool:DumpProbabilities( currentLevel, nSamples )

	nSamples = nSamples or 10000

	print( "Practical Probabilities ( level = " .. currentLevel .. ", samples = " .. nSamples .. " ) :" )

	local counts = {}

	for k,v in pairs(self._pool) do
		counts[k] = 0
	end

	for i=1, nSamples do
		local name, data = self:ChooseRandom( currentLevel )
		counts[name] = counts[name] + 1
	end

	for k,v in pairs(counts) do
		print( "  " .. k .. " : " .. v / nSamples * 100 .. "%" )
	end

end

--------------------------------------------------------------------------------
function DynamicWeightPool:_CalculateWeight( data, currentLevel )

	if currentLevel == nil then
		print( self._name .. " - CalculateWeight : CurrentLevel is nil" )
	end
	
	-- Base weight
	local baseWeight = data.Weight or 100

	-- Item level
	local itemLevel = data.Level
	if itemLevel == nil then
		if data.Cost == nil then
			return baseWeight
		end

		-- Calculate item level from cost
		itemLevel = math.ceil( data.Cost / 400 )	-- ~400g = Lv.1, ~800g = Lv.2 ...
	end

	--
	-- Current level = 10 :
	-- [10] [9] [8] [7] [6] [5] [4] [3] [2] [1] [0]
	--  100 100 100  80 ----------------------- 20
	--
	-- Current level = 5 :
	-- [5] [4] [3] [2] [1] [0]
	-- 100 100 100  80  50  20
	--
	local levelWeight
	if itemLevel > currentLevel then
		levelWeight = 0.0
	elseif itemLevel >= currentLevel - 2 then
		levelWeight = 1.0
	else
		levelWeight = lerp( 0.2, 0.8, itemLevel / ( currentLevel - 3 ) )
	end

--	print( "CurrentLevel = " .. currentLevel .. ", ItemLevel = " .. itemLevel )
--	print( "  Weight by Level = " .. levelWeight * 100 )

	return baseWeight * levelWeight

end





--------------------------------------------------------------------------------
--
--	DropOddsPool class
--
--------------------------------------------------------------------------------
function DropOddsPool:new( kvFileName )
	local o = {}
	setmetatable( o, { __index = DropOddsPool } )
	o:__init( kvFileName )
	return o
end

setmetatable( DropOddsPool, { __call = DropOddsPool.new } )

--------------------------------------------------------------------------------
function DropOddsPool:__init( kvFileName )
	
	self._name = kvFileName

	-- Load the file
	print( "Generating drop odds pool from " .. kvFileName )

	local filePath = "scripts/pools/" .. kvFileName .. ".txt"
	local kv = LoadKeyValues( filePath )
	if kv == nil then
		print( "  Couldn't load KV file : " .. filePath )
		return
	end

	self._pool = kv

	-- Number of items
	local n = 0
	for k,v in pairs( self._pool ) do
		n = n + 1
	end
	self._numItems = n

	print( "  Num items : " .. self._numItems )

end

--------------------------------------------------------------------------------
function DropOddsPool:ItemPoolsForDrop()
	
	local itemPools = {}

	for k,v in pairs(self._pool) do
		if v.Chance == nil then
			print( k .. " has no drop chance." )
		end

		if RollPercentage( v.Chance ) then
			table.insert( itemPools, k )
		end
	end

	return itemPools

end

--------------------------------------------------------------------------------
function DropOddsPool:DumpProbabilities( nSamples )
	
	nSamples = nSamples or 10000

	print( "Probabilities ( samples = " .. nSamples .. " ) :" )

	local counts = {}

	for k,v in pairs(self._pool) do
		counts[k] = 0
	end

	for i=1, nSamples do
		local itemPools = self:ItemPoolsForDrop()
		for _,v in pairs(itemPools) do
			counts[v] = counts[v] + 1
		end
	end

	for k,v in pairs(counts) do
		print( "  " .. k .. " : " .. v / nSamples * 100 .. "%" )
	end

end
