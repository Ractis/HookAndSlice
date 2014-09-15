
require( "DotaHS_Math" )
require( "DotaHS_PerlinNoise" )
require( "DotaHS_Profiler" )

--------------------------------------------------------------------------------
-- FORWARD DECL
--------------------------------------------------------------------------------
if GridNavMap == nil then
	GridNavMap = class({})
end

local ProbabilityQuadtree	= {}	-- Class

if GridNavClusterMap == nil then
	GridNavClusterMap = class({})
end

local GridNavCluster		= {}	-- Class
local ClusterRegion			= {}	-- Class
local ClusterRegionLabel	= {}	-- Class

local PriorityQueue			= {}	-- Class



--------------------------------------------------------------------------------
--
-- GridNavMap
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Pre-Initialize
--------------------------------------------------------------------------------
function GridNavMap:PreInitialize( kv )

	profile_begin( "GridNavMap:PreInitialize" )

	self.gridMinX = GridNav:WorldToGridPosX( GetWorldMinX() )
	self.gridMaxX = GridNav:WorldToGridPosX( GetWorldMaxX() )
	self.gridMinY = GridNav:WorldToGridPosY( GetWorldMinY() )
	self.gridMaxY = GridNav:WorldToGridPosY( GetWorldMaxY() )
	self.gridWidth  = self.gridMaxX - self.gridMinX + 1
	self.gridHeight = self.gridMaxY - self.gridMinY + 1

	self:_Log( "Grid Bounds :" )
	self:_Log( "  Min = ( " .. self.gridMinX .. ", " .. self.gridMinY .. " )" )
	self:_Log( "  Max = ( " .. self.gridMaxX .. ", " .. self.gridMaxY .. " )" )

	-- Find player start
	local startEnt = Entities:FindByClassname( nil, "info_player_start_goodguys" )
	if startEnt == nil then
		self:_Log( "info_player_start_goodguys is NOT FOUND" )
		return
	end

	local startOrigin = startEnt:GetAbsOrigin()
	self.startX = GridNav:WorldToGridPosX( startOrigin.x )
	self.startY = GridNav:WorldToGridPosY( startOrigin.y )

	self:_Log( "Start Position : ( " .. self.startX .. ", " .. self.startY .. " )" )

	-- Fire event
--[[
	FireGameEvent( "dotahs_map_info", {
		minX = self.gridMinX,
		maxX = self.gridMaxX,
		minY = self.gridMinY,
		maxY = self.gridMaxY,
	} )
--]]

	-- Map configuration
	self.safeArea = self:WorldUnitToCost( kv.StartSafeZoneDistance or 2000 )

	self._vDynamicObstructions = kv.DynamicObstructions or {}	-- obstruction name : traversable path name

	local traversableNameToObstructionName = {}
	for k,v in pairs(self._vDynamicObstructions) do
		traversableNameToObstructionName[v] = k
	end

	-- Collect all dynamic obstructions
	local vObstructionDisabledByDefault = {}
	local vObstructionEntMap	-- obstruction name : obstruction entity
	vObstructionEntMap = self:_CollectAllObstructions( vObstructionDisabledByDefault )	
	local vTraversableIndexMap	= self:_CollectAllTraversables()	-- traversable name : [gridIndex_1, gridIndex_2, cost between 1 and 2]
	self._vObstructionDisabledByDefault = vObstructionDisabledByDefault

	-- Generate static maps
	self.vBlocked				= self:_GenerateBlockedMap()
	self.vCost, self.vPartition	= self:_GenerateCostAndPartitionMap( self.vBlocked, vTraversableIndexMap )
	self.vPoolID				= self:_GeneratePoolIDMap( self.vCost, kv.NoLevelFlow )

	--
	-- Update graph
	--   edgeName : traversableName
	--            to
	--   edgeName : obstructionEntity
	--
	for edgeName, traversableName in pairs(self.vPartitionGraph) do
		local obstructionName = traversableNameToObstructionName[traversableName]
		local obstructionEnt = vObstructionEntMap[obstructionName]
		self.vPartitionGraph[edgeName] = obstructionEnt
	end

	--
	-- Initialize GridNavCluster map
	--
	GridNavClusterMap:PreInitialize( self )

	-- Register Commands
	Convars:RegisterCommand( "dotahs_save_gridnavmap_all",
	function ( ... )
	 	self:_SaveMapToFileAll()
	end, "Save all GridNavMaps", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotahs_save_map_poolid",
	function ( ... )
	 	self:_SavePoolIDMapToFile()
	end, "Save PoolID Map", FCVAR_CHEAT )

	profile_end()
	
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function GridNavMap:Initialize( kv )

	if not self._isPreInited then
		-- Do not init GridNavMap until the map has been completely loaded.
		self:PreInitialize( kv )
		self._isPreInited = true
	end

	profile_begin( "GridNavMap:Initialize" )

	-- Generate dynamic maps
	self.vPopulation			= self:_GeneratePopulationMap( self.vCost )

	self.probabilityTree		= self:_GenerateProbabilityTree( self.vPopulation )

	-- Restore obstruction state
	for k,v in pairs( self._vObstructionDisabledByDefault ) do
		v:SetEnabled( false, true )
	end

	-- Debug output grid nav map
	if kv.OutputGridNavMapImage == 1 then
		self:_Log( "OutputGridNavMapImage == 1" )
		self:_SaveMapToFileAll()
	end

	profile_end()

end

--------------------------------------------------------------------------------
function GridNavMap:CostToWorldUnit( cost )
	return cost * 64
end

--------------------------------------------------------------------------------
function GridNavMap:WorldUnitToCost( worldUnit )
	return worldUnit / 64
