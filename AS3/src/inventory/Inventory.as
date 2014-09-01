package inventory 
{
	import flash.display.Sprite;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Inventory extends Sprite 
	{
		private var _slotMap:Dictionary				= new Dictionary();
		private var _allSlots:Vector.<Slot>			= new Vector.<Slot>();
		private var _equipmentSlots:Vector.<Slot>	= new Vector.<Slot>();
		private var _consumableSlots:Vector.<Slot>	= new Vector.<Slot>();
		private var _backpackSlots:Vector.<Slot>	= new Vector.<Slot>();
		
		public function Inventory() 
		{
			super();
			
			var panelWidth:Number = 300;
			var offsetX:Number = 0;
			var offsetY:Number = 0;
			
			offsetY = 20;
			
			var _createSlot:Function = function ( slotName:String, posCenterX:Number, posCenterY:Number ):Slot
			{
				var slot:Slot = new Slot();
				slot.x = offsetX + posCenterX - Slot.SLOT_WIDTH / 2;
				slot.y = offsetY + posCenterY - Slot.SLOT_HEIGHT / 2;
				slot.name = slotName;
				
				_slotMap[slotName] = slot;
				_allSlots.push( slot );
				
				addChild( slot );
				
				return slot;
			}
			
			//------------------------------------------------------------
			// Add equipment slots
			var title:TextField = Utils.CreateLabel( "EQUIPMENTS", FontType.TitleFont );
			title.y = 15;
			title.width = panelWidth;
			title.setTextFormat( new TextFormat( null, 15, 0xCCCCCC, null, null, null, null, null, TextFormatAlign.CENTER ) );
			addChild( title );
			
			var intervalX:Number = Slot.SLOT_WIDTH + 20;
			_equipmentSlots.push( _createSlot( "slot_equipment_head", panelWidth / 2, 50 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_body", panelWidth / 2, 100 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_foot", panelWidth / 2, 150 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_accessory_1", panelWidth / 2 + intervalX, 75 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_accessory_2", panelWidth / 2 + intervalX, 125 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_weapon_1", panelWidth / 2 - intervalX, 75 ) );
			_equipmentSlots.push( _createSlot( "slot_equipment_weapon_2", panelWidth / 2 - intervalX, 125 ) );
			
			offsetY += 250;
			
			//------------------------------------------------------------
			// Add comsumable slots
			title = Utils.CreateLabel( "COMSUMABLES", FontType.TitleFont );
			title.y = offsetY - 55;
			title.width = panelWidth;
			title.setTextFormat( new TextFormat( null, 15, 0xCCCCCC, null, null, null, null, null, TextFormatAlign.CENTER ) );
			addChild( title );
			
			var numX:int = 4;
			intervalX = Slot.SLOT_WIDTH + 10;
			
			for ( var i:int = 0; i < numX; i++ )
			{
				var coord:Number = Number(i) - 1.5;
				_consumableSlots.push( _createSlot( "slot_consumable_" + String( i+1 ), panelWidth / 2 + coord * intervalX, 0 ) );
			}
			
			offsetY += 100;
			
			//------------------------------------------------------------
			// Add backpack slots
			title = Utils.CreateLabel( "BACKPACK", FontType.TitleFont );
			title.y = offsetY - 55;
			title.width = panelWidth;
			title.setTextFormat( new TextFormat( null, 15, 0xCCCCCC, null, null, null, null, null, TextFormatAlign.CENTER ) );
			addChild( title );
			
			numX = 5;
			var numY:int = 3;
			var backpackPanelWidth:Number = Slot.SLOT_WIDTH * numX;
			
			offsetX = ( panelWidth - backpackPanelWidth ) / 2 + ( Slot.SLOT_WIDTH / 2 );
			
			for ( var j:int = 0; j < numY; j++ )
			for ( i = 0; i < numX; i++ )
			{
				_backpackSlots.push( _createSlot( "slot_backpack_" + String( i + j * numX ), i * Slot.SLOT_WIDTH, j * Slot.SLOT_HEIGHT ) );
			}
			
			// Dummy texture
			graphics.beginFill( 0x0E0044, 0.75 );
			graphics.drawRect( 0, 0, panelWidth, 490 );
			graphics.endFill();
		}
		
		public function addItem( item:Item, slotName:String ):Boolean
		{
			var slot:Slot = _slotMap[slotName];
			
			if ( !slot ) {
				Utils.Log( "Slot \"" + slotName + "\" is not found" );
				return false;
			}
			
			slot.addItem( item );
			item.currentInventory = this;
			
			item.addEventListener( ItemEvent.ITEM_PICKEDUP, _onItemPickedup );
			item.addEventListener( ItemEvent.ITEM_DROPPED, _onItemDropped );
			
			return true;
		}
		
		public function removeItem( item:Item, slotName:String ):Boolean
		{
			var slot:Slot = _slotMap[slotName];
			
			if ( !slot ) {
				Utils.Log( "Slot \"" + slotName + "\" is not found" );
				return false;
			}
			
			if ( !slot.removeItem( item ) ) {
				return false;
			}
			
			item.currentInventory = null;
			
			item.removeEventListener( ItemEvent.ITEM_PICKEDUP, _onItemPickedup );
			item.removeEventListener( ItemEvent.ITEM_DROPPED, _onItemDropped );
			
			return true;
		}
		
		public function addItemToBackpack( item:Item, index:int ):Boolean
		{
			return addItem( item, "slot_backpack_" + String( index ) );
		}
		
		public function moveToEmptySlot( item:Item, filter:Array ):void
		{
			for each ( var slotName:String in filter )
			{
				var slot:Slot = _slotMap[slotName];
				if ( slot.isEmpty )
				{
					// Try swap
					var evt:InventoryEvent = new InventoryEvent( InventoryEvent.INVENTORY_SWAP );
					evt.slotName1 = item.currentSlot.name;
					evt.slotName2 = slot.name;
					
					Utils.Log( "Move to " + evt.slotName2 + " from " + evt.slotName1 );
					dispatchEvent( evt );
					
					return;
				}
			}
		}
		
		public function moveToEmptyBackpackSlot( item:Item ):void
		{
			for each ( var slot:Slot in _backpackSlots )
			{
				if ( slot.isEmpty )
				{
					// Try swap
					var evt:InventoryEvent = new InventoryEvent( InventoryEvent.INVENTORY_SWAP );
					evt.slotName1 = item.currentSlot.name;
					evt.slotName2 = slot.name;
					
					Utils.Log( "Move to " + evt.slotName2 + " from " + evt.slotName1 );
					dispatchEvent( evt );
					
					return;
				}
			}
		}
		
		private function _onItemDropped( e:ItemEvent ):void 
		{
			Utils.Log( "[AS3] onItemDropped : " + e.item.itemID );
			
			var item:Item = e.item;
			stage.removeChild( item );
			item.stopDrag();
			
			// Drop on the ground;
			var evt:InventoryEvent
			if ( !hitTestObject( item ) )
			{
				Utils.Log( "Drop the item[" + item.itemID + "] to ground" );
				
				evt = new InventoryEvent( InventoryEvent.INVENTORY_DROP );
				evt.slotName1 = item.lastSlot.name;
				dispatchEvent( evt );
			}
			else
			{
				// Try to move slot
				for each ( var slot:Slot in _allSlots )
				{
					if ( slot.hitTestPoint( stage.mouseX, stage.mouseY ) )
					{
						evt = new InventoryEvent( InventoryEvent.INVENTORY_SWAP );
						evt.slotName1 = e.item.lastSlot.name;
						evt.slotName2 = slot.name;
						
						if ( evt.slotName1 != evt.slotName2 )
						{
							Utils.Log( "Hit to " + slot.name );
							dispatchEvent( evt );
						}
						
						break;
					}
				}
			}
			
			_resetItemLocation( item );
		}
		
		private function _resetItemLocation( item:Item ):void 
		{
			item.lastSlot.addItem( item );
			item.lastSlot = null;
		}
		
		private function _onItemPickedup( e:ItemEvent ):void 
		{
			var item:Item = e.item;
			if ( !item.currentSlot ) return;
			
			Utils.Log( "[AS3] onItemPickedup : " + e.item.itemID );
			
			item.lastSlot = item.currentSlot;
			if ( item.currentSlot ) {
				item.currentSlot.removeItem( item );
			}
			stage.addChild( item );
			item.startDrag( true );
		}
		
	}

}