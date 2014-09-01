package inventory 
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Item extends Sprite 
	{
		public var currentSlot:Slot;
		public var lastSlot:Slot;
		public var currentInventory:Inventory;
		
		private var _itemData:Object;
		private var _labelCharges:TextField;
		private var _detailPanel:ItemDetailPanel;
		private var _isDragging:Boolean = false;
		
		public function Item( itemData:Object ) 
		{
			super();
			
			_itemData = itemData;
			
			if ( itemData.itemID >= 0 )
			{
				var texture:DisplayObject = Utils.ItemNameToTexture( itemData.itemName );
				
				// (124 x 64)
				//  -> 44 x 32
				texture.x = -22;
				texture.y = -16;
				texture.scaleX = 0.5;
				texture.scaleY = 0.5;
				
				addChild( texture );
			}
			
			if ( itemData.itemCharges > 0 )
			{
				// Stackable item
				_labelCharges = Utils.CreateLabel( "", FontType.TextFontBold );
				_labelCharges.width = 44;
				_labelCharges.height = 32;
			//	_labelCharges.background = true;
			//	_labelCharges.backgroundColor = 0x333333;
				_labelCharges.mouseEnabled = false;
				
				addChild( _labelCharges );
				
				itemCharges = itemData.itemCharges;
			}
			
			// Dummy
			graphics.beginFill( 0x000055 );
			graphics.drawRect( -22, -16, 44, 32 );
			graphics.endFill();
			
			addEventListener( MouseEvent.ROLL_OVER,		_onMouseRollOver );
			addEventListener( MouseEvent.ROLL_OUT,		_onMouseRollOut );
			addEventListener( MouseEvent.MOUSE_DOWN,	_onMouseDown );
			addEventListener( MouseEvent.MOUSE_UP,		_onMouseUp );
			addEventListener( MouseEvent.DOUBLE_CLICK,	_onMouseDoubleClick );
			
			doubleClickEnabled = true;
		}
		
		private function _onMouseDoubleClick( e:MouseEvent ):void 
		{
			if ( isInBackpack )	currentInventory.moveToEmptySlot( this, suitableSlotNameList );
			else				currentInventory.moveToEmptyBackpackSlot( this );
		}
		
		public function kill():void
		{
			_detailPanel.hide();
		}
		
		private function _onMouseUp( e:MouseEvent ):void 
		{
			if ( _isDragging )
			{
				dispatchEvent( new ItemEvent( ItemEvent.ITEM_DROPPED, this ) );
				
				_isDragging = false;
			}
		}
		
		private function _onMouseDown( e:MouseEvent ):void 
		{
			_isDragging = true;
			
			dispatchEvent( new ItemEvent( ItemEvent.ITEM_PICKEDUP, this ) );
		}
		
		private function _onMouseRollOut( e:MouseEvent ):void 
		{
			if ( _detailPanel == null ) return;
			
			_detailPanel.hide();
		}
		
		private function _onMouseRollOver( e:MouseEvent ):void 
		{
			if ( _detailPanel == null ) {
				_detailPanel = new ItemDetailPanel( _itemData, this );
			}
			
			_detailPanel.show();
		}
		
		public static function _createTestItem():Item
		{
			// dotarpg_pickedup_item
			var itemData:Object = {
				itemID : -1,
				itemName : "item_blades_of_attack",
				itemCategory : "Weapon",
				itemLevel : 1,
				itemRarity : 0,
				itemCharges : 3,
				itemBaseProperties : "BonusDamage:9,BonusDamage:0,BonusDamage:0,",
				itemAdditionalProperties : ""
			};
			
			return new Item( itemData );
		}
		
		public function get itemID():int { return _itemData.itemID; }
		
		public function set itemCharges( charges:int ):void
		{
			_itemData.itemCharges = charges;
			
			_labelCharges.text = charges.toString();
			_labelCharges.x = 22 - _labelCharges.textWidth  - 3;
			_labelCharges.y = 16 - _labelCharges.textHeight - 2;
		}
		
		public function get isInBackpack():Boolean
		{
			if ( currentSlot )	return currentSlot.name.indexOf( "backpack" ) >= 0;
			else				return lastSlot.name.indexOf( "backpack" ) >= 0;
		}
		
		public function get suitableSlotNameList():Array
		{
			if ( !categoryToSuitableSlotMap )
			{
				categoryToSuitableSlotMap = new Dictionary();
				
				categoryToSuitableSlotMap["Weapon"]		= [ "slot_equipment_weapon_1", "slot_equipment_weapon_2" ];
				categoryToSuitableSlotMap["Helmet"]		= [ "slot_equipment_head" ];
				categoryToSuitableSlotMap["Body"]		= [ "slot_equipment_body" ];
				categoryToSuitableSlotMap["Boots"]		= [ "slot_equipment_foot" ];
				categoryToSuitableSlotMap["Gloves"]		= [ "slot_equipment_accessory_1", "slot_equipment_accessory_2" ];
				categoryToSuitableSlotMap["Accessory"]	= [ "slot_equipment_accessory_1", "slot_equipment_accessory_2" ];
				categoryToSuitableSlotMap["LargeAccessory"]	= categoryToSuitableSlotMap["Accessory"];
				categoryToSuitableSlotMap["Potion"]		= [ "slot_consumable_1", "slot_consumable_2", "slot_consumable_3", "slot_consumable_4" ];
			}
			
			return categoryToSuitableSlotMap[_itemData.itemCategory];
		}
		
		static private var categoryToSuitableSlotMap:Dictionary;
		
	}

}