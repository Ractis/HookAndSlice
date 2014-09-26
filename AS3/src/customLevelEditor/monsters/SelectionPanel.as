package customLevelEditor.monsters {
	import customLevelEditor.EditorContext;
	import customLevelEditor.events.EditorContextEvent;
	import customLevelEditor.monsters.MonsterListDataProvider;
	import flash.display.Sprite;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class SelectionPanel extends Sprite 
	{
		static public const GRID_DIM_X:int = 7;
		static public const CELL_WIDTH:Number = 48;
		static public const CELL_HEIGHT:Number = 56;
		static public const GRID_MARGIN:Number = 4;
		
		private var _gridPanelMap:Dictionary = new Dictionary();
		
		public function SelectionPanel() 
		{
			super();
			
			Utils.Log( "Initializing SelectMonsterPanel" );
			
			//------------------------------------------------------------
			// Create grid panels of a corresponding category
			//------------------------------------------------------------
			var categoryMap:Dictionary = new Dictionary();
			var categoryOrder:Vector.<String> = new Vector.<String>();
			var category:String;
			
			for each ( var monster:Object in MonsterListDataProvider.monsterArray )
			{
				category = monster.Category;
				if ( !categoryMap[category] )
				{
					Utils.Log( "ADDED a new category : " + category );
					categoryMap[category] = new Array();
					categoryOrder.push( category );
				}
				
				categoryMap[category].push( monster );
			}
			
			_createGridPanel( "All", MonsterListDataProvider.monsterArray );
			for each ( category in categoryOrder )
			{
				_createGridPanel( category, categoryMap[category] );
			}
			
			//------------------------------------------------------------
			// Show default panel
			//------------------------------------------------------------
			_gridPanelMap[ "All" ].visible = true;
			
			//------------------------------------------------------------
			// Register event listeners
			//------------------------------------------------------------
			EditorContext.inst.addEventListener( EditorContextEvent.CHANGED_ACTIVE_POOL, _onChangedActivePool );
		}
		
		private function _onChangedActivePool( e:EditorContextEvent ):void 
		{
		/*	if ( EditorContext.inst.activePool == null )
			{
				visible = false;
			}
			else
			{
				visible = true;
			}*/
		}
		
		private function _createGridPanel( category:String, monsterList:Array ):void
		{
			var gridPanel:Sprite = new Selection_GridPanel( category, monsterList );
			
			// Add as child
			_gridPanelMap[category] = gridPanel;
			gridPanel.visible = false;
			addChild( gridPanel );
		}
		
	}

}