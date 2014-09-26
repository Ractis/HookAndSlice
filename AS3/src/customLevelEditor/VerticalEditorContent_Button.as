package customLevelEditor {
	import customLevelEditor.Constants;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.text.TextField;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VerticalEditorContent_Button extends Sprite 
	{
		static private const BUTTON_WIDTH:Number = 240;
		static private const BUTTON_HEIGHT:Number = 36;
		
		private var _bg:Shape;
		private var _label:TextField;
		
		public function VerticalEditorContent_Button( text:String ) 
		{
			super();
			
			//------------------------------------------------------------
			// MOVE
			//------------------------------------------------------------
			this.x = ( Constants.PANEL_WIDTH - BUTTON_WIDTH ) / 2;
			
			//------------------------------------------------------------
			// Draw the background
			//------------------------------------------------------------
			_bg = new Shape();
			addChild( _bg );
			bgColor = 0x0090d9;
			
			//------------------------------------------------------------
			// Create a label
			//------------------------------------------------------------
			_label = new EditorLabel( "", 12, 0xFFFFFF );
			addChild( _label );
			labelText = text;
		}
		
		public function set bgColor( value:uint ):void
		{
			var g:Graphics = _bg.graphics;
			g.clear();
			g.beginFill( value, 1 );
			g.drawRect( 0, 0, BUTTON_WIDTH, BUTTON_HEIGHT );
			g.endFill();
		}
		
		public function set labelText( value:String ):void
		{
			_label.text = value;
			_label.x = ( BUTTON_WIDTH - _label.textWidth ) / 2;
			_label.y = ( BUTTON_HEIGHT - _label.textHeight ) / 2 - 2;
		}
		
	}

}