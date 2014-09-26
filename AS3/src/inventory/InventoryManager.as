package inventory
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class InventoryManager extends Sprite 
	{
		private var api:IDotaAPI;
		private var _itemMap:Dictionary = new Dictionary();
		private var _inventory:Inventory;
		
		public function InventoryManager() 
		{
			super();
			
			showInventory();
			
			addEventListener( MouseEvent.ROLL_OVER, _onMouseRollOver );
			addEventListener( MouseEvent.ROLL_OUT, _onMouseRollOut );
		}
		
		public function onLoaded( api:IDotaAPI ):void
		{
			this.api = api;
			
		//	visible = false;
			_inventory.visible = false;
			
			// Register event listeners
			api.SubscribeToGameEvent( "dotahs_clear_all_items",			_onClearAll );
			api.SubscribeToGameEvent( "dotahs_pickedup_item",			_onPickedupItem );
			api.SubscribeToGameEvent( "dotahs_dropped_item",			_onDroppedItem );
			api.SubscribeToGameEvent( "dotahs_add_item_to_slot",		_onAddItemToSlot );
			api.SubscribeToGameEvent( "dotahs_remove_item_from_slot",	_onRemoveItemFromSlot );
			api.SubscribeToGameEvent( "dotahs_change_item_charges",		_onChangeItemCharges );
			api.SubscribeToGameEvent( "dotahs_toggle_inventory",		_onToggleInventory );
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
		
		private function _onMouseRollOut( e:MouseEvent ):void 
		{
			_inventory.alpha = 0.5;
		}
		
		private function _onMouseRollOver( e:MouseEvent ):void 
		{
			_inventory.alpha = 1.0;
		}
		
		private function _onInventorySwap( e:InventoryEvent ):void 
		{
			api.SendServerCommand( "dotahs_inventory_swap " + e.slotName1 + " " + e.slotName2 );
		}
		
		private function _onInventoryDrop( e:InventoryEvent ):void 
		{
			api.SendServerCommand( "dotahs_inventory_drop " + e.slotName1 );
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
			
			_log( "Local Player ID = " + api.localPlayerID )
			_log( "Player ID = " + eventData.playerID );
			
			if ( eventData.playerID != api.localPlayerID ) return;
			
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
			
			if ( eventData.playerID != api.localPlayerID ) return;
			
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
		//	_log( "onToggleInventory" );
			
			if ( eventData.playerID == api.localPlayerID )
			{
				// Toggle Inventory
				_inventory.visible = !_inventory.visible;
			}
		}
		
		private function _log( ...rest ):void
		{
			Utils.Log( rest );
		}
		
	}

}