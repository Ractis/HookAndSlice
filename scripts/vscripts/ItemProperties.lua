
--------------------------------------------------------------------------------
if ItemProperties == nil then
	ItemProperties = class({})
end

--------------------------------------------------------------------------------
-- AttachTo
--------------------------------------------------------------------------------
function ItemProperties:AttachTo( unit, item )
	self:_Log( "Attaching modifiers of " .. item:GetAbilityName() )

	self:_AttachTo_Impl( unit, item.DotaRPG_BaseProperties )
	self:_AttachTo_Impl( unit, item.DotaRPG_AdditionalProperties )
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

	self:_DetachFrom_Impl( unit, item.DotaRPG_BaseProperties )
	self:_DetachFrom_Impl( unit, item.DotaRPG_AdditionalProperties )
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
	local itemName = "item_dotarpg_modifiers_" .. propertyKey
	local modifierName = "dotarpg_" .. propertyKey .. "_" .. value

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
	local modifierName = "dotarpg_" .. propertyKey .. "_" .. value

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
