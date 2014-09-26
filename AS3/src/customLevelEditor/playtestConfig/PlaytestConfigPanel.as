package customLevelEditor.playtestConfig
{
	import customLevelEditor.BaseVerticalEditorContentPanel;
	import customLevelEditor.EditorContext;
	import customLevelEditor.LevelData;
	import customLevelEditor.VerticalEditorContent_Button;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class PlaytestConfigPanel extends BaseVerticalEditorContentPanel 
	{
		private var _levelData:LevelData;
		
		private var _areaListPanel:Sprite;
		private var _areaPanels:Vector.<AreaCellPanel> = new Vector.<AreaCellPanel>();
		private var _activeAreaPanel:AreaCellPanel;
		
		private var _difficultyListPanel:Sprite;
		private var _difficultyPanels:Vector.<DifficultyCellPanel> = new Vector.<DifficultyCellPanel>();
		private var _activeDifficultyPanel:DifficultyCellPanel;
		
		private var _btPlay:VerticalEditorContent_Button;
		
		public function PlaytestConfigPanel() 
		{
			super();
			
			//------------------------------------------------------------
			// Area list
			//------------------------------------------------------------
			_areaListPanel = new Sprite();
			addChild( _areaListPanel );
			_areaListPanel.y = 155;
			
			_createAreaPanel( 1, "Standard, Broad" );
			_createAreaPanel( 2, "Standard, Narrow" );
			_createAreaPanel( 3, "Arena, Simple" );
			_createAreaPanel( 4, "Arena, Complex" );
			
			_updateLayout_areaPanels();
			
			selectedAreaPanel = _areaPanels[0];
			
			//------------------------------------------------------------
			// Difficulty list
			//------------------------------------------------------------
			_difficultyListPanel = new Sprite();
			addChild( _difficultyListPanel );
			_difficultyListPanel.y = 400;
			
			_createDifficultyPanel( 0, "Normal" );
			_createDifficultyPanel( 1, "Hard" );
			_createDifficultyPanel( 2, "Insane" );
			
			_updateLayout_difficultyPanels();
			
			selectedDifficultyPanel = _difficultyPanels[0];
			
			//------------------------------------------------------------
			// BUTTONS
			//------------------------------------------------------------
			_btPlay = new VerticalEditorContent_Button( "PLAY THIS LEVEL" );
			addChild( _btPlay );
			_btPlay.y = 650;
			_btPlay.bgColor = 0xd90048;
			
			//------------------------------------------------------------
			// Event listeners
			//------------------------------------------------------------
			_btPlay.addEventListener( MouseEvent.CLICK, _onPlayClick );
		}
		
		public function set levelData( data:LevelData ):void
		{
			_levelData = data;
		}
		
		private function _createAreaPanel( areaID:int, areaName:String ):void
		{
			var panel:AreaCellPanel = new AreaCellPanel( areaID, areaName );
			_areaListPanel.addChild( panel );
			_areaPanels.push( panel );
			
			panel.addEventListener( MouseEvent.CLICK, function ( e:MouseEvent ):void
			{
				selectedAreaPanel = panel;
			} );
		}
		
		private function set selectedAreaPanel( value:AreaCellPanel ):void
		{
			if ( _activeAreaPanel )
			{
				_activeAreaPanel.selected = false;
			}
			
			for each ( var panel:AreaCellPanel in _areaPanels )
			{
				if ( panel == value )
				{
					_activeAreaPanel = panel;
					panel.selected = true;
					break;
				}
			}
		}
		
		private function _updateLayout_areaPanels():void
		{
			// Layout
			var currentY:Number = 0;
			var margin:Number = 5;
			
			for each ( var panel:AreaCellPanel in _areaPanels )
			{
				panel.y = currentY;
				currentY += panel.panelHeight + margin;
			}
		}
		
		private function _createDifficultyPanel( difficulty:int, text:String ):void
		{
			var panel:DifficultyCellPanel = new DifficultyCellPanel( difficulty, text );
			_difficultyListPanel.addChild( panel );
			_difficultyPanels.push( panel );
			
			panel.addEventListener( MouseEvent.CLICK, function ( e:MouseEvent ):void
			{
				selectedDifficultyPanel = panel;
			} );
		}
		
		private function set selectedDifficultyPanel( value:DifficultyCellPanel ):void
		{
			if ( _activeDifficultyPanel )
			{
				_activeDifficultyPanel.selected = false;
			}
			
			for each ( var panel:DifficultyCellPanel in _difficultyPanels )
			{
				if ( panel == value )
				{
					_activeDifficultyPanel = panel;
					panel.selected = true;
					break;
				}
			}
		}
		
		private function _updateLayout_difficultyPanels():void
		{
			// Layout
			var currentY:Number = 0;
			var margin:Number = 5;
			
			for each ( var panel:DifficultyCellPanel in _difficultyPanels )
			{
				panel.y = currentY;
				currentY += panel.panelHeight + margin;
			}
		}
		
		private function _onPlayClick( e:MouseEvent ):void
		{
			if ( !_levelData.isReadyForPlay )
			{
				Utils.Log( "The custom level is not ready for play." );
				return;
			}
			
			EditorContext.inst.playLevel( _levelData, _activeAreaPanel.areaID, _activeDifficultyPanel.difficulty );
		}
		
		override public function get panelTitle():String 
		{
			return "AREA & DIFFICULTY";
		}
		
	}

}