end

--------------------------------------------------------------------------------
function GridNavMap:GridPosToPoolName( gridPosX, gridPosY )
	local idx = self:_GridPosToIndex( gridPosX, gridPosY )
	local poolID = self.vPoolID[idx]
	if poolID then
		return self.vPoolNameMap[poolID]
	else
		return self.vPoolNameMap[1]	-- DEFAULT POOL
	end
end

--------------------------------------------------------------------------------
-- Distance from Starting point
--------------------------------------------------------------------------------
function GridNavMap:WorldPosToCost( worldPos )
	return self.vCost[self:WorldPosToIndex( worldPos )]
end

--------------------------------------------------------------------------------
function GridNavMap:WorldPosToPartitionID( worldPos )
	return self.vPartition[self:WorldPosToIndex( worldPos )]
end

--------------------------------------------------------------------------------
-- Generate Probability Tree for Horde
--------------------------------------------------------------------------------
function GridNavMap:GenerateHordeProbabilityTree( posHeadOfParty, posTailOfParty, hordeCostMin, bEnableSaveDebugImage )
	
	self:_Log( "Generating probability tree for HORDE..." )
	self:_Log( "  Head of Party : " .. tostring( posHeadOfParty ) )
	self:_Log( "  Tail of Party : " .. tostring( posTailOfParty ) )

	local map = {}
	local tree = ProbabilityQuadtree( self.gridMinX, self.gridMinY, self.gridWidth, self.gridHeight )

	local vCost = self.vCost
	local vPopulation = self.vPopulation

	local costHead = self:WorldPosToCost( posHeadOfParty )
	local costTail = self:WorldPosToCost( posTailOfParty )
	local hordeCostMax = hordeCostMin + 5

	self:_ForEachGrid( function ( index, x, y )
		local cost = vCost[index]
		local population = vPopulation[index] or 0	-- At SafeArea may be nil

		if cost == nil then
			return
		end

		local prob = 0
		if cost > costHead + hordeCostMin then
			if cost < costHead + hordeCostMax then
				prob = 1
			end
		elseif cost < costTail - hordeCostMin then
			if cost > costTail - hordeCostMax then
				prob = 1
			end
		end

		prob = prob - population	-- Spawn in depopulated area
		prob = math.max( prob, 0 )

		map[index] = prob

		tree:Insert( x, y, prob )
	end )

	-- TODO: Normalize probability in order to have 50:50 relationship between head and tail

	-- Generate debug image
	if bEnableSaveDebugImage then
		self:_SaveMapToFile( "horde", map, function ( population )
			if population ~= nil then
				local r = lerp( 1, 0  , population ) * 255
				local g = lerp( 1, 0.3, population ) * 255
				local b = lerp( 1, 0.6, population ) * 255
				return string.format( "%d %d %d", math.floor(r), math.floor(g), math.floor(b) )
			else
				return "0 0 0"
			end
		end )
	end

	return tree

end

