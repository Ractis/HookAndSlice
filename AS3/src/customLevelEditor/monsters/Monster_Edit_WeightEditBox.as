package customLevelEditor.monsters
{
	import customLevelEditor.EditorSimpleSlider;
	import customLevelEditor.events.MonsterEvent;
	import customLevelEditor.MonsterData;
	import flash.display.Graphics;
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Monster_Edit_WeightEditBox extends EditorSimpleSlider 
	{
		private var _data:MonsterData;
		private var _index:int;
		
		public function Monster_Edit_WeightEditBox( difficulty:int, bHorde:Boolean, data:MonsterData ) 
		{
			_data = data;
			_index = difficulty + ( bHorde ? 3 : 0 );	// [ normal, hard, insane, hordeNormal, hordeHard, hordeInsane ]
			
			super( 40 );
			
			valueGainPerTick = 5;
			
			var g:Graphics = graphics;
			
			//------------------------------------------------------------
			// Draw a Tip
			//------------------------------------------------------------
			var color:uint;
			switch ( difficulty )
			{
				case 0: color = 0x40ff40; break;
				case 1: color = 0xffff40; break;
				case 2: color = 0xff4040; break;
				default: color = 0xFFFFFF; break;
			}
			
			g.beginFill( color, 0.5 );
			if ( true )//bHorde )
			{
				g.drawRect( 0, 0, 6, 6 );
			}
			else
			{
				// Thats a terrible thing... Source2's Scaleform does not support this function...
				g.drawTriangles( Vector.<Number>( [0, 0, 0, 8, 8, 0] ) );
			}
			g.endFill();
			
			//------------------------------------------------------------
			// Add Event listeners
			//------------------------------------------------------------
			addEventListener( Event.ADDED_TO_STAGE, _onAddedToStage );
			addEventListener( Event.REMOVED_FROM_STAGE, _onRemovedFromStage );
		}
		
		private function _onAddedToStage(e:Event):void
		{
			_data.addEventListener( MonsterEvent.CHANGED_WEIGHT, _onChangedWeight );
			_onChangedWeight();
		}
		
		private function _onRemovedFromStage(e:Event):void
		{
			_data.removeEventListener( MonsterEvent.CHANGED_WEIGHT, _onChangedWeight );
		}
		
		private function _onChangedWeight( e:MonsterEvent=null ):void
		{
			updateText();
		}
		
		override protected function get value():int 
		{
			return _data.getWeightOf( _index );
		}
		
		override protected function set value(v:int):void 
		{
			_data.setWeightOf( _index, v );
		}
		
	}

}