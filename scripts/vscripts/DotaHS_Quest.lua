
--------------------------------------------------------------------------------
function CreateQuest( name )
	return SpawnEntityFromTableSynchronous( "quest", {
		["name"]	= name,
		["title"]	= "#Quest_" .. name,
	} )
end

--------------------------------------------------------------------------------
function CreateSubquestOf( quest, hueShift --[[broken]] )
	local subquest = SpawnEntityFromTableSynchronous( "subquest_base", {
		show_progress_bar = true,
	--	progress_bar_hue_shift = hueShift or 0,
	} )
	quest:AddSubquest( subquest )
	return subquest
end

--------------------------------------------------------------------------------
-- Update Subquest then Quest
--

--------------------------------------------------------------------------------
function Quest_UpdateValue( quest, current, target )
	if target then
		quest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_TARGET_VALUE, target )
	end
	quest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_CURRENT_VALUE, current )
end

--------------------------------------------------------------------------------
function Subquest_UpdateValue( subquest, current, target )
	subquest:SetTextReplaceValue( SUBQUEST_TEXT_REPLACE_VALUE_TARGET_VALUE, target )
	subquest:SetTextReplaceValue( QUEST_TEXT_REPLACE_VALUE_CURRENT_VALUE, current )
end
