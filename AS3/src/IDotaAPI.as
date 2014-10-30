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
		function get gameTime():Number;
		function get localPlayerID():int;
		function get isLobbyLeader():Boolean;
	}
	
}