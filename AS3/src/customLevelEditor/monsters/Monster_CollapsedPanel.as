package customLevelEditor.monsters {
	import customLevelEditor.Constants;
	import customLevelEditor.EditorLabel;
	import customLevelEditor.MonsterData;
	import customLevelEditor.MonsterPortrait;
	import flash.display.Bitmap;
	import flash.display.Graphics;
	import flash.filters.GlowFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Monster_CollapsedPanel extends Monster_Base 
	{
		[Embed(source = "assets/LabelLevel.png")]	static private const LabelLevelImage:Class;
		
		public function Monster_CollapsedPanel( data:MonsterData ) 
		{
			super( data );
			
			// BG
			var g:Graphics = graphics;
			//g.beginFill( 0x00c5d7 );
			g.beginFill( 0xFFFFFF, 0.05 );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, 40 );
			g.endFill();
			
			// Portrait
			var portrait:MonsterPortrait = new MonsterPortrait( monsterData, 32, 37 );
			portrait.x = 19;
			portrait.y = 1;
			addChild( portrait );
			portrait.filters = [ new GlowFilter( 0xFFFFFF, 0.75, 6, 6, 1, 3 ) ];
			
			// NameLabel
			var lbName:TextField = new EditorLabel( monsterData.name, 20, 0xFFFFFF );
			lbName.x = 59;
			lbName.y = 1;
			lbName.autoSize = TextFieldAutoSize.NONE;
			lbName.width = 150;
			addChild( lbName );
			
			lbName = new EditorLabel( monsterData.fullName, 9, 0xFFFFFF );
			lbName.x = 60;
			lbName.y = 22;
			lbName.alpha = 0.5;
			lbName.autoSize = TextFieldAutoSize.NONE;
			lbName.width = 150;
			addChild( lbName );
			
			// Level
			var levelBox:Monster_Edit_LevelEditBox = new Monster_Edit_LevelEditBox( monsterData, true );
			levelBox.x = 217 + 50;
			levelBox.y = ( 40 - 24 ) / 2;
			addChild( levelBox );
			
			// Labels
			var label:Bitmap = new LabelLevelImage();
			label.x = 217;
			label.y = Math.floor( ( 40 - 9 ) / 2 );		// Fix for avoiding awful quality
			label.alpha = 0.7;
			addChild( label );
		}
		
		override public function get panelHeight():Number 
		{
			return 40;
		}
		
	}

}