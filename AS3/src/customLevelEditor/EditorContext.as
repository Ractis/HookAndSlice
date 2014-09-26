package customLevelEditor {
	import customLevelEditor.events.EditorContextEvent;
	import customLevelEditor.LevelData;
	import customLevelEditor.MonsterPoolData;
	import customLevelEditor.playtestConfig.PlaytestConfigPanel;
	import flash.display.Sprite;
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class EditorContext extends EventDispatcher
	{
		static public const TOOL_PANEL_MONSTER_SELECTION:String = "toolPanelMonsterSelection";
		
		static private var _inst:EditorContext = new EditorContext();
		
		private var _activePool:MonsterPoolData;
		private var _toolPanelMap:Dictionary = new Dictionary();
		private var _currentToolPanel:Sprite;
		private var _playtestConfigPanel:PlaytestConfigPanel;
		
		public var api:IDotaAPI;
		
		public function EditorContext() 
		{
			if ( _inst )
			{
				throw new Error();
			}
		}
		
		static public function get inst():EditorContext
		{
			return _inst;
		}
		
		public function registerToolPanel( panel:Sprite, name:String ):void
		{
			_toolPanelMap[name] = panel;
			panel.visible = false;
		}
		
		public function showToolPanel( name:String ):void
		{
			hideCurrentToolPanel();
			
			var panel:Sprite = _toolPanelMap[name];
			if ( panel )
			{
				_currentToolPanel = panel;
				panel.visible = true;
			}
			else
			{
				Utils.Log( "ToolPanel not found. NAME : " + name );
			}
		}
		
		public function hideCurrentToolPanel():void
		{
			if ( _currentToolPanel )
			{
				_currentToolPanel.visible = false;
				_currentToolPanel = null;
			}
		}
		
		public function get isActiveToolPanel():Boolean
		{
			return _currentToolPanel != null;
		}
		
		public function get activePool():MonsterPoolData
		{
			return _activePool;
		}
		
		public function set activePool( value:MonsterPoolData ):void
		{
			var oldActivePool:MonsterPoolData = _activePool;
			_activePool = value;
			
			// Fire event
			var event:EditorContextEvent = new EditorContextEvent( EditorContextEvent.CHANGED_ACTIVE_POOL );
			event.oldActivePool = oldActivePool;
			dispatchEvent( event );
		}
		
		public function addMonsterToActivePool( monsterObj:Object ):void
		{
			if ( activePool == null )
			{
				Utils.Log( "addMonsterToActivePool : activePool is null" );
				return;
			}
			
			activePool.addMonster( monsterObj );
		}
		
		public function removeMonsterFromActivePool( monsterObj:Object ):void
		{
			if ( activePool == null )
			{
				Utils.Log( "removeMonsterFromActivePool : activePool is null" );
				return;
			}
			
			activePool.removeMonster( monsterObj );
		}
		
		public function createPlaytestConfigPanel():void
		{
			// fix for Scaleform
			// Dont store sprite instances as static.
			_playtestConfigPanel = new PlaytestConfigPanel();
		}
		
		public function pushPlaytestConfigPanel( editorWindow:VerticalEditorPanel, data:LevelData ):void
		{
			_playtestConfigPanel.levelData = data;
			editorWindow.pushContentPanel( _playtestConfigPanel );
		}
		
		public function playLevel( data:LevelData, areaID:int, difficulty:int ):void
		{
			var kv:String = data.generateKeyValuesString();
			kv = '"CustomLevel"\n{\n' + kv + "}";
			kv = kv.replace( /"/g, "'" );
		//	kv = kv.replace( /"/g, "<q>" ).replace( /\n/g, "<n>" ).replace( /\t/g, " " );
			trace( kv );
			
			if ( api )
			{
				var seek:int = 0;
				var packetSize:int = 460;
				
				while ( seek < kv.length )
				{
					var packet:String = kv.slice( seek, seek + packetSize );
					api.SendServerCommand( 'dotahs_custom_level_buffer "' + packet + '"' );		// MAX : 512 chars.
					seek += packetSize;
				}
				
				api.SendServerCommand( "dotahs_custom_level_buffer_end" );
				api.SendServerCommand( "dotahs_play_custom_level " + areaID + " " + difficulty );
			}
		}
		
	}

}