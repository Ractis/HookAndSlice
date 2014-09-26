package customLevelEditor 
{
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ListView extends Sprite 
	{
		public var marginY:Number = 5;
		
		protected var cells:Vector.<ListViewCell> = new Vector.<ListViewCell>();
		
		public function ListView() 
		{
			super();
			
		}
		
		public function appendCell( cell:ListViewCell ):void
		{
			addChild( cell );
			cells.push( cell );
			
			updateLayout();
		}
		
		public function updateLayout():void
		{
			var currentY:Number = 0;
			
			for each ( var cell:ListViewCell in cells )
			{
				cell.y = currentY;
				currentY += cell.panelHeight + marginY;
			}
		}
		
	}

}