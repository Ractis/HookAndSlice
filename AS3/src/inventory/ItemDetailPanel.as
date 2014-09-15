package inventory
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.text.TextField;
	
	public class ItemDetailPanel extends Sprite 
	{
		private var _owner:Item;
		private var _itemID:int;
		private var _tfItemName:TextField;
		private var _tfItemCategory:TextField;
		private var _tfItemLevel:TextField;
		private var _tfItemProperties:TextField;
		
		public function ItemDetailPanel( itemData:Object, owner:Item = null ) 
		{
			super();
			
			_itemID = itemData.itemID;
			_owner = owner;
			
			mouseEnabled = false;
			
			if ( _itemID >= 0 )
			{
				var texture:DisplayObject = Utils.ItemNameToTexture( itemData.itemName );
				
				// (124 x 64)
				//  -> 44 x 32
				texture.scaleX = 0.5;
				texture.scaleY = 0.5;
				
				addChild( texture );
			}
			
			// background
			graphics.beginFill( 0x222222 );
			graphics.drawRect( 0, 0, 200, 150 );
			graphics.endFill();
			
			_tfItemName = Utils.CreateLabel( "#DOTA_Tooltip_Ability_" + itemData.itemName, FontType.TitleFontBold );
			_tfItemCategory = Utils.CreateLabel( itemData.itemCategory.toUpperCase(), FontType.TitleFont );
			_tfItemProperties = Utils.CreateLabel( _generatePropertiesText( itemData ), FontType.TextFont );
			
			_tfItemName.x = 5;
			_tfItemName.y = 50;
			_tfItemCategory.x = 5;
			_tfItemCategory.y = 15;
			_tfItemProperties.x = 50;
			_tfItemProperties.y = 100;
			
			addChild( _tfItemName );
			addChild( _tfItemCategory );
			addChild( _tfItemProperties );
		}
		
		private function _generatePropertiesText( itemData:Object ):String 
		{
			var text:String = "";
			for each ( var property:Object in _deserializeProperties( itemData.itemBaseProperties as String ) )
			{
				text += property.key + " : " + String( property.value ) + "\n";
			}
			
			return text;
		}
		
		private function _deserializeProperties( serializedData:String ):Array 
		{
			var data:Array = new Array();
			
			var propertiesArray:Array = serializedData.split( ',' );
			for ( var i:uint = 0; i < propertiesArray.length; i++ )
			{
				if ( String(propertiesArray[i]).indexOf( ':' ) < 0 ) continue;
				
				var objectProperty:Array = propertiesArray[i].split( ':' );
				
				data.push( {
					key   : objectProperty[0],
					value : objectProperty[1]
				} );
			}
			
			return data;
		}
		
		public static function _createTestPanel():ItemDetailPanel
		{
			// dotahs_pickedup_item
			var itemData:Object = {
				itemID : -1,
				itemName : "item_blades_of_attack",
				itemCategory : "weapon",
				itemLevel : 1,
				itemRarity : 0,
				itemBaseProperties : "BonusDamage:9,BonusDamage:0,BonusDamage:0,",
				itemAdditionalProperties : ""
			};
			
			return new ItemDetailPanel( itemData );
		}
		
		public function show():void 
		{
			if ( stage ) return;
			
			_updatePosition();
			
			_owner.stage.addChild( this );
			
			addEventListener( Event.ENTER_FRAME, _onEnterFrame );
		}
		
		public function hide():void 
		{
			if ( stage == null ) return;
			
			removeEventListener( Event.ENTER_FRAME, _onEnterFrame );
			
			stage.removeChild( this );
		}
		
		private function _onEnterFrame( e:Event ):void 
		{
			_updatePosition();
		}
		
		private function _updatePosition():void 
		{
			var offsetX:Number = 25;
			var offsetY:Number = -55;
			var mousePos:Point = _owner.localToGlobal( new Point( _owner.mouseX, _owner.mouseY ) );
			this.x = mousePos.x + offsetX;
			this.y = mousePos.y + offsetY;
		}
		
	}

}