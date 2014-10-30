package 
{
	import com.greensock.plugins.AutoAlphaPlugin;
	import com.greensock.plugins.TweenPlugin;
	import customLevelEditor.CustomLevelEditor;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.Dictionary;
	import gridNav.MapViewer;
	import inventory.Inventory;
	import inventory.InventoryEvent;
	import inventory.InventoryManager;
	import inventory.Item;
	import inventory.ItemDetailPanel;
	import voteFollower.VoteFollowerPanel;
	import voting.VotingPanel;
	
	public class Main extends MovieClip implements IDotaAPI
	{
		// element details filled out by game engine
		public var gameAPI:Object;
		public var globals:Object;
		public var elementName:String;
		
		private var _tfTest:TextField;
		
		private var _mapViewer:MapViewer;
		
		// Modules
		private var _inventoryManager:InventoryManager;
		private var _customLevelEditor:CustomLevelEditor;
		private var _voteFollowerPanel:VoteFollowerPanel;
		
		public function Main():void
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			try
			{
				trace( "DotaHS GUI Initializing." );
				
				// TweenLite
				TweenPlugin.activate([AutoAlphaPlugin]);
				
				// Create modules
				addChild( _inventoryManager = new InventoryManager() );
				addChild( _customLevelEditor = new CustomLevelEditor() );
				addChild( _voteFollowerPanel = new VoteFollowerPanel() );
				
				// Test modules here!
			}
			catch ( e:Error )
			{
				Utils.LogError( e );
			}
		}
		
		// called by the game engine when this .swf has finished loading
		public function onLoaded():void
		{
			try {
				_log( "========================================" );
				_log( "  Initializing ..." );
				_log( "========================================" );
				
				// Show the UI
				visible = true;
				
				// Initialize modules
				_inventoryManager.onLoaded( this );
				_customLevelEditor.onLoaded( this );
				_voteFollowerPanel.onLoaded( this );
				
				var votingPanel:VotingPanel = new VotingPanel( gameAPI );
				addChild( votingPanel );
				votingPanel.x = 300;
				votingPanel.y = 200;
				
				// Register game event listeners
			//	gameAPI.SubscribeToGameEvent( "dotahs_map_info",	_onMapInfo );
			//	gameAPI.SubscribeToGameEvent( "dotahs_map_data",	_onMapData );
			} catch ( e:Error ) {
				Utils.LogError( e );
			}
		}
		
		private function _onMapInfo( eventData:Object ):void 
		{
			_log( "========================================" );
			_log( "  onMapInfo" );
			_log( "" );
			
			var minX:int = eventData.minX;
			var maxX:int = eventData.maxX;
			var minY:int = eventData.minY;
			var maxY:int = eventData.maxY;
			var mapWidth:int  = maxX - minX + 1;
			var mapHeight:int = maxY - minY + 1;
			
			_log( "x : [" + minX + ", " + maxX + "]" );
			_log( "y : [" + minY + ", " + maxY + "]" );
			_log( "Width  : " + mapWidth );
			_log( "Height : " + mapHeight );
			
			// Init the map viewer
			if ( !_mapViewer )
			{
				_mapViewer = new MapViewer();
				_mapViewer.x = 400;
				_mapViewer.y = 50;
				_mapViewer.scaleX = 2;
				_mapViewer.scaleY = 2;
				addChild( _mapViewer );
			}
			
			_mapViewer.updateBounds( minX, maxX, minY, maxY );
		}
		
		private function _onMapData( eventData:Object ):void 
		{
		//	_log( "map data[" + eventData.posY + "] - size : " + String(eventData.data).length );
			
			if ( !_mapViewer )
			{
				_log( "Map viewer is null! - posY : " + eventData.posY );
				return;
			}
			
			_log( "PRE UPDATE ROW" );
			_mapViewer.updateRow( eventData.posY, String(eventData.data) );
			_log( "POST UPDATE ROW" );
		}
		
		// called by the game engine after onLoaded and whenever the screen size is changed
		public function onScreenSizeChanged():void
		{
		}
		
		private function _log( ...rest ):void
		{
			Utils.Log( rest );
		}
		
		public function SubscribeToGameEvent( eventName:String, callback:Function ):void
		{
			gameAPI.SubscribeToGameEvent( eventName, callback );
		}
		
		public function SendServerCommand( command:String ):void
		{
			// command.length <= 512
			gameAPI.SendServerCommand( command );
		}
		
		public function get gameTime():Number
		{
		//	return globals.Game.GetGameTime();	// <= Will cause HANG! DO NOT USE IT.
			return globals.Game.Time();
		}
		
		public function get localPlayerID():int
		{
			return globals.Players.GetLocalPlayer();
		}
		
		public function get isLobbyLeader():Boolean
		{
		//	return false;
			return localPlayerID == 0;
		}
		
	}
	
}