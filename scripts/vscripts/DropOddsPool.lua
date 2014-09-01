
--------------------------------------------------------------------------------
DropOddsPool = {}

function DropOddsPool:new( kvFileName )
	local o = {}
	setmetatable( o, { __index = DropOddsPool } )
	o:__init( kvFileName )
	return o
end

setmetatable( DropOddsPool, { __call = DropOddsPool.new } )

--------------------------------------------------------------------------------
function DropOddsPool:__init( kvFileName )
	
	self._name = kvFileName

	-- Load the file
	print( "Generating drop odds pool from " .. kvFileName )

	local filePath = "scripts/pools/" .. kvFileName .. ".txt"
	local kv = LoadKeyValues( filePath )
	if kv == nil then
		print( "  Couldn't load KV file : " .. filePath )
		return
	end

	self._pool = kv

	-- Number of items
	local n = 0
	for k,v in pairs( self._pool ) do
		n = n + 1
	end
	self._numItems = n

	print( "  Num items : " .. self._numItems )

end

--------------------------------------------------------------------------------
function DropOddsPool:ItemPoolsForDrop()
	
	local itemPools = {}

	for k,v in pairs(self._pool) do
		if v.Chance == nil then
			print( k .. " has no drop chance." )
		end

		if RollPercentage( v.Chance ) then
			table.insert( itemPools, k )
		end
	end

	return itemPools

end

--------------------------------------------------------------------------------
function DropOddsPool:DumpProbabilities( nSamples )
	
	nSamples = nSamples or 10000

	print( "Probabilities ( samples = " .. nSamples .. " ) :" )

	local counts = {}

	for k,v in pairs(self._pool) do
		counts[k] = 0
	end

	for i=1, nSamples do
		local itemPools = self:ItemPoolsForDrop()
		for _,v in pairs(itemPools) do
			counts[v] = counts[v] + 1
		end
	end

	for k,v in pairs(counts) do
		print( "  " .. k .. " : " .. v / nSamples * 100 .. "%" )
	end

end
