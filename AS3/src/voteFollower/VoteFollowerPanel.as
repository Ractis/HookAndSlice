package voteFollower 
{
	import com.greensock.TweenLite;
	import flash.display.Bitmap;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filters.GlowFilter;
	import flash.geom.Matrix;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class VoteFollowerPanel extends Sprite 
	{
		static public const USE_DUMMY:Boolean = false;
		
		static public const GRID_DIM_X_PER_ATTR:int = 2;
		static public const GRID_MARGIN:int = 8;
		static public const GRID_PADDING:int = 24 - GRID_MARGIN;
		
		static public const HEADER_HEIGHT:Number = 45;
		static public const FOOTER_HEIGHT:Number = 60;
		
		private var api:IDotaAPI;
		
		private var _grid:Sprite;
		
		private var _strHeroes:Array = new Array();
		private var _agiHeroes:Array = new Array();
		private var _intHeroes:Array = new Array();
		
		private var _strCells:Vector.<FollowerHeroButton> = new Vector.<FollowerHeroButton>();
		private var _agiCells:Vector.<FollowerHeroButton> = new Vector.<FollowerHeroButton>();
		private var _intCells:Vector.<FollowerHeroButton> = new Vector.<FollowerHeroButton>();
		private var _cellMap:Dictionary = new Dictionary();
		
		private var _heroesSelected:Array = new Array();
		
		private var _numMaxBots:int;
		private var _numBots:int;
		
		private var _isInitialized:Boolean = false;
		
		private var _footerOffsetY:Number;
		private var _labelMaxBots:TextField;
		private var _labelBots:TextField;
		
		private var _btnAccept:Sprite;
		private var _btnDecline:Sprite;
		private var _labelSuggester:TextField;
		
		private var _labelTimer:TextField;
		private var _followerSelectionStartTime:Number = 0;
		private var _followerSelectionEndTime:Number = 0;
		private var _followerSelectionIsActive:Boolean = false;
		
		[Embed(source = "assets/FollwerAccept.png")]	static private const _imgAcceptButtonClass:Class;
		[Embed(source = "assets/FollwerDecline.png")]	static private const _imgDeclineButtonClass:Class;
		
		public function VoteFollowerPanel() 
		{
			super();
			
			_grid = new Sprite();
			addChild( _grid );
			
			// Draw background
			var nColumn:int = GRID_DIM_X_PER_ATTR * 3;
			var nRow:int = 2;
			var panelWidth:Number = GRID_PADDING * 2 + GRID_MARGIN * (nColumn + 1) + FollowerHeroButton.PORTRAIT_WIDTH * nColumn;
			var gridHeight:Number = GRID_PADDING * 2 + GRID_MARGIN * (nRow + 1) + FollowerHeroButton.PORTRAIT_HEIGHT * nRow;
			var panelHeight:Number = HEADER_HEIGHT + FOOTER_HEIGHT + gridHeight;
			
			_footerOffsetY = panelHeight - FOOTER_HEIGHT;
			
			var g:Graphics = graphics;
			g.beginFill( 0x000000, 0.85 );
			g.drawRect( 0, 0, panelWidth, HEADER_HEIGHT );
			g.endFill();
			
			var mat:Matrix = new Matrix();
			mat.createGradientBox( panelWidth + 200, gridHeight + 200, 0, -100, -100 + HEADER_HEIGHT );
			g.beginGradientFill( "radial", [0x3d3d3d, 0x111111], [0.8, 0.8], [0, 255], mat );
			g.drawRect( 0, HEADER_HEIGHT, panelWidth, gridHeight );
			g.endFill();
			
			g.beginFill( 0x000000, 0.85 );
			g.drawRect( 0, _footerOffsetY, panelWidth, FOOTER_HEIGHT );
			g.endFill();
			
			// Layout
			y = 75;
			x = ( 1024 - panelWidth ) / 2;
			
			// Window title
			var title:TextField = Utils.CreateLabel( "SELECT FOLLOWERS", FontType.TitleFontBold, function ( format:TextFormat ):void
			{
				format.size = 18;
			} );
			title.autoSize = TextFieldAutoSize.LEFT;
			title.x = 20;
			title.y = 11;
			title.alpha = 0.95;
			addChild( title );
			title.filters = [new GlowFilter( 0x0080ff, 0.5 )];
			
			// Buttons
			_btnAccept = _createButton( _imgAcceptButtonClass, "LET'S GO!" );
			_btnDecline = _createButton( _imgDeclineButtonClass, "NO THANKS" );
			
			_btnAccept.visible = false;
			
			// Suggester msg
			_labelSuggester = Utils.CreateLabel( "Lobby leader selects followers.", FontType.TextFont,function ( format:TextFormat ):void
			{
				format.size = 16;
			} );
			_labelSuggester.autoSize = TextFieldAutoSize.LEFT;
			_labelSuggester.x = panelWidth - _labelSuggester.textWidth - 25;
			_labelSuggester.y = _footerOffsetY + 18;
			_labelSuggester.alpha = 0.75;
			addChild( _labelSuggester );
			_labelSuggester.visible = false;
			
			// Timer
			_labelTimer = Utils.CreateLabel( "0:00", FontType.TextFont, function ( format:TextFormat ):void
			{
				format.size = 18;
			} );
			_labelTimer.autoSize = TextFieldAutoSize.LEFT;
			_labelTimer.x = panelWidth - _labelTimer.textWidth - 25;
			_labelTimer.y = 11;
			_labelTimer.alpha = 0.8;
			addChild( _labelTimer );
			
			addEventListener( Event.ENTER_FRAME, _onTickFollowerSelectionTimer );
			
			// Test
			if ( USE_DUMMY )
			{
				_onFollowerInfoBegin( { numStr:3, numAgi:3, numInt:3 } );
				_cellMap["DUMMY"] = _strCells[0];
				_followerSelectionIsActive = true;
				
				_makeMeAsSuggester();
			}
			numMaxBots = 5;
			numBots = 0;
		}
		
		private function _onTickFollowerSelectionTimer(e:Event):void 
		{
			if ( !_followerSelectionIsActive ) return;
			if ( !api ) return;
			
			var currentTime:Number = api.gameTime;
			var remainingTime:Number = _followerSelectionEndTime - currentTime;
			
			if ( remainingTime <= 0 )
			{
				// Selection has been ended!
				remainingTime = 0;
				_onClickExit( null );
			}
			
			// Update the label
			var secRemaining:int = Math.ceil( remainingTime );
			_labelTimer.text = "0:" + ( secRemaining < 10 ? "0" : "" ) + secRemaining;
		}
		
		public function onLoaded( api:IDotaAPI ):void
		{
			this.api = api;
			
			TweenLite.set( this, { autoAlpha:0 } );
			
			api.SubscribeToGameEvent( "dotahs_follower_info_begin",	_onFollowerInfoBegin );
			api.SubscribeToGameEvent( "dotahs_follower_info",		_onFollowerInfo );
			api.SubscribeToGameEvent( "dotahs_follower_info_end",	_onFollowerInfoEnd );
			api.SubscribeToGameEvent( "dotahs_follower_approved",	_onApprovedFollower );
			api.SubscribeToGameEvent( "dotahs_follower_vote_end",	_onVotingEnd );
		}
		
		private function _onFollowerInfoBegin( eventData:Object ):void
		{
			try {
				if ( !_isInitialized )
				{
					_setNumHeroes( eventData.numStr, eventData.numAgi, eventData.numInt );
				}
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
		private function _onFollowerInfo( eventData:Object ):void
		{
			try {
				if ( !_isInitialized )
				{
					switch ( eventData.attribute )
					{
						case "str": _strHeroes.push( eventData.heroName ); break;
						case "agi": _agiHeroes.push( eventData.heroName ); break;
						case "int": _intHeroes.push( eventData.heroName ); break;
					}
				}
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
		private function _onFollowerInfoEnd( eventData:Object ):void
		{
			try {
				if ( !_isInitialized )
				{
					_strHeroes.sort();
					_agiHeroes.sort();
					_intHeroes.sort();
					
					var updateCells:Function = function ( heroes:Array, cellArray:Vector.<FollowerHeroButton> ):void
					{
						for ( var i:int = 0; i < cellArray.length; i++ )
						{
							cellArray[i].heroName = heroes[i];
							_cellMap[heroes[i]] = cellArray[i];
						}
					};
					updateCells( _strHeroes, _strCells );
					updateCells( _agiHeroes, _agiCells );
					updateCells( _intHeroes, _intCells );
					
					// Set maximum bots
					numMaxBots = eventData.numMaxPlayers - eventData.numPlayers;
					Utils.Log( "Num Maximum Bots = " + _numMaxBots );
					
					if ( !api.isLobbyLeader )
					{
						_makeMeAsSuggester();
					}
					
					_isInitialized = true;
				}
				
				Utils.Log( "Follower Selection Time = " + eventData.followerSelectionTime );
				followerSelectionTime = eventData.followerSelectionTime;
				
				TweenLite.to( this, 1.25, { autoAlpha:1 } );
				
			} catch (e:Error) {
				Utils.LogError(e);
			}
		}
		
		private function _onApprovedFollower( eventData:Object ):void
		{
			var heroName:String = eventData.heroName;
			var approved:Boolean = eventData.approved;
			
			Utils.Log( "Updating follower state" );
			Utils.Log( "  - Hero Name : " + heroName );
			Utils.Log( "  - Is Approved : " + approved );
			
			if ( approved )
			{
				_heroesSelected.push( heroName );
			}
			else
			{
				for ( var i:String in _heroesSelected )
				{
					if ( _heroesSelected[i] == heroName )
					{
						_heroesSelected.splice( i, 1 );
						break;
					}
				}
			}
			
			_cellMap[heroName].isSelected = approved;
			numBots = _heroesSelected.length;
		}
		
		private function _onVotingEnd( eventData:Object ):void
		{
			// Close
			TweenLite.to( this, 0.75, { autoAlpha:0 } );
		}
		
		private function _makeMeAsSuggester():void
		{
			removeChild( _btnAccept );
			removeChild( _btnDecline );
			_labelSuggester.visible = true;
		}
		
		private function _setNumHeroes( nStr:int, nAgi:int, nInt:int ):void
		{
			var offsetX:Number = GRID_PADDING;
			var offsetY:Number = GRID_PADDING + HEADER_HEIGHT;
			
			var _this:VoteFollowerPanel = this;
			
			var generateCells:Function = function ( n:int, columnOffset:int, cellArray:Vector.<FollowerHeroButton> ):void
			{
				var nRows:int = Math.ceil( n / GRID_DIM_X_PER_ATTR );

				for ( var i:int = 0; i < n; i++ )
				{
					var ix:int = i % GRID_DIM_X_PER_ATTR + columnOffset;
					var iy:int = Math.floor( i / GRID_DIM_X_PER_ATTR );
					
					// Create a hero panel
					var hero:FollowerHeroButton = new FollowerHeroButton( _this );
					_grid.addChild( hero );
					hero.x = hero.panelWidth * ix + GRID_MARGIN * (ix + 1) + offsetX;
					hero.y = hero.panelHeight * iy + GRID_MARGIN * (iy + 1) + offsetY;
					
					cellArray.push( hero );
				}
			};
			
			generateCells( nStr, GRID_DIM_X_PER_ATTR * 0, _strCells );
			generateCells( nAgi, GRID_DIM_X_PER_ATTR * 1, _agiCells );
			generateCells( nInt, GRID_DIM_X_PER_ATTR * 2, _intCells );
		}
		
		private function _createButton( bgImgClass:Class, text:String ):Sprite
		{
			var buttonWidth:Number = 180;
			var buttonHeight:Number = 32;
			
			var button:Sprite = new Sprite();
			addChild( button );
			button.x = 310;
			button.y = _footerOffsetY + ( FOOTER_HEIGHT - buttonHeight ) / 2;
			
			var img:Bitmap = new bgImgClass();
			button.addChild( img );
			
			// Text
			var label:TextField = Utils.CreateLabel( text, FontType.TextFontBold );
			button.addChild( label );
			var format:TextFormat = label.defaultTextFormat;
			format.align = TextFormatAlign.CENTER;
			label.defaultTextFormat = format;
			label.setTextFormat( format );
			
			label.width = 180;
			label.height = 32;
			label.y = 7;
			
			// Event listener
			button.addEventListener( MouseEvent.CLICK, _onClickExit );
			
			return button;
		}
		
		private function _onClickExit( event:MouseEvent ):void
		{
			if ( _followerSelectionIsActive )
			{
				_followerSelectionIsActive = false;
				
				if ( api )
				{
					for each ( var heroName:String in _heroesSelected )
					{
						api.SendServerCommand( "dotahs_add_follower " + heroName );
					}
					api.SendServerCommand( "dotahs_end_follower_vote" );
				}
				else
				{
					_onVotingEnd( null );
				}
			}
		}
		
		private function set numMaxBots( value:int ):void
		{
			_numMaxBots = value;
			
			if ( _labelMaxBots )
			{
				removeChild( _labelMaxBots );
				_labelMaxBots = null;
			}
			
			_labelMaxBots = Utils.CreateLabel( " of " + value + " SELECTED", FontType.TextFont );
			_labelMaxBots.autoSize = TextFieldAutoSize.LEFT;
			_labelMaxBots.x = 40;
			_labelMaxBots.y = _footerOffsetY + 22;
			
			var format:TextFormat = _labelMaxBots.defaultTextFormat;
			format.size = 16;
			_labelMaxBots.setTextFormat( format );
			_labelMaxBots.alpha = 0.65;
			
			addChild( _labelMaxBots );
		}
		
		private function set numBots( value:int ):void
		{
			_numBots = value;
			
			if ( !_labelBots )
			{
				_labelBots = Utils.CreateLabel( "0", FontType.TextFontBold );
				_labelBots.autoSize = TextFieldAutoSize.LEFT;
				_labelBots.x = 20;
				_labelBots.y = _footerOffsetY + 10;
				
				var format:TextFormat = _labelBots.defaultTextFormat;
				format.size = 32;
				_labelBots.defaultTextFormat = format;
				_labelBots.setTextFormat( format );
				
				_labelBots.alpha = 0.85;
				
				addChild( _labelBots );
			}
			
			_labelBots.text = value.toString();
			_labelMaxBots.x = _labelBots.x + _labelBots.textWidth + 5;
			
			// Update the button
			if ( value == 0 )
			{
				_btnAccept.visible = false;
				_btnDecline.visible = true;
			}
			else
			{
				_btnAccept.visible = true;
				_btnDecline.visible = false;
			}
		}
		
		private function set followerSelectionTime( value:Number ):void
		{
			_followerSelectionStartTime = api.gameTime;
			_followerSelectionEndTime = api.gameTime + value;
			_followerSelectionIsActive = true;
			
			Utils.Log( "  - Start Time : " + _followerSelectionStartTime );
			Utils.Log( "  - End Time : " + _followerSelectionEndTime );
		}
		
		internal function addFollower( heroName:String ):void
		{
			if ( !_followerSelectionIsActive ) return;
			
			if ( api && !api.isLobbyLeader )
			{
				api.SendServerCommand( "dotahs_suggest_follower " + heroName );
				return;
			}
			
			if ( _numBots == _numMaxBots ) return;
			
			if ( api )
			{
				api.SendServerCommand( "dotahs_approve_follower " + heroName + " 1" );
			}
			else
			{
				_onApprovedFollower( { heroName:heroName, approved:true } );
			}
		}
		
		internal function removeFollower( heroName:String ):void
		{
			if ( !_followerSelectionIsActive ) return;
			
			if ( api && !api.isLobbyLeader )
			{
				api.SendServerCommand( "dotahs_suggest_follower " + heroName );
				return;
			}
			
			if ( api )
			{
				api.SendServerCommand( "dotahs_approve_follower " + heroName + " 0" );
			}
			else
			{
				_onApprovedFollower( { heroName:heroName, approved:false } );
			}
		}
		
	}

}