package customLevelEditor {
	import customLevelEditor.BaseVerticalEditorContentPanel;
	import customLevelEditor.EditorContext;
	import customLevelEditor.EditorLabel;
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VerticalEditorPanel extends Sprite 
	{
		[Embed(source = "assets/back.png")]	static private const BackImg:Class;
		[Embed(source = "assets/next.png")]	static private const NextImg:Class;
		
		private var _contentPanelStack:Vector.<BaseVerticalEditorContentPanel> = new Vector.<BaseVerticalEditorContentPanel>();
		private var _currentDepth:int = -1;
		
		private var _backButton:SimpleButton;
		private var _nextButton:SimpleButton;
		private var _lbTitle:EditorLabel;
		
		public function VerticalEditorPanel() 
		{
			super();
			
			//------------------------------------------------------------
			// Draw background
			//------------------------------------------------------------
			var g:Graphics = graphics;
			g.beginFill( 0x0, 0.5 );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, 768 );
			g.endFill();
			
			// Title
			g.beginFill( 0x0, 0.25 );
			g.drawRect( 0, 55, Constants.PANEL_WIDTH, 30 );
			g.endFill();
			
			//------------------------------------------------------------
			// Create mask
			//------------------------------------------------------------
			var mask:Shape = new Shape();
			g = mask.graphics;
			g.beginFill( 0 );
			g.drawRect( 0, 0, Constants.PANEL_WIDTH, 768 );
			g.endFill();
			addChild( mask );
			this.mask = mask;
			
			//------------------------------------------------------------
			// Create Label
			//------------------------------------------------------------
			_lbTitle = new EditorLabel( "", 14, 0xFFFFFF );
			addChild( _lbTitle );
			_lbTitle.y = 55 + 4;
			_lbTitle.alpha = 0.75;
			_lbTitle.autoSize = TextFieldAutoSize.NONE;
			_lbTitle.width = Constants.PANEL_WIDTH;
			_lbTitle.height = 30;
			var format:TextFormat = _lbTitle.defaultTextFormat;
			format.align = TextFormatAlign.CENTER;
			_lbTitle.defaultTextFormat = format;
			
			//------------------------------------------------------------
			// Create buttons
			//------------------------------------------------------------
			_backButton = _createButton( BackImg, onClickBack, 10, 10 );
			_nextButton = _createButton( NextImg, onClickNext, 20 + 36, 10 );
			
			_updateButtonStates();
		}
		
		public function get activeContentPanel():BaseVerticalEditorContentPanel
		{
			if ( _contentPanelStack.length > 0 ) {
				return _contentPanelStack[_currentDepth];
			}
			return null;
		}
		
		public function pushContentPanel( contentPanel:BaseVerticalEditorContentPanel ):void
		{
			if ( activeContentPanel )
			{
				removeChild( activeContentPanel );
				EditorContext.inst.hideCurrentToolPanel();
			}
			
			// Prune
			_contentPanelStack = _contentPanelStack.slice( 0, _currentDepth + 1 );
			
			// Push
			_contentPanelStack.push( contentPanel );
			addChild( contentPanel );
			_lbTitle.text = contentPanel.panelTitle;
			
			_currentDepth++;
			
			_updateButtonStates();
		}
		
		private function onClickBack( e:MouseEvent ):void
		{
			removeChild( activeContentPanel );
			EditorContext.inst.hideCurrentToolPanel();
			
			_currentDepth--;
			addChild( activeContentPanel );
			_lbTitle.text = activeContentPanel.panelTitle;
			
			_updateButtonStates();
		}
		
		private function onClickNext( e:MouseEvent ):void
		{
			removeChild( activeContentPanel );
			EditorContext.inst.hideCurrentToolPanel();
			
			_currentDepth++;
			addChild( activeContentPanel );
			_lbTitle.text = activeContentPanel.panelTitle;
			
			_updateButtonStates();
		}
		
		private function _updateButtonStates():void
		{
			_backButton.visible = _currentDepth > 0;
			_nextButton.visible = _currentDepth < ( _contentPanelStack.length - 1 );
		}
		
		private function _createButton( iconClass:Class, callback:Function, btnX:Number, btnY:Number ):SimpleButton
		{
			//------------------------------------------------------------
			// Hit Test
			//------------------------------------------------------------
			var hitbox:Shape = new Shape();
			hitbox.graphics.beginFill( 0 );
			hitbox.graphics.drawRect( -5, -5, 32 + 10, 32 + 10 );
			hitbox.graphics.endFill();
			
			//------------------------------------------------------------
			// Icon
			//------------------------------------------------------------
			var defaultState:Sprite = new Sprite();
			var defaultIcon:DisplayObject = _createIcon( iconClass );
			defaultIcon.alpha = 0.5;
			defaultState.addChild( defaultIcon );
			
			var activeState:Sprite = new Sprite();
			activeState.addChild( _createIcon( iconClass ) );
			
			//------------------------------------------------------------
			// Create a Button
			//------------------------------------------------------------
			var btn:SimpleButton = new SimpleButton( defaultState, activeState, activeState, hitbox );
			addChild( btn );
			btn.x = btnX;
			btn.y = btnY;
			
			btn.addEventListener( MouseEvent.CLICK, callback );
			
			return btn;
		}
		
		private function _createIcon( iconClass:Class ):DisplayObject
		{
			var icon:Bitmap = new iconClass();
			icon.smoothing = true;
			icon.width = 36;
			icon.height = 36;
			return icon;
		}
		
	}

}