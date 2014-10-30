
require( "DotaHS_GridNavMap" )
require( "DotaHS_AI_ObstacleManager" )

--------------------------------------------------------------------------------
-- FORWARD DECL
--------------------------------------------------------------------------------
local AI_LocalGridCell
local PriorityQueue

LGC_STATE_UNKNOWN	= 0
LGC_STATE_SAFETY	= 1
LGC_STATE_DANGER	= 2

--------------------------------------------------------------------------------
--
-- LocalGridNavMap
--
--------------------------------------------------------------------------------
if AI_LocalGridNavMap == nil then
	AI_LocalGridNavMap = class({})
	local radius = 10	-- 640 units
	AI_LocalGridNavMap.gridMin		= -radius
	AI_LocalGridNavMap.gridMax		= radius
	AI_LocalGridNavMap.nGridDim		= radius * 2 + 1
	AI_LocalGridNavMap.nBrickDim	= 3		-- Subgrid
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:constructor( unit )
	self.entity = unit
	self.vGridMap = {}
	self.nObstacles = 0
	self.vForceFieldMap = {}
	self.bInForceField = false

	self.bounds = AABB()
	self.bounds.extentX = self.gridMax
	self.bounds.extentY = self.gridMax

	self:_OnUpdateGlobalPos()
	self.lastGlobalGridPos = self.globalGridPos

	-- Construct GridNavMap
	self:_RefreshGridMap()

	-- Register event listener
	AI_ObstacleManager:AddListener( self )
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_OnUpdateGlobalPos()
	self.globalGridPos	= { self:GetGlobalGridPos() }
	self.globalMinMax	= self:GetGlobalMinMax()

	self.bounds.centerX	= self.globalGridPos[1]
	self.bounds.centerY	= self.globalGridPos[2]

	self.localGridPosX	= self:GlobalToLocalGridPosX( self.globalGridPos[1] )
	self.localGridPosY	= self:GlobalToLocalGridPosY( self.globalGridPos[2] )
	self.localMinX		= ( self.localGridPosX + self.gridMin - 1 ) % self.nGridDim + 1
	self.localMinY		= ( self.localGridPosY + self.gridMin - 1 ) % self.nGridDim + 1
	self.localMaxX		= ( self.localGridPosX + self.gridMax - 1 ) % self.nGridDim + 1
	self.localMaxY		= ( self.localGridPosY + self.gridMax - 1 ) % self.nGridDim + 1
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:Update()
	self.centerOfGrid = self:GetCenterOfGrid()
	self:_OnUpdateGlobalPos()

	-- Update the GridMap
	local deltaGridPosX = self.globalGridPos[1] - self.lastGlobalGridPos[1]
	local deltaGridPosY = self.globalGridPos[2] - self.lastGlobalGridPos[2]

	if deltaGridPosX ~= 0 or deltaGridPosY ~= 0 then
		if deltaGridPosX ~= 0 and deltaGridPosY ~= 0 then

			self:_ShiftRowBy( deltaGridPosY )

			-- minmax for shifting columns
			local minmax = { unpack(self.globalMinMax) }
			if deltaGridPosY < 0 then
				minmax[2] = minmax[2] - deltaGridPosY
			else
				minmax[4] = minmax[4] - deltaGridPosY
			end
			self:_ShiftColumnBy( deltaGridPosX, minmax )

		elseif deltaGridPosY ~= 0 then
			self:_ShiftRowBy( deltaGridPosY )
		elseif deltaGridPosX ~= 0 then
			self:_ShiftColumnBy( deltaGridPosX )
		end
	end

	-- Gather force fields
	local totalForce = Vector(0,0,0)
	self.bInForceField	= false
	for k,v in pairs( self.vForceFieldMap ) do
		local force = v:CalculateForce( self.entity )
		if force then
			self.bInForceField = true
			totalForce = totalForce + force
		end
	end
	if self.bInForceField then
		self.forceDir = totalForce:Normalized()
	end

	-- End update
	self.lastGlobalGridPos = self.globalGridPos
end

