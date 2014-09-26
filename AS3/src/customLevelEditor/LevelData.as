package customLevelEditor {
	import customLevelEditor.events.LevelDataEvent;
	import customLevelEditor.MonsterPoolData;
	import flash.events.EventDispatcher;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class LevelData extends EventDispatcher
	{
		private var _startingLevel:int = 1;
		private var _healthPercent:int = 100;
		private var _expPercent:int = 300;
		private var _densityPercent:int = 100;
		
		public var monsterPools:Vector.<MonsterPoolData> = new Vector.<MonsterPoolData>();
		
		public function LevelData() 
		{
			
		}
		
		public function get isReadyForPlay():Boolean
		{
			if ( monsterPools.length == 0 )
			{
				// NO MONSTER POOLS
				return false;
			}
			
			for each ( var pool:MonsterPoolData in monsterPools )
			{
				if ( !pool.isReadyForPlay )
				{
					return false;
				}
			}
			
			return true;
		}
		
		public function get startingLevel():int 
		{
			return _startingLevel;
		}
		
		public function set startingLevel(value:int):void 
		{
			_startingLevel = value;
		}
		
		public function get healthPercent():int 
		{
			return _healthPercent;
		}
		
		public function set healthPercent(value:int):void 
		{
			_healthPercent = value;
		}
		
		public function get expPercent():int 
		{
			return _expPercent;
		}
		
		public function set expPercent(value:int):void 
		{
			_expPercent = value;
		}
		
		public function get densityPercent():int 
		{
			return _densityPercent;
		}
		
		public function set densityPercent(value:int):void 
		{
			_densityPercent = value;
		}
		
		private function get _expMultiplier():Number
		{
			return Number(expPercent) / 100;
		}
		
		private function get _health():Number
		{
			return Number(healthPercent) / 100;
		}
		
		private function get _density():Number
		{
			return Number(densityPercent) / 100;
		}
		
		public function addPool( poolData:MonsterPoolData ):void
		{
			monsterPools.push( poolData );
			updatePoolProperties();
			
			// Fire event
			var event:LevelDataEvent = new LevelDataEvent( LevelDataEvent.ADDED_POOL );
			event.poolData = poolData;
			dispatchEvent( event );
		}
		
		public function generateKeyValuesString():String
		{
			var o:String = "";
			
			// Level Properties
			o += '\t"StartingLevel"\t\t\t\t\t"' + startingLevel + '"\n';
			o += '\t"ExpMultiplier"\t\t\t\t\t"' + _expMultiplier + '"\n';
			o += '\t"EnemyHPMultiplier"\t\t\t\t"' + _health + '"\n';
			o += '\t"DesiredEnemyDensity"\t\t\t"' + _density + '"\n';
			o += '\n';
			
			// ItemLevel
			o += '\t"BaseItemLevelPools"\n';
			o += '\t{\n';
			for ( var i:int = 0; i < monsterPools.length; i++ )
			{
				// 4 8 12 16 (20
				// 5 10 15 (20
				// 7 14 (20
				// 10 (20
				var itemLevel:int = Math.round( 20 / ( monsterPools.length + 1 ) * ( i + 1 ) );
				o += '\t\t"monster_pool_' + (i+1).toString() + '"\t"' + itemLevel + '"\n';
			}
			o += '\t}\n';
			o += '\n';
			
			// Monster Pools
			o += '\t"MonsterPools"\n';
			o += "\t{\n";
			for ( i = 0; i < monsterPools.length; i++ )
			{
				o += '\t\t"monster_pool_' + (i+1).toString() + '"\n';
				o += monsterPools[i].generateKeyValuesString();
			}
			o += "\t}\n";
			return o;
		}
		
		private function updatePoolProperties():void
		{
			for ( var k:String in monsterPools )
			{
				monsterPools[k].id = parseInt( k ) + 1;
				monsterPools[k].color = _randomColorAry[k];
			}
		}

		static private const _randomColorAry:Vector.<uint> = Vector.<uint>( [
			0x70ddff, 0x56baec, 0x2b78d2, 0x1e457a
		] );
		
		static private function _toColor( text:String ):uint
		{
			var rgb:Array = text.split( " " );
			return ( int(rgb[0]) << 16 ) + ( int(rgb[1]) << 8 ) + int(rgb[2]);
		}
		
	}

}