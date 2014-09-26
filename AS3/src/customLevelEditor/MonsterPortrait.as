package customLevelEditor {
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLRequest;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterPortrait extends Sprite 
	{
		[Embed(source = "assets/slark_vert.jpg")]
		static private const DummyImage:Class;
		
		[Embed(source = "assets/attr_damage.png")]
		static private const DangerousImg:Class;
		
		private var _img:Loader;
		private var _portraitWidth:int;
		private var _portraitHeight:int;
		
		public function MonsterPortrait( monsterData:MonsterData, portraitWidth:Number, portraitHeight:Number ) 
		{
			super();
			
			_portraitWidth = portraitWidth;
			_portraitHeight = portraitHeight;
			
			// Dummy
			var dummyImg:Bitmap = new DummyImage();
			dummyImg.smoothing = true;
			dummyImg.width	= portraitWidth;
			dummyImg.height = portraitHeight;
			addChild( dummyImg );
			
			// Loader
			_img = new Loader();
			_img.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, function ( e:IOErrorEvent ):void { } );	// Just ignore IOError
			_img.contentLoaderInfo.addEventListener( Event.COMPLETE, _onCompleteImg );
			_img.load( new URLRequest( "images\\monsters\\" + monsterData.fullName + ".png" ) );
			
			// Dangerous icon
			if ( monsterData.isDangerous )
			{
				var icon:Bitmap = new DangerousImg();
				icon.width = portraitWidth / 3;
				icon.height = portraitWidth / 3;
				icon.alpha = 0.75;
				addChild( icon );
				icon.y = portraitHeight - icon.height;
			}
		}
		
		private function _onCompleteImg( e:Event ):void
		{
			try {
				_img.content.width = _portraitWidth;
				_img.content.height = _portraitHeight;
				addChildAt( _img, 1 );
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
	}

}