package customLevelEditor.playtestConfig 
{
	import customLevelEditor.ListViewCell;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class DifficultyCellPanel extends ListViewCell 
	{
		private var _difficulty:int;
		private var _selected:Boolean;
		
		public function DifficultyCellPanel( difficulty:int, label:String ) 
		{
			super();
			
			_difficulty = difficulty;
			
			lbTitle.text = label;
			
			setBarColor( difficultyColor );
		}
		
		public function set selected( value:Boolean ):void
		{
			_selected = value;
			setBackgroundColor( _selected ? difficultyColor : 0xFFFFFF, _selected ? 0.75 : 0.05 );
		}
		
		public function get difficulty():int
		{
			return _difficulty;
		}
		
		private function get difficultyColor():uint
		{
			switch ( _difficulty )
			{
				case 0: return 0x40ff40;
				case 1: return 0xffff40;
				case 2: return 0xff4040;
			}
			
			return 0x000000;
		}
		
	}

}