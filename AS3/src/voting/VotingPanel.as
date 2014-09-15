package voting 
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.filters.GlowFilter;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import scaleform.clik.events.ButtonEvent;
	import vcomponents.VButton;
	import vcomponents.VComponent;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VotingPanel extends Sprite 
	{
		[Embed(source = "assets/fav_star.png")]		static private const FavStarImage:Class;
		[Embed(source = "assets/fav_heart.png")]	static private const FavHeartImage:Class;
		[Embed(source = "assets/vote_empty.png")]	static private const VoteEmptyImage:Class;
		[Embed(source = "assets/vote_yes.png")]		static private const VoteYesImage:Class;
		
		private var gameAPI:Object;
		private var _btnYes:VButton;
		private var _btnNo:VButton;
		
		public function VotingPanel( gameAPI:Object ) 
		{
			super();
			
			this.gameAPI = gameAPI;
			visible = false;
			
			// Background
			var bg:VComponent = new VComponent( "bg_overlayBox" );
			bg.width = 400;
			bg.height = 160;
			addChild( bg );
			
			var label:TextField = Utils.CreateLabel( "#dotahs_play_again", FontType.TextFont );
			var tf:TextFormat = new TextFormat();
			tf.size = 24;
			tf.align = TextFormatAlign.CENTER;
			tf.color = 0xEA7070;
			tf.font = FontType.TextFont;
			label.setTextFormat( tf );
			label.y = 30;
			label.width = 400;
			label.alpha = 0.9;
			label.filters = [ new GlowFilter() ];
			addChild( label );
			
			_btnYes = new VButton( "chrome_button_primary", "YES" );
			_btnYes.x = 125 + 4;
			_btnYes.y = 95 + 2;
			addChild( _btnYes );

			_btnNo = new VButton( "chrome_button_normal", "NO" );
			_btnNo.x = 275;
			_btnNo.y = 95;
			addChild( _btnNo );
			
			// Register event listeners
			_btnYes.addEventListener( ButtonEvent.CLICK, _onClickYes );
			_btnNo.addEventListener( ButtonEvent.CLICK, _onClickNo );
			
			// Register game events
			gameAPI.SubscribeToGameEvent( "dotahs_restart_vote_begin",	_onBeginVote );
			gameAPI.SubscribeToGameEvent( "dotahs_restart_vote_end",	_onEndVote );
		}
		
		private function _onBeginVote( eventData:Object ):void
		{
			_log( "========================================" );
			_log( "  onBeginVote" );
			_log( "" );
			
			_btnYes.enabled = true;
			_btnNo.enabled = true;
			visible = true;
		}
		
		private function _onEndVote( eventData:Object ):void
		{
			_log( "========================================" );
			_log( "  onEndVote" );
			_log( "" );
			
			visible = false;
		}
		
		private function _onClickYes( e:ButtonEvent ):void 
		{
			gameAPI.SendServerCommand( "dotahs_vote_yes" );
			_disableButtons();
		}
		
		private function _onClickNo( e:ButtonEvent ):void 
		{
			gameAPI.SendServerCommand( "dotahs_vote_no" );
			_disableButtons();
		}
		
		private function _disableButtons():void
		{
			_btnYes.enabled = false;
			_btnNo.enabled = false;
		}
		
		private function _log( ...rest ):void
		{
			Utils.Log( rest );
		}
		
	}

}