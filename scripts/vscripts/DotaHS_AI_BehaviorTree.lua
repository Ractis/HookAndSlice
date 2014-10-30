
require( "DotaHS_Common" )

--------------------------------------------------------------------------------
-- BehaviorTree
--------------------------------------------------------------------------------

-- Behavior Status
BH_INVALID = 0
BH_SUCCESS = 1
BH_FAILURE = 2
BH_RUNNING = 3

BehaviorStatusColorMap = {
	[BH_INVALID] = { 255, 255, 255, 128 },
	[BH_SUCCESS] = { 128, 255, 128, 255 },
	[BH_FAILURE] = { 255, 128, 128, 255 },
	[BH_RUNNING] = { 255, 255, 128, 255 },
}

--------------------------------------------------------------------------------
BehaviorNode = class({})

function BehaviorNode:constructor( name )
	self.tag = "---"
	self.name = name
	self.description = ""
	self.prefix = nil	-- prefix of description
	self.status = BH_INVALID
	self.context = nil
end

function BehaviorNode:OnInitialize()
	-- override me
end

function BehaviorNode:OnTerminate( status )
	-- override me
end

function BehaviorNode:Execute()
	-- override me
	self:_Log( "Invalid BehaviorNode." )
end

function BehaviorNode:Tick()
	if self.status == BH_INVALID then
		self:OnInitialize()
	end

	self.status = self:Execute()

	if self.status ~= BH_RUNNING then
		self:OnTerminate( self.status )
	end

	return self.status
end

function BehaviorNode:Reset()
	self.status = BH_INVALID
end

function BehaviorNode:SetContext( context )
	self.context = context
end

function BehaviorNode:_Log( text )
	print( "[AI/BTree] \"" .. self.name .. "\" : " .. text )
end

--------------------------------------------------------------------------------
CompositeNode = class({}, nil, BehaviorNode)

function CompositeNode:constructor( name, children )
	BehaviorNode.constructor( self, name )
	self.children = children
end

function CompositeNode:AddChild( child )
	table.insert( self.children, child )
end

function CompositeNode:RemoveChild( child )
	for k,v in ipairs( self.children ) do
		if v == child then
			table.remove( self.children, k )
			break
		end
	end
end

function CompositeNode:Reset()
	BehaviorNode.Reset( self )
	for _,v in ipairs( self.children ) do
		v:Reset()
	end
end

function CompositeNode:SetContext( context )
	BehaviorNode.SetContext( self, context )
	for _,v in ipairs( self.children ) do
		v:SetContext( context )
	end
end

--------------------------------------------------------------------------------
SelectorNode = class({}, nil, CompositeNode)

function SelectorNode:constructor( name, children )
	CompositeNode.constructor( self, name, children )

	self.tag = "SEL"
end

function SelectorNode:OnInitialize()
	self.currentIndex = 1
end

function SelectorNode:Execute()
	if #self.children == 0 then
		self:_Log( "Has no children." )
		return BH_FAILURE
	end

	while true do
		local s = self.children[self.currentIndex]:Tick()

		-- If the child succeeds, or keep running, do the same.
		if s ~= BH_FAILURE then
			return s
		end

		-- Hit the end of the array, it didn't end well...
		self.currentIndex = self.currentIndex + 1
		if self.currentIndex > #self.children then
			return BH_FAILURE
		end
	end
end

--------------------------------------------------------------------------------
SequenceNode = class({}, nil, CompositeNode)

function SequenceNode:constructor( name, children )
	CompositeNode.constructor( self, name, children )

	self.tag = "SEQ"
end

function SequenceNode:OnInitialize()
	self.currentIndex = 1
end

function SequenceNode:Execute()
	if #self.children == 0 then
		self:_Log( "Has no children." )
		return BH_FAILURE
	end

	while true do
		local s = self.children[self.currentIndex]:Tick()

		-- If the child fails, or keep running, do the same.
		if s ~= BH_SUCCESS then
			return s
		end

		-- Hit the end of the array, job done!
		self.currentIndex = self.currentIndex + 1
		if self.currentIndex > #self.children then
			return BH_SUCCESS
		end
	end
