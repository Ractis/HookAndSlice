package customLevelEditor.monsters {
	import customLevelEditor.events.MonsterEvent;
	import customLevelEditor.MonsterData;
	import customLevelEditor.MonsterPortrait;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ProbabilityCharts_CircleIcon extends Sprite 
	{
		private var _data:MonsterData;
		
		private var _bgCircle:Shape;
		private var _maskPortrait:Shape;
		private var _portrait:MonsterPortrait;
		
		public function ProbabilityCharts_CircleIcon( monsterData:MonsterData ) 
		{
			super();
			
			_data = monsterData;
			
			var g:Graphics;
			
			//------------------------------------------------------------
			// BG
			//------------------------------------------------------------
			_bgCircle = new Shape();
			addChild( _bgCircle );
			
			//------------------------------------------------------------
			// Portrait
			//------------------------------------------------------------
			_maskPortrait = new Shape();
			addChild( _maskPortrait );
			g = _maskPortrait.graphics;
			g.beginFill( 0x0 );
			g.drawCircle( 0, 0, 12 );
			g.endFill();
			
			_portrait = new MonsterPortrait( _data, 24, 28 );
			addChild( _portrait );
			_portrait.mask = _maskPortrait;
			_portrait.x = -12;
			_portrait.y = -14;
			
			//------------------------------------------------------------
			// Filter
			//------------------------------------------------------------
		//	filters = [ new DropShadowFilter( 0 ) ];
			
			//------------------------------------------------------------
			// Event Listenrs
			//------------------------------------------------------------
			_data.addEventListener( MonsterEvent.CHANGED_COLOR, _onChangedColor );
			_onChangedColor();
		}
		
		private function _onChangedColor(e:MonsterEvent = null):void 
		{
			var g:Graphics = _bgCircle.graphics;
			g.beginFill( _data.color );
			g.drawCircle( 0, 0, 14 );
			g.endFill();
		}
		
	}

}