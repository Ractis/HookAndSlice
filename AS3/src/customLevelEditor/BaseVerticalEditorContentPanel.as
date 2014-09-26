package customLevelEditor {
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class BaseVerticalEditorContentPanel extends Sprite 
	{
		public function BaseVerticalEditorContentPanel() 
		{
			super();
		}
		
		public function get panelTitle():String
		{
			// override me
			return "<null>";
		}
		
	}

}