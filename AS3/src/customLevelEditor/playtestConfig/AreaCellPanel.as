package customLevelEditor.playtestConfig 
{
	import customLevelEditor.ListViewCell;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class AreaCellPanel extends ListViewCell 
	{
		private var _areaID:int;
		private var _selected:Boolean;
		
		public function AreaCellPanel( areaID:int, areaName:String ) 
		{
			super();
			
			_areaID = areaID;
			
			lbTitle.text = areaName;
		}
		
		public function set selected( value:Boolean ):void
		{
			_selected = value;
			setBackgroundColor( _selected ? 0x0090d9 : 0xFFFFFF, _selected ? 0.75 : 0.05 );
		}
		
		public function get areaID():int
		{
			return _areaID;
		}
		
	}

}