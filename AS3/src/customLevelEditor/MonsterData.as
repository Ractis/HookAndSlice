package customLevelEditor {
	import customLevelEditor.events.MonsterEvent;
	import flash.events.EventDispatcher;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterData extends EventDispatcher
	{
		public var name:String;
		public var fullName:String;
		
		public var index:int;
		
		private var _color:uint;
		
		private var _weightNormal:int = 100;
		private var _weightHard:int = -1;
		private var _weightInsane:int = -1;
		private var _weightHordeNormal:int = -1;
		private var _weightHordeHard:int = -1;
		private var _weightHordeInsane:int = -1;
		
		private var _isFixedLevel:Boolean;
		private var _level:int;
		
		private var _isDangerous:Boolean;
		
		public function MonsterData( monsterObj:Object = null ) 
		{
			if ( monsterObj )
			{
				name = "#" + monsterObj.Name;
				fullName = monsterObj.Name;
				index = monsterObj.Index;
				
				if ( monsterObj.FixedLevel )
				{
					_isFixedLevel = true;
					_level = monsterObj.FixedLevel;
				}
				else
				{
					_isFixedLevel = false;
					_level = 1;
				}
				
				if ( monsterObj.Intensity )
				{
					_isDangerous = true;
				}
				else
				{
					_isDangerous = false;
				}
			}
			else
			{
				name = "KOBOLD";
				fullName = "npc_dota_neutral_kobold";
				index = -1;
				_isFixedLevel = false;
				_level = 1;
				_isDangerous = false;
			}
			_color = Math.random() * 0xFFFFFF;
		}
		
		public function get color():uint { return _color; }
		public function set color( value:uint ):void
		{
			_color = value;
			dispatchEvent( new MonsterEvent( MonsterEvent.CHANGED_COLOR ) );
		}
		
		public function generateKeyValuesString():String
		{
			var o:String = '';
			o += '\t\t\t"' + fullName + '"\n';
			o += '\t\t\t{\n';
			o += '\t\t\t\t"Weight"\t\t"' + weightNormal.toString() + ' ' + weightHard.toString() + ' ' + weightInsane.toString() + '"\n';
			o += '\t\t\t\t"WeightHorde"\t"' + weightHordeNormal.toString() + ' ' + weightHordeHard.toString() + ' ' + weightHordeInsane.toString() + '"\n';
			if ( !isFixedLevel ) {
				o += '\t\t\t\t"Level"\t\t\t"' + level.toString() + '"\n';
			}
			if ( isDangerous ) {
				o += '\t\t\t\t"Intensity"\t\t"1"\n';
			}
			o += '\t\t\t}\n';
			
			return o;
		}
		
		public function getWeightOf( index:int ):int
		{
			switch ( index )
			{
				case 0: return weightNormal;
				case 1: return weightHard;
				case 2: return weightInsane;
				case 3: return weightHordeNormal;
				case 4: return weightHordeHard;
				case 5: return weightHordeInsane;
			}
			
			throw new Error();
		}
		
		public function setWeightOf( index:int, newWeight:int ):void 
		{
			switch ( index )
			{
				case 0: _weightNormal		= newWeight; break;
				case 1: _weightHard			= newWeight; break;
				case 2: _weightInsane		= newWeight; break;
				case 3: _weightHordeNormal	= newWeight; break;
				case 4: _weightHordeHard	= newWeight; break;
				case 5: _weightHordeInsane	= newWeight; break;
				default: throw new Error();
			}
			
			// Fire event
			dispatchEvent( new MonsterEvent( MonsterEvent.CHANGED_WEIGHT ) );
		}
		
		public function isCustomWeight( index:int ):Boolean
		{
			switch ( index )
			{
				case 0: return true;
				case 1: return bCustomWeightHard;
				case 2: return bCustomWeightInsane;
				case 3: return bCustomWeightHordeNormal;
				case 4: return bCustomWeightHordeHard;
				case 5: return bCustomWeightHordeInsane;
			}
			
			throw new Error();
		}
		
		public function get bCustomWeightHard():Boolean { return _weightHard >= 0; }
		public function get bCustomWeightInsane():Boolean { return _weightInsane >= 0; }
		public function get bCustomWeightHordeNormal():Boolean { return _weightHordeNormal >= 0; }
		public function get bCustomWeightHordeHard():Boolean { return _weightHordeHard >= 0; }
		public function get bCustomWeightHordeInsane():Boolean { return _weightHordeInsane >= 0; }
		
		public function get weightNormal():int
		{
			return _weightNormal;
		}
		
		public function get weightHard():int
		{
			if ( bCustomWeightHard ) return _weightHard;
			else if ( bCustomWeightInsane ) return _average( weightNormal, weightInsane );
			else return weightNormal;
		}
		
		public function get weightInsane():int
		{
			if ( bCustomWeightInsane ) return _weightInsane;
			else return weightNormal;
		}
		
		public function get weightHordeNormal():int
		{
			if ( bCustomWeightHordeNormal ) return _weightHordeNormal;
			else return _weightNormal;
		}
		
		public function get weightHordeHard():int
		{
			if ( bCustomWeightHordeHard ) return _weightHordeHard;
			else if ( bCustomWeightHordeInsane ) return _average( weightHordeNormal, weightHordeInsane );
			else return weightHordeNormal;
		}
		
		public function get weightHordeInsane():int
		{
			if ( bCustomWeightHordeInsane ) return _weightHordeInsane;
			else return weightHordeNormal;
		}
		
		public function get isFixedLevel():Boolean
		{
			return _isFixedLevel;
		}
		
		public function get level():int
		{
			return _level;
		}
		
		public function set level( value:int ):void
		{
			if ( _isFixedLevel )
			{
				throw new Error( "FIXED LEVEL" );
			}
			
			_level = value;
			dispatchEvent( new MonsterEvent( MonsterEvent.CHANGED_LEVEL ) );
		}
		
		public function get isDangerous():Boolean
		{
			return _isDangerous;
		}
		
		private function _average( a:int, b:int ):int
		{
			return ( a + b ) / 2;
		}
		
	}

}