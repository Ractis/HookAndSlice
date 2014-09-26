package customLevelEditor {
	import customLevelEditor.events.MonsterEvent;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterData;
	import flash.events.EventDispatcher;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class MonsterPoolData extends EventDispatcher
	{
		static public const MAX_MONSTERS:int = 5;
		
		public var monsters:Vector.<MonsterData> = new Vector.<MonsterData>();
		
		private var _id:uint;
		private var _color:uint = 0xFFFFFF;
		
		public function MonsterPoolData() 
		{
			
		}
		
		public function get isReadyForPlay():Boolean
		{
			for ( var i:int = 0; i < 6; i++ )
			{
				if ( getTotalWeightOf(i) <= 0 )
				{
					return false;
				}
			}
			
			return true;
		}
		
		public function addMonster( monsterObj:Object ):void
		{
			if ( monsters.length >= MAX_MONSTERS )
			{
				return;
			}
			
			var monster:MonsterData = new MonsterData( monsterObj );
			monsters.push( monster );
			monsters.sort( function ( a:MonsterData, b:MonsterData ):int {
				return a.index - b.index;
			} );
			updateColor();
			
			// Event listeners
			monster.addEventListener( MonsterEvent.CHANGED_WEIGHT, _onMonsterChangedWeight );
			
			// Fire event
			var event:MonsterPoolEvent = new MonsterPoolEvent( MonsterPoolEvent.ADDED_MONSTER );
			event.monsterData = monster;
			dispatchEvent( event );
			
			dispatchEvent( new MonsterPoolEvent( MonsterPoolEvent.UPDATE_WEIGHTS ) );
		}
		
		public function removeMonster( monsterObj:Object ):void
		{
			var monster:MonsterData;
			
			for ( var i:int = 0; i < monsters.length; i++ )
			{
				if ( monsters[i].fullName == monsterObj.Name )
				{
					monster = monsters.splice( i, 1 )[0];
					break;
				}
			}
			
			if ( !monster )
			{
				Utils.Log( "MonsterPoolData#removeMonster - Monster[" + monsterObj.Name + " not found." );
				return;
			}
			
			updateColor();
			
			// Event listeners
			monster.removeEventListener( MonsterEvent.CHANGED_WEIGHT, _onMonsterChangedWeight );
			
			// Fire event
			var event:MonsterPoolEvent = new MonsterPoolEvent( MonsterPoolEvent.REMOVED_MONSTER );
			event.monsterData = monster;
			dispatchEvent( event );
			
			dispatchEvent( new MonsterPoolEvent( MonsterPoolEvent.UPDATE_WEIGHTS ) );
		}
		
		public function updateColor():void
		{
			for ( var k:String in monsters )
			{
				monsters[k].color = _randomColorAry[k];
			}
		}
		
		public function getTotalWeightOf( index:int ):int
		{
			var total:int = 0;
			for each ( var data:MonsterData in monsters )
			{
				total += data.getWeightOf( index );
			}
			return total;
		}
		
		public function generateKeyValuesString():String
		{
			var o:String = "\t\t{\n";
			for each ( var data:MonsterData in monsters )
			{
				o += data.generateKeyValuesString();
			}
			o += "\t\t}\n";
			return o;
		}
		
		private function _onMonsterChangedWeight( e:MonsterEvent ):void
		{
			dispatchEvent( new MonsterPoolEvent( MonsterPoolEvent.UPDATE_WEIGHTS ) );
		}
		
		public function get id():uint { return _id; }
		public function set id( value:uint ):void
		{
			_id = value;
			dispatchEvent( new MonsterPoolEvent( MonsterPoolEvent.CHANGED_ID ) );
		}
		
		public function get color():uint { return _color; }
		public function set color( value:uint ):void
		{
			_color = value;
			dispatchEvent( new MonsterPoolEvent( MonsterPoolEvent.CHANGED_COLOR ) );
		}
		
		static private const _randomColorAry:Vector.<uint> = Vector.<uint>( [
			_toColor( "237 137 145" ),	_toColor( "150 111 255" ),	_toColor( "108 224 160" ),
			_toColor( "142 247 244" ),	_toColor( "92 185 254" ),	_toColor( "177 221 64" ),
			_toColor( "247 240 67" ),	_toColor( "245 134 101" ),	_toColor( "236 191 65" ),
			_toColor( "180 239 255" ),	_toColor( "0 192 78" ),		_toColor( "73 162 187" ),
			_toColor( "191 105 222" ),	_toColor( "44 213 100" ),	_toColor( "241 154 117" ),
			_toColor( "221 44 218" ),	_toColor( "0 110 218" ),	_toColor( "96 217 90" )
		] );
		
		static private function _toColor( text:String ):uint
		{
			var rgb:Array = text.split( " " );
			return ( int(rgb[0]) << 16 ) + ( int(rgb[1]) << 8 ) + int(rgb[2]);
		}
		
	}

}