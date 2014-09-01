
--------------------------------------------------------------------------------
local function _Serialize( o, tab )

	if type(o) == "number" then
		return '"' .. tostring(o) .. '"'

	elseif type(o) == "string" then
		return string.format("%q", o)

	elseif type(o) == "table" then
		tab = tab or ""
		local tab_more = tab .. "    "
		local str = "\n" .. tab .. "{\n"
		for k,v in pairs(o) do
			str = str .. tab_more .. string.format("%q ", k)
			str = str .. _Serialize(v, tab_more) .. "\n"
		end
		str = str .. tab .. "}"
		return str

	else
		print( "cannot serialize a " .. type(o) )
		return string.format("%q", "[INVALID TYPE]")
	end
end

--------------------------------------------------------------------------------
function SerializeKeyValues( kv, name )
	return string.format("%q", name) .. _Serialize( kv )
end

--------------------------------------------------------------------------------
function KeyValuesToFile( kv, name )
	StringToFile( name .. ".txt", SerializeKeyValues(kv, name) )
end

--------------------------------------------------------------------------------
function FileToKeyValues( name )
	return LoadKeyValues( "ems/" .. name .. ".txt" )
end
