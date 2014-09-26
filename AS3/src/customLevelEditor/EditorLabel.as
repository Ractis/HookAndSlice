package customLevelEditor {
	import customLevelEditor.EditorLabel;
	import flash.text.AntiAliasType;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class EditorLabel extends TextField 
	{
		
		public function EditorLabel( text:String, size:Number, color:uint ) 
		{
			super();
			
			embedFonts = true;
			
			var format:TextFormat = new TextFormat( "editorFont", size, color );
			defaultTextFormat = format;
			embedFonts = true;
			antiAliasType = AntiAliasType.ADVANCED;
			this.selectable = false;
			this.text = text;
			autoSize = TextFieldAutoSize.LEFT;
			
			// Scaleform's localization system may replace the TextFormat.
			// So we need to re-assign it here.
			textColor = color;
			setTextFormat( format );
		}
		
	}

}