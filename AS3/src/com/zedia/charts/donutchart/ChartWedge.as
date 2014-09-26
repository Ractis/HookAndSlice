package com.zedia.charts.donutchart {
	import flash.display.Sprite;

	/**
	 * @author dominic gelineau
	 * 
	 * This class is based on Lee Brimelow Wedge class that can be found here
	 * http://code.google.com/p/leebrimelow/source/browse/trunk/as3/com/theflashblog/drawing/Wedge.as
	 * 
	 * I modified it so that every wedge is a display object so I guess I reverted it back from what Lee changed it
	 */
	public class ChartWedge extends Sprite {
		private var _arc : Number;

		public function ChartWedge(radius : Number, arc : Number, color : uint) {
			_arc = arc;
			var segAngle : Number;
            var angle:Number;
            var angleMid:Number;
            var numOfSegs:Number;
            var ax:Number;
            var ay:Number;
            var bx:Number;
            var by:Number;
            var cx:Number;
            var cy:Number;
            
            graphics.beginFill(color);
            graphics.moveTo(0, 0);
            
            if (Math.abs(arc) > 360) {
            	arc = 360;
            }
                        
            numOfSegs = Math.ceil(Math.abs(arc) / 45);
            segAngle = arc / numOfSegs;
            segAngle = (segAngle / 180) * Math.PI;
            angle = (0 / 180) * Math.PI;
                        
            ax = Math.cos(angle) * radius;
            ay = Math.sin(-angle) * radius;
                        
            graphics.lineTo(ax, ay);

            for (var i:int=0; i<numOfSegs; i++) {
            	angle += segAngle;
            	angleMid = angle - (segAngle / 2);
            	bx = Math.cos(angle) * radius;
           		by = Math.sin(angle) * radius;
            	cx = Math.cos(angleMid) * (radius / Math.cos(segAngle / 2));
                cy = Math.sin(angleMid) * (radius / Math.cos(segAngle / 2));
                graphics.curveTo(cx, cy, bx, by);
            }
                        
            // Close the wedge
            graphics.lineTo(0, 0);
			graphics.endFill();
		}

		public function get arc() : Number {
			return _arc;
		}
	}
}