package customLevelEditor.monsters {
	import customLevelEditor.BaseVerticalEditorContentPanel;
	import customLevelEditor.Constants;
	import customLevelEditor.EditorContext;
	import customLevelEditor.EditorLabel;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterPoolData;
	import customLevelEditor.VerticalEditorContent_Button;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterPoolEditPanel extends BaseVerticalEditorContentPanel
	{
		private var _poolData:MonsterPoolData;
		
		private var _btToggleSelection:VerticalEditorContent_Button;
		private var _monsterListPanel:Sprite;
		
		private var _monsterPanels:Vector.<Monster_Base> = new Vector.<Monster_Base>;
		private var _tempCollapsedPanelForActive:Monster_CollapsedPanel;
		private var _tempEditPanelForActive:Monster_EditPanel;
		
		private var _counter:TextField;
		
		public function MonsterPoolEditPanel( $poolData:MonsterPoolData = null ) 
		{
			_poolData = $poolData ? $poolData : new MonsterPoolData();
			
			var g:Graphics;
			
			// Add button
			_btToggleSelection = new VerticalEditorContent_Button( "SELECT MONSTERS" );
			addChild( _btToggleSelection );
			_btToggleSelection.y = 100;
			
			// MonsterList panel
			_monsterListPanel = new Sprite();
			addChild( _monsterListPanel );
			_monsterListPanel.y = 155;
			
			// Add DonutChart
			var chart:ProbabilityChartsPanel = new ProbabilityChartsPanel( _poolData );
			addChild( chart );
			chart.x = Constants.PANEL_WIDTH / 2;
			chart.y = 610;
			
			// Add Counter
			_counter = new EditorLabel( "0/0", 48, 0xFFFFFF );
			addChildAt( _counter, 0 );
			_counter.autoSize = TextFieldAutoSize.NONE;
			_counter.width = Constants.PANEL_WIDTH - 10;
			var format:TextFormat = _counter.defaultTextFormat;
			format.align = TextFormatAlign.RIGHT;
			_counter.setTextFormat( format );
			_counter.defaultTextFormat = format;
			_counter.alpha = 0.15;
			_counter.y = 405;
			
			_updateCounter();
			
			// Register event listeners
			_btToggleSelection.addEventListener( MouseEvent.CLICK, _onClickToggleSelection );
			_poolData.addEventListener( MonsterPoolEvent.ADDED_MONSTER, _onAddedMonster );
			_poolData.addEventListener( MonsterPoolEvent.REMOVED_MONSTER, _onRemovedMonster );
			addEventListener( Event.ADDED_TO_STAGE, _onAddedToStage );
		}
		
		public function get poolData():MonsterPoolData
		{
			return _poolData;
		}
		
		override public function get panelTitle():String 
		{
			return "POOL " + _poolData.id;
		}
		
		private function _onClickToggleSelection(e:MouseEvent):void 
		{
			if ( !EditorContext.inst.isActiveToolPanel )
			{
				// SHOW
				EditorContext.inst.showToolPanel( EditorContext.TOOL_PANEL_MONSTER_SELECTION );
				
				_btToggleSelection.bgColor = 0x9a9a9a;
				_btToggleSelection.labelText = "HIDE MONSTERS";
			}
			else
			{
				// HIDE
				EditorContext.inst.hideCurrentToolPanel();
				
				_btToggleSelection.bgColor = 0x0090d9;
				_btToggleSelection.labelText = "SELECT MONSTERS";
			}
		}
		
		private function _onAddedToStage( e:Event ):void
		{
			_btToggleSelection.bgColor = 0x0090d9;
			_btToggleSelection.labelText = "SELECT MONSTERS";
			
			// Show selection panel as default
			_onClickToggleSelection( null );
			
			EditorContext.inst.activePool = _poolData;
		}
		
		private function _onAddedMonster(e:MonsterPoolEvent):void 
		{
			//Utils.Log( e.monsterData.name );
			
			// Create a monster panel
			var panel:Monster_CollapsedPanel = new Monster_CollapsedPanel( e.monsterData );
			_monsterListPanel.addChild( panel );
			
			panel.addEventListener( MouseEvent.CLICK, function ( e:MouseEvent ):void
			{
				_makeAsActive( panel );
			} );
			
			// Layout
			_monsterPanels.push( panel );
			_updateLayout_monsterPanels();
			_updateCounter();
		}
		
		private function _onRemovedMonster( e:MonsterPoolEvent ):void
		{
			// Find monster panel
			if ( _tempEditPanelForActive && _tempEditPanelForActive.monsterData.fullName == e.monsterData.fullName )
			{
				_makeAsActive( null );
			}
			
			for each ( var panel:Monster_Base in _monsterPanels )
			{
				if ( panel.monsterData.fullName == e.monsterData.fullName )
				{
					_monsterListPanel.removeChild( panel );
					_monsterPanels.splice( _monsterPanels.indexOf(panel), 1 );
					break;
				}
			}
			
			_updateLayout_monsterPanels();
			_updateCounter();
		}
		
		private function _makeAsActive( panel:Monster_CollapsedPanel ):void
		{
			if ( _tempEditPanelForActive )
			{
				_monsterPanels.splice( _monsterPanels.indexOf( _tempEditPanelForActive ), 1 );
				_monsterListPanel.removeChild( _tempEditPanelForActive );
				_tempEditPanelForActive = null;
				
				_monsterListPanel.addChild( _tempCollapsedPanelForActive );
				_monsterPanels.push( _tempCollapsedPanelForActive );
				_tempCollapsedPanelForActive = null;
			}
			
			// Find and replace with EditPanel
			var activePanel:Monster_EditPanel;
			
			if ( panel )
			{
				_monsterListPanel.removeChild( panel );
				_monsterPanels.splice( _monsterPanels.indexOf( panel ), 1 );
				
				activePanel = new Monster_EditPanel( panel.monsterData );
				_monsterListPanel.addChild( activePanel );
				_monsterPanels.push( activePanel );
			}
			
			_updateLayout_monsterPanels();
			
			// Store
			_tempEditPanelForActive = activePanel;
			_tempCollapsedPanelForActive = panel;
		}
		
		private function _updateLayout_monsterPanels():void
		{
			// Sort
			_monsterPanels.sort( function ( a:Monster_Base, b:Monster_Base ):int
			{
				return a.monsterData.index - b.monsterData.index;
			} );
			
			// Layout
			var currentY:Number = 0;
			var margin:Number = 5;
			
			for each ( var panel:Monster_Base in _monsterPanels )
			{
				panel.y = currentY;
				currentY += panel.panelHeight + margin;
			}
		}
		
		private function _updateCounter():void
		{
			_counter.text = _monsterPanels.length.toString() + "/" + MonsterPoolData.MAX_MONSTERS;
		}
		
	}

}