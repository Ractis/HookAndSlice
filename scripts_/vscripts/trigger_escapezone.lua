
function OnStartTouch( trigger )
	print( "OnStartTouch : " .. trigger.activator:GetClassname() )

	local unit = trigger.activator
	if unit.DotaHS_IsHostage then
		unit.DotaHS_IsEscaped = true
	end
end

function OnEndTouch( trigger )
	print( "OnEndTouch   : " .. trigger.activator:GetClassname() )

	local unit = trigger.activator
	if unit.DotaHS_IsHostage then
		unit.DotaHS_IsEscaped = false
	end
end