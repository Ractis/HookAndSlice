
require( "Util_Quest" )
require( "timers" )
require( "SpawnManager" )

--------------------------------------------------------------------------------
-- Act like AI-Director
-- Refs:
--   asw_director.cpp/h
--   asw_director_intensity.h
--------------------------------------------------------------------------------
if SpawnDirector == nil then
	SpawnDirector = class({})
end

--------------------------------------------------------------------------------
local DIRECTOR_DEBUG = false
local DELTA_TIME = 0.25

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function SpawnDirector:Initialize( kv )

	self._flHordeIntervalMin	= kv.HordeIntervalMin or 60
	self._flHordeIntervalMax	= kv.HordeIntervalMax or 60
	self._flRelaxedTimeMin		= kv.DirectorRelaxedTimeMin or 15
	self._flRelaxedTimeMax		= kv.DirectorRelaxedTimeMax or 30
	self._flPeakTimeMin			= kv.DirectorPeakTimeMin or 1
	self._flPeakTimeMax			= kv.DirectorPeakTimeMax or 3
	self._flIntensityFarRange	= kv.IntensityFarRange or 600

	Intensity.flIntensityScaleDynamic	= 1.0
	Intensity.flIntensityScale			= kv.IntensityScale or 0.15
	Intensity.flIntensityDecayTime		= kv.IntensityDecayTime or 20
	Intensity.flIntensityInhibitDecay	= kv.IntensityInhibitDecay or 3.5

	self:_Log( "Horde Interval = " .. self._flHordeIntervalMin .. " to " .. self._flHordeIntervalMax )
	self:_Log( "Director Relaxed Time = " .. self._flRelaxedTimeMin .. " to " .. self._flRelaxedTimeMax )
	self:_Log( "Director Peak Time = " .. self._flPeakTimeMin .. " to " .. self._flPeakTimeMax )
	self:_Log( "Intensity Far Range = " .. self._flIntensityFarRange )
	self:_Log( "Intensity Scale = " .. Intensity.flIntensityScale )
	self:_Log( "Intensity Decay Time = " .. Intensity.flIntensityDecayTime )
	self:_Log( "Intensity Inhibit Decay = " .. Intensity.flIntensityInhibitDecay )

	self._bSpawningEnemies = true
	self._bReachedIntensityPeak = false
	self._flMaxIntensity = 0
	self._vIntensities = {}	-- PlayerID : Intensity
	self._vHPRatio = {}		-- PlayerID : HP ratio
	
	if DIRECTOR_DEBUG then
		self._questHordeTimer = CreateQuest( "HordeTimer" )
		self._subquestHordeTimer = CreateSubquestOf( self._questHordeTimer )
		self._questSustainTimer = CreateQuest( "SustainTimer" )
		self._subquestSustainTimer = CreateSubquestOf( self._questSustainTimer )
		self._questPlayerMaxIntensity = CreateQuest( "PlayerMaxIntensity" )
		self._subquestPlayerMaxIntensity = CreateSubquestOf( self._questPlayerMaxIntensity )
	--	self._questPlayerMinIntensity = CreateQuest( "PlayerMinIntensity" )
	--	self._subquestPlayerMinIntensity = CreateSubquestOf( self._questPlayerMinIntensity )
	end

	-- CreateTimer
	Timers:CreateTimer( function ()
		self:_OnUpdate()
		return DELTA_TIME
	end )

	-- Register Event Listeners
	ListenToGameEvent( 'entity_killed',	Dynamic_Wrap(SpawnDirector, "OnEntityKilled"), self )

end

--------------------------------------------------------------------------------
function SpawnDirector:_OnUpdate()
	self:_UpdatePlayerStats()
	self:_UpdateIntensity()
	self:_UpdateHorde()
	self:_UpdateSpawningState()
end

