
--
-- event.caster : CDOTA_BaseNPC
--

function ToggleInventory( event )
	local playerID = event.caster:GetPlayerID()
	print( "Toggle inventory by Player (ID = " .. playerID .. ")" )

	FireGameEvent( "dotahs_toggle_inventory", { ["playerID"] = playerID } )
end
