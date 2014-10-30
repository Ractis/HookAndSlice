
--------------------------------------------------------------------------------
-- Find Good Circle Position
--------------------------------------------------------------------------------
function DotaHS_FindGoodCirclePosition( radius, units, AI )
	
	-- Parameters
	local maxUnits = 10
	local radiusFactor = 0.85

	-- Select units
	units = {unpack(units)}	-- Make copy

	local aryP = {}
	while #aryP < maxUnits do
		if #units == 0 then break end

		local i = RandomInt( 1, #units )
		table.insert( aryP, units[i]:GetAbsOrigin() )
		table.remove( units, i )
	end

	-- Generate suitable circles
	local r = radius * radiusFactor
	local r2 = r * r
	local twoR = r * 2

	local aryC = {}
	for i=1, #aryP do
		local pi = aryP[i]
		for j=i+1, #aryP do
			local pj = aryP[j]

			local dir = pj - pi
			local dist = dir:Length2D()
			dir = dir:Normalized()

			if dist <= twoR then
				-- Found suitable pair of points
				local halfD = dist / 2
				local height = math.sqrt( r2 - halfD * halfD )
				local pb = pi + dir * halfD

				table.insert( aryC, pb + RotatePosition( Vector(0,0,0), QAngle(0,-90,0), dir ) * height )
				table.insert( aryC, pb + RotatePosition( Vector(0,0,0), QAngle(0, 90,0), dir ) * height )
			end
		end
	end

	-- Find the best circle
	local bestN = 0
	local bestC = nil	-- center of the circle

	for _,v in ipairs(aryC) do
		local n = #AI:FindEnemiesInRange( r, v )
		if n > bestN then
			bestN = n
			bestC = v
		end
	end

	if bestC then
		-- Find the minimum circle
		local P = {}
		for _,v in ipairs(AI:FindEnemiesInRange( r, bestC )) do
			table.insert( P, v:GetAbsOrigin() )
		end
		bestC = DotaHS_MinCircle( P )
	end

	return bestC, bestN

end

--------------------------------------------------------------------------------
function DotaHS_CircleFromPoints( p1, p2, p3 )
	local offset	= p2.x^2 + p2.y^2
	local bc		= (p1.x^2 + p1.y^2 - offset) / 2.0
	local cd		= (offset - p3.x^2 - p3.y^2) / 2.0
	local det		=  (p1.x-p2.x)*(p2.y-p3.y) - (p2.x-p3.x)*(p1.y-p2.y)

	if math.abs(det) < 1e-5 then
		print( "[Solver] CircleFromThreePoints - det is less than epsilon!" )
	end

	local idet = 1 / det

	local x =  (bc*(p2.y-p3.y) - cd*(p1.y-p2.y)) * idet
	local y =  (cd*(p1.x-p2.x) - bc*(p2.x-p3.x)) * idet

	local center = Vector(x,y,0)
	local radius = (p2 - center):Length2D()
	return center, radius
end

--------------------------------------------------------------------------------
function DotaHS_MinCircleImpl( n, P, m, R )
	local c = Vector(0,0,0)
	local r = 0;

	if m == 1 then
		c = R[1]
		r = 0
	elseif m == 2 then
		c = (R[1]+R[2]) / 2
		r = (R[1] - c):Length2D()
	elseif m == 3 then
		return DotaHS_CircleFromPoints( R[1], R[2], R[3] )
	end

	for i=1, n do
		if (P[i] - c):Length2D() > r then
			R[m+1] = P[i]
			c, r = DotaHS_MinCircleImpl( i-1, P, m+1, R )
		end
	end

	return c, r
end

--------------------------------------------------------------------------------
function DotaHS_MinCircle( P )
	return DotaHS_MinCircleImpl( #P, P, 0, {} )
end

--------------------------------------------------------------------------------
-- Find Good Direction
--------------------------------------------------------------------------------
function DotaHS_FindGoodDirection( origin, range, radius, units )

	-- Allocate buffer
	local dim = 32
	local buffer = {}
	for i=1, dim do buffer[i] = 0 end

	local deltaAngle = math.pi * 2 / dim
	local angleOffset = RandomFloat( 0, deltaAngle )

	local radToIndex = function ( rad )
		return math.floor( rad / deltaAngle - angleOffset )
	end
	local indexToRad = function ( index )
		return ( index + 0.5 ) * deltaAngle + angleOffset
	end
	local writeTo = function ( index, value )
		if index < 1 then index = index + dim end
		if index > dim then index = index - dim end
		buffer[index] = buffer[index] + value
	end

	-- Update
	for _,v in ipairs(units) do

		-- To Polar coodinates
		local relPos = v:GetAbsOrigin() - origin
		local r = relPos:Length2D()
		local phi = math.atan2( relPos.y, relPos.x )

		local theta = math.atan2( radius, r )
		theta = math.min( theta, math.pi / 4 )	-- Should be less than 45 deg

		-- Fill the buffer
		local indexR = radToIndex( phi - theta )
		local indexL = radToIndex( phi + theta )

		for i=indexR, indexL do
			local centerPhi = indexToRad( i )
			local diff = math.abs( phi - centerPhi )
			local factor = 1.0 - ( diff / theta )
			factor = math.max( factor, 0 )
			writeTo( i, factor )
		end

	end

	-- Find best direction
	local bestScore = 0
	local bestIndex = nil
	for k,v in ipairs(buffer) do
		if v > bestScore then
			bestScore = v
			bestIndex = tonumber(k)
		end
	end

	if not bestIndex then
		return
	end

	local bestPhi = indexToRad( bestIndex )

	return Vector( math.cos( bestPhi ), math.sin( bestPhi ), 0 ), bestScore

end
