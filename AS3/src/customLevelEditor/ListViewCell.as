package customLevelEditor 
{
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ListViewCell extends Sprite 
	{
		protected var lbTitle:EditorLabel;
		
		private var _colorBar:Shape;
		
		private var _bgColor:uint = 0xFFFFFF;
		private var _bgAlpha:Number = 0.05;
		private var _barColor:uint = 0xFFFFFF;
		
		public function ListViewCell() 
		{
			super();
			
			//------------------------------------------------------------
			// Color bar
			//------------------------------------------------------------
			_colorBar = new Shape();
			addChild( _colorBar );
			
			//------------------------------------------------------------
			// Label
			//------------------------------------------------------------
			lbTitle = new EditorLabel( "", 16, 0xFFFFFF );
			addChild( lbTitle );
			lbTitle.x = 11;
			lbTitle.y = panelHeight / 2 - 11;
			
			_drawBackground();
			_drawColorBar();
		}
		
		public function get panelHeight():Number
		{
			return 40;
		}
		
		protected function setBackgroundColor( color:uint, alpha:Number ):void
		{
			_bgColor = color;
			_bgAlpha = alpha;
			_drawBackground();
		}
		
		protected function setBarColor( color:uint ):void
		{
			_barColor = color;
			_drawColorBar();
		}
		
		private function _drawBackground():void
		{
			var g:Graphics = graphics;
			g.clear();
			g.beginFill( _bgColor, _bgAlpha );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, panelHeight );
			g.endFill();
		}
		
		private function _drawColorBar():void
		{
			var g:Graphics = _colorBar.graphics;
			g.clear();
			g.beginFill( _barColor );
			g.drawRect( 0, 0, Constants.MONSTER_COLOR_BAR_WIDTH, panelHeight );
			g.endFill();
		}
		
	}

}