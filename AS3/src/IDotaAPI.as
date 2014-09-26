package  
{
	
	/**
	 * ...
	 * @author ractis
	 */
	public interface IDotaAPI 
	{
		function SubscribeToGameEvent( eventName:String, callback:Function ):void;
		function SendServerCommand( command:String ):void;
		function get localPlayerID():int;
	}
	
}