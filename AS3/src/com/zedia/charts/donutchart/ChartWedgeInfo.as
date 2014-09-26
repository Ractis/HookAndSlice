package com.zedia.charts.donutchart {
	/**
	 * @author dominic
	 */
	public class ChartWedgeInfo {
		public var color : uint;
		public var percent : Number;
		public function ChartWedgeInfo(newPercent:Number, newColor:uint){
			percent = newPercent;
			color = newColor;			
		}
	}
}