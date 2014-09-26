package customLevelEditor.levels {
	import customLevelEditor.Constants;
	import customLevelEditor.EditorLabel;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterPoolData;
	import customLevelEditor.MonsterPortrait;
	import customLevelEditor.monsters.MonsterPoolEditPanel;
	import customLevelEditor.VerticalEditorPanel;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterPoolPanel extends Sprite 
	{
		private var _data:MonsterPoolData;
		
		private var _colorBar:Shape;
		private var _label:EditorLabel;
		private var _portraitMap:Dictionary = new Dictionary();		// MonsterData : Portrait
		
		private var _poolEditor:MonsterPoolEditPanel;
		
		public var editorWindow:VerticalEditorPanel;
		
		public function MonsterPoolPanel( poolData:MonsterPoolData ) 
		{
			super();
			
			_data = poolData;
			
			//------------------------------------------------------------
			// BG
			//------------------------------------------------------------
			var g:Graphics = graphics;
			//g.beginFill( 0x00c5d7 );
			g.beginFill( 0xFFFFFF, 0.05 );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, panelHeight );
			g.endFill();
			
			//------------------------------------------------------------
			// Color bar
			//------------------------------------------------------------
			_colorBar = new Shape();
			addChild( _colorBar );
			
			//------------------------------------------------------------
			// Label
			//------------------------------------------------------------
			_label = new EditorLabel( "Pool", 20, 0xFFFFFF );
			addChild( _label );
			_label.x = 11;
			_label.y = 17;
			
			//------------------------------------------------------------
			// Register event listener
			//------------------------------------------------------------
			addEventListener( MouseEvent.CLICK, _onClick );
			_data.addEventListener( MonsterPoolEvent.ADDED_MONSTER, _onAddedMonster );
			_data.addEventListener( MonsterPoolEvent.REMOVED_MONSTER, _onRemovedMonster );
			
			_data.addEventListener( MonsterPoolEvent.CHANGED_COLOR, _drawColorBar );
			_drawColorBar();
			
			_data.addEventListener( MonsterPoolEvent.CHANGED_ID, _updateLabel );
			_updateLabel();
		}
		
		private function _onClick(e:MouseEvent):void 
		{
			// Show the pool editor
			if ( !_poolEditor )
			{
				_poolEditor = new MonsterPoolEditPanel( _data );
			}
			
			editorWindow.pushContentPanel( _poolEditor );
		}
		
		private function _onAddedMonster( e:MonsterPoolEvent ):void
		{
			var portrait:MonsterPortrait = new MonsterPortrait( e.monsterData, 24, 28 );
			addChild( portrait );
			portrait.y = ( panelHeight - 28 ) / 2;
			
			_portraitMap[e.monsterData] = portrait;
			_updateLayout_monsters();
		}
		
		private function _onRemovedMonster( e:MonsterPoolEvent ):void
		{
			var portrait:MonsterPortrait = _portraitMap[e.monsterData];
			delete _portraitMap[e.monsterData];
			removeChild( portrait );
			_updateLayout_monsters();
		}
		
		private function _drawColorBar( e:Event = null ):void
		{
			var g:Graphics = _colorBar.graphics;
			g.clear();
			g.beginFill( _data.color );
			g.drawRect( 0, 0, Constants.MONSTER_COLOR_BAR_WIDTH, panelHeight );
			g.endFill();
		}
		
		private function _updateLabel( e:Event = null ):void
		{
			_label.text = "POOL " + _data.id;
		}
		
		private function _updateLayout_monsters():void
		{
			var interval:Number = 25;
			var currentX:Number = Constants.PANEL_WIDTH - interval;
			
			for ( var i:int = _data.monsters.length - 1; i >= 0; i-- )
			{
				_portraitMap[_data.monsters[i]].x = currentX;
				currentX -= interval;
			}
		}
		
		public function get panelHeight():Number
		{
			return 60;
		}
		
	}

}