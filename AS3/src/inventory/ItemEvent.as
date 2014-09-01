package inventory 
{
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ItemEvent extends Event 
	{
		static public const ITEM_PICKEDUP:String = "itemPickedup";
		static public const ITEM_DROPPED:String = "itemDropped";
		
		public var item:Item;
		
		public function ItemEvent( type:String, item:Item ) 
		{
			super( type );
			this.item = item;
		}
		
	}

}