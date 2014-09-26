package customLevelEditor.events {
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterEvent extends Event 
	{
		static public const CHANGED_COLOR:String = "changedColor";
		static public const CHANGED_WEIGHT:String = "changedWeight";
		static public const CHANGED_LEVEL:String = "changedLevel";
		
		public function MonsterEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new MonsterEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("MonsterEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}