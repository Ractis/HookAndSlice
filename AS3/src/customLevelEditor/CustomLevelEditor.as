package customLevelEditor 
{
	import customLevelEditor.levels.LevelEditPanel;
	import customLevelEditor.monsters.SelectionPanel;
	import flash.display.Sprite;
	import flash.text.Font;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class CustomLevelEditor extends Sprite 
	{
		[Embed( source = "assets/Play-Regular.ttf",
				fontName = "editorFont",
				mimeType = "application/x-font",
				advancedAntiAliasing = "true",
				embedAsCFF = "false")]
		private const editorFont:Class;
		
		private var api:IDotaAPI;
		
		public function CustomLevelEditor() 
		{
			super();
			
			Font.registerFont( editorFont );
			
			// Initialize
			var selectMonsterPanel:SelectionPanel = new SelectionPanel();
			addChild( selectMonsterPanel );
			selectMonsterPanel.x = 600 - 10 - selectMonsterPanel.width;
			selectMonsterPanel.y = ( 768 - selectMonsterPanel.height ) / 2;
			EditorContext.inst.registerToolPanel( selectMonsterPanel, EditorContext.TOOL_PANEL_MONSTER_SELECTION );
			
			EditorContext.inst.createPlaytestConfigPanel();
			
			var levelEditor:LevelEditPanel = new LevelEditPanel();
				
			var editor:VerticalEditorPanel = new VerticalEditorPanel();
			levelEditor.editorWindow = editor;
			addChild( editor );
			editor.pushContentPanel( levelEditor );
			editor.x = 600;
		}
		
		public function onLoaded( api:IDotaAPI ):void
		{
			this.api = api;
			visible = false;
		
			EditorContext.inst.api = api;
			
			// Register event listeners
			api.SubscribeToGameEvent( "dotahs_show_leveleditor",	_onShowLevelEditor );
			api.SubscribeToGameEvent( "dotahs_hide_leveleditor",	_onHideLevelEditor );
		}
		
		private function _onShowLevelEditor( eventData:Object ):void 
		{
			visible = true;
		}
		
		private function _onHideLevelEditor( eventData:Object ):void 
		{
			visible = false;
		}
		
	}

}