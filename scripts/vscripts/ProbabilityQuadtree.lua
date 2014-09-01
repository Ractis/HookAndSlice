
require( "Util_WeightTable" )

--------------------------------------------------------------------------------
local _intersect = function( ax1, ay1, aw, ah, bx1, by1, bw, bh )
	local ax2 = ax1 + aw
	local ay2 = ay1 + ah
	local bx2 = bx1 + bw
	local by2 = by1 + bh

	return ax1 < bx2 and ax2 > bx1 and ay1 < by2 and ay2 > by1
end 

--------------------------------------------------------------------------------
ProbabilityQuadtree = {}

function ProbabilityQuadtree:new( x, y, w, h, hasParent )
	local o = {}
	setmetatable( o, { __index = ProbabilityQuadtree } )
	o:__init( x, y, w, h, hasParent )
	return o
end

setmetatable( ProbabilityQuadtree, { __call = ProbabilityQuadtree.new } )

--------------------------------------------------------------------------------
function ProbabilityQuadtree:__init( x, y, w, h, hasParent )
	if not hasParent then
		print( "[Quadtree] Created. x: " .. x .. ", y: " ..  y .. ", w: " .. w .. ", h: " .. h )
	end

	self.x = x
	self.y = y
	self.w = w
	self.h = h
	self.weight = 0
end

--------------------------------------------------------------------------------
function ProbabilityQuadtree:Insert( x, y, weight )

	self.weight = self.weight + weight

	if self.w <= 1 and self.h <= 1 then
		-- Attach to this
		return
	end

	if self.children == nil  then
		-- Create children
		local childW = self.w / 2
		local childH = self.h / 2

		self.children = {
			ProbabilityQuadtree( self.x, self.y,					childW, childH, true ),
			ProbabilityQuadtree( self.x + childW, self.y,			childW, childH, true ),
			ProbabilityQuadtree( self.x, self.y + childH,			childW, childH, true ),
			ProbabilityQuadtree( self.x + childW, self.y + childH,	childW, childH, true ),
		}
	end

	for _,v in pairs( self.children ) do
		if _intersect( x + 0.5, y + 0.5, 0, 0, v:GetBoundingBox() ) then
			v:Insert( x, y, weight )
			break
		end
	end

end

--------------------------------------------------------------------------------
function ProbabilityQuadtree:ChooseRandom()

	if self.children then
		local selected = RandomFromWeights( self.children, function ( k, v )
			return v.weight
		end )

		return self.children[selected]:ChooseRandom()
	else
		return self:GetBoundingBox()
	end

end

--------------------------------------------------------------------------------
function ProbabilityQuadtree:GetBoundingBox()
	return self.x, self.y, self.w, self.h
end


--------------------------------------------------------------------------------
-- TEST
--------------------------------------------------------------------------------
--[[
probTree = ProbabilityQuadtree.new( 0, 0, 4, 4 )
probTree:Insert( 1, 0, 150 )
probTree:Insert( 0, 1, 50 )
probTree:Insert( 3, 2, 50 )
probTree:UpdateProbability()

for i=0, 10 do
	local x, y, w, h = probTree:pick( 0.1 * i )
	print( x .. ", " .. y .. ", " .. w .. ", " .. h )
end
--]]
