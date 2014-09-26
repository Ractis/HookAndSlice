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
	public class Monster_EditPanel extends Monster_Base 
	{
		[Embed(source = "assets/LabelWeight.png")]	static private const LabelWeightImage:Class;
		[Embed(source = "assets/LabelHorde.png")]	static private const LabelHordeImage:Class;
		[Embed(source = "assets/LabelLevel.png")]	static private const LabelLevelImage:Class;
		
		public function Monster_EditPanel( data:MonsterData ) 
		{
			super( data );
			
			var g:Graphics = graphics;
			g.beginFill( 0xFFFFFF, 0.15 );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, 120 );
			g.endFill();
			
			// Portrait
			var portrait:MonsterPortrait = new MonsterPortrait( monsterData, 64, 74 );
			portrait.x = 19;
			portrait.y = 6;
			addChild( portrait );
			portrait.filters = [ new GlowFilter( 0xFFFFFF, 0.75, 8, 8, 1, 3 ) ];
			
			// NameLabel
			var lbName:TextField = new EditorLabel( monsterData.name, 20, 0xFFFFFF );
			lbName.x = 14;
			lbName.y = 81;
			lbName.autoSize = TextFieldAutoSize.NONE;
			lbName.width = 200;
			addChild( lbName );
			
			lbName = new EditorLabel( monsterData.fullName, 9, 0xFFFFFF );
			lbName.x = 16;
			lbName.y = 102;
			lbName.alpha = 0.5;
			lbName.autoSize = TextFieldAutoSize.NONE;
			lbName.width = 200;
			addChild( lbName );
			
			// Weight EditBox
			var ebWeight:Monster_Edit_WeightEditBox;
			
			ebWeight = new Monster_Edit_WeightEditBox(0,false,monsterData);
			ebWeight.x = 148;
			ebWeight.y = 8;
			addChild( ebWeight );
			
			ebWeight = new Monster_Edit_WeightEditBox(1,false,monsterData);
			ebWeight.x = 198;
			ebWeight.y = 8;
			addChild( ebWeight );
			
			ebWeight = new Monster_Edit_WeightEditBox(2,false,monsterData);
			ebWeight.x = 248;
			ebWeight.y = 8;
			addChild( ebWeight );
			
			ebWeight = new Monster_Edit_WeightEditBox(0,true,monsterData);
			ebWeight.x = 148;
			ebWeight.y = 52;
			addChild( ebWeight );
			
			ebWeight = new Monster_Edit_WeightEditBox(1,true,monsterData);
			ebWeight.x = 198;
			ebWeight.y = 52;
			addChild( ebWeight );
			
			ebWeight = new Monster_Edit_WeightEditBox(2,true,monsterData);
			ebWeight.x = 248;
			ebWeight.y = 52;
			addChild( ebWeight );
			
			// Level
			var levelBox:Monster_Edit_LevelEditBox = new Monster_Edit_LevelEditBox( monsterData );
			levelBox.x = 217 + 50;
			levelBox.y = 98 - 8;
			addChild( levelBox );
			
			// Labels
			var label:Bitmap = new LabelWeightImage();
			label.x = 96;
			label.y = 16;
			label.alpha = 0.7;
			addChild( label );
			
			label = new LabelHordeImage();
			label.x = 96;
			label.y = 60;
			label.alpha = 0.7;
			addChild( label );
			
			label = new LabelLevelImage();
			label.x = 217;
			label.y = 98;
			label.alpha = 0.7;
			addChild( label );
		}
		
		override public function get panelHeight():Number 
		{
			return 120;
		}
		
	}

}