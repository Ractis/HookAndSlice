package customLevelEditor 
{
	import com.greensock.TweenLite;
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class EditorSimpleSlider extends Sprite 
	{
		static public const PRESET_LEVEL:String = "presetLevel";
		static public const PRESET_WEIGHT:String = "presetWeight";
		
		public var pixelsPerTick:int = 15;
		public var valueGainPerTick:int = 1;
		public var valueMin:int = 0;
		public var valueMax:int = 999999;
		
		private var _tfNumber:TextField;
		private var _tfSuffix:TextField;
		private var _sliderSign:DisplayObject;
		
		private var _valueGetter:Function;
		private var _valueSetter:Function;
		private var _autoUpdateText:Boolean;
		
		static private var _isDragging:Boolean = false;
		static private var _dragStartX:Number;
		static private var _dragStartValue:int;
		
		[Embed(source = "assets/SliderSign.png")]
		static private const SliderSignImg:Class;
		
		public function EditorSimpleSlider( panelWidth:Number, valueGetter:Function = null, valueSetter:Function = null, autoUpdateText:Boolean = false ) 
		{
			super();
			
			_valueGetter = valueGetter;
			_valueSetter = valueSetter;
			_autoUpdateText = autoUpdateText;
			
			//------------------------------------------------------------
			// BG
			//------------------------------------------------------------
			var g:Graphics = graphics;
			g.beginFill( 0xFFFFFF, 0.1 );
			g.drawRect( 0, 0, panelWidth, 24 );
			g.endFill();
			
			//------------------------------------------------------------
			// Number Display
			//------------------------------------------------------------
			_tfNumber = new EditorLabel( value.toString(), 16, 0xFFFFFF );
			_tfNumber.autoSize = TextFieldAutoSize.NONE;
			
			var format:TextFormat = _tfNumber.defaultTextFormat;
			format.align = TextFormatAlign.RIGHT;
			_tfNumber.setTextFormat( format );
			_tfNumber.defaultTextFormat = format;
			
			_tfNumber.y = 0.5;
			_tfNumber.width = panelWidth;
			_tfNumber.height = 24 - _tfNumber.y;
			
			addChild( _tfNumber );
			
			//------------------------------------------------------------
			// Slider Sign
			//------------------------------------------------------------
			_sliderSign = new SliderSignImg();
			addChild( _sliderSign );
			_sliderSign.y = 20;
			_sliderSign.alpha = 0;
		//	_sliderSign.scale9Grid = new Rectangle( 9, 3, 22, 2 );	// NO EFFECT
			_sliderSign.width = panelWidth;
			
			//------------------------------------------------------------
			// Add Event listeners
			//------------------------------------------------------------
			addEventListener( MouseEvent.ROLL_OVER, _onRollOver );
			addEventListener( MouseEvent.MOUSE_DOWN, _onMouseDown );
		}
		
		public function updateText():void
		{
			_tfNumber.text = value.toString();
		}
		
		public function set sliderPreset( value:String ):void
		{
			switch ( value )
			{
			case PRESET_WEIGHT:
				valueMin = 0;
				valueMax = 999999;
				valueGainPerTick = 5;
				pixelsPerTick = 15;
				break;
				
			case PRESET_LEVEL:
				valueMin = 1;
				valueMax = 99;
				valueGainPerTick = 1;
				pixelsPerTick = 30;
				break;
			}
		}
		
		public function set suffix( value:String ):void
		{
			if ( !_tfSuffix )
			{
				_tfSuffix = new EditorLabel( value, 14, 0xFFFFFF );
				_tfSuffix.x = _tfNumber.width;
				_tfSuffix.y = 0.5 + 1;
				_tfSuffix.height = 24 - _tfSuffix.y;
				addChild( _tfSuffix );
			}
			else
			{
				_tfSuffix.text = value;
			}
		}
		
		protected function get value():int
		{
			return _valueGetter();
		}
		
		protected function set value( v:int ):void
		{
			_valueSetter( v );
		}
		
		public function get panelHeight():Number
		{
			return 24;
		}
		
		private function _onMouseDown(e:MouseEvent):void 
		{
			// Start drag
			_isDragging = true;
			_dragStartX = e.stageX;
			_dragStartValue = value;
			
			stage.addEventListener( MouseEvent.MOUSE_MOVE, _onMouseDrag );
			stage.addEventListener( MouseEvent.MOUSE_UP, _onMouseUp );
		}
		
		private function _onMouseUp(e:MouseEvent):void 
		{
			stage.removeEventListener( MouseEvent.MOUSE_MOVE, _onMouseDrag );
			stage.removeEventListener( MouseEvent.MOUSE_UP, _onMouseUp );
			
			_isDragging = false;
		}
		
		private function _onMouseDrag(e:MouseEvent):void 
		{
			var diff:Number = e.stageX - _dragStartX;
		//	trace( diff );
			var ticks:int = Math.floor( diff / pixelsPerTick );
			value = Math.min( Math.max( _dragStartValue + ticks * valueGainPerTick, valueMin ), valueMax );
			
			if ( _autoUpdateText ) updateText();
		}
		
		private function _onRollOver(e:MouseEvent):void
		{
			if ( _isDragging ) return;
			
			TweenLite.killDelayedCallsTo( _fadeOut );
			TweenLite.killTweensOf( _sliderSign );
			TweenLite.to( _sliderSign, 0.25, { alpha:0.3 } );
			TweenLite.delayedCall( 1.5, _fadeOut );
		}
		
		private function _fadeOut( ...args ):void
		{
			TweenLite.to( _sliderSign, 0.5, { alpha:0.0 } );
		}
		
	}

}