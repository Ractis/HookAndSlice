package customLevelEditor.events {
	import customLevelEditor.MonsterPoolData;
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class EditorContextEvent extends Event 
	{
		static public const CHANGED_ACTIVE_POOL:String = "changedActivePool";
		
		public var oldActivePool:MonsterPoolData;
		
		public function EditorContextEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new EditorContextEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("EditorContextEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}