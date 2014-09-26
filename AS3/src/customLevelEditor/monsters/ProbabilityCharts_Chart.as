package customLevelEditor.monsters {
	import com.zedia.charts.donutchart.ChartWedgeInfo;
	import com.zedia.charts.donutchart.DonutChart;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterData;
	import customLevelEditor.MonsterPoolData;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ProbabilityCharts_Chart extends Sprite 
	{
		private var _difficulty:int;
		private var _bHorde:Boolean;
		private var _index:int;
		private var _poolData:MonsterPoolData;
		private var _donut:DonutChart;
		
		private const OFFSET_y:Number = 20;
		
		public function ProbabilityCharts_Chart( difficulty:int, bHorde:Boolean, poolData:MonsterPoolData ) 
		{
			super();
			
			_difficulty = difficulty;
			_bHorde = bHorde;
			_index = difficulty + ( bHorde ? 3 : 0 );
			
			_poolData = poolData;
			
			// Create a mask
			var maskShape:Shape = new Shape();
			var g:Graphics = maskShape.graphics;
			g.beginFill( 0xffffff );
			g.drawRect( -120, _bHorde ? OFFSET_y : -OFFSET_y, 240, _bHorde ? 120 : -120 );
			g.endFill();
			
			mask = maskShape;
			addChild( maskShape );
			
			// Register event listener
			poolData.addEventListener( MonsterPoolEvent.UPDATE_WEIGHTS, _refresh );
			_refresh();
		}
		
		private function _refresh( ...args ):void
		{
			if ( _donut )
			{
				removeChild( _donut );
				_donut = null;
			}
			
			if ( _poolData.monsters.length == 0 )
			{
				return;
			}
			
			// Generate wedges
			var nSeparators:int = _poolData.monsters.length - 1;
			var separatorPercent:Number = 0.005;
			var normalizationFactor:Number = 0.5 - nSeparators * separatorPercent;
			
			var wedges:Vector.<ChartWedgeInfo> = new Vector.<ChartWedgeInfo>();
			var totalWeight:int = _poolData.getTotalWeightOf( _index );
			for each ( var data:MonsterData in _poolData.monsters )
			{
				var weight:int = data.getWeightOf( _index );
				wedges.push( new ChartWedgeInfo( weight / totalWeight * normalizationFactor, data.color ) );
				
				// Separator
				wedges.push( new ChartWedgeInfo( separatorPercent, 0x333333 ) );
			}
			
			// Generate donut chart
			_donut = new DonutChart( 90 + ( _difficulty ) * 15, 6, 0x333333, wedges );
			_donut.y = _bHorde ? OFFSET_y : -OFFSET_y
			_donut.rotation += _bHorde ? 90 : -90;
			_donut.scaleX = _bHorde ? -1 : 1;
			addChild( _donut );
		}
		
	}

}