--------------------------------------------------------------------------------
-- Refresh entire GridMap
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_RefreshGridMap()
	self:_Log( "Refreshing GridMap" )

	local minmax = self.globalMinMax

	for globalY = minmax[2], minmax[4] do
		local localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = {}

		for globalX = minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			vRow[localX] = AI_LocalGridCell( self, globalX, globalY )
		end

		-- Store
		self.vGridMap[localY] = vRow
	end

	-- Update obstacles
	local obstacles = AI_ObstacleManager:GetOverlappingObstacles( self.bounds )
	self:_Log( #obstacles .. " overlapping obstacles found." )
	for k,v in ipairs( obstacles ) do
		self:Rasterize( v, true )
	end
end

--------------------------------------------------------------------------------
-- Shift Rows
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_ShiftRowBy( deltaY, minmax )
	minmax = minmax or { unpack(self.globalMinMax) }

	local nShift = math.abs( deltaY )
	if nShift >= self.nGridDim then
		self:_RefreshGridMap()
		return
	end

	-- Update rows
	if deltaY < 0 then
		minmax[4] = minmax[2] + (nShift-1)
	else
		minmax[2] = minmax[4] - (nShift-1)
	end

	for globalY = minmax[2], minmax[4] do
		localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = self.vGridMap[localY]

		for globalX = minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			vRow[localX] = AI_LocalGridCell( self, globalX, globalY )
		end
	end

	-- Obstacles
	local bounds = AABB.CreateFromGridMinMax( minmax )
	local obstacles = AI_ObstacleManager:GetOverlappingObstacles( bounds )
--	self:_Log( #obstacles .. " overlapping obstacles found." )
	for k,v in ipairs( obstacles ) do
		self:Rasterize( v, true, minmax )
	end
end

--------------------------------------------------------------------------------
-- Shift Columns
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_ShiftColumnBy( deltaX, minmax )
	minmax = minmax or { unpack(self.globalMinMax) }

	local nShift = math.abs( deltaX )
	if nShift >= self.nGridDim then
		self:_RefreshGridMap()
		return
	end

	-- Update columns
	if deltaX < 0 then
		minmax[3] = minmax[1] + (nShift-1)
	else
		minmax[1] = minmax[3] - (nShift-1)
	end

	for globalY = minmax[2], minmax[4] do
		localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = self.vGridMap[localY]

		for globalX = minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			vRow[localX] = AI_LocalGridCell( self, globalX, globalY )
		end
	end

	-- Obstacles
	local bounds = AABB.CreateFromGridMinMax( minmax )
	local obstacles = AI_ObstacleManager:GetOverlappingObstacles( bounds )
--	self:_Log( #obstacles .. " overlapping obstacles found." )
	for k,v in ipairs( obstacles ) do
		self:Rasterize( v, true, minmax )
	end
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:DebugDraw()
	-- Draw Cell
	local minmax = self.globalMinMax
	local posZ = self.entity:GetAbsOrigin().z

	for globalY=minmax[2], minmax[4] do
		local localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = self.vGridMap[localY]

		for globalX=minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			local cell = self.vGridMap[localY][localX]

			local worldPos = self:GlobalGridPosToWorldCenter( globalX, globalY )
			worldPos.z = posZ

			local color = cell:GetColor()
			DebugDrawBox( worldPos, Vector(-16,-16,-16), Vector(16,16,16), color[1]*255, color[2]*255, color[3]*255, color[4]*255, 1.0 )
			local text = cell:GetText()
			if text then
				DebugDrawText( worldPos, text, true, 1.0 )
			end
		end
	end

	-- Draw Force
	if self.bInForceField then
		local from = self.entity:GetAbsOrigin()
		local to = self.forceDir:Normalized() * 250 + from
		DebugDrawLine( from, to, 255, 0, 255, true, 1.0 )
	end
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:GetCenterCell()
	return self.vGridMap[self.localGridPosY][self.localGridPosX]
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:GetCurrentState()
	local centerCell = self:GetCenterCell()

	-- The cell is occupied
	if not centerCell:IsSafety() then
		return LGC_STATE_DANGER
	end

	-- The cell is in range of SEPARATION force field
	if self.bInForceField then
		return LGC_STATE_DANGER
	end

	-- Safety!
	return LGC_STATE_SAFETY
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:GetStateByWorldPos( worldPos )
	local globalX = GridNav:WorldToGridPosX( worldPos.x )
	local globalY = GridNav:WorldToGridPosY( worldPos.y )

	if globalX < self.globalMinMax[1] or globalX > self.globalMinMax[3] then
		return LGC_STATE_UNKNOWN
	end
	if globalY < self.globalMinMax[2] or globalY > self.globalMinMax[4] then
		return LGC_STATE_UNKNOWN
	end

	local localX = self:GlobalToLocalGridPosX( globalX )
	local localY = self:GlobalToLocalGridPosY( globalY )

	local cell = self.vGridMap[localY][localX]

	-- The cell is occupied
	if not cell:IsSafety() then
		return LGC_STATE_DANGER
	end

	-- Safety!
	return LGC_STATE_SAFETY
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:CalculateNearestSafetyPosition()

	-- for DEBUG
	local minmax = self.globalMinMax
	for globalY=minmax[2], minmax[4] do
		local localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = self.vGridMap[localY]

		for globalX=minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			local cell = self.vGridMap[localY][localX]
			cell.cost = nil
		end
	end

	-- Neighbors
	local neighborOffsets = {
		{ -1,  1, 1.414 },	-- NW
		{  0,  1, 1 },		-- N
		{  1,  1, 1.414 },	-- NE
		{ -1,  0, 1 },		-- W
		{  1,  0, 1 },		-- E
		{ -1, -1, 1.414 },	-- SW
		{  0, -1, 1 },		-- S
		{  1, -1, 1.414 },	-- SE
	}
	for i=1, #neighborOffsets do
		local j = math.random( #neighborOffsets )
		neighborOffsets[i], neighborOffsets[j] = neighborOffsets[j], neighborOffsets[i]
	end

	-- Effect of force field
	local leastDistance = -1
	if self.bInForceField then
		leastDistance = 150	-- in euclidean distance

		-- Weighting neighbors node
		for _,v in ipairs(neighborOffsets) do
			local neighborDir = Vector( v[1], v[2], 0 ):Normalized()
			local score = self.forceDir:Dot( neighborDir )
			if score >= 0 then
				-- FORWARD
				local factor = (1-score)*2+1 -- http://www.wolframalpha.com/input/?i=plot+%281-x%29*2%2B1%2C+x%3D0%2C1
				v[3] = v[3] * factor
			else
				-- BACKWARD
				v[3] = 999
			end
		end
	end

	-- Floodfill
	local distanceMap = {}
	local nodeMap = {}
	local openQueue = PriorityQueue( distanceMap )
	local closed = {}
	local numSearched = 0

	local addToOpen = function ( localX, localY, cost )
		local localIndex = self:LocalGridPosToLocalIndex( localX, localY )
		if closed[localIndex] == nil then
			if not openQueue:contains( localIndex ) then

				-- Create new node
				nodeMap[localIndex] = {
					["localX"] = localX,
					["localY"] = localY,
				}
				distanceMap[localIndex] = cost
				openQueue:push( localIndex )

				self.vGridMap[localY][localX].cost = cost

			elseif cost < distanceMap[localIndex] then

				-- decrease key
				distanceMap[localIndex] = cost
				openQueue:update( localIndex )

				self.vGridMap[localY][localX].cost = cost

			end
		end
	end

	addToOpen( self.localGridPosX, self.localGridPosY, 1 )

	while not openQueue:empty() do
		local currentIndex = openQueue:pop()
		local currentNode = nodeMap[currentIndex]
		local currentX = currentNode.localX
		local currentY = currentNode.localY
		local currentCost = distanceMap[currentIndex]
		local currentCell = self.vGridMap[currentY][currentX]

		if currentCell:IsSafety() then
			local currentWorldPos = self:LocalGridPosToWorldCenter( currentX, currentY )
			local distInEuclidean = ( currentWorldPos - self.entity:GetAbsOrigin() ):Length2D()
			if distInEuclidean >= leastDistance then
			--	self:_Log( numSearched .. " local grid cell has been observed." )
				return currentWorldPos
			end
		end

		closed[currentIndex] = currentCost
		numSearched = numSearched + 1

		-- Collect neighbor nodes
		if not currentCell:IsBlocked() then
			self:_ForEachNeighbor( neighborOffsets, currentX, currentY,
			function ( x, y, cost )
				addToOpen( x, y, currentCost + cost )
			end )
		end
	end

	-- Safety position not found
	self:_Log( numSearched .. " local grid cell has been observed but safety position not found." )
	return nil

end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:CalculateRetreatPosition( friends, enemies )

	-- for DEBUG
	local minmax = self.globalMinMax
	for globalY=minmax[2], minmax[4] do
		local localY = self:GlobalToLocalGridPosY( globalY )
		local vRow = self.vGridMap[localY]

		for globalX=minmax[1], minmax[3] do
			local localX = self:GlobalToLocalGridPosX( globalX )
			local cell = self.vGridMap[localY][localX]
			cell.retreatScore = nil
		end
	end

	-- Neighbors
	local neighborOffsets = {
		{ -1,  1, 1.414 },	-- NW
		{  0,  1, 1 },		-- N
		{  1,  1, 1.414 },	-- NE
		{ -1,  0, 1 },		-- W
		{  1,  0, 1 },		-- E
		{ -1, -1, 1.414 },	-- SW
		{  0, -1, 1 },		-- S
		{  1, -1, 1.414 },	-- SE
	}
	for i=1, #neighborOffsets do
		local j = math.random( #neighborOffsets )
		neighborOffsets[i], neighborOffsets[j] = neighborOffsets[j], neighborOffsets[i]
	end

	-- A*
	local scoreGMap	= {}
	local scoreFMap	= {}
	local scoreHMap	= {}
	local nodeMap	= {}
	local openQueue	= PriorityQueue( scoreFMap )
	local closed = {}
	local numSearched = 0
	local lowestScoreH = 999999
	local lowestScoreHNode = nil
	local highestScoreH = -999999

	local heuristicCostEstimate = function ( worldPos )
		-- distance from ally
		local nearestDist = 999999
		for k,v in pairs(friends) do
			local dist = ( worldPos - v:GetAbsOrigin() ):Length2D()
			nearestDist = math.min( nearestDist, dist )
		end

		local maxDistFromFriend = 1200
		if maxDistFromFriend > 1200 then
			-- TODO: Make ramp
			return 999999
		end

		-- dangerous level
		local dangerous = 0
		for k,v in pairs(enemies) do
			local dist = ( worldPos - v:GetAbsOrigin() ):Length2D()
			dangerous = dangerous - dist
		end
		return dangerous
	end

	local addToOpen = function ( localX, localY, scoreG )
		local localIndex = self:LocalGridPosToLocalIndex( localX, localY )
		if closed[localIndex] == nil then
			if not openQueue:contains( localIndex ) then

				-- Create new node
				nodeMap[localIndex] = {
					["localX"] = localX,
					["localY"] = localY,
				}

				local scoreH = heuristicCostEstimate( self:LocalGridPosToWorldCenter( localX, localY ) )

				scoreGMap[localIndex] = scoreG
				scoreHMap[localIndex] = scoreH
				scoreFMap[localIndex] = scoreG + scoreH

				openQueue:push( localIndex )

				self.vGridMap[localY][localX].retreatScore = scoreH
			--	self.vGridMap[localY][localX].retreatScore = scoreFMap[localIndex]

			elseif scoreG < scoreGMap[localIndex] then

				-- decrease key
				scoreGMap[localIndex] = scoreG
				scoreFMap[localIndex] = scoreG + scoreHMap[localIndex]
				
				openQueue:update( localIndex )

			--	self.vGridMap[localY][localX].retreatScore = scoreFMap[localIndex]

			end
		end
	end

	addToOpen( self.localGridPosX, self.localGridPosY, 0 )

	while not openQueue:empty() do
		local currentIndex = openQueue:pop()
		local currentNode = nodeMap[currentIndex]
		local currentX = currentNode.localX
		local currentY = currentNode.localY
		local currentCost = scoreGMap[currentIndex]
		local currentCell = self.vGridMap[currentY][currentX]

		if not currentCell:IsBlocked() then
			if scoreHMap[currentIndex] > highestScoreH then
				highestScoreH = scoreHMap[currentIndex]
			end

		--	local currentWorldPos = self:LocalGridPosToWorldCenter( currentX, currentY )
		--	local distInEuclidean = ( currentWorldPos - self.entity:GetAbsOrigin() ):Length2D()
		--	if distInEuclidean >= leastDistance then
		--	--	self:_Log( numSearched .. " local grid cell has been observed." )
		--		return currentWorldPos
		--	end
			if scoreHMap[currentIndex] < lowestScoreH then
				lowestScoreH = scoreHMap[currentIndex]
				lowestScoreHNode = currentNode
			end
		end

		closed[currentIndex] = currentCost
		numSearched = numSearched + 1

		-- Collect neighbor nodes
		if not currentCell:IsBlocked() then
			self:_ForEachNeighbor( neighborOffsets, currentX, currentY,
			function ( x, y, cost )
				addToOpen( x, y, currentCost + cost )
			end )
		end
	end

	-- Return lowest threat score
	AI_LocalGridNavMap._retreatLowestScoreH		= lowestScoreH
	AI_LocalGridNavMap._retreatHighestScoreH	= highestScoreH
	return self:LocalGridPosToWorldCenter( lowestScoreHNode.localX, lowestScoreHNode.localY )

--	-- Retreat position not found
--	self:_Log( numSearched .. " local grid cell has been observed but retreat position not found." )
--	return nil

end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_ForEachNeighbor( neighborOffsets, currentX, currentY, func )
	local discard

	for _,v in ipairs( neighborOffsets ) do
		discard = false

		-- WRAPPING
		if v[1] < 0 and currentX == self.localMinX then discard = true end
		if v[2] < 0 and currentY == self.localMinY then discard = true end
		if v[1] > 0 and currentX == self.localMaxX then discard = true end
		if v[2] > 0 and currentY == self.localMaxY then discard = true end

		if not discard then
			-- OFFSET
			local x = currentX + v[1]
			local y = currentY + v[2]

			-- REPEATING
			if x == 0 then
				x = self.nGridDim
			elseif x == self.nGridDim + 1 then
				x = 1
			end
			if y == 0 then
				y = self.nGridDim
			elseif y == self.nGridDim + 1 then
				y = 1
			end

			func( x, y, v[3] )
		end
	end
end

--------------------------------------------------------------------------------
-- Event Listeners
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:OnAddedObstacle( obstacle )
	if obstacle.casterEntityID == self.entity:entindex() then
		return
	end

	self.nObstacles = self.nObstacles + 1
--	self:_Log( "Num Obstacles = " .. self.nObstacles )
	-- Optimize : CHECK COLLISION?
	self:Rasterize( obstacle, true )
end

function AI_LocalGridNavMap:OnRemovedObstacle( obstacle )
	if obstacle.casterEntityID == self.entity:entindex() then
		return
	end

	self.nObstacles = self.nObstacles - 1
--	self:_Log( "Num Obstacles = " .. self.nObstacles )
	-- Optimize : CHECK COLLISION?
	self:Rasterize( obstacle, false )
end

function AI_LocalGridNavMap:OnAddedForceField( forceField )
--	self:_Log( "ForceField : " .. forceField.name )
	if not forceField:FilterUnit( self.entity ) then
		return
	end

	self.vForceFieldMap[forceField.name] = forceField
end

function AI_LocalGridNavMap:OnRemovedForceField( forceField )
	self.vForceFieldMap[forceField.name] = nil
end

--------------------------------------------------------------------------------
-- Obstacle Rasterizers
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:Rasterize( obstacle, bAdd, minmax )
	minmax = minmax or self.globalMinMax

	if obstacle.type == OBSTACLE_TYPE_DIRECTIONAL then
		self:RasterizeDirectional( obstacle, bAdd, minmax )
	elseif obstacle.type == OBSTACLE_TYPE_CIRCLE then
		self:RasterizeCircle( obstacle, bAdd, minmax )
	elseif obstacle.type == OBSTACLE_TYPE_QUADRANT then
		self:RasterizeQuadrant( obstacle, bAdd, minmax )
	else
		self:_Log( "Valid rasterize method not found. ObstacleType = " .. obstacle.type )
	end
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:RasterizeDirectional( obstacle, bAdd, minmax )

	-- Draw 2 Triangles
	local buffer = {}
	local v = obstacle.corners
	self:RasterizeTriangle( v[1], v[3], v[2], minmax, buffer )
	self:RasterizeTriangle( v[1], v[4], v[3], minmax, buffer )

	-- Update LocalGridNav
	for localIndex,v in pairs(buffer) do
		local localX, localY = self:LocalIndexToLocalGridPos( localIndex )
		local cell = self.vGridMap[localY][localX]
		cell.nObstacles = cell.nObstacles + ( bAdd and 1 or -1 )
	end

end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:RasterizeCircle( obstacle, bAdd, minmax )

	local bounds = obstacle.bounds
	local minX = math.max( minmax[1], bounds.centerX - bounds.extentX )
	local minY = math.max( minmax[2], bounds.centerY - bounds.extentY )
	local maxX = math.min( minmax[3], bounds.centerX + bounds.extentX )
	local maxY = math.min( minmax[4], bounds.centerY + bounds.extentY )

	-- Rasterize
	local r = obstacle.circleRadius / 64
	local r2 = r * r

	for y = minY, maxY do
		local relY = y - bounds.centerY
		local localY = self:GlobalToLocalGridPosY( y )

		for x = minX, maxX do
			local relX = x - bounds.centerX
			if (relX*relX + relY*relY) < r2 then

				local localX = self:GlobalToLocalGridPosX( x )
				local cell = self.vGridMap[localY][localX]
				cell.nObstacles = cell.nObstacles + ( bAdd and 1 or -1 )

			end
		end
	end

end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:RasterizeQuadrant( obstacle, bAdd, minmax )

	-- Draw 2 Triangles
	local buffer = {}
	local v = obstacle.corners
	self:RasterizeTriangle( v[1], v[2], v[3], minmax, buffer )
	self:RasterizeTriangle( v[1], v[3], v[4], minmax, buffer )

	-- Update LocalGridNav
	for localIndex,v in pairs(buffer) do
		local localX, localY = self:LocalIndexToLocalGridPos( localIndex )
		local cell = self.vGridMap[localY][localX]
		cell.nObstacles = cell.nObstacles + ( bAdd and 1 or -1 )
	end

end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:RasterizeTriangle( v0, v1, v2, minmax, buffer )

	-- Refs:
	--   http://fgiesen.wordpress.com/2013/02/08/triangle-rasterization-in-practice/
	--   http://fgiesen.wordpress.com/2013/02/10/optimizing-the-basic-rasterizer/

	local orient2D = function ( a, b, c )
		return (b.x-a.x)*(c.y-a.y) - (b.y-a.y)*(c.x-a.x)
	end

	-- Compute triangle bounding DebugDrawBox
	local minX = math.min( v0.x, v1.x, v2.x )
	local minY = math.min( v0.y, v1.y, v2.y )
	local maxX = math.max( v0.x, v1.x, v2.x )
	local maxY = math.max( v0.y, v1.y, v2.y )

	-- Clip against screen bounds
	minX = math.max( minX, minmax[1] )
	minY = math.max( minY, minmax[2] )
	maxX = math.min( maxX, minmax[3] )
	maxY = math.min( maxY, minmax[4] )

	-- Triangle setup
	local A01 = v0.y - v1.y
	local A12 = v1.y - v2.y
	local A20 = v2.y - v0.y
	local B01 = v1.x - v0.x
	local B12 = v2.x - v1.x
	local B20 = v0.x - v2.x

	-- Barycentric coodinates at minX/minY corner
	local p = { x = minX, y = minY }
	local w0_row = orient2D( v1, v2, p )
	local w1_row = orient2D( v2, v0, p )
	local w2_row = orient2D( v0, v1, p )

	-- Rasterize
	for y = minY, maxY do
		-- Barycentric coodinates at start of row
		local w0 = w0_row
		local w1 = w1_row
		local w2 = w2_row

		for x = minX, maxX do
			-- If p is on or inside all edges, render pixel.
			if w0 >= 0 and w1 >= 0 and w2 >= 0 then
				buffer[self:GlobalGridPosToLocalIndex(x,y)] = true
			end

			-- One step to the right
			w0 = w0 + A12
			w1 = w1 + A20
			w2 = w2 + A01
		end

		-- One row step
		w0_row = w0_row + B12
		w1_row = w1_row + B20
		w2_row = w2_row + B01
	end

end



--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function AI_LocalGridNavMap:GetGlobalGridPos()
	local worldPos = self.entity:GetAbsOrigin()
	local x = GridNav:WorldToGridPosX( worldPos.x )
	local y = GridNav:WorldToGridPosY( worldPos.y )
	return x, y
end

function AI_LocalGridNavMap:GetCenterOfGrid()
	local gridX, gridY = self:GetGlobalGridPos()
	local worldX = GridNav:GridPosToWorldCenterX( gridX )
	local worldY = GridNav:GridPosToWorldCenterY( gridY )
	return Vector( worldX, worldY, 0 )
end

function AI_LocalGridNavMap:GlobalToLocalGridPosX( globalX )
	return ( globalX - GridNavMap.gridMinX - self.gridMin ) % self.nGridDim + 1
end

function AI_LocalGridNavMap:GlobalToLocalGridPosY( globalY )
	return ( globalY - GridNavMap.gridMinY - self.gridMin ) % self.nGridDim + 1
end

function AI_LocalGridNavMap:LocalToGlobalGridPosX( localX )
	local offsetFromMin = ( localX - self.localMinX + self.nGridDim ) % self.nGridDim
	return self.globalMinMax[1] + offsetFromMin
end

function AI_LocalGridNavMap:LocalToGlobalGridPosY( localY )
	local offsetFromMin = ( localY - self.localMinY + self.nGridDim ) % self.nGridDim
	return self.globalMinMax[2] + offsetFromMin
end

function AI_LocalGridNavMap:LocalGridPosToLocalIndex( localX, localY )
	localX = localX - 1
	localY = localY - 1
	return localX + localY * self.nGridDim + 1
end

function AI_LocalGridNavMap:GlobalGridPosToLocalIndex( globalX, globalY )
	local localX = self:GlobalToLocalGridPosX( globalX )
	local localY = self:GlobalToLocalGridPosY( globalY )
	return self:LocalGridPosToLocalIndex( localX, localY )
end

function AI_LocalGridNavMap:LocalIndexToLocalGridPos( localIndex )
	localIndex = localIndex - 1
	local localX = localIndex % self.nGridDim + 1
	local localY = math.floor( localIndex / self.nGridDim ) + 1
	return localX, localY
end

function AI_LocalGridNavMap:GetGlobalMinMax()
	local minX = self.globalGridPos[1] + self.gridMin
	local minY = self.globalGridPos[2] + self.gridMin
	local maxX = self.globalGridPos[1] + self.gridMax
	local maxY = self.globalGridPos[2] + self.gridMax
	return { minX, minY, maxX, maxY }
end

function AI_LocalGridNavMap:GlobalGridPosToWorldCenter( globalX, globalY )
	local worldX = GridNav:GridPosToWorldCenterX( globalX )
	local worldY = GridNav:GridPosToWorldCenterY( globalY )
	return Vector( worldX, worldY, 0 )
end

function AI_LocalGridNavMap:LocalGridPosToWorldCenter( localX, localY )
	local globalX = self:LocalToGlobalGridPosX( localX )
	local globalY = self:LocalToGlobalGridPosY( localY )
	return self:GlobalGridPosToWorldCenter( globalX, globalY )
end

--------------------------------------------------------------------------------
function AI_LocalGridNavMap:_Log( text )
	print( "[AI/LocalGridNavMap] " .. text )
end





--------------------------------------------------------------------------------
--
-- LocalGridCell
--
--------------------------------------------------------------------------------
LGC_DEBUG_COLOR_NONE			= 0
LGC_DEBUG_COLOR_OBSTACLES		= 1
LGC_DEBUG_COLOR_COST_B			= 2
LGC_DEBUG_COLOR_COST			= 3
LGC_DEBUG_COLOR_RETREAT			= 4

LGC_DEBUG_TEXT_NONE				= 0
LGC_DEBUG_TEXT_NUM_OBSTACLES	= 1

if AI_LocalGridCell == nil then
	AI_LocalGridCell = class({})
	AI_LocalGridCell.iDebugDrawColor = LGC_DEBUG_COLOR_OBSTACLES
	AI_LocalGridCell.iDebugText = LGC_DEBUG_TEXT_NONE
end

--------------------------------------------------------------------------------
function AI_LocalGridCell:constructor( localGridMap, globalX, globalY )
	local index = GridNavMap:_GridPosToIndex( globalX, globalY )
	self._isBlocked = GridNavMap.vBlocked[index]
	self._worldPos = localGridMap:GlobalGridPosToWorldCenter( globalX, globalY )
	self.timeCreated = GameRules:GetGameTime()
	self.nObstacles = 0
end

--------------------------------------------------------------------------------
function AI_LocalGridCell:IsBlocked()
	if self._isBlocked then
		-- Check realtime
		return not GridNav:IsTraversable( self._worldPos ) or GridNav:IsBlocked( self._worldPos )
	else
		return false
	end
end

--------------------------------------------------------------------------------
function AI_LocalGridCell:GetColor()
	local color = { 0, 0, 0, 1 }
	local val = self:IsBlocked() and 0.0 or 1.0
	local alpha = math.max( 2.0 - ( GameRules:GetGameTime() - self.timeCreated ), 0.0 ) / 2.0
	color[4] = alpha * 0.3

	if AI_LocalGridCell.iDebugDrawColor == LGC_DEBUG_COLOR_OBSTACLES then
		if self.nObstacles > 0 then
			if self.nObstacles == 2 then
				color[2] = val
			elseif self.nObstacles == 3 then
				color[3] = val
			else
				color[1] = val
			end
		elseif self.nObstacles < 0 then
			-- INVALID STATE
			color[1], color[2], color[3] = val, val, val

			if not self.isInvalid then
				print( "INVALID CELL !!!" )
				self.isInvalid = true
			end
		end

	elseif AI_LocalGridCell.iDebugDrawColor == LGC_DEBUG_COLOR_COST_B then
		color[4] = self.nObstacles > 0 and 1.0 or 0.0
		if self.cost then
			color[2] = val
			color[3] = 1.0 - math.min( (self.cost-1) / 5, 1.0 )
		end

	elseif AI_LocalGridCell.iDebugDrawColor == LGC_DEBUG_COLOR_COST then
		-- Visualize cost
		color[4] = self.nObstacles > 0 and 1.0 or 0.0
		if self.cost then
			local fracCost = self.cost % 3
			val = fracCost / 3
			color[1], color[2], color[3] = val, val, val
		end

	elseif AI_LocalGridCell.iDebugDrawColor == LGC_DEBUG_COLOR_RETREAT then
		if self.retreatScore then
			local val = ( self.retreatScore - AI_LocalGridNavMap._retreatLowestScoreH )
					  / ( AI_LocalGridNavMap._retreatHighestScoreH - AI_LocalGridNavMap._retreatLowestScoreH )
			color[1], color[2], color[3] = val, 0, 0
			color[4] = 1.0 - val
		end

	end

	return color
end

function AI_LocalGridCell:GetText()
	if AI_LocalGridCell.iDebugText == LGC_DEBUG_TEXT_NUM_OBSTACLES then
		return tostring(self.nObstacles)
	else
		return nil
	end
end

--------------------------------------------------------------------------------
function AI_LocalGridCell:IsSafety()
	return self.nObstacles == 0 and not self:IsBlocked()
end





--------------------------------------------------------------------------------
--
-- Priority Queue
--
--------------------------------------------------------------------------------
if PriorityQueue == nil then
	PriorityQueue = class({})
end

function PriorityQueue:constructor( distanceMap )
	self.heap = {}
	self.indexInHeap = {}
	self.distanceMap = distanceMap
	self.compare = function ( a, b )
		return a < b
	end
end

function PriorityQueue:empty()
	return #self.heap == 0
end

function PriorityQueue:push( v )
	local index = #self.heap + 1
	self.heap[index] = v
	self.indexInHeap[v] = index
	self:preserveHeapPropertyUp( index )
	self:verifyHeap()
end

function PriorityQueue:pop()
	local heap = self.heap
	local top = heap[1]
	self.indexInHeap[top] = nil
	if #heap ~= 1 then
		heap[1] = heap[#heap]
		self.indexInHeap[heap[1]] = 1
		heap[#heap] = nil
		self:preserveHeapPropertyDown()
		self:verifyHeap()
	else
		heap[1] = nil
	end
	return top
end

function PriorityQueue:update( v )  -- decrease-key
	local index = self.indexInHeap[v]
	self:preserveHeapPropertyUp( index )
	self:verifyHeap()
end

function PriorityQueue:contains( v )
	return self.indexInHeap[v] ~= nil
end

function PriorityQueue:pushOrUpdate( v )
	local index = self.indexInHeap[v]
	if index == nil then
		index = #self.heap + 1
		self.heap[index] = v
		self.indexInHeap[v] = index
	end
	self:preserveHeapPropertyUp( index )
	self:verifyHeap()
end

function PriorityQueue:parent( index )
	return math.floor( index / 2 )
end

function PriorityQueue:child( index, offset )
	return index * 2 + offset
end

function PriorityQueue:swapHeapElements( indexA, indexB )
	local valueA = self.heap[indexA]
	local valueB = self.heap[indexB]
	self.heap[indexA] = valueB
	self.heap[indexB] = valueA
	self.indexInHeap[valueA] = indexB
	self.indexInHeap[valueB] = indexA
end

function PriorityQueue:verifyHeap()
	if false then
		local heap = self.heap
		for i=2, #heap do
			if self.compare( self.distanceMap[heap[i]], self.distanceMap[heap[self:parent(i)]] ) then
				print( "Element is smaller than its parens" )
			end
		end
	end
end

function PriorityQueue:preserveHeapPropertyUp( index )
	local heap = self.heap
	local origIndex = index
	local numLevelsMoved = 0
	
	if index == 1 then return end
	
	local currentlyBeingMoved = heap[index]
	local currentlyBeingMovedDist = self.distanceMap[currentlyBeingMoved]
	while true do
		if index == 1 then break end -- Stop at root
		local parentIndex = self:parent(index)
		local parentValue = heap[parentIndex]
		if self.compare( currentlyBeingMovedDist, self.distanceMap[parentValue] ) then
			numLevelsMoved = numLevelsMoved + 1
			index = parentIndex
		else
			break
		end
	end
	
	index = origIndex
	for i=1, numLevelsMoved do
		local parentIndex = self:parent(index)
		local parentValue = heap[parentIndex]
		self.indexInHeap[parentValue] = index
		heap[index] = parentValue
		index = parentIndex
	end
	heap[index] = currentlyBeingMoved
	self.indexInHeap[currentlyBeingMoved] = index
	
	self:verifyHeap()
end

function PriorityQueue:preserveHeapPropertyDown()
	local heap = self.heap
	if #heap == 0 then return end
	local index = 1
	local currentlyBeingMoved = heap[1]
	local currentlyBeingMovedDist = self.distanceMap[currentlyBeingMoved]
	local heapSize = #heap
	while true do
		local firstChildIndex = self:child( index, 0 )
		if firstChildIndex > heapSize then break end -- No children
		local smallestChildOffset = 0
		local smallestChildDist = self.distanceMap[heap[firstChildIndex]]
		if firstChildIndex + 1 <= heapSize then
			local secondChild = heap[firstChildIndex+1]
			local secondChildDist = self.distanceMap[secondChild]
			if self.compare( secondChildDist, smallestChildDist ) then
				smallestChildOffset = 1
				smallestChildDist = secondChildDist
			end
		end
		if self.compare( smallestChildDist, currentlyBeingMovedDist ) then
			self:swapHeapElements( firstChildIndex + smallestChildOffset, index )
			index = firstChildIndex + smallestChildOffset
		else
			break
		end
	end

	self:verifyHeap()
end



-- Test
--[[
function PriorityQueue.new( ... )
	local o = {}
	setmetatable(o, { __index = PriorityQueue } )
	o:constructor( ... )
	return o
end

local distMap = {}
local nodeMap = {}
pqueue = PriorityQueue.new(distMap)

math.randomseed( os.time() )
for i=1, 50 do
	local node = { ["i"] = i }
	distMap[node] = math.random( 100 )
	nodeMap[i] = node
	pqueue:push( node )
end

for i=1, 20 do
	local node = nodeMap[i]
	distMap[node] = distMap[node] * 0.7
	pqueue:update( node ) -- decrease key
end

while not pqueue:empty() do
	local node = pqueue:pop()
	print( ("[%2d] %.1f"):format( node.i, distMap[node] ) )
end
--]]


--------------------------------------------------------------------------------
--[[
function PriorityQueue:constructor( cmp )
	self.heap = {}
	self.cmp = cmp or function ( a, b ) return a.cost < b.cost end
end

function PriorityQueue:push( v )
	local heap = self.heap
	
	-- Percolate up
	local hole = #heap + 1
	while hole > 1 and self.cmp( v, heap[math.floor(hole/2)] ) do
		heap[hole] = heap[math.floor(hole/2)]
		hole = math.floor(hole/2)
	end
	heap[hole] = v
end

function PriorityQueue:pop()
	local heap = self.heap
	
	local v = heap[1]
	heap[1] = heap[#heap]
	heap[#heap] = nil
	
	-- Percolate down
	local hole = 1
	local child
	local temp = heap[hole]
	while hole*2 <= #heap do
		child = hole * 2
		if child ~= #heap and self.cmp( heap[child+1], heap[child] ) then
			child = child + 1
		end
		if self.cmp( heap[child], temp ) then
			heap[hole] = heap[child]
		else
			break
		end
		
		hole = child
	end
	heap[hole] = temp
	
	return v
end

function PriorityQueue:empty()
	return #self.heap == 0
end
--]]
