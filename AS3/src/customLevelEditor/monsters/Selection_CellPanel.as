package customLevelEditor.monsters {
	import customLevelEditor.EditorContext;
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.net.URLRequest;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Selection_CellPanel extends Sprite 
	{
		private var _monsterObj:Object;
		private var _isInPool:Boolean = false;
		private var _overlay:Sprite;
		private var _removeIcon:DisplayObject;
		
		[Embed(source = "../assets/attr_damage.png")]
		static private const DangerousImg:Class;
		
		[Embed(source = "assets/RemoveFromPool.png")]
		static private const RemoveImg:Class;
		
		public function Selection_CellPanel( monsterData:Object ) 
		{
			super();
			
			_monsterObj = monsterData;
			
			var g:Graphics;
			
			//------------------------------------------------------------
			// BG for test
			//------------------------------------------------------------
			g = graphics;
			g.beginFill( Math.random() * 0xFFFFFF, 1 );
			g.drawRect( 0, 0, SelectionPanel.CELL_WIDTH, SelectionPanel.CELL_HEIGHT );
			g.endFill();
			
			//------------------------------------------------------------
			// Portrait
			//------------------------------------------------------------
			var img:Loader = new Loader();
			img.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, function ( e:IOErrorEvent ):void { } );	// Just ignore IOError
			img.contentLoaderInfo.addEventListener( Event.COMPLETE, function ( e:Event ):void
			{
				img.content.width = SelectionPanel.CELL_WIDTH;
				img.content.height = SelectionPanel.CELL_HEIGHT;
			} );
			img.load( new URLRequest( "images\\monsters\\" + monsterData.Name + ".png" ) );
		//	img.width = CELL_WIDTH;
		//	img.height = CELL_HEIGHT;
			addChild( img );
			
			//------------------------------------------------------------
			// Dangerous icon
			//------------------------------------------------------------
			if ( _monsterObj.Intensity )
			{
				var icon:Bitmap = new DangerousImg();
				icon.width = 16;
				icon.height = 16;
				icon.alpha = 0.75;
				addChild( icon );
				icon.y = SelectionPanel.CELL_HEIGHT - icon.height;
			}
			
			//------------------------------------------------------------
			// overlay
			//------------------------------------------------------------
			_overlay = new Sprite();
			
			g = _overlay.graphics;
			g.beginFill( 0, 0.75 );
			g.drawRect( 0, 0, SelectionPanel.CELL_WIDTH, SelectionPanel.CELL_HEIGHT );
			g.endFill();
			
			addChild( _overlay );
			_overlay.visible = false;
			
			_removeIcon = new RemoveImg();
			_overlay.addChild( _removeIcon );
			_removeIcon.alpha = 0.25;
			
			//------------------------------------------------------------
			// Register event listeners
			//------------------------------------------------------------
			addEventListener( MouseEvent.CLICK, _onClick );
			addEventListener( MouseEvent.MOUSE_DOWN, function ( e:MouseEvent ):void
			{
				// Just ignore about Ctrl key...
				// We should use CLIK instead of AS3/MouseEvent.
				Utils.Log( "MouseDowned" + ( e.ctrlKey /*Always false in Scaleform*/ ? " with CTRL" : "" ) + " : " + monsterData.Name );
			} );
		}
		
		public function notifyAddedToPool():void
		{
			if ( _isInPool ) return;
			
			_overlay.visible = true;
			_isInPool = true;
		}
		
		public function notifyRemovedFromPool():void
		{
			if ( !_isInPool ) return;
			
			_overlay.visible = false;
			_isInPool = false;
		}
		
		private function _onClick( e:MouseEvent ):void
		{
			Utils.Log( "Clicked : " + _monsterObj.Name );
				
			if ( !_isInPool ) {
				EditorContext.inst.addMonsterToActivePool( _monsterObj );
			} else {
				EditorContext.inst.removeMonsterFromActivePool( _monsterObj );
			}
		}
		
	}

}