--------------------------------------------------------------------------------
function SpawnDirector:_UpdatePlayerStats()
	local nPlayersTotal = 0
	local nPlayersAlive = 0

	self:_ForEachPlayer( function ( playerID, hero )
		if not hero then return end

		nPlayersTotal = nPlayersTotal + 1
		if hero:IsAlive() then
			nPlayersAlive = nPlayersAlive + 1
		end
	end )

	self._nPlayersAlive = nPlayersAlive

	if nPlayersAlive == 0 then
		-- All player dead
		return
	end

	local scale = nPlayersTotal / nPlayersAlive
	if math.abs( Intensity.flIntensityScaleDynamic - scale ) > 1e-5 then
		-- Change dynamic intensity scale
		Intensity.flIntensityScaleDynamic = scale
		self:_Log( "Changed dynamic intensity scale to " .. scale )
		self:_Log( "Num players alive : " .. nPlayersAlive .. " / " .. nPlayersTotal )
	end
end

--------------------------------------------------------------------------------
function SpawnDirector:_UpdateIntensity()
	local maxIntensity = -999
	local minIntensity = 999
	local maxIntensityPlayerName
	local minIntensityPlayerName

	self:_ForEachPlayer( function ( playerID, hero )
		if not hero then return end

		local intensity = self:_GetIntensityOf( playerID )

		-- Check damage taken
		local hpRatio = hero:GetHealth() / hero:GetMaxHealth()

		if self._vHPRatio[playerID] then

			-- Damage ratio during DELTA_TIME
			local damageRatio = self._vHPRatio[playerID] - hpRatio
			if damageRatio > 0 then
				local stress = INTENSITY_NONE
				if damageRatio < 0.01 then
					stress = INTENSITY_NONE		-- below 0.01
				elseif damageRatio < 0.05 then
					stress = INTENSITY_MILD		-- 0.01 to 0.05
				elseif damageRatio < 0.2 then
					stress = INTENSITY_MODERATE	-- 0.05 to 0.2
				elseif damageRatio < 0.4 then
					stress = INTENSITY_HIGH		-- 0.2 to 0.4
				else
					stress = INTENSITY_EXTREME	-- over 0.4
				end

				intensity:Increase( stress )
			end

		end

		self._vHPRatio[playerID] = hpRatio

		-- Update
		intensity:Update( DELTA_TIME )

		-- Update max intensity
		local playerName = "#" .. hero:GetClassname()
		if intensity.flValue > maxIntensity then
			maxIntensity = intensity.flValue
			maxIntensityPlayerName = playerName
		end
		if intensity.flValue < minIntensity then
			minIntensity = intensity.flValue
			minIntensityPlayerName = playerName
		end
	end )

	if DIRECTOR_DEBUG then
		if maxIntensityPlayerName then
			self._questPlayerMaxIntensity:SetTextReplaceString( " by " .. maxIntensityPlayerName )
		else
			self._subquestPlayerMaxIntensity:SetTextReplaceString( "" )
		end
		Quest_UpdateValue( self._questPlayerMaxIntensity, math.ceil( maxIntensity * 100 ), 100 )
		Subquest_UpdateValue( self._subquestPlayerMaxIntensity, math.ceil( maxIntensity * 100 ), 100 )
		--[[
		if minIntensityPlayerName then
			self._questPlayerMinIntensity:SetTextReplaceString( " by " .. minIntensityPlayerName )
		else
			self._subquestPlayerMinIntensity:SetTextReplaceString( "" )
		end
		Quest_UpdateValue( self._questPlayerMinIntensity, math.ceil( minIntensity * 100 ), 100 )
		Subquest_UpdateValue( self._subquestPlayerMinIntensity, math.ceil( minIntensity * 100 ), 100 )
		-]]
	end

	self._flMaxIntensity = maxIntensity
end

--------------------------------------------------------------------------------
function SpawnDirector:_GetIntensityOf( playerID )
	if not self._vIntensities[playerID] then
		self._vIntensities[playerID] = Intensity()
	end

	return self._vIntensities[playerID]
end

