
function lerp( a, b, t )
	return a + t * ( b - a )
end

function invlerp( a, b, x )
	return ( x - a ) / ( b - a )
end

function clamp( x, a, b )
	return math.max( a, math.min( b, x ) )
end

function saturate( x )
	return clamp( x, 0.0, 1.0 )
end

function acos( v )
	if ( -1.0 < v ) then
		if ( v < 1.0 ) then
			return math.acos( v )
		else
			return 0.0
		end
	else
		return math.pi
	end
end

function asin( v )
	if ( -1.0 < v ) then
		if ( v < 1.0 ) then
			return math.asin( v )
		else
			return math.pi / 2
		end
	else
		return -math.pi / 2
	end
end


function log2( n )

	local _n = 2
	local x  = 1

	if _n < n then

		repeat
			x = x + 1
			_n = _n + _n
		until _n >= n

	elseif _n > n then

		if n == 1 then
			return 0
		else
			return nil
		end

	end

	if _n > n then
		return x-1
	else
		return x
	end
end
