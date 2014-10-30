
function OnStartTouch( trigger )
--	DeepPrintTable( trigger )
	local unit = trigger.activator
	local box = trigger.caller

	if not unit:IsAlive() then
		return
	end

	FindClearSpaceForUnit( unit, box:GetCenter(), true )
	unit:ForceKill( true )

	if unit:IsRealHero() and not unit.DotaHS_IsFollowerBot then
		local playerID = unit:GetPlayerID()
		local msg = PlayerResource:GetPlayerName( playerID ) .. " has touched down."
		GameRules:SendCustomMessage( msg, unit:GetTeam(), 1 )
	end
end
