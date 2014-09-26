package customLevelEditor.events {
	import customLevelEditor.MonsterPoolData;
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class LevelDataEvent extends Event 
	{
		static public const ADDED_POOL:String = "addedPool";
		static public const REMOVED_POOL:String = "removedPool";
		
		public var poolData:MonsterPoolData;
		
		public function LevelDataEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new LevelDataEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("LevelDataEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}