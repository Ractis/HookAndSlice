package inventory 
{
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Slot extends Sprite 
	{
		static public const SLOT_WIDTH:Number = 44 + 8;
		static public const SLOT_HEIGHT:Number = 32 + 8;
		
		private var _item:Item;
		
		public function Slot() 
		{
			super();
			
			// Dummy texture
			graphics.beginFill( 0x555555 );
			graphics.lineStyle( 1, 0xDDDDDD, 1 );
			graphics.drawRect( 0, 0, SLOT_WIDTH, SLOT_HEIGHT );
			graphics.endFill();
		}
		
		public function addItem( item:Item ):void 
		{
			_item = item;
			addChild( item );
			
			_item.currentSlot = this;
			
			_item.x = SLOT_WIDTH / 2;
			_item.y = SLOT_HEIGHT / 2;
		}
		
		public function removeItem( item:Item ):Boolean 
		{
			if ( !contains( item ) )
			{
				Utils.Log( "Slot " + name + " doesn't contain Item[" + item.itemID + "]" );
				return false;
			}
			
			item.currentSlot = null;
			
			removeChild( item );
			_item = null;
			
			return true;
		}
		
		public function get isEmpty():Boolean { return _item == null; }
		
	}

}