--------------------------------------------------------------------------------
-- Obstruction / Traversable
--------------------------------------------------------------------------------
function GridNavMap:_CollectAllObstructions( vObstructionDisabledByDefault )
	local obstructionEntityMap = {}

	-- Collect all simple obstructions in the map
	for _,v in pairs(Entities:FindAllByClassname( "point_simple_obstruction" )) do
		local entName = v:GetName()
		if self._vDynamicObstructions[entName] ~= nil then
			-- Set obstruction state
			obstructionEntityMap[entName] = v

			self:_Log( string.format( "Found obstruction %q : %s", entName, tostring(v:IsEnabled()) ) )

			-- Make temporarily enable the obstruction for generating maps
			if not v:IsEnabled() then
				table.insert( vObstructionDisabledByDefault, v )
				v:SetEnabled( true, true --[[ what's this? ]] )
			end
		end
	end

	return obstructionEntityMap
end

--------------------------------------------------------------------------------
function GridNavMap:_CollectAllTraversables()
	local traversables = {}			-- Traversable name : TRUE
	local traversablePosMap = {}	-- Traversable name : [ worldPos_1, worldPos_2 ]
	local traversableInfoMap = {}	-- Traversable name : [ gridIndex_1, gridIndex_2 ]

	-- List all traversables
	for _,v in pairs(self._vDynamicObstructions) do
		traversables[v] = true
		traversablePosMap[v] = {}
		traversableInfoMap[v] = {}
	end

	-- Find all traversables in the map
	for _,v in pairs(Entities:FindAllByClassname( "path_corner" )) do

		local entName = v:GetName()		-- e.g. traversable_boss_entrance_1 or 2

		if entName and #entName > 2 then
			local traversableName = string.sub( entName, 1, #entName - 2 )
			local traversableIndex = tonumber( string.sub( entName, -1 ) )

			if traversables[traversableName] then
				-- Valid traversable
				local gridIdx = self:WorldPosToIndex( v:GetAbsOrigin() )
				traversablePosMap[traversableName][traversableIndex] = v:GetAbsOrigin()
				traversableInfoMap[traversableName][traversableIndex] = gridIdx

				self:_Log( string.format( "Found traversable %d of %q", traversableIndex, traversableName ) )
			end
		end
	end

	-- Calculate cost between pair of traversable
	for k,v in pairs(traversablePosMap) do
		local dist = ( v[1] - v[2] ):Length2D()
		local cost = self:WorldUnitToCost( dist )

		traversableInfoMap[k][3] = cost

		self:_Log( string.format( "Cost between pair of %q : %d", k, cost ) )
	end

	return traversableInfoMap
end

--------------------------------------------------------------------------------
-- Map generators
--------------------------------------------------------------------------------
function GridNavMap:_GenerateBlockedMap()

	self:_Log( "Generating blocked map..." )

	local map = {}

	self:_ForEachGrid( function ( index, x, y )

		local worldPosX = GridNav:GridPosToWorldCenterX( x )
		local worldPosY = GridNav:GridPosToWorldCenterY( y )
		local worldPos = Vector( worldPosX, worldPosY, 0 )

		local isBlocked = not GridNav:IsTraversable( worldPos ) or GridNav:IsBlocked( worldPos )

		map[index] = isBlocked

	end )

	return map

end

--------------------------------------------------------------------------------
function GridNavMap:_GenerateCostAndPartitionMap( vBlocked, vTraversableIndexMap )

	self:_Log( "Generating cost map..." )

	local costMap = {}
	local partitionMap = {}
	local currentPartitionID = 1

	local graph = {}	-- edgeName (e.g. "1:2", "2:4") : corresponding traversable

	--------------------------------------------------------------------------------
	-- Flood fill func
	--------------------------------------------------------------------------------
	local funcFloodFill = function ( startX, startY, startCost )
		
		self:_Log( "FloodFill from ( " .. startX .. ", " .. startY .. " ) : cost = " .. startCost )

		local openQueue = PriorityQueue.new( function ( a, b )
			return a.cost < b.cost
		end )
		local openSet = {}
		local closed = costMap	-- key: gridIndex, value: cost

		local startNode = self:_CreateNode( startX, startY )
		startNode.cost = startCost

		openQueue:push( startNode )
		openSet[startNode.index] = true

		local costMax = 0
		local nOpen = 0

		while not openQueue:empty() do

			local currentNode = openQueue:pop()
			openSet[currentNode.index] = nil

			closed[currentNode.index] = currentNode.cost
			partitionMap[currentNode.index] = currentPartitionID
			costMax = math.max( costMax, currentNode.cost )

			for _,neighborNode in pairs( self:_GetNeighborNodes( currentNode ) ) do
			--	print( "x: " .. neighborNode.x .. ", y: " .. neighborNode.y .. ", idx : " .. neighborNode.index )

				if vBlocked[neighborNode.index] == false then
					if openSet[neighborNode.index] == nil and closed[neighborNode.index] == nil then
						-- Mark as open
						neighborNode.cost = neighborNode.cost + currentNode.cost

						openQueue:push( neighborNode )
						openSet[neighborNode.index] = true
					end
				end
			end

		end

		-- Update map distance
		self.flMapDistance = math.max( self:CostToWorldUnit( costMax ), self.flMapDistance or 0 )

		currentPartitionID = currentPartitionID + 1

	end

	--------------------------------------------------------------------------------
	-- Generate cost and partition map

	-- 1st pass
	funcFloodFill( self.startX, self.startY, 0 )

	-- Nth pass
	local nTraversables = 0
	for k,v in pairs(vTraversableIndexMap) do
		nTraversables = nTraversables + 1
	end

	local nTraversablesLastPass = 999999

	while nTraversables > 0 and nTraversables ~= nTraversablesLastPass do

		nTraversablesLastPass = nTraversables

		for k,v in pairs(vTraversableIndexMap) do

			local bFilled_1 = costMap[v[1]] ~= nil
			local bFilled_2 = costMap[v[2]] ~= nil

			if bFilled_1 ~= bFilled_2 then

				local filledIdx, notFilledIdx
				if bFilled_1 then
					filledIdx		= v[1]
					notFilledIdx	= v[2]
				else
					filledIdx		= v[2]
					notFilledIdx	= v[1]
				end

				-- Do floodfill
				local costBetweenTraversables = v[3]
				local startCost = costMap[filledIdx] + costBetweenTraversables
				local gridX, gridY = self:_IndexToGridPos( notFilledIdx )

				funcFloodFill( gridX, gridY, startCost )

				-- Update graph
				local edgeName = string.format( "%d:%d", partitionMap[filledIdx], partitionMap[notFilledIdx] )
				graph[edgeName] = k

				self:_Log( string.format( "Edge %q => %q", edgeName, k ) )

				-- Remove
				vTraversableIndexMap[k] = nil
				nTraversables = nTraversables - 1

			end

		end

	end

	-- Well...
	self.vPartitionGraph = graph

	return costMap, partitionMap

end

--------------------------------------------------------------------------------
function GridNavMap:_GeneratePoolIDMap( vCost, bNoLevelFlow )

	self:_Log( "Generating pool map..." )

	local poolIDMap = {}
	local poolEntAry = {}

	-- Collect pool entities in the map
	for _,v in pairs(Entities:FindAllByClassname( "info_target" )) do
		local entName = v:GetName()
		if string.find( entName, "monster_pool_" ) == 1 then
			local poolPos = v:GetAbsOrigin()
			local gridIndex = self:WorldPosToIndex( poolPos )

			local gridPosX = GridNav:WorldToGridPosX( poolPos.x )
			local gridPosY = GridNav:WorldToGridPosY( poolPos.y )

			table.insert( poolEntAry, {
				name = entName,
				["x"] = GridNav:WorldToGridPosX( poolPos.x ),
				["y"] = GridNav:WorldToGridPosY( poolPos.y ),
				["index"] = gridIndex,
				cost = vCost[gridIndex]
			} )

			self:_Log( "Added monster pool :" )
			self:_Log( "  Name : " .. entName )
			self:_Log( "  Cost : " .. vCost[gridIndex] )
		end
	end

	if not bNoLevelFlow then

		--------------------------------------------------------------------------------
		-- Level has a flow

		-- Cost to poolID
		local costToPoolID = function ( cost )
			local lastID = 0
			for id, poolEntInfo in ipairs( poolEntAry ) do
				if cost < poolEntInfo.cost then
					break
				end
				lastID = id
			end
			return math.max( lastID, 1 )
		end

		-- Generate poolID map
		self:_ForEachGrid( function ( index, x, y )
			if vCost[index] == nil then
				return
			end
			if vCost[index] < self.safeArea then
				return
			end

			poolIDMap[index] = costToPoolID( vCost[index] )
		end )

	else

		--------------------------------------------------------------------------------
		-- Level has no flow

		-- Flood fill from all seeds
		local openQueue = PriorityQueue.new( function ( a, b )
			return a.cost < b.cost
		end )
		local openSet = {}
		local closed = {}	-- GridIndex : PoolID

		-- Put all seeds
		for poolID, poolData in ipairs( poolEntAry ) do

			local gridIndex = poolData.index
			local gridNode = self:_CreateNode( poolData.x, poolData.y, gridIndex )
			gridNode.poolID = poolID
			gridNode.cost = 0

			openQueue:push( gridNode )
			openSet[gridIndex] = true

		end

		while not openQueue:empty() do

			local currentNode		= openQueue:pop()
			local currentGridIndex	= currentNode.index
			openSet[currentGridIndex] = nil

			closed[currentGridIndex] = currentNode.poolID

			-- Collect neighbour nodes
			for _,neighbourNode in pairs( self:_GetNeighborNodes( currentNode ) ) do
				local neighbourGridIndex = neighbourNode.index
				if self.vBlocked[neighbourGridIndex] == false then
					if openSet[neighbourGridIndex] == nil and closed[neighbourGridIndex] == nil then
						-- Add to open queue
						neighbourNode.poolID	= currentNode.poolID
						neighbourNode.cost		= neighbourNode.cost + currentNode.cost

						openQueue:push( neighbourNode )
						openSet[neighbourGridIndex] = true
					end
				end
			end
		end

		poolIDMap = closed

	end

	-- Create PoolID to PoolName
	local vPoolNameMap = {}
	for id, poolEntInfo in ipairs( poolEntAry ) do
		vPoolNameMap[id] = poolEntInfo.name
	end
	self.vPoolNameMap = vPoolNameMap

	return poolIDMap

end

--------------------------------------------------------------------------------
function GridNavMap:_GeneratePopulationMap( vCost )

	self:_Log( "Generating population map..." )

	local populationMap = {}
	local scale = 0.125
	local seed = RandomInt( 100, 33333 )

	self:_ForEachGrid( function ( index, x, y )
		if vCost[index] == nil then
			return
		end
		if vCost[index] < self.safeArea then
			return
		end

		local population = PerlinNoise2D( x * scale, y * scale, seed ) / 1.5 / 2 + 0.5
		population = invlerp( 7/16, 11/16, population )
		population = saturate( population )
		populationMap[index] = population
	end )

	return populationMap

end

--------------------------------------------------------------------------------
function GridNavMap:_GenerateProbabilityTree( vPopulation )

	self:_Log( "Generating probability tree..." )

	local tree = ProbabilityQuadtree( self.gridMinX, self.gridMinY, self.gridWidth, self.gridHeight )

	self:_ForEachGrid( function ( index, x, y )
		if vPopulation[index] == nil then
			return
		end

		tree:Insert( x, y, vPopulation[index] )
	end )

	return tree

end

--------------------------------------------------------------------------------
-- Map writers
--------------------------------------------------------------------------------
function GridNavMap:_SaveBlockedMapToFile()
	self:_SaveMapToFile( "blockedArea", self.vBlocked, function ( isBlocked )
		local pixelVal = ( isBlocked and 255 or 0 )
		return string.format( "%d %d %d", pixelVal, pixelVal, pixelVal )
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SaveCostMapToFile()
	self:_SaveMapToFile( "cost", self.vCost, function ( cost )
		if cost ~= nil then
			local v = math.fmod( cost, 75 ) / 75
			local r = lerp( 0.424, 1, v ) * 255
			local g = lerp( 1, 0.014, v ) * 255
			return string.format( "%d %d 0", math.floor(r), math.floor(g) )
		else
			return "0 0 0"
		end
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SavePartitionMapToFile()
	-- https://github.com/davidmerfield/randomColor
	local randomColorMap = {
		"237 137 145",	"150 111 255",	"108 224 160",
		"142 247 244",	"92 185 254",	"177 221 64",
		"247 240 67",	"245 134 101",	"236 191 65",	-- 9
		"180 239 255",	"0 192 78",		"73 162 187",
		"191 105 222",	"44 213 100",	"241 154 117",
		"221 44 218",	"0 110 218",	"96 217 90",	-- 18
	}

	self:_SaveMapToFile( "partition", self.vPartition, function ( partitionID )
		if partitionID ~= nil then
			return randomColorMap[partitionID] or "255 255 255"
		else
			return "0 0 0"
		end
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SavePoolIDMapToFile()
	-- https://github.com/davidmerfield/randomColor
	local randomColorMap = {
		"237 137 145",	"150 111 255",	"108 224 160",
		"142 247 244",	"92 185 254",	"177 221 64",
		"247 240 67",	"245 134 101",	"236 191 65",	-- 9
		"180 239 255",	"0 192 78",		"73 162 187",
		"191 105 222",	"44 213 100",	"241 154 117",
		"221 44 218",	"0 110 218",	"96 217 90",	-- 18
	}

	self:_SaveMapToFile( "poolID", self.vPoolID, function ( poolID )
		if poolID ~= nil then
			return randomColorMap[poolID] or "255 255 255"
		else
			return "0 0 0"
		end
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SavePopulationMapToFile()
	self:_SaveMapToFile( "population", self.vPopulation, function ( population )
		if population ~= nil then
			local r = lerp( 1, 0  , population ) * 255
			local g = lerp( 1, 0.3, population ) * 255
			local b = lerp( 1, 0.6, population ) * 255
			return string.format( "%d %d %d", math.floor(r), math.floor(g), math.floor(b) )
		else
			--return "0 0 0"
			return "255 255 255"
		end
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SaveEnemiesMapToFile( numEnemies )
	numEnemies = numEnemies or 100
	local vEnemies = {}
	for i=1, numEnemies do
		local x, y = self.probabilityTree:ChooseRandom()
		local index = self:_GridPosToIndex( x, y )
		vEnemies[index] = 1
		vEnemies[index-1] = 1
		vEnemies[index+1] = 1
		vEnemies[index-self.gridWidth] = 1
		vEnemies[index+self.gridWidth] = 1
	end

	self:_SaveMapToFile( "enemies" .. numEnemies, self.vPopulation, function ( population, index )
		if vEnemies[index] then
			return "255 0 0"
		elseif population ~= nil then
			local r = lerp( 1, 0  , population ) * 255
			local g = lerp( 1, 0.3, population ) * 255
			local b = lerp( 1, 0.6, population ) * 255
			return string.format( "%d %d %d", math.floor(r), math.floor(g), math.floor(b) )
		else
			--return "0 0 0"
			return "255 255 255"
		end
	end )
end

--------------------------------------------------------------------------------
function GridNavMap:_SaveMapToFileAll()
	self:_SaveBlockedMapToFile()
	self:_SaveCostMapToFile()
	self:_SavePartitionMapToFile()
	self:_SavePoolIDMapToFile()
	self:_SavePopulationMapToFile()
	self:_SaveEnemiesMapToFile( 100 )
	self:_SaveEnemiesMapToFile( 200 )
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------
function GridNavMap:_ForEachGrid( func --[[ index, gridPosX, gridPosY ]] )
	for j=self.gridMaxY, self.gridMinY, -1 do
		for i=self.gridMinX, self.gridMaxX do
			func( self:_GridPosToIndex( i, j ), i, j )
		end
	end
end

function GridNavMap:_GridPosToIndex( gridPosX, gridPosY )
	local texelPosX = gridPosX - self.gridMinX
	local texelPosY = gridPosY - self.gridMinY
	return texelPosX + texelPosY * self.gridWidth + 1
end

function GridNavMap:_IndexToGridPos( index )
	index = index - 1
	local gridPosX = index % self.gridWidth + self.gridMinX
	local gridPosY = math.floor( index / self.gridWidth ) + self.gridMinY
	return gridPosX, gridPosY
end

function GridNavMap:WorldPosToIndex( worldPos )
	local gridPosX = GridNav:WorldToGridPosX( worldPos.x )
	local gridPosY = GridNav:WorldToGridPosY( worldPos.y )
	return self:_GridPosToIndex( gridPosX, gridPosY )
end

function GridNavMap:_CreateNode( x, y, index )
	local node = {
		["x"] = x,
		["y"] = y,
		["index"] = index or self:_GridPosToIndex( x, y )
	}
	return node
end

function GridNavMap:_GetNeighborNodes( node )
	-- { x, y, index, cost }
	local offsets = {
	--	{ -1,  1, -1 + self.gridWidth, 1.414 },	-- NW
		{  0,  1,  0 + self.gridWidth, 1 },		-- N
	--	{  1,  1,  1 + self.gridWidth, 1.414 },	-- NE
		{ -1,  0, -1, 1 },						-- W
		{  1,  0,  1, 1 },						-- E
	--	{ -1, -1, -1 - self.gridWidth, 1.414 },	-- SW
		{  0, -1,  0 - self.gridWidth, 1 },		-- S
	--	{  1, -1,  1 - self.gridWidth, 1.414 },	-- SE
	}

	local neighborNodes = {}

	for _,v in pairs(offsets) do
		if not self:_IsOutOfBound( node.x + v[1], node.y + v[2] ) then

			local neighborNode = self:_CreateNode( node.x + v[1], node.y + v[2], node.index + v[3] )
			neighborNode.cost = v[4]
			
			table.insert( neighborNodes, neighborNode )

		end
	end

	return neighborNodes
end

function GridNavMap:_IsOutOfBound( x, y )
	if x < self.gridMinX then return true end
	if x > self.gridMaxX then return true end
	if y < self.gridMinY then return true end
	if y > self.gridMaxY then return true end
	return false
end

--------------------------------------------------------------------------------
-- IO
--------------------------------------------------------------------------------
function GridNavMap:_Log( text )
	print( "[GridNavMap] " .. text )
end

function GridNavMap:_SaveImageDataToFile( imageType, data )
	-- Generate timestamp
	local timestamp = GetSystemDate() .. "-" .. GetSystemTime()
	timestamp = timestamp:gsub(":",""):gsub("/","")

	-- Generate file name
	local fileName = "addons/dotahs/gridnav_" .. GetMapName() .. "_" .. imageType .. "_" .. timestamp .. ".ppm"

	-- Write to the file
	InitLogFile( fileName, "" )
	AppendToLogFile( fileName, data )

	self:_Log( "Wrote image to " .. fileName )
end

function GridNavMap:_SaveMapToFile( imageType, map, valueToColorTextFunc )
	-- Header
	local ppm = { "P3 " .. self.gridWidth .. " " .. self.gridHeight .. " 255\n\n" }

	-- Generate pixel data
	self:_ForEachGrid( function ( index )
		ppm[#ppm+1] = valueToColorTextFunc( map[index], index )
	end)

	-- Write
	self:_SaveImageDataToFile( imageType, table.concat( ppm, " " ) )
end





--------------------------------------------------------------------------------
--
-- ProbabilityQuadtree
--
--------------------------------------------------------------------------------

local _intersect = function( ax1, ay1, aw, ah, bx1, by1, bw, bh )
	local ax2 = ax1 + aw
	local ay2 = ay1 + ah
	local bx2 = bx1 + bw
	local by2 = by1 + bh

	return ax1 < bx2 and ax2 > bx1 and ay1 < by2 and ay2 > by1
end 

--------------------------------------------------------------------------------

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
		local selected = DotaHS_RandomFromWeights( self.children, function ( k, v )
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
--
-- GridNavClusterMap
-- 
-- A HIGH-LEVEL grid map.
-- This class is used for spawning enemies from all players current position.
-- Cluster-based algorithm may improve the performance of finding positions to spawn.
--
--------------------------------------------------------------------------------

local CLUSTER_DIM = 16	-- This value is the dimension of the cluster

--------------------------------------------------------------------------------
-- Generate
--------------------------------------------------------------------------------
function GridNavClusterMap:PreInitialize( gridNavMap )

	profile_begin( "GridNavClusterMap:PreInitialize" )

	self.gridNavMap = gridNavMap
	self.numClustersX = math.ceil( gridNavMap.gridWidth  / CLUSTER_DIM )
	self.numClustersY = math.ceil( gridNavMap.gridHeight / CLUSTER_DIM )

	self:_Log( "Initializing ClusterMap..." )
	self:_Log( "  NumClusters = ( " .. self.numClustersX .. ", " .. self.numClustersY .. " )" )

	self.vClusterMap = {}
	self.vRegionMap = {}

	--------------------------------------------------------------------------------
	-- 1st-pass

	local nextGlobalRegionID = 1
	for y=0, self.numClustersY-1 do
		for x=0, self.numClustersX-1 do

			-- Append a new cluster to the cluster map
			local cluster = GridNavCluster( x, y, gridNavMap )
			self.vClusterMap[self:ClusterPosToClusterIndex(x,y)] = cluster

			-- Generate cluster regions
			nextGlobalRegionID = cluster:GenerateClusterRegions( nextGlobalRegionID )

		end
	end

	self:_Log( "  NumRegions = " .. ( nextGlobalRegionID - 1 ) )

	--------------------------------------------------------------------------------
	-- 2nd-pass

	local totalConnections = 0
	for y=0, self.numClustersY-1 do
		for x=0, self.numClustersX-1 do

			local cluster = self:GetClusterAt( x, y )

			for _,v in ipairs(cluster.vRegions) do
				self.vRegionMap[v.globalID] = v
			end

			totalConnections = totalConnections + cluster:UpdateConnections( self )

		end
	end

	self:_Log( "  NumConnections = " .. totalConnections )

	profile_end()

end

--------------------------------------------------------------------------------
function GridNavClusterMap:FindCandidateRegions( vAllPlayersPos, distance )

--	if #vAllPlayersPos == 0 then
--		self:_Log( "Couldn't find candidate regions : No players available" )
--	end

	local openQueue = PriorityQueue.new( function ( a, b )
		return a.cost < b.cost
	end )
	local openSet = {}
	local closed = {}
	local candidateRegions = {}
	local numSearched = 0

	-- Seeds
	for playerID,pos in pairs(vAllPlayersPos) do
		local regionID = self:WorldPosToRegionID( pos )
		if openSet[regionID] == nil then
			openQueue:push( {
				["regionID"] = regionID,
				["cost"] = 0,
				["playerID"] = playerID,
			} )
			openSet[regionID] = true
		end
	end

	while not openQueue:empty() do

		local currentRegionData	= openQueue:pop()
		local currentRegionID	= currentRegionData.regionID
		local currentRegion		= self:GetRegion( currentRegionID )
		openSet[currentRegionID] = nil

		if currentRegionData.cost > distance then
			break
		elseif currentRegionData.cost == distance then
			table.insert( candidateRegions, {
				["region"]			= currentRegion,
				["nearestPlayerID"]	= currentRegionData.playerID,
			} )
		end

		closed[currentRegionID] = currentRegionData.cost
		numSearched = numSearched + 1

		-- Collect neighbour nodes
		for k,_ in pairs(currentRegion.neighbourRegions) do
			if closed[k] == nil and openSet[k] == nil then
				-- Add to open nodes
				openQueue:push( {
					["regionID"]	= k,
					["cost"]		= currentRegionData.cost + 1,
					["playerID"]	= currentRegionData.playerID,
				} )
				openSet[k] = true
			end
		end

	end

	self:_Log( "Searched regions: " .. numSearched )
	self:_Log( "Found candidate regions: " .. #candidateRegions )

	return candidateRegions

end

--------------------------------------------------------------------------------
function GridNavClusterMap:ClusterPosToClusterIndex( x, y )
	return x + y*self.numClustersX + 1
end

--------------------------------------------------------------------------------
function GridNavClusterMap:GetClusterAt( x, y )
	return self.vClusterMap[ self:ClusterPosToClusterIndex( x, y ) ]
end

--------------------------------------------------------------------------------
function GridNavClusterMap:GetRegion( globalID )
	return self.vRegionMap[ globalID ]
end

--------------------------------------------------------------------------------
function GridNavClusterMap:WorldPosToRegionID( worldPos )
	local gridPosX = GridNav:WorldToGridPosX( worldPos.x )
	local gridPosY = GridNav:WorldToGridPosY( worldPos.y )
	local globalCellPosX = gridPosX - self.gridNavMap.gridMinX
	local globalCellPosY = gridPosY - self.gridNavMap.gridMinY
	local clusterX = math.floor( globalCellPosX / CLUSTER_DIM )
	local clusterY = math.floor( globalCellPosY / CLUSTER_DIM )
	local localCellPosX = globalCellPosX - clusterX * CLUSTER_DIM
	local localCellPosY = globalCellPosY - clusterY * CLUSTER_DIM

	local cluster = self:GetClusterAt( clusterX, clusterY )
	return cluster:GetGlobalRegionIDAt( localCellPosX, localCellPosY )
end

--------------------------------------------------------------------------------
function GridNavClusterMap:_Log( text )
	print( "[GridNavClusterMap] " .. text )
end





--------------------------------------------------------------------------------
--
-- GridNavCluster
--
--------------------------------------------------------------------------------

function GridNavCluster:new( clusterX, clusterY, gridNavMap )
	local o = {}
	setmetatable( o, { __index = GridNavCluster } )
	o:__init( clusterX, clusterY, gridNavMap )
	return o
end

setmetatable( GridNavCluster, { __call = GridNavCluster.new } )

--------------------------------------------------------------------------------
function GridNavCluster:__init( clusterX, clusterY, gridNavMap )
	self.x = clusterX
	self.y = clusterY
	self.gridNavMap = gridNavMap
end

--------------------------------------------------------------------------------
function GridNavCluster:GenerateClusterRegions( nextGlobalRegionID )
	
--	print( "[GridNavCluster] Generating cluster regions... x: " .. self.x .. ", y: " .. self.y )

	local labelTable = {}	-- Label ID : ClusterRegionLabel
	local labelMap = {}		-- Cell Index : Label ID

	--------------------------------------------------------------------------------
	-- 1st-pass

	local nextLabelID = 1	-- Initial label
	self:_ForEachCell( function ( index, u, v )

		if not self:_IsWalkable( u, v ) then return end

		-- Find label for neighbours (0 if out of range)
		local labelN = (v>0) and labelMap[index - CLUSTER_DIM] or 0
		local labelW = (u>0) and labelMap[index - 1] or 0

		if labelN == 0 and labelW == 0 then

			-- Neighbours is empty
			labelTable[nextLabelID] = ClusterRegionLabel( nextLabelID )
			labelTable[nextLabelID]:IncrementMass()
			labelMap[index] = nextLabelID
			nextLabelID = nextLabelID + 1

		else

			local L = {}
			if labelN > 0 then table.insert( L, labelN ) end
			if labelW > 0 then table.insert( L, labelW ) end
			table.sort( L )

			local currentLabelID = labelTable[L[1]]:GetRoot().ID
			local root = labelTable[currentLabelID]:GetRoot()
			root:IncrementMass()
			labelMap[index] = currentLabelID

			for _,v in pairs(L) do
				if root.ID ~= labelTable[v]:GetRoot().ID then
					labelTable[v]:Join( labelTable[currentLabelID] )
				end
			end
		end

	end )

	-- Sort labels by Mass
	local labelIDToMassMap = {}		-- Label ID : Mass
	for _,v in ipairs(labelTable) do
		local rootID = v:GetRoot().ID
		labelIDToMassMap[rootID] = ( labelIDToMassMap[rootID] or 0 ) + v.mass
	end

	local rootIDAry = {}
	for k,_ in pairs(labelIDToMassMap) do
		table.insert( rootIDAry, k )
	end
	table.sort( rootIDAry, function ( a, b )
		return labelIDToMassMap[a] > labelIDToMassMap[b]
	end )

	-- Create regions
	local regions = {}			-- Local Region ID : ClusterRegion
	local rootIDToRegionID = {}	-- Root ID : Local Region ID
	for k,v in ipairs(rootIDAry) do
		table.insert( regions, ClusterRegion( nextGlobalRegionID + k-1, k, labelIDToMassMap[v] ) )
		rootIDToRegionID[v] = k
	end

	--------------------------------------------------------------------------------
	-- Final-pass

	local globalRegionIDMap = {}	-- Cell Index : Global Region ID

	self:_ForEachCell( function ( index, u, v )
		
		if not self:_IsWalkable( u, v ) then return end

		local oldRegionID = labelMap[index]
		oldRegionID = labelTable[oldRegionID]:GetRoot().ID
		local localRegionID = rootIDToRegionID[oldRegionID]

		local region = regions[localRegionID]
		table.insert( region.cells, self:LocalPosToGlobalIndex( u, v ) )
		globalRegionIDMap[index] = region.globalID

	end )

	self.vRegions = regions
	self.vGlobalRegionIDMap = globalRegionIDMap

	return nextGlobalRegionID + #regions

end

--------------------------------------------------------------------------------
function GridNavCluster:UpdateConnections( clusterMap )
	
	local numConnections = 0

	-- North
	if self.y > 0 then
		local clusterB = clusterMap:GetClusterAt( self.x, self.y - 1 )
		for u=0, CLUSTER_DIM-1 do
			local isWalkableA = self:_IsWalkable( u, 0 )
			local isWalkableB = clusterB:_IsWalkable( u, CLUSTER_DIM-1 )

			if isWalkableA and isWalkableB then
				local indexA = self:LocalPosToLocalIndex( u, 0 )
				local indexB = clusterB:LocalPosToLocalIndex( u, CLUSTER_DIM-1 )
				local regionA = clusterMap:GetRegion( self.vGlobalRegionIDMap[indexA] )
				local regionB = clusterMap:GetRegion( clusterB.vGlobalRegionIDMap[indexB] )

				if regionA.neighbourRegions[regionB.globalID] == nil then
					-- Add a connection
					regionA.neighbourRegions[regionB.globalID] = true
					regionB.neighbourRegions[regionA.globalID] = true

					numConnections = numConnections + 1
				end
			end
		end
	end

	-- West
	if self.x > 0 then
		local clusterB = clusterMap:GetClusterAt( self.x - 1, self.y  )
		for v=0, CLUSTER_DIM-1 do
			local isWalkableA = self:_IsWalkable( 0, v )
			local isWalkableB = clusterB:_IsWalkable( CLUSTER_DIM-1, v )

			if isWalkableA and isWalkableB then
				local indexA = self:LocalPosToLocalIndex( 0, v )
				local indexB = clusterB:LocalPosToLocalIndex( CLUSTER_DIM-1, v )
				local regionA = clusterMap:GetRegion( self.vGlobalRegionIDMap[indexA] )
				local regionB = clusterMap:GetRegion( clusterB.vGlobalRegionIDMap[indexB] )

				if regionA.neighbourRegions[regionB.globalID] == nil then
					-- Add a connection
					regionA.neighbourRegions[regionB.globalID] = true
					regionB.neighbourRegions[regionA.globalID] = true

					numConnections = numConnections + 1
				end
			end
		end
	end

	return numConnections

end

--------------------------------------------------------------------------------
function GridNavCluster:LocalPosToLocalIndex( u, v )
	return u + v*CLUSTER_DIM + 1
end

--------------------------------------------------------------------------------
function GridNavCluster:LocalPosToGlobalIndex( u, v )
	local cellPosX = self.x * CLUSTER_DIM + u
	local cellPosY = self.y * CLUSTER_DIM + v
	return cellPosX + cellPosY * self.gridNavMap.gridWidth + 1
end

--------------------------------------------------------------------------------
function GridNavCluster:GetGlobalRegionIDAt( u, v )
	return self.vGlobalRegionIDMap[self:LocalPosToLocalIndex( u, v )]
end

--------------------------------------------------------------------------------
function GridNavCluster:_IsWalkable( u, v )
	return self.gridNavMap.vCost[self:LocalPosToGlobalIndex(u,v)] ~= nil
end

--------------------------------------------------------------------------------
function GridNavCluster:_ForEachCell( func --[[ index, u, v ]] )
	for v=0, CLUSTER_DIM-1 do
		for u=0, CLUSTER_DIM-1 do
			local index = self:LocalPosToLocalIndex( u, v )
			func( index, u, v )
		end
	end
end





--------------------------------------------------------------------------------
--
-- ClusterRegion
--
--------------------------------------------------------------------------------

function ClusterRegion:new( globalID, localID, numCells )
	local o = {}
	setmetatable( o, { __index = ClusterRegion } )
	o:__init( globalID, localID, numCells )
	return o
end

setmetatable( ClusterRegion, { __call = ClusterRegion.new } )

--------------------------------------------------------------------------------
function ClusterRegion:__init( globalID, localID, numCells )
	self.globalID	= globalID
	self.localID	= localID
	self.numCells	= numCells
	self.cells		= {}	-- Cell ID in the Cluster
	self.neighbourRegions = {}

--	print( "[GridNavClusterRegion] GlobalID: " .. globalID .. ", LocalID: " .. localID .. ", NumCells: " .. numCells )
end





--------------------------------------------------------------------------------
--
-- ClusterRegionLabel
--
--------------------------------------------------------------------------------

function ClusterRegionLabel:new( ID )
	local o = {}
	setmetatable( o, { __index = ClusterRegionLabel } )
	o:__init( ID )
	return o
end

setmetatable( ClusterRegionLabel, { __call = ClusterRegionLabel.new } )

--------------------------------------------------------------------------------
function ClusterRegionLabel:__init( ID )
	self.ID = ID
	self.root = self
	self.rank = 0
	self.mass = 0
end

--------------------------------------------------------------------------------
function ClusterRegionLabel:GetRoot()
	if self.root ~= self then
		self.root = self.root:GetRoot()
	end
	return self.root
end

--------------------------------------------------------------------------------
function ClusterRegionLabel:IncrementMass()
	self.mass = self.mass + 1
end

--------------------------------------------------------------------------------
function ClusterRegionLabel:Join( label2 )
	if label2.rank < self.rank then
		label2.root = self
	else
		self.root = label2
		if self.rank == label2.rank then
			label2.rank = label2.rank + 1
		end
	end
end





--------------------------------------------------------------------------------
--
-- PriorityQueue
--
-- This class is just QUEUE. It work for this gamemode.
--
--------------------------------------------------------------------------------

function PriorityQueue.new( cmp )
	local o = {}
	setmetatable( o, { __index = PriorityQueue } )
	o:__init( cmp )
	return o
end

function PriorityQueue:__init( cmp )
	self._cmp	= cmp or function( a, b ) return a < b end
	self._queue = {}
end

function PriorityQueue:push( v )
	table.insert( self._queue, v )
--	table.sort( self._queue, self._cmp )	-- CAREFUL!!!
end

function PriorityQueue:pop()
	return table.remove( self._queue, 1 )
end

function PriorityQueue:peek()
	return self._queue[1]
end

function PriorityQueue:empty()
	return #self._queue == 0
end