end

--------------------------------------------------------------------------------
ParallelNode = class({}, nil, CompositeNode)

function ParallelNode:constructor( name, children )
	CompositeNode.constructor( self, name, children )

	self.tag = "PAR"

	self.requireAllToFailure = false
	self.requireAllToSuccess = true
end

function ParallelNode:OnInitialize()
	self.childrenRunning = {unpack(self.children)}
	self.numFailure = 0
	self.numSuccess = 0
end

function ParallelNode:Execute()
	if #self.childrenRunning == 0 then
		return BH_FAILURE
	end

	for k,v in ipairs( self.childrenRunning ) do
		local s = v:Tick()

		if s == BH_FAILURE then
			if not self.requireAllToFailure then
				return BH_FAILURE
			end
			self.numFailure = self.numFailure + 1
			table.remove( self.childrenRunning, k )
		end

		if s == BH_SUCCESS then
			if not self.requireAllToSuccess then
				return BH_SUCCESS
			end
			self.numSuccess = self.numSuccess + 1
			table.remove( self.childrenRunning, k )
		end
	end

	if self.requireAllToFailure and self.numFailure == #self.children then
		return BH_FAILURE
	end
	if self.requireAllToSuccess and self.numSuccess == #self.children then
		return BH_SUCCESS
	end

	return BH_RUNNING
end

--------------------------------------------------------------------------------
ProbabilitySelectorNode = class({}, nil, CompositeNode)

function ProbabilitySelectorNode:constructor( name, methodName, children )
	CompositeNode.constructor( self, name, children )

	self.tag = "PROB"

	self.methodName = methodName
end

