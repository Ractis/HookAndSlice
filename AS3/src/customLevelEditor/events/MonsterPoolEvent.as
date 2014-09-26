package customLevelEditor.events {
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterData;
	import flash.events.Event;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterPoolEvent extends Event 
	{
		static public const ADDED_MONSTER:String = "addedMonster";
		static public const REMOVED_MONSTER:String = "removedMonster";
		static public const UPDATE_WEIGHTS:String = "updateWeights";
		static public const CHANGED_ID:String = "changedId";
		static public const CHANGED_COLOR:String = "changedColor";
		
		public var monsterData:MonsterData;
		
		public function MonsterPoolEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new MonsterPoolEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("MonsterPoolEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}