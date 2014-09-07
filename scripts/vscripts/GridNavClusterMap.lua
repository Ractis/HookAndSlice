
--
-- GridNavClusterMap
-- 
-- A HIGH-LEVEL grid map.
-- This class is used for spawning enemies from all players current position.
-- Cluster-based algorithm may improve the performance of finding positions to spawn.
--

require( "PriorityQueue" )
require( "Profiler" )

--------------------------------------------------------------------------------
if GridNavClusterMap == nil then
	GridNavClusterMap = class({})
end

--------------------------------------------------------------------------------
local CLUSTER_DIM = 16	-- This value is the dimension of the cluster

--------------------------------------------------------------------------------
-- Generate
--------------------------------------------------------------------------------
function GridNavClusterMap:Initialize( gridNavMap )

	profile_begin( "GridNavClusterMap:Initialize" )

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
-- GridNavCluster
--------------------------------------------------------------------------------
GridNavCluster = {}

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
-- ClusterRegion
--------------------------------------------------------------------------------
ClusterRegion = {}

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
-- ClusterRegionLabel
--------------------------------------------------------------------------------
ClusterRegionLabel = {}

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
