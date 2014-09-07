
function OnStartTouch( trigger )
	print( "OnStartTouch : " .. trigger.activator:GetClassname() )

	local unit = trigger.activator
	if unit.DotaRPG_IsHostage then
		unit.DotaRPG_IsEscaped = true
	end
end

function OnEndTouch( trigger )
	print( "OnEndTouch   : " .. trigger.activator:GetClassname() )

	local unit = trigger.activator
	if unit.DotaRPG_IsHostage then
		unit.DotaRPG_IsEscaped = false
	end
end