package customLevelEditor.monsters {
	import customLevelEditor.Constants;
	import customLevelEditor.events.MonsterEvent;
	import customLevelEditor.MonsterData;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Monster_Base extends Sprite 
	{
		private var _data:MonsterData;
		private var _colorBar:Shape;
		
		public function Monster_Base( $data:MonsterData ) 
		{
			super();
			
			_data = $data;
			
			_colorBar = new Shape();
			addChild( _colorBar );
			
			// Register event listener
			_data.addEventListener( MonsterEvent.CHANGED_COLOR, function ( e:MonsterEvent ):void {
				_drawColorBar();
			} );
			_drawColorBar();
		}
		
		private function _drawColorBar():void
		{
			var g:Graphics = _colorBar.graphics;
			g.clear();
			g.beginFill( _data.color );
			g.drawRect( 0, 0, Constants.MONSTER_COLOR_BAR_WIDTH, panelHeight );
			g.endFill();
		}
		
		public function get panelHeight():Number
		{
			// override me
			return 0;
		}
		
		public function get monsterData():MonsterData
		{
			return _data;
		}
		
	}

}