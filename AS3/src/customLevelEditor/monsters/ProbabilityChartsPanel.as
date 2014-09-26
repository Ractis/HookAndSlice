package customLevelEditor.monsters {
	import customLevelEditor.MonsterPoolData;
	import flash.display.Sprite;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class ProbabilityChartsPanel extends Sprite 
	{
		private var _poolData:MonsterPoolData;
		
		public function ProbabilityChartsPanel( poolData:MonsterPoolData ) 
		{
			super();
			
			_poolData = poolData;
			
			// Create all
			var chart:ProbabilityCharts_Chart;
			
			chart = new ProbabilityCharts_Chart( 0, false, _poolData );
			addChild( chart );
			
			chart = new ProbabilityCharts_Chart( 1, false, _poolData );
			addChild( chart );
			
			chart = new ProbabilityCharts_Chart( 2, false, _poolData );
			addChild( chart );
			
			chart = new ProbabilityCharts_Chart( 0, true, _poolData );
			addChild( chart );
			
			chart = new ProbabilityCharts_Chart( 1, true, _poolData );
			addChild( chart );
			
			chart = new ProbabilityCharts_Chart( 2, true, _poolData );
			addChild( chart );
			
			var iconContainer:ProbabilityCharts_IconContainer;
			
			iconContainer = new ProbabilityCharts_IconContainer( false, _poolData );
			addChild( iconContainer );
			
			iconContainer = new ProbabilityCharts_IconContainer( true, _poolData );
			addChild( iconContainer );
		}
		
	}

}