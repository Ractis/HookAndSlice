package com.zedia.charts.donutchart {
	import flash.display.Sprite;

	/**
	 * @author dominic gelineau
	 * 
	 * This class basicaly creates a mask that is in the shape of a donut and adds wedges under it
	 * The code for the donut mask was translated from the ActionScript 2 found here:
	 * http://flash-creations.com/notes/dynamic_drawingapi.php
	 */
	public class DonutChart extends Sprite {
		private var _donutMask : Sprite;
		private var _wedgeHolder : Sprite;
		private var _backWedge : ChartWedge;
		private var _wedges : Vector.<ChartWedgeInfo>;
		private var _chartWedgeVector : Vector.<ChartWedge>;

		public function DonutChart(radius : Number, strokeWidth : Number, backColor : uint, wedges : Vector.<ChartWedgeInfo> = null) {
			_wedges = wedges;
			var TO_RADIANS : Number = Math.PI / 180;
			
			_donutMask = new Sprite();
			_donutMask.graphics.beginFill(0xff0000);
			var r1:int = radius;
			var r2:int = radius - strokeWidth;
			_donutMask.graphics.lineTo(r1, 0);
			var a:Number = 0.268;
			
			var endx:Number;
			var endy:Number;
			var ax:Number;
			var ay:Number;
			var i:int;
			
			for (i = 0; i < 12; i++) {
		    	endx = r1*Math.cos((i+1)*30*TO_RADIANS);
		    	endy = r1*Math.sin((i+1)*30*TO_RADIANS);
		    	ax = endx+r1*a*Math.cos(((i+1)*30-90)*TO_RADIANS);
		    	ay = endy+r1*a*Math.sin(((i+1)*30-90)*TO_RADIANS);
		    	_donutMask.graphics.curveTo(ax, ay, endx, endy);	
			}
			
			_donutMask.graphics.moveTo(0, 0);
			_donutMask.graphics.lineTo(r2, 0);
			
			for (i=12; i > 0; i--) {
				endx = r2*Math.cos((i-1)*30*TO_RADIANS);
				endy = r2*Math.sin((i-1)*30*TO_RADIANS);
				ax = endx+r2*(0-a)*Math.cos(((i-1)*30-90)*TO_RADIANS);
				ay = endy+r2*(0-a)*Math.sin(((i-1)*30-90)*TO_RADIANS);
				_donutMask.graphics.curveTo(ax, ay, endx, endy);     
   			}
			
			addChild(_donutMask);
			
			_wedgeHolder = new Sprite();
			addChild(_wedgeHolder);
			_wedgeHolder.mask = _donutMask;
			
			_backWedge = new ChartWedge(radius, 360, backColor);
			_wedgeHolder.addChild(_backWedge);
			
			var wedge:ChartWedge;
			_chartWedgeVector = new Vector.<ChartWedge>();
			if (_wedges != null){
				for (i=0; i < _wedges.length; i++){
					wedge = new ChartWedge(radius, _wedges[i].percent * 360, _wedges[i].color);
					_wedgeHolder.addChild(wedge);
					_chartWedgeVector.push(wedge);
					
					if (i != 0){
						wedge.rotation = _chartWedgeVector[i - 1].rotation + _chartWedgeVector[i - 1].arc;
					}
				}
			}			
			rotation = -90;		
		}
		
		public function destroy():void{
			
		}
	}
}