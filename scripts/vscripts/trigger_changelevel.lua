local gamemode = "spiralheroes"

function ChangeLevelTo( mapname )
	SendToServerConsole("dota_launch_custom_game " .. gamemode .. " " .. mapname )
end

function OnChangeLevel_Test( trigger )
	ChangeLevelTo( "untitled_1" )
end

function OnChangeLevel_Level1( trigger )
	ChangeLevelTo( "level1" )
end
