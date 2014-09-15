package 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.Dictionary;
	import gridNav.MapViewer;
	import inventory.Inventory;
	import inventory.InventoryEvent;
	import inventory.Item;
	import inventory.ItemDetailPanel;
	import voting.VotingPanel;
	
	public class Main extends MovieClip 
	{
		// element details filled out by game engine
		public var gameAPI:Object;
		public var globals:Object;
		public var elementName:String;
		
		private var _tfTest:TextField;
		
		private var _itemMap:Dictionary = new Dictionary();
		private var _inventory:Inventory;
		private var _mapViewer:MapViewer;
		
		public function Main():void
		{
			showInventory();
			
			addEventListener( MouseEvent.ROLL_OVER, _onMouseRollOver );
			addEventListener( MouseEvent.ROLL_OUT, _onMouseRollOut );
		}
		
		private function _onMouseRollOut( e:MouseEvent ):void 
		{
			_inventory.alpha = 0.5;
		}
		
		private function _onMouseRollOver( e:MouseEvent ):void 
		{
			_inventory.alpha = 1.0;
		}
		
		// called by the game engine when this .swf has finished loading
		public function onLoaded():void
		{
			_log( "========================================" );
			_log( "  Initializing ..." );
			_log( "========================================" );
			
			// Show the UI
			visible = true;
		//	showInventory();
			_inventory.visible = false;
			
			var votingPanel:VotingPanel = new VotingPanel( gameAPI );
			addChild( votingPanel );
			votingPanel.x = 300;
			votingPanel.y = 200;
			
			// Register game event listeners
			gameAPI.SubscribeToGameEvent( "dotahs_clear_all_items",			_onClearAll );
			gameAPI.SubscribeToGameEvent( "dotahs_pickedup_item",			_onPickedupItem );
			gameAPI.SubscribeToGameEvent( "dotahs_dropped_item",			_onDroppedItem );
			gameAPI.SubscribeToGameEvent( "dotahs_add_item_to_slot",		_onAddItemToSlot );
			gameAPI.SubscribeToGameEvent( "dotahs_remove_item_from_slot",	_onRemoveItemFromSlot );
			gameAPI.SubscribeToGameEvent( "dotahs_change_item_charges",	_onChangeItemCharges );
			gameAPI.SubscribeToGameEvent( "dotahs_toggle_inventory",		_onToggleInventory );
			gameAPI.SubscribeToGameEvent( "dotahs_map_info",				_onMapInfo );
			gameAPI.SubscribeToGameEvent( "dotahs_map_data",				_onMapData );
		}
		
		private function _onInventorySwap( e:InventoryEvent ):void 
		{
			gameAPI.SendServerCommand( "dotahs_inventory_swap " + e.slotName1 + " " + e.slotName2 );
		}
		
		private function _onInventoryDrop( e:InventoryEvent ):void 
		{
			gameAPI.SendServerCommand( "dotahs_inventory_drop " + e.slotName1 );
		}
		
		private function _onClearAll( eventData:Object ):void
		{
			_log( "========================================" );
			_log( "  onClearAll" );
			_log( "" );
			
			// Reset items
			_itemMap = new Dictionary();
			
			// Reset intentory
			if ( _inventory ) {
				removeChild( _inventory );
			}
			
			_inventory = new Inventory();
			_inventory.visible = false;
			addChild( _inventory );
			_inventory.y = 50;
			
			_inventory.addEventListener( InventoryEvent.INVENTORY_SWAP, _onInventorySwap );
			_inventory.addEventListener( InventoryEvent.INVENTORY_DROP, _onInventoryDrop );
		}
		
		private function _onAddItemToSlot( eventData:Object ):void 
		{
			_log( "========================================" );
			_log( "  onAddItemToSlot" );
			_log( "" );
			
			_log( "Local Player ID = " + localPlayerID )
			_log( "Player ID = " + eventData.playerID );
			
			if ( eventData.playerID != localPlayerID ) return;
			
			var item:Item = _itemMap[eventData.itemID];
			if ( !item ) {
				_log( "Item[" + eventData.itemID + "] is null" );
				return;
			}
			
			_inventory.addItem( item, eventData.slotName );
		}
		
		private function _onRemoveItemFromSlot( eventData:Object ):void 
		{
			_log( "========================================" );
			_log( "  onRemoveItemFromSlot" );
			_log( "" );
			
			if ( eventData.playerID != localPlayerID ) return;
			
			var item:Item = _itemMap[eventData.itemID];
			if ( !item ) {
				_log( "Item[" + eventData.itemID + "] is null" );
				return;
			}
			
			_inventory.removeItem( item, eventData.slotName );
		}
		
		private function _onPickedupItem( eventData:Object ):void 
		{
			_log( "========================================" );
			_log( "  onPickedupItem" );
			_log( "" );
			
			_log( "Player ID : " + eventData.playerID );
			_log( "Item ID : " + eventData.itemID );
			_log( "Item name : " + eventData.itemName );
			
			var item:Item = new Item( eventData );
			_itemMap[eventData.itemID] = item;
		}
		
		private function _onDroppedItem( eventData:Object ):void 
		{
			_log( "========================================" );
			_log( "  onDroppedItem" );
			_log( "" );
			
			_log( "Player ID : " + eventData.playerID );
			_log( "Item ID : " + eventData.itemID );
			
			var item:Item = _itemMap[eventData.itemID];
			if ( !item ) {
				_log( "Item[" + eventData.itemID + "] is null" );
				return;
			}
			
			item.kill();
			_itemMap[eventData.itemID] = null;
		}
		
		private function _onChangeItemCharges( eventData:Object ):void
		{
			_log( "========================================" );
			_log( "  onChangeItemCharges" );
			_log( "" );
			
			_log( "Item ID : " + eventData.itemID );
			
			var item:Item = _itemMap[eventData.itemID];
			if ( !item ) {
				_log( "Item[" + eventData.itemID + "] is null" );
				return;
			}
			
			item.itemCharges = eventData.itemCharges;
		}
		
		private function _onToggleInventory( eventData:Object ):void
		{
			if ( eventData.playerID == localPlayerID )
			{
				// Toggle Inventory
				_inventory.visible = !_inventory.visible;
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
		
		private function showInventory():void 
		{
			// Create inventory
			_inventory = new Inventory();
			addChild( _inventory );
			_inventory.y = 50;
			
		//	_inventory.addItemToBackpack( Item._createTestItem(), 3 );
		//	_inventory.addItemToBackpack( Item._createTestItem(), 5 );
		//	_inventory.addItemToBackpack( Item._createTestItem(), 12 );
		}
		
		// called by the game engine after onLoaded and whenever the screen size is changed
		public function onScreenSizeChanged():void
		{
		}
		
		private function _log( ...rest ):void
		{
			Utils.Log( rest );
		}
		
		public function get localPlayerID():int
		{
			return globals.Players.GetLocalPlayer();
		}
		
	}
	
}