--------------------------------------------------------------------------------
function SpawnDirector:_UpdateHorde()

	if DIRECTOR_DEBUG then
		if self._hordeTimerDuration and self._hordeDue then
			local remainingTime = self._hordeDue - GameRules:GetGameTime()
			remainingTime = math.max( remainingTime, 0 )
			local elapsedTime = self._hordeTimerDuration - remainingTime

			Subquest_UpdateValue( self._subquestHordeTimer, elapsedTime, self._hordeTimerDuration )
			Quest_UpdateValue( self._questHordeTimer, math.ceil( remainingTime ) )
		end
	end

	if self._hordeDue == nil then

		-- Start the horde timer
		local duration = RandomFloat( self._flHordeIntervalMin, self._flHordeIntervalMax )
		self:_Log( "Will be spawning a horde in " .. math.ceil( duration ) .. " seconds" )
		self._hordeTimerDuration = duration
		self._hordeDue = GameRules:GetGameTime() + duration

	elseif self._hordeDue < GameRules:GetGameTime() then

		-- Attempt to spawn horde
		if self._bSpawningEnemies == true and self._nPlayersAlive > 0 then
			SpawnManager:SpawnHorde()
			self._hordeDue = nil	-- invalidate the timer

		else
			-- If we failed to spawn the horde, try again shortly.
			local duration = RandomFloat( 8, 12 )
			self:_Log( "Will be spawning a horde in " .. math.ceil( duration ) .. " seconds" )
			self._hordeTimerDuration = duration
			self._hordeDue = GameRules:GetGameTime() + duration

		end

	end
end

--------------------------------------------------------------------------------
function SpawnDirector:_UpdateSpawningState()

	if DIRECTOR_DEBUG then
		if self._sustainTimer then
			local remainingTime = self._sustainTimer - GameRules:GetGameTime()
			remainingTime = math.max( remainingTime, 0 )
			local elapsedTime = self._sustainDuration - remainingTime

			Subquest_UpdateValue( self._subquestSustainTimer, elapsedTime, self._sustainDuration )
			Quest_UpdateValue( self._questSustainTimer, math.ceil( remainingTime ) )
		else
			Subquest_UpdateValue( self._subquestSustainTimer, 0, 1 )
			Quest_UpdateValue( self._questSustainTimer, 0 )
		end
	end

	--
	-- Spawn enemies until a peak intensity is reached, then gives the players a breather
	--
	if not self._bSpawningEnemies then
		-- We're in a relaxed state
		if self._sustainTimer == nil then
			-- Don't start our relax timer until the players have left the PEAK
			if self._flMaxIntensity < 1.0 then
				local duration = RandomFloat( self._flRelaxedTimeMin, self._flRelaxedTimeMax )
				self._sustainDuration = duration
				self._sustainTimer = GameRules:GetGameTime() + duration
				self:_Log( "Started sustain timer : duration = " .. duration )
			end

		elseif self._sustainTimer < GameRules:GetGameTime() then
			self._bSpawningEnemies = true
			self._bReachedIntensityPeak = false
			self._sustainTimer = nil
			self:_Log( "Elapsed sustain timer" )

		end

	else
		-- We're spawning enemies
		if self._bReachedIntensityPeak then
			-- Hold the peak intensity for a while, then drop back to the relaxed state
			if self._sustainTimer == nil then
				local duration = RandomFloat( self._flPeakTimeMin, self._flPeakTimeMax )
				self._sustainDuration = duration
				self._sustainTimer = GameRules:GetGameTime() + duration
				self:_Log( "Started peak timer : duration = " .. duration )

			elseif self._sustainTimer < GameRules:GetGameTime() then
				self._bSpawningEnemies = false
				self._sustainTimer = nil
				self:_Log( "Elapsed peak timer" )

			end
		else
			if self._flMaxIntensity >= 1.0 then
				self._bReachedIntensityPeak = true
				self:_Log( "Reached intensity peak" )
			end
		end

	end

	SpawnManager:SetEnableSpawnDesiredEnemies( self._bSpawningEnemies )
