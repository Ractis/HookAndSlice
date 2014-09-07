
require( "PriorityQueue" )
require( "Math" )
require( "PerlinNoise" )
require( "ProbabilityQuadtree" )
require( "GridNavClusterMap" )
require( "Profiler" )

--------------------------------------------------------------------------------
if GridNavMap == nil then
	GridNavMap = class({})
end

--------------------------------------------------------------------------------
-- Generate
--------------------------------------------------------------------------------
function GridNavMap:Initialize( kv )

	profile_begin( "GridNavMap:Initialize" )

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
	FireGameEvent( "dotarpg_map_info", {
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

	-- Generate maps
	self.vBlocked				= self:_GenerateBlockedMap()
	self.vCost, self.vPartition	= self:_GenerateCostAndPartitionMap( self.vBlocked, vTraversableIndexMap )
	self.vPoolID				= self:_GeneratePoolIDMap( self.vCost, kv.NoLevelFlow )
	self.vPopulation			= self:_GeneratePopulationMap( self.vCost )

	self.probabilityTree	= self:_GenerateProbabilityTree( self.vPopulation )

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

	-- Restore obstruction state
	for k,v in pairs( vObstructionDisabledByDefault ) do
		v:SetEnabled( false, true )
	end

	--
	-- Initialize GridNavCluster map
	--
	GridNavClusterMap:Initialize( self )

	-- Register Commands
	Convars:RegisterCommand( "dotarpg_save_gridnavmap_all",
	function ( ... )
	 	self:_SaveMapToFileAll()
	end, "Save all GridNavMaps", FCVAR_CHEAT )

	Convars:RegisterCommand( "dotarpg_save_map_poolid",
	function ( ... )
	 	self:_SavePoolIDMapToFile()
	end, "Save PoolID Map", FCVAR_CHEAT )

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
	local fileName = "addons/dotarpg/gridnav_" .. GetMapName() .. "_" .. imageType .. "_" .. timestamp .. ".ppm"

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
