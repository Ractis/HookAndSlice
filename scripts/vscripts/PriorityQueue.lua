
PriorityQueue = {}

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
	table.sort( self._queue, self._cmp )
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
