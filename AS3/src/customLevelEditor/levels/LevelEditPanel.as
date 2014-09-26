package customLevelEditor.levels {
	import customLevelEditor.BaseVerticalEditorContentPanel;
	import customLevelEditor.EditorContext;
	import customLevelEditor.events.LevelDataEvent;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.LevelData;
	import customLevelEditor.ListView;
	import customLevelEditor.MonsterPoolData;
	import customLevelEditor.VerticalEditorContent_Button;
	import customLevelEditor.VerticalEditorPanel;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class LevelEditPanel extends BaseVerticalEditorContentPanel 
	{
		static private const MAX_POOLS:int = 4;
		
		private var _levelData:LevelData;
		
		private var _poolListPanel:Sprite;
		private var _poolPanels:Vector.<MonsterPoolPanel> = new Vector.<MonsterPoolPanel>();
		
		private var _btAdd:VerticalEditorContent_Button;
		private var _btPlay:VerticalEditorContent_Button;
		
		public var editorWindow:VerticalEditorPanel;
		
		public function LevelEditPanel() 
		{
			super();
			
			_levelData = new LevelData();
			
			//------------------------------------------------------------
			// Add button
			//------------------------------------------------------------
			_btAdd = new VerticalEditorContent_Button( "ADD POOL" );
			addChild( _btAdd );
			_btAdd.y = 100;
			
			_btPlay = new VerticalEditorContent_Button( "SELECT AREA & DIFFICULTY" );
			addChild( _btPlay );
			_btPlay.y = 650;
			
			//------------------------------------------------------------
			// List panel
			//------------------------------------------------------------
			_poolListPanel = new Sprite();
			addChild( _poolListPanel );
			_poolListPanel.y = 155;
			
			//------------------------------------------------------------
			// Custom properties
			//------------------------------------------------------------
			var propertyListPanel:ListView = new ListView();
			addChild( propertyListPanel );
			propertyListPanel.y = 450;
			
			var propertyCell:LevelPropertyCellPanel;
			
			propertyListPanel.appendCell( new LevelPropertyCellPanel( "Starting Hero Level", _levelData, "startingLevel", false ) );
			propertyListPanel.appendCell( new LevelPropertyCellPanel( "EXP Multiplier", _levelData, "expPercent", true ) );
			propertyListPanel.appendCell( new LevelPropertyCellPanel( "Enemy HP Multiplier", _levelData, "healthPercent", true ) );
			propertyListPanel.appendCell( new LevelPropertyCellPanel( "Enemy Density", _levelData, "densityPercent", true ) );
			
			//------------------------------------------------------------
			// Register event listeners
			//------------------------------------------------------------
			_btAdd.addEventListener( MouseEvent.CLICK, _onAddClick );
			_btPlay.addEventListener( MouseEvent.CLICK, _onPlayClick );
			_levelData.addEventListener( LevelDataEvent.ADDED_POOL, _onAddedPool );
			_levelData.addEventListener( LevelDataEvent.REMOVED_POOL, _onRemovedPool );
			
			_updateAddPoolButtonState();
			_updatePlayButtonState();
		}
		
		override public function get panelTitle():String 
		{
			return "CUSTOM LEVEL";
		}
		
		private function _onAddClick( e:MouseEvent ):void
		{
			if ( _levelData.monsterPools.length >= MAX_POOLS )
			{
				Utils.Log( "Max num of monster pools has been reached." )
				return;
			}
			
			_levelData.addPool( new MonsterPoolData() );
		}
		
		private function _onPlayClick( e:MouseEvent ):void
		{
			if ( !_levelData.isReadyForPlay )
			{
				Utils.Log( "The custom level is not ready for play." );
				return;
			}
			
			EditorContext.inst.pushPlaytestConfigPanel( editorWindow, _levelData );
		}
		
		private function _onAddedPool( e:LevelDataEvent ):void 
		{
			// Create the pool panel
			var poolPanel:MonsterPoolPanel = new MonsterPoolPanel( e.poolData );
			poolPanel.editorWindow = editorWindow;
			_poolPanels.push( poolPanel );
			
			_poolListPanel.addChild( poolPanel );
			_updateLayout_poolPanels();
			_updateAddPoolButtonState();
			
			// Register event listener
			e.poolData.addEventListener( MonsterPoolEvent.UPDATE_WEIGHTS, _updatePlayButtonState );
			_updatePlayButtonState();
		}
		
		private function _onRemovedPool( e:LevelDataEvent ):void 
		{
			throw new Error();
		}
		
		private function _updateLayout_poolPanels():void
		{
			// Layout
			var currentY:Number = 0;
			var margin:Number = 5;
			
			for each ( var panel:MonsterPoolPanel in _poolPanels )
			{
				panel.y = currentY;
				currentY += panel.panelHeight + margin;
			}
		}
		
		private function _updateAddPoolButtonState():void
		{
			if ( _levelData.monsterPools.length >= MAX_POOLS )
			{
				_btAdd.bgColor = 0x9a9a9a;
			}
			else
			{
				_btAdd.bgColor = 0x0090d9;
			}
		}
		
		private function _updatePlayButtonState(...args):void
		{
			if ( !_levelData.isReadyForPlay )
			{
				_btPlay.bgColor = 0x9a9a9a;
			}
			else
			{
				_btPlay.bgColor = 0xd90048;
			}
		}
		
	}

}