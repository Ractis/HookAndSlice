package customLevelEditor.monsters 
{
	import customLevelEditor.EditorLabel;
	import customLevelEditor.EditorSimpleSlider;
	import customLevelEditor.events.MonsterEvent;
	import customLevelEditor.MonsterData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Monster_Edit_LevelEditBox extends Sprite 
	{
		private var _data:MonsterData;
		
		private var _slider:EditorSimpleSlider;
		private var _label:EditorLabel;
		
		public function Monster_Edit_LevelEditBox( data:MonsterData, forceNonEditable:Boolean = false ) 
		{
			super();
			
			_data = data;
			
			var isEditable:Boolean = !forceNonEditable && !_data.isFixedLevel;
			
			if ( isEditable )
			{
				addChild( _slider = new EditorSimpleSlider( 28, _getLevel, _setLevel ) );
				_slider.valueMin = 1;
				_slider.valueMax = 99;
				_slider.pixelsPerTick *= 2;
			}
			else
			{
				_label = new EditorLabel( _getLevel().toString(), 16, _data.isFixedLevel ? 0xFF4000 : 0xFFFFFF );
				_label.autoSize = TextFieldAutoSize.NONE;
				
				_label.y = 0.5;
				_label.width = 28;
				_label.height = 24 - _label.y;
				
				addChild( _label );
			}
			
			//------------------------------------------------------------
			// Add Event listeners
			//------------------------------------------------------------
			addEventListener( Event.ADDED_TO_STAGE, _onAddedToStage );
			addEventListener( Event.REMOVED_FROM_STAGE, _onRemovedFromStage );
		}
		
		private function _getLevel():int
		{
			return _data.level;
		}
		
		private function _setLevel( value:int ):void
		{
			_data.level = value;
		}
		
		private function _onAddedToStage(e:Event):void
		{
			_data.addEventListener( MonsterEvent.CHANGED_LEVEL, _onChangedLevel );
			_onChangedLevel();
		}
		
		private function _onRemovedFromStage(e:Event):void
		{
			_data.removeEventListener( MonsterEvent.CHANGED_LEVEL, _onChangedLevel );
		}
		
		private function _onChangedLevel(e:MonsterEvent=null):void 
		{
			if ( _slider )
			{
				_slider.updateText();
			}
			if ( _label )
			{
				_label.text = _getLevel().toString();
			}
		}
		
	}

}