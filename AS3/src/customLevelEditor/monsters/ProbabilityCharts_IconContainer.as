package customLevelEditor.monsters {
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterData;
	import customLevelEditor.MonsterPoolData;
	import flash.display.Sprite;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ProbabilityCharts_IconContainer extends Sprite 
	{
		private var _bHorde:Boolean;
		private var _index:int;
		private var _poolData:MonsterPoolData;
		
		private var _iconMap:Dictionary = new Dictionary();	// MonsterData : CircleIcon
		
		private const OFFSET_Y:Number = 20;
		private const RADIUS:Number = 65;
		
		public function ProbabilityCharts_IconContainer( bHorde:Boolean, poolData:MonsterPoolData ) 
		{
			super();
			
			_bHorde = bHorde;
			_index = bHorde ? 3 : 0;
			_poolData = poolData;
			
			//------------------------------------------------------------
			// Event listeners
			//------------------------------------------------------------
			_poolData.addEventListener( MonsterPoolEvent.ADDED_MONSTER, _onAddedMonster );
			_poolData.addEventListener( MonsterPoolEvent.REMOVED_MONSTER, _onRemovedMonster );
			_poolData.addEventListener( MonsterPoolEvent.UPDATE_WEIGHTS, _onUpdateWeights );
		}
		
		private function _onAddedMonster(e:MonsterPoolEvent):void 
		{
			var icon:ProbabilityCharts_CircleIcon = new ProbabilityCharts_CircleIcon( e.monsterData );
			_iconMap[e.monsterData] = icon;
			
			addChildAt( icon, _poolData.monsters.indexOf( e.monsterData ) );
		}
		
		private function _onRemovedMonster(e:MonsterPoolEvent):void 
		{
			var icon:ProbabilityCharts_CircleIcon = _iconMap[e.monsterData];
			removeChild( icon );
		}
		
		private function _onUpdateWeights(e:MonsterPoolEvent):void 
		{
			var totalWeight:int = _poolData.getTotalWeightOf( _index );
			var currentPercent:Number = 0;
			
			for each ( var data:MonsterData in _poolData.monsters )
			{
				var percent:Number = data.getWeightOf( _index ) / totalWeight;
				var centerPercent:Number = currentPercent + ( percent / 2 );
				
				var theta:Number = ( ( centerPercent * 180 ) + 90 ) / 180 * Math.PI;
				var centerY:Number = Math.cos( theta ) * RADIUS - OFFSET_Y;
				var centerX:Number = -Math.sin( theta ) * RADIUS;
				
				if ( _bHorde ) centerY *= -1;
				
				var icon:ProbabilityCharts_CircleIcon = _iconMap[data];
				icon.x = centerX;
				icon.y = centerY;
				
				currentPercent += percent;
			}
		}
		
	}

}