end

--------------------------------------------------------------------------------
function SpawnDirector:OnEntityKilled( event )
	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if not killedUnit then
		return
	end

	-- An enemy unit?
	if killedUnit:GetTeam() == DOTA_TEAM_BADGUYS then

		-- That was dangerous threat?
		local intensity = killedUnit.DotaRPG_Intensity or 0

		self:_ForEachPlayer( function ( playerID, hero )
			if not hero then return end

			local stress = INTENSITY_MILD

			if intensity >= 2 then
				stress = INTENSITY_EXTREME
			elseif intensity == 1 then
				stress = INTENSITY_HIGH
			else
				local dist = self:_Distance( killedUnit, hero )
			--	print( "DIST : " .. dist )
				if dist > self._flIntensityFarRange then
					stress = INTENSITY_MILD
				else
					stress = INTENSITY_MODERATE
				end
			end

			self:_GetIntensityOf( playerID ):Increase( stress )
		end )

		--[[
		if intensity > 0 then
			self:_Log( "INTENSITY LEVEL : " .. intensity )
		end
		--]]

	end
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
function SpawnDirector:_Log( text )
	print( "[SpawnDirector] " .. text )
end

function SpawnDirector:_ForEachPlayer( func --[[ playerID, hero ]] )
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( playerID ) == DOTA_TEAM_GOODGUYS then
			if PlayerResource:HasSelectedHero( playerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( playerID )
				func( playerID, hero )
			end
		end
	end
end

function SpawnDirector:_Distance( unitA, unitB )
	return ( unitA:GetAbsOrigin() - unitB:GetAbsOrigin() ):Length2D()
end



--------------------------------------------------------------------------------
-- class : Intensity
--------------------------------------------------------------------------------

-- From asw_director in AlienSwarm SDK
INTENSITY_NONE 		= 0
INTENSITY_MILD 		= 1
INTENSITY_MODERATE	= 2
INTENSITY_HIGH		= 3
INTENSITY_EXTREME	= 4
INTENSITY_MAXIMUM	= 5

--------------------------------------------------------------------------------
Intensity = {}

function Intensity:new()
	local o = {}
	setmetatable( o, { __index = Intensity } )
	o:__init()
	return o
end

setmetatable( Intensity, { __call = Intensity.new } )

--------------------------------------------------------------------------------
function Intensity:__init()
	self.flValue = 0
	self.timeToDecay = 0
end

--------------------------------------------------------------------------------
function Intensity:Update( deltaTime )
	if self.timeToDecay < GameRules:GetGameTime() then
		-- decayInhibitTimer.Elapsed
		self.flValue = self.flValue - deltaTime / Intensity.flIntensityDecayTime
		self.flValue = math.max( self.flValue, 0 )
	end
end

--------------------------------------------------------------------------------
function Intensity:Increase( stress )
--	print( "STRESS TYPE : " .. stress )
	local value = Intensity.IntensityToValueMap[stress]
	value = value * Intensity.flIntensityScale * Intensity.flIntensityScaleDynamic
--	print( "ADDING INTENSITY VAL : " .. value )
	self.flValue = math.min( self.flValue + value, 1.0 )

	-- Don't decay immediately
	self:InhibitDecay( Intensity.flIntensityInhibitDecay )
end

--------------------------------------------------------------------------------
function Intensity:InhibitDecay( duration )
	self.timeToDecay = math.max( self.timeToDecay, GameRules:GetGameTime() + duration )
end

--------------------------------------------------------------------------------
Intensity.IntensityToValueMap = {
	[INTENSITY_NONE]		= 0,
	[INTENSITY_MILD]		= 0.05,
	[INTENSITY_MODERATE]	= 0.2,
	[INTENSITY_HIGH]		= 0.5,
	[INTENSITY_EXTREME]		= 1.0,
	[INTENSITY_MAXIMUM]		= 999999.9,
}

