package vcomponents 
{
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VButton extends VComponent 
	{
		
		public function VButton( type:String, label:String ) 
		{
			super( type );
			
			if ( inst == null ) return;
			
			inst.label = label;
		}
		
		public function get enabled():Boolean
		{
			if ( inst == null ) return true;
			return inst.enabled;
		}
		
		public function set enabled( value:Boolean ):void
		{
			if ( inst == null ) return;
			inst.enabled = value;
		}
		
	}

}