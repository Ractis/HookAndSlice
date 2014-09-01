package gridNav 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.geom.Rectangle;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MapViewer extends Sprite 
	{
		private var _minX:int;
		private var _minY:int;
		private var _gridWidth:int;
		private var _gridHeight:int;
		private var _bitmapData:BitmapData;
		private var _bitmap:Bitmap;
		
		public function MapViewer() 
		{
			super();
			
			// Test
			graphics.beginFill( 0x00FF00 );
			graphics.drawRect( 0, 0, 256, 256 );
			graphics.endFill();
		}
		
		public function updateBounds( minX:int, maxX:int, minY:int, maxY:int ):void
		{
			_minX = minX;
			_minY = minY;
			
			_gridWidth  = maxX - minX + 1;
			_gridHeight = maxY - minY + 1;
			
		//	if ( !_bitmapData || _bitmapData.width != gridWidth || _bitmapData.height != gridHeight )
		//	{
				_bitmapData = new BitmapData( _gridWidth, _gridHeight, false, 0xFF00FF );
		//	}
			
			if ( !_bitmap )
			{
				_bitmap = new Bitmap();
				addChild( _bitmap );
			}
			
			_bitmap.bitmapData = _bitmapData;
		}
		
		public function updateRow( posY:int, data:String ):void
		{
			// Aug.18 / 2014
			//
			// DON'T USE BitmapData.width/height. These properties are corrupted.
			
			if ( !_bitmapData )
			{
				Utils.Log( "(updating map) BitmapData is null" );
				return;
			}
			
			Utils.Log( "PRE CHECK WIDTH" );
			if ( data.length != _gridWidth )
			{
				Utils.Log( "(updating map) Row data size is incorrect! : rowSize = " + data.length + ", desiredSize = " + _bitmapData.width );
				return;
			}
			Utils.Log( "POST CHECK WIDTH" );
			
			var posYInImage:int = posY - _minY;
			Utils.Log( "(updating map) posYInImage = " + posYInImage );
			
			if ( posYInImage < 0 || posYInImage >= _gridHeight )
			{
				Utils.Log( "(updating map) PosY is invalid! : posY = " + posY );
				return;
			}
			
			// Update bitmap
			Utils.Log( "(updating map) row at : " + posY );
			
		//	_bitmapData.lock();
			
			for ( var i:int = 0; i < data.length; i++ )
			{
				var color:uint = 0xFF00FF;
				
				switch ( data.charAt(i) )
				{
				case "0":	color = 0x000000;	break;
				case "1":	color = 0xFFFFFF;	break;
				}
				
				Utils.Log( "pos = (" + i + ", " + posYInImage + ")" );
				_bitmapData.setPixel( i, posYInImage, color );
			//	graphics.beginFill( color, 1 );
			//	graphics.drawRect( i, posYInImage, 1, 1 );
			//	graphics.endFill();
			}
			
		//	_bitmapData.unlock( new Rectangle( 0, posYInImage, data.length, 1 ) );
		//	_bitmapData.unlock();
			Utils.Log( "UNLOCK" );
		}
		
	}

}