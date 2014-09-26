package customLevelEditor.levels 
{
	import customLevelEditor.EditorSimpleSlider;
	import customLevelEditor.LevelData;
	import customLevelEditor.ListViewCell;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class LevelPropertyCellPanel extends ListViewCell 
	{
		public var slider:EditorSimpleSlider;
		
		public function LevelPropertyCellPanel( label:String, levelData:LevelData, propertyName:String, bPercent:Boolean ) 
		{
			super();
			
			lbTitle.text = label;
			
			slider = new EditorSimpleSlider( 40, function ():int { return levelData[propertyName]; }, function (v:int):void { levelData[propertyName] = v; }, true );
			addChild( slider );
			slider.x = 240;
			slider.y = ( panelHeight - slider.panelHeight ) / 2;
			
			if ( bPercent )
			{
				slider.sliderPreset = EditorSimpleSlider.PRESET_WEIGHT;
				slider.suffix = "%";
			}
			else
			{
				slider.sliderPreset = EditorSimpleSlider.PRESET_LEVEL;
			}
		}
		
		override public function get panelHeight():Number 
		{
			return 40;
		}
		
	}

}