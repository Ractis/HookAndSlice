
function OnStartTouch( trigger )
	local unit = trigger.activator
	unit:ForceKill( true )

	if unit:IsRealHero() then
		local playerID = unit:GetPlayerID()
		local msg = PlayerResource:GetPlayerName( playerID ) .. " has touched down."
		GameRules:SendCustomMessage( msg, unit:GetTeam(), 1 )
	end
end
