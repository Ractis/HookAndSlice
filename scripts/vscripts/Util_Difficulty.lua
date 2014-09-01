function GetValueByDifficulty( value )
	local normal, hard, insane = string.match( value, "(%d+) (%d+) (%d+)" )
	if normal and hard and insane then
		local difficulty = GameRules:GetCustomGameDifficulty()
		if difficulty == 0 then
			return normal
		elseif difficulty == 1 then
			return hard
		else
			return insane
		end
	end

	return value
end