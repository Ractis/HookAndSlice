package inventory 
{
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class InventoryEvent extends Event 
	{
		static public const INVENTORY_SWAP:String = "inventorySwap";
		static public const INVENTORY_DROP:String = "inventoryDrop";
		
		public var slotName1:String;
		public var slotName2:String;
		
		public function InventoryEvent( type:String ) 
		{
			super( type );
		}
		
	}

}