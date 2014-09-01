
require( "Math" )
require( "Util_WeightTable" )

--------------------------------------------------------------------------------
DynamicWeightPool = {}

function DynamicWeightPool:new( kvFileName )
	local o = {}
	setmetatable( o, { __index = DynamicWeightPool } )
	o:__init( kvFileName )
	return o
end

setmetatable( DynamicWeightPool, { __call = DynamicWeightPool.new } )

--------------------------------------------------------------------------------
function DynamicWeightPool:__init( kvFileName )

	self._name = kvFileName

	-- Load the file
	print( "Generating weight pool from " .. kvFileName )

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
function DynamicWeightPool:ChooseRandom( currentLevel )
	
	local selected = RandomFromWeights( self._pool, function ( k, v )
		return self:_CalculateWeight( v, currentLevel )
	end)

	return selected, self._pool[selected]

end

--------------------------------------------------------------------------------
function DynamicWeightPool:DumpProbabilities( currentLevel, nSamples )

	nSamples = nSamples or 10000

	print( "Practical Probabilities ( level = " .. currentLevel .. ", samples = " .. nSamples .. " ) :" )

	local counts = {}

	for k,v in pairs(self._pool) do
		counts[k] = 0
	end

	for i=1, nSamples do
		local name, data = self:ChooseRandom( currentLevel )
		counts[name] = counts[name] + 1
	end

	for k,v in pairs(counts) do
		print( "  " .. k .. " : " .. v / nSamples * 100 .. "%" )
	end

end

--------------------------------------------------------------------------------
function DynamicWeightPool:_CalculateWeight( data, currentLevel )

	if currentLevel == nil then
		print( self._name .. " - CalculateWeight : CurrentLevel is nil" )
	end
	
	-- Base weight
	local baseWeight = data.Weight or 100

	-- Item level
	local itemLevel = data.Level
	if itemLevel == nil then
		if data.Cost == nil then
			return baseWeight
		end

		-- Calculate item level from cost
		itemLevel = math.ceil( data.Cost / 400 )	-- ~400g = Lv.1, ~800g = Lv.2 ...
	end

	--
	-- Current level = 10 :
	-- [10] [9] [8] [7] [6] [5] [4] [3] [2] [1] [0]
	--  100 100 100  80 ----------------------- 20
	--
	-- Current level = 5 :
	-- [5] [4] [3] [2] [1] [0]
	-- 100 100 100  80  50  20
	--
	local levelWeight
	if itemLevel > currentLevel then
		levelWeight = 0.0
	elseif itemLevel >= currentLevel - 2 then
		levelWeight = 1.0
	else
		levelWeight = lerp( 0.2, 0.8, itemLevel / ( currentLevel - 3 ) )
	end

--	print( "CurrentLevel = " .. currentLevel .. ", ItemLevel = " .. itemLevel )
--	print( "  Weight by Level = " .. levelWeight * 100 )

	return baseWeight * levelWeight

end
