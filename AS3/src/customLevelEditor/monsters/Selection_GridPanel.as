package customLevelEditor.monsters {
	import customLevelEditor.EditorContext;
	import customLevelEditor.events.EditorContextEvent;
	import customLevelEditor.events.MonsterPoolEvent;
	import customLevelEditor.MonsterData;
	import customLevelEditor.MonsterPoolData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author ractis
	 */
	public class Selection_GridPanel extends Sprite 
	{
		private var _cellMap:Dictionary = new Dictionary();
		
		public function Selection_GridPanel( category:String, monsterList:Array ) 
		{
			super();
			
			Utils.Log( "Num Monsters = " + monsterList.length + " in " + category );
			
			//------------------------------------------------------------
			// Calculate the size of grid panel
			//------------------------------------------------------------
			var numRows:int = Math.ceil( monsterList.length / SelectionPanel.GRID_DIM_X );
			//Utils.Log( "Num Rows = " + numRows );
			
			var panelWidth:Number = SelectionPanel.GRID_DIM_X * SelectionPanel.CELL_WIDTH + ( SelectionPanel.GRID_DIM_X + 1 ) * SelectionPanel.GRID_MARGIN;
			var panelHeight:Number = numRows * SelectionPanel.CELL_HEIGHT + ( numRows + 1 ) * SelectionPanel.GRID_MARGIN;
			
			//------------------------------------------------------------
			// Draw BG
			//------------------------------------------------------------
			var g:Graphics = graphics;
			g.beginFill( 0xFFFFFF, 0.5 );
			g.drawRect( 0, 0, panelWidth, panelHeight );
			g.endFill();
			
			//------------------------------------------------------------
			// Create cells for all monsters
			//------------------------------------------------------------
			for ( var i:int = 0; i < monsterList.length; i++ )
			{
				var monsterData:Object = monsterList[i];
				
				var cell:Selection_CellPanel = new Selection_CellPanel( monsterData );
				addChild( cell );
				_cellMap[monsterData.Name] = cell;
				
				// Calculate coodinates for this cell
				var gridX:int = i % SelectionPanel.GRID_DIM_X;
				var gridY:int = Math.floor( i / SelectionPanel.GRID_DIM_X );
				
				cell.x = gridX * SelectionPanel.CELL_WIDTH + ( gridX + 1 ) * SelectionPanel.GRID_MARGIN;
				cell.y = gridY * SelectionPanel.CELL_HEIGHT + ( gridY + 1 ) * SelectionPanel.GRID_MARGIN;
			}
			
			//------------------------------------------------------------
			// Register event listeners
			//------------------------------------------------------------
			EditorContext.inst.addEventListener( EditorContextEvent.CHANGED_ACTIVE_POOL, _onChangedActivePool );
			
			_onChangedActivePool( null );
		}
		
		private function _onChangedActivePool( e:EditorContextEvent ):void
		{
			var oldActivePool:MonsterPoolData = e ? e.oldActivePool : null;
			if ( oldActivePool )
			{
				oldActivePool.removeEventListener( MonsterPoolEvent.ADDED_MONSTER, _onAddedMonster );
				oldActivePool.removeEventListener( MonsterPoolEvent.REMOVED_MONSTER, _onRemovedMonster );
			}
			
			var newActivePool:MonsterPoolData = EditorContext.inst.activePool;
			if ( newActivePool )
			{
				newActivePool.addEventListener( MonsterPoolEvent.ADDED_MONSTER, _onAddedMonster );
				newActivePool.addEventListener( MonsterPoolEvent.REMOVED_MONSTER, _onRemovedMonster );
			}
			
			_refreshAllCellStates();
		}
		
		private function _onAddedMonster( e:MonsterPoolEvent ):void
		{
			var cell:Selection_CellPanel = _cellMap[e.monsterData.fullName];
			if ( cell )
			{
				cell.notifyAddedToPool();
			}
		}
		
		private function _onRemovedMonster( e:MonsterPoolEvent ):void
		{
			var cell:Selection_CellPanel = _cellMap[e.monsterData.fullName];
			if ( cell )
			{
				cell.notifyRemovedFromPool();
			}
		}
		
		private function _refreshAllCellStates():void
		{
			// Reset all
			for each ( var cellPanel:Selection_CellPanel in _cellMap )
			{
				cellPanel.notifyRemovedFromPool();
			}
			
			// Update
			if ( EditorContext.inst.activePool )
			{
				for each ( var monsterInPool:MonsterData in EditorContext.inst.activePool.monsters )
				{
					var cell:Selection_CellPanel = _cellMap[monsterInPool.fullName];
					if ( cell ) cell.notifyAddedToPool();
				}
			}
		}
		
	}

}