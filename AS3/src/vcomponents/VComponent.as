package vcomponents 
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.utils.getDefinitionByName;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VComponent extends Sprite 
	{
		public var inst:Object;
		
		public function VComponent( type:String ) 
		{
			super();
			
			var newObjectClass:Class;
			try
			{
				newObjectClass = getDefinitionByName( type ) as Class;
			}
			catch ( error : ReferenceError )
			{
				trace( "[VComponent] " + type + " is not found" );
				return;
			}
			
			inst = new newObjectClass();
			addChild( inst as MovieClip );
		}
		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void 
		{
			if ( inst == null ) {
				super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			} else {
				inst.addEventListener(type, listener, useCapture, priority, useWeakReference);
			}
		}
		
		override public function get width():Number 
		{
			return super.width
		}
		
		override public function set width(value:Number):void 
		{
			if ( inst == null ) {
				super.width = value;
			} else {
				inst.width = value;
			}
		}
		
		override public function get height():Number 
		{
			return super.height;
		}
		
		override public function set height(value:Number):void 
		{
			if ( inst == null ) {
				super.height = value;
			} else {
				inst.height = value;
			}
		}
		
	}

}