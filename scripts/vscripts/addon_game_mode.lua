
require( "DotaHS_GameMode" )

--------------------------------------------------------------------------------
-- PRECACHE
--------------------------------------------------------------------------------
function Precache( context )
	PrecacheResource( "particle", "particles/loots/loot_rare_starfall.vpcf", context )
	PrecacheItemByNameSync( "item_tombstone", context )
--	PrecacheUnitByNameSync( "npc_dota_hero_naga_siren", context )
end

--------------------------------------------------------------------------------
-- ACTIVATE
--------------------------------------------------------------------------------
function Activate()
    GameRules.DotaHS = DotaHS()
    GameRules.DotaHS:InitGameMode()
end
