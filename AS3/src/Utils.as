package  
{
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Utils 
	{
		
		public static function CreateLabel( text:String, fontType:String ):TextField
		{
			var tf:TextField = new TextField();
			tf.selectable = false;
			
			var format:TextFormat = new TextFormat();
			format.font = fontType;
			format.color = 0xDDDDDD;
			tf.defaultTextFormat = format;
			
			tf.text = text;
		//	tf.autoSize = TextFieldAutoSize.LEFT;
			tf.autoSize = TextFieldAutoSize.NONE;
			
			return tf;
		}
		
		public static function ItemNameToTexture( itemName:String ):DisplayObject
		{
			var textureName:String = itemName.replace( "item_", "images\\items\\" ) + ".png";
			
			var texture:Loader = new Loader();
			texture.load( new URLRequest( textureName ) );
			return texture;
		}
		
		static public function Log( ...rest ):void 
		{
			trace( "[DotaRPG] " + rest );
		}
		
	}

}