
--------------------------------------------------------------------------------
function RandomFromWeights( array, funcWeight --[[ (k, v) : return weight ]] )
	local totalWeight = 0
	local selected

	for k,v in pairs( array ) do
		local weight = funcWeight( k, v )
		local r = RandomFloat( 0, totalWeight + weight )
		if r >= totalWeight then
			selected = k
		end
		totalWeight = totalWeight + weight
	end

	return selected
end
