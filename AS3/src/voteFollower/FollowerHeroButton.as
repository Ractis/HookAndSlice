package voteFollower 
{
	import flash.display.Bitmap;
	import flash.display.Graphics;
	import flash.display.Loader;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.filters.BevelFilter;
	import flash.filters.DropShadowFilter;
	import flash.net.URLRequest;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class FollowerHeroButton extends Sprite 
	{
		[Embed(source = "assets/npc_dota_hero_follower.png")]
		static private const _dummyFollowerPortraitClass:Class;
		[Embed(source = "assets/FollowerAdded.png")]
		static private const _addedIconClass:Class;
		[Embed(source = "assets/FollowerCardOverlay.png")]
		static private const _cardOverlayClass:Class;
		[Embed(source = "assets/FollowerCardShadow.png")]
		static private const _cardShadowClass:Class;
		
		public static const PORTRAIT_WIDTH:int = 71;
		public static const PORTRAIT_HEIGHT:int = 94;
		
		private var _iconAdded:Bitmap;
		private var _img:Loader;
		private var _maskRoundRect:Shape;
		
		private var _votePanel:VoteFollowerPanel;
		
		private var _heroName:String = "DUMMY";
		
		public function FollowerHeroButton( votePanel:VoteFollowerPanel ) 
		{
			super();
			
			_votePanel = votePanel;
			
			// Shadow
			var shadow:Bitmap = new _cardShadowClass();
			var shadowCont:Sprite = new Sprite();
			shadowCont.mouseEnabled = false;
			shadowCont.mouseChildren = false;
			
			shadowCont.addChild( shadow );
			addChild( shadowCont );
			shadow.x = -7;
			shadow.y = -7;
			
			// Mask
			_maskRoundRect = new Shape();
			var g:Graphics = _maskRoundRect.graphics;
			g.beginFill( 0xFFFFFF );
			g.drawRoundRect( 0, 0, panelWidth, panelHeight, 20, 20 );
			g.endFill();
			
			// Create hero's portrait
			if ( VoteFollowerPanel.USE_DUMMY )
			{
				var dummyImg:Bitmap = new _dummyFollowerPortraitClass();
				addChild( dummyImg );
				addChild( _maskRoundRect );
				dummyImg.mask = _maskRoundRect;
			}
			
			// Bevel
			var bevel:Bitmap = new _cardOverlayClass();
			addChild( bevel );
			
			// Icon: Added
			_iconAdded = new _addedIconClass();
			addChild( _iconAdded );
			_iconAdded.x = -3;
			_iconAdded.y = 53;
			
			// Register event listeners
			addEventListener( MouseEvent.CLICK, _onClick );
			
			// reset state
			isSelected = false;
		}
		
		private function _onClick( e:MouseEvent ):void 
		{
			try
			{
				Utils.Log( "Clicked follower" );
				if ( isSelected )
				{
				//	Utils.Log( "Removing a follower" );
					_votePanel.removeFollower( _heroName );
				}
				else
				{
				//	Utils.Log( "Adding a follower" );
					_votePanel.addFollower( _heroName );
				}
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
		public function set heroName( value:String ):void
		{
			_heroName = value;
			
			_img = new Loader();
			_img.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, function ( e:IOErrorEvent ):void { } );	// Just ignore IOError
			_img.contentLoaderInfo.addEventListener( Event.COMPLETE, _onCompleteImg );
			_img.load( new URLRequest( "images\\heroes\\selection\\npc_dota_hero_" + value + ".png" ) );
		}
		
		private function _onCompleteImg( e:Event ):void
		{
			try {
				addChildAt( _img, 1 );
				addChild( _maskRoundRect );
				_img.mask = _maskRoundRect;
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
		public function get panelWidth():Number { return PORTRAIT_WIDTH; }
		public function get panelHeight():Number { return PORTRAIT_HEIGHT; }
		
		public function get isSelected():Boolean
		{
			return _iconAdded.visible;
		}
		public function set isSelected( value:Boolean ):void
		{
			_iconAdded.visible = value;
		}
		
	}

}