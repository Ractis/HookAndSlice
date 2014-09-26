
--
-- Stack-based simple profiler
--

if _stackTable_Name == nil then
	_stackTable_Name = {}
	_stackTable_Time = {}
end

local function _clock()
	-- return os.clock()
	return Time()	-- Valve, please implement os.clock()
end

-- http://lua-users.org/wiki/FormattingNumbers
local function comma_value( amount )
	local formatted = amount
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k==0) then
			break
		end
	end
 	return formatted
end

function profile_begin( name )
	table.insert( _stackTable_Name, name )
	table.insert( _stackTable_Time, _clock() )
end

function profile_end()
	local fullname = table.concat( _stackTable_Name, " / " )
	local elapsed = _clock() - _stackTable_Time[#_stackTable_Time]

	print( string.format( "[PROF] %s : %.2f sec", fullname, elapsed ) )

	-- Show memory usage
	local kilobytes = collectgarbage("count")
	print( string.format( "[PROF] %s : Memory usage = %s bytes", fullname, comma_value(kilobytes*1024) ) )

	table.remove( _stackTable_Name, #_stackTable_Name )
	table.remove( _stackTable_Time, #_stackTable_Time )
end
