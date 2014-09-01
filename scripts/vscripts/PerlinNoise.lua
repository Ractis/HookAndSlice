
--
-- Reference :
--   http://pastebin.com/EZRaakNf
--

--------------------------------------------------------------------------------
local random, randomseed = math.random, math.randomseed
local floor = math.floor
local min, max = math.min, math.max

--------------------------------------------------------------------------------
local _noise = {}

--------------------------------------------------------------------------------
local function Cos_Interpolate( a, b, x )
	local ft = x * math.pi
	local f = ( 1 - math.cos(ft) ) * 0.5

	return a * ( 1 - f ) + b * f
end

--------------------------------------------------------------------------------
local function Noise2D( x, y, i, seed )
	local nx = _noise[x]

	if nx and nx[y] then
		return nx[y]
	else
		nx = nx or {}
		randomseed( ( x * seed + y * i ^ 1.1 + 14 ) / 789221 + 33 * x + 15731 * y * seed )
	end

	random()

	_noise[x] = nx
	nx[y] = random( -1000, 1000 ) / 1000

	return nx[y]
end

--------------------------------------------------------------------------------
local function Smooth_Noise2D( x, y, i, seed )
	local corners = ( Noise2D( x-1, y-1, i, seed ) +
					  Noise2D( x+1, y-1, i, seed ) +
					  Noise2D( x-1, y+1, i, seed ) +
					  Noise2D( x+1, y+1, i, seed ) ) / 16
	local sides = ( Noise2D( x-1, y, i, seed ) +
					Noise2D( x+1, y, i, seed ) +
					Noise2D( x, y-1, i, seed ) +
					Noise2D( x, y+1, i, seed ) ) / 8
	local center = Noise2D( x, y, i, seed ) / 4
	return corners + sides + center
end

--------------------------------------------------------------------------------
local function Interpolate_Noise2D( x, y, i, seed )
	local int_x = floor(x)
	local frac_x = x - int_x

	local int_y = floor(y)
	local frac_y = y - int_y

	local v1 = Smooth_Noise2D( int_x,   int_y,   i, seed )
	local v2 = Smooth_Noise2D( int_x+1, int_y,   i, seed )
	local v3 = Smooth_Noise2D( int_x,   int_y+1, i, seed )
	local v4 = Smooth_Noise2D( int_x+1, int_y+1, i, seed )

	local i1 = Cos_Interpolate( v1, v2, frac_x )
	local i2 = Cos_Interpolate( v3, v4, frac_x )

	return Cos_Interpolate( i1, i2, frac_y )
end

--------------------------------------------------------------------------------
function PerlinNoise2D( x, y, seed )
	local total = 0
	local persistence = 0.5
	local octaves = 3

	for i = 0, octaves-1 do
		local frequency = 2 ^ i
		local amplitude = persistence ^ i

		total = total + Interpolate_Noise2D( x * frequency, y * frequency, i, seed ) * amplitude
	end

	return total
end
