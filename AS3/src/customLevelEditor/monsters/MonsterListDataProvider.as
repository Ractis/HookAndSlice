package customLevelEditor.monsters {
	import com.adobe.serialization.json.JSON;
	import flash.utils.ByteArray;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterListDataProvider 
	{
	//	[Embed(source="assets/Editor_AllMonsterList.json", mimeType="application/octet-stream")]
	//	static private const JsonData:Class;
		
		static private var _monsterArray:Array;
		
		public function MonsterListDataProvider() 
		{
			
		}
		
		static public function get monsterArray():Array
		{
			if ( !_monsterArray )
			{
				Utils.Log( "Parsing JSON by using as3corelib..." );
			//	_monsterArray = JSON.parse( new JsonData() ) as Array;	// Didn't work on Scaleform...
				try {
					var jsonStr:String = '[{"Index":1,"Category":"Neutrals","Subcategory":"Kobold","Name":"npc_dota_neutral_kobold","FixedLevel":1,"Intensity":""},{"Index":2,"Category":"Neutrals","Subcategory":"Kobold","Name":"npc_dota_neutral_kobold_tunneler","FixedLevel":1,"Intensity":""},{"Index":3,"Category":"Neutrals","Subcategory":"Kobold","Name":"npc_dota_neutral_kobold_taskmaster","FixedLevel":2,"Intensity":""},{"Index":4,"Category":"Neutrals","Subcategory":"Hill Troll","Name":"npc_dota_neutral_forest_troll_berserker","FixedLevel":2,"Intensity":""},{"Index":5,"Category":"Neutrals","Subcategory":"Hill Troll","Name":"npc_dota_neutral_forest_troll_high_priest","FixedLevel":2,"Intensity":""},{"Index":6,"Category":"Neutrals","Subcategory":"Vhoul Assassin","Name":"npc_dota_neutral_gnoll_assassin","FixedLevel":2,"Intensity":""},{"Index":7,"Category":"Neutrals","Subcategory":"Ghost","Name":"npc_dota_neutral_fel_beast","FixedLevel":2,"Intensity":""},{"Index":8,"Category":"Neutrals","Subcategory":"Ghost","Name":"npc_dota_neutral_ghost","FixedLevel":3,"Intensity":""},{"Index":9,"Category":"Neutrals","Subcategory":"Harpy","Name":"npc_dota_neutral_harpy_scout","FixedLevel":2,"Intensity":""},{"Index":10,"Category":"Neutrals","Subcategory":"Harpy","Name":"npc_dota_neutral_harpy_storm","FixedLevel":3,"Intensity":""},{"Index":11,"Category":"Neutrals","Subcategory":"Wolf","Name":"npc_dota_neutral_giant_wolf","FixedLevel":3,"Intensity":""},{"Index":12,"Category":"Neutrals","Subcategory":"Wolf","Name":"npc_dota_neutral_alpha_wolf","FixedLevel":4,"Intensity":""},{"Index":13,"Category":"Neutrals","Subcategory":"Ogre","Name":"npc_dota_neutral_ogre_mauler","FixedLevel":2,"Intensity":""},{"Index":14,"Category":"Neutrals","Subcategory":"Ogre","Name":"npc_dota_neutral_ogre_magi","FixedLevel":3,"Intensity":""},{"Index":15,"Category":"Neutrals","Subcategory":"Golem","Name":"npc_dota_neutral_mud_golem","FixedLevel":5,"Intensity":""},{"Index":16,"Category":"Neutrals","Subcategory":"Centaur","Name":"npc_dota_neutral_centaur_outrunner","FixedLevel":2,"Intensity":""},{"Index":17,"Category":"Neutrals","Subcategory":"Centaur","Name":"npc_dota_neutral_centaur_khan","FixedLevel":5,"Intensity":""},{"Index":18,"Category":"Neutrals","Subcategory":"Satyr","Name":"npc_dota_neutral_satyr_trickster","FixedLevel":2,"Intensity":""},{"Index":19,"Category":"Neutrals","Subcategory":"Satyr","Name":"npc_dota_neutral_satyr_soulstealer","FixedLevel":4,"Intensity":""},{"Index":20,"Category":"Neutrals","Subcategory":"Satyr","Name":"npc_dota_neutral_satyr_hellcaller","FixedLevel":6,"Intensity":""},{"Index":21,"Category":"Neutrals","Subcategory":"Hellbear","Name":"npc_dota_neutral_polar_furbolg_champion","FixedLevel":4,"Intensity":""},{"Index":22,"Category":"Neutrals","Subcategory":"Hellbear","Name":"npc_dota_neutral_polar_furbolg_ursa_warrior","FixedLevel":5,"Intensity":""},{"Index":23,"Category":"Neutrals","Subcategory":"Wildwing","Name":"npc_dota_neutral_wildkin","FixedLevel":1,"Intensity":""},{"Index":24,"Category":"Neutrals","Subcategory":"Wildwing","Name":"npc_dota_neutral_enraged_wildkin","FixedLevel":5,"Intensity":""},{"Index":25,"Category":"Neutrals","Subcategory":"Troll","Name":"npc_dota_neutral_dark_troll","FixedLevel":3,"Intensity":""},{"Index":26,"Category":"Neutrals","Subcategory":"Troll","Name":"npc_dota_neutral_dark_troll_warlord","FixedLevel":6,"Intensity":""},{"Index":27,"Category":"Holdout","Subcategory":"Wave2","Name":"npc_dota_creature_basic_zombie","FixedLevel":"","Intensity":""},{"Index":28,"Category":"Holdout","Subcategory":"Wave2","Name":"npc_dota_creature_basic_zombie_exploding","FixedLevel":"","Intensity":1},{"Index":29,"Category":"Holdout","Subcategory":"Wave2","Name":"npc_dota_creature_corpselord","FixedLevel":"","Intensity":1},{"Index":30,"Category":"Holdout","Subcategory":"Wave4","Name":"npc_dota_creature_lesser_nightcrawler","FixedLevel":"","Intensity":""},{"Index":31,"Category":"Holdout","Subcategory":"Wave4","Name":"npc_dota_creature_slithereen","FixedLevel":"","Intensity":1},{"Index":32,"Category":"Holdout","Subcategory":"Wave7","Name":"npc_dota_creature_mini_roshan","FixedLevel":"","Intensity":1},{"Index":33,"Category":"Holdout","Subcategory":"Wave7","Name":"npc_dota_creature_tormented_soul","FixedLevel":"","Intensity":1},{"Index":34,"Category":"Holdout","Subcategory":"Wave11","Name":"npc_dota_creature_missile_launcher","FixedLevel":"","Intensity":1},{"Index":35,"Category":"Holdout","Subcategory":"Wave12","Name":"npc_dota_creature_minor_lich","FixedLevel":"","Intensity":1},{"Index":36,"Category":"Holdout","Subcategory":"Wave12","Name":"npc_dota_creature_snow_creep_melee","FixedLevel":"","Intensity":""},{"Index":37,"Category":"DotaHS","Subcategory":"Intellect","Name":"npc_dotahs_bane","FixedLevel":"","Intensity":""},{"Index":38,"Category":"DotaHS","Subcategory":"Intellect","Name":"npc_dotahs_dazzle","FixedLevel":"","Intensity":1},{"Index":39,"Category":"DotaHS","Subcategory":"Intellect","Name":"npc_dotahs_faerie_dragon","FixedLevel":"","Intensity":1},{"Index":40,"Category":"DotaHS","Subcategory":"Intellect","Name":"npc_dotahs_jakiro","FixedLevel":"","Intensity":1},{"Index":41,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_magnus","FixedLevel":"","Intensity":1},{"Index":42,"Category":"DotaHS","Subcategory":"Agility","Name":"npc_dotahs_nevermore","FixedLevel":"","Intensity":1},{"Index":43,"Category":"DotaHS","Subcategory":"Agility","Name":"npc_dotahs_nyxnyxnyx","FixedLevel":"","Intensity":1},{"Index":44,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_phoenix","FixedLevel":"","Intensity":1},{"Index":45,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_pudge","FixedLevel":"","Intensity":1},{"Index":46,"Category":"DotaHS","Subcategory":"Intellect","Name":"npc_dotahs_pugna","FixedLevel":"","Intensity":1},{"Index":47,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_rattletrap","FixedLevel":"","Intensity":1},{"Index":48,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_tusk","FixedLevel":"","Intensity":1},{"Index":49,"Category":"DotaHS","Subcategory":"Strength","Name":"npc_dotahs_wisp","FixedLevel":"","Intensity":1}]';
					Utils.Log( "Length of jsonStr : " + jsonStr.length );
					_monsterArray = JSON.decode( jsonStr, false ) as Array;
				} catch ( e:Error ) {
					Utils.Log( e.message );
					Utils.Log( e.getStackTrace() );
				}
				Utils.Log( "Finished parsing JSON" );
			}
			return _monsterArray;
		}
		
	}

}