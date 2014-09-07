
--
-- Stack-based simple profiler
--

if _stackTable_Name == nil then
	_stackTable_Name = {}
	_stackTable_Time = {}
end

local function _clock()
	-- return os.clock()
	return Time()
end

function profile_begin( name )
	table.insert( _stackTable_Name, name )
	table.insert( _stackTable_Time, _clock() )
end

function profile_end()
	local fullname = table.concat( _stackTable_Name, " / " )
	local elapsed = _clock() - _stackTable_Time[#_stackTable_Time]

	print( string.format( "[PROF] %s : %.2f sec", fullname, elapsed ) )

	table.remove( _stackTable_Name, #_stackTable_Name )
	table.remove( _stackTable_Time, #_stackTable_Time )
end