function ProbabilitySelectorNode:OnInitialize()
	local weightTable = self.context[self.methodName]( self.context, #self.children )
	if #weightTable ~= #self.children then
		self:_Log( "Wrong num of weights. got " .. #weightTable .. " but " .. #self.children .. " expected." )
	end

	local selected = DotaHS_RandomFromWeights( weightTable )
	self.selectedNode = self.children[selected]

	self.description = "Selected : " .. selected
	for k,v in ipairs( self.children ) do
		v.prefix = tostring( weightTable[k] )
	end
end

function ProbabilitySelectorNode:Execute()
	return self.selectedNode:Tick()
end

--------------------------------------------------------------------------------
PrioritySelectorNode = class({}, nil, SelectorNode)

function PrioritySelectorNode:constructor( name, children )
	SelectorNode.constructor( self, name, children )

	self.tag = "PRIO"
end

function PrioritySelectorNode:Execute()
	local lastIndex = self.currentIndex

	-- Reset failed nodes
	for i=1, lastIndex-1 do
		self.children[i]:Reset()
	end

	self.currentIndex = 1
	local s = SelectorNode.Execute( self )

	-- Reset interrupted nodes
	if self.currentIndex < lastIndex then
		for i=self.currentIndex+1, lastIndex do
			self.children[i]:Reset()
		end
	end

	return s
end


--------------------------------------------------------------------------------
ActionNode = class({}, nil, BehaviorNode)

function ActionNode:constructor( name, methodName )
	BehaviorNode.constructor( self, name )

	self.tag = "ACT"

	self.methodName = methodName
end

function ActionNode:Execute()
	local s = self.context[self.methodName]( self.context )
	if s == nil then
		self:_Log( "Action method didn't return value." )
	end
	return s
end

--------------------------------------------------------------------------------
ConditionNode = class({}, nil, BehaviorNode)

function ConditionNode:constructor( name, methodName )
	BehaviorNode.constructor( self, name )

	self.tag = "COND"

	self.methodName = methodName
end

function ConditionNode:Execute()
	if self.context[self.methodName]( self.context ) then
		return BH_SUCCESS
	else
		return BH_FAILURE
	end
end

--------------------------------------------------------------------------------
DecoratorNode = class({}, nil, BehaviorNode)

function DecoratorNode:constructor( name, decoratedNode )
	BehaviorNode.constructor( self, name )

	if decoratedNode == nil then
		self:_Log( "No decorated node." )
	end
	self.decoratedNode = decoratedNode

	self.tag = "DEC"
end

function DecoratorNode:Reset()
	BehaviorNode.Reset( self )
	self.decoratedNode:Reset()
end

function DecoratorNode:SetContext( context )
	BehaviorNode.SetContext( self, context )
	self.decoratedNode:SetContext( context )
end

--------------------------------------------------------------------------------
Action_Wait = class({}, nil, ActionNode)

function Action_Wait:constructor( waitTime )
	ActionNode.constructor( self, "Wait" )
	self.waitTime = waitTime	-- sec
end

function Action_Wait:OnInitialize()
	self.endTime = GameRules:GetGameTime() + self.waitTime
	self:UpdateDescription()
end

function Action_Wait:Execute()
	self:UpdateDescription()

	if GameRules:GetGameTime() >= self.endTime then
		return BH_SUCCESS
	else
		return BH_RUNNING
	end
end

function Action_Wait:UpdateDescription()
	local remainingTime = self.endTime - GameRules:GetGameTime()
	local elapsedTime = self.waitTime - remainingTime
	self.description = ("Wait (%.1f / %.1f sec)"):format( elapsedTime, self.waitTime )
end

--------------------------------------------------------------------------------
Action_WaitRandom = class({}, nil, Action_Wait)

function Action_WaitRandom:constructor( waitTimeMin, waitTimeMax )
	Action_Wait.constructor( self )
	self.name = "WaitRandom"
	self.waitTimeMin = waitTimeMin
	self.waitTimeMax = waitTimeMax
end

function Action_WaitRandom:OnInitialize()
	self.waitTime = RandomFloat( self.waitTimeMin, self.waitTimeMax )
	Action_Wait.OnInitialize( self )
end

--------------------------------------------------------------------------------
Action_MoveTo = class({}, nil, ActionNode)

function Action_MoveTo:constructor( name, methodName, bDontInterrupt )
	ActionNode.constructor( self, name )
	self.methodName = methodName
	self.bDontInterrupt = bDontInterrupt
end

function Action_MoveTo:OnInitialize()
	self.description = "Move To " .. self.name

	self.targetPosition = self.context[self.methodName]( self.context )
end

function Action_MoveTo:Execute()
	if self.targetPosition then
		--self:_Log( self.description )
		self.context:MoveTo( self.targetPosition, self.bDontInterrupt )
		return BH_SUCCESS
	else
		-- Valid target position not found.
		self:_Log( "MoveTo : Valid target position not found." )
		return BH_FAILURE
	end
end

--------------------------------------------------------------------------------
Decorator_ForceSuccess = class({}, nil, DecoratorNode)

function Decorator_ForceSuccess:constructor( decoratedNode )
	DecoratorNode.constructor( self, "ForceSuccess", decoratedNode )
end

function Decorator_ForceSuccess:Execute()
	local s = self.decoratedNode:Tick()
	if s == BH_FAILURE then
		-- Failure to Success
		s = BH_SUCCESS
	end
	return s
end

--------------------------------------------------------------------------------
Decorator_Loop = class({}, nil, DecoratorNode)

function Decorator_Loop:constructor( numLoops, decoratedNode )
	DecoratorNode.constructor( self, "Loop", decoratedNode )
	self.numLoops = numLoops
end

function Decorator_Loop:OnInitialize()
	self.currentLoops = 0
	self:UpdateDescription()
end

function Decorator_Loop:Execute()
	if self.decoratedNode.status ~= BH_RUNNING then
		self.decoratedNode:Reset()
	end

	local s = self.decoratedNode:Tick()

	if s ~= BH_RUNNING then
		self.currentLoops = self.currentLoops + 1
		self:UpdateDescription()

		if self.numLoops > 0 and self.currentLoops == self.numLoops then
			-- Reached a number of times
			return s
		end
	end

	return BH_RUNNING
end

function Decorator_Loop:UpdateDescription()
	if self.numLoops > 0 then
		self.description = ("Loop (%d / %d)"):format( self.currentLoops, self.numLoops )
	else
		self.description = ("Loop (%d)"):format( self.currentLoops )
	end
end

--------------------------------------------------------------------------------
Decorator_UntilFailure = class({}, nil, DecoratorNode)

function Decorator_UntilFailure:constructor( decoratedNode )
	DecoratorNode.constructor( self, "UntilFailure", decoratedNode )
end

function Decorator_UntilFailure:Execute()
	if self.decoratedNode.status ~= BH_RUNNING then
		self.decoratedNode:Reset()
	end

	local s = self.decoratedNode:Tick()

	if s == BH_FAILURE then
		return BH_FAILURE
	end

	return BH_RUNNING
end

--------------------------------------------------------------------------------
Decorator_Cooldown = class({}, nil, DecoratorNode)

function Decorator_Cooldown:constructor( cooldownTime, decoratedNode )
	DecoratorNode.constructor( self, "Cooldown", decoratedNode )
	self.cooldownTime = cooldownTime	-- sec
	self.cooldownEndTime = 0
end

function Decorator_Cooldown:Execute()
	local remainingTime = math.max( self.cooldownEndTime - GameRules:GetGameTime(), 0.0 )
	self.description = (self.name .. " (%.1f / %.1f sec)"):format( remainingTime, self.cooldownTime )

	if GameRules:GetGameTime() < self.cooldownEndTime then
		-- On cooldown...
		return BH_FAILURE
	end

	local s = self.decoratedNode:Tick()

	if self:ShouldBeCooldown( s ) then
		self.cooldownTime = self:GetCooldownTime()
		self.cooldownEndTime = GameRules:GetGameTime() + self.cooldownTime
	end

	return s
end

function Decorator_Cooldown:ShouldBeCooldown( s )
	return s == BH_SUCCESS
end

function Decorator_Cooldown:GetCooldownTime()
	return self.cooldownTime
end

--------------------------------------------------------------------------------
Decorator_CooldownRandom = class({}, nil, Decorator_Cooldown)

function Decorator_CooldownRandom:constructor( cooldownTimeMin, cooldownTimeMax, decoratedNode )
	Decorator_Cooldown.constructor( self, cooldownTimeMin, decoratedNode )
	self.name = "Cooldown R"
	self.cooldownTimeMin = cooldownTimeMin
	self.cooldownTimeMax = cooldownTimeMax
end

function Decorator_CooldownRandom:GetCooldownTime()
	return RandomFloat( self.cooldownTimeMin, self.cooldownTimeMax )
end

--------------------------------------------------------------------------------
Decorator_CooldownAlsoFailure = class({}, nil, Decorator_Cooldown)

function Decorator_CooldownAlsoFailure:constructor( cooldownTime, decoratedNode )
	Decorator_Cooldown.constructor( self, cooldownTime, decoratedNode )
	self.name = "Cooldown F"
end

function Decorator_CooldownAlsoFailure:ShouldBeCooldown( s )
	return s == BH_SUCCESS or s == BH_FAILURE
end

--------------------------------------------------------------------------------
Decorator_CooldownRandomAlsoFailure = class({}, nil, Decorator_CooldownRandom)

function Decorator_CooldownRandomAlsoFailure:constructor( cooldownTimeMin, cooldownTimeMax, decoratedNode )
	Decorator_CooldownRandom.constructor( self, cooldownTimeMin, cooldownTimeMax, decoratedNode )
	self.name = "Cooldown R|F"
end

function Decorator_CooldownRandomAlsoFailure:ShouldBeCooldown( s )
	return Decorator_CooldownAlsoFailure.ShouldBeCooldown( self, s )
end
