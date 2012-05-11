Ext.ns('Ext.ux.RapidApp.AppTab');


Ext.ux.RapidApp.AppTab.TabPanel = Ext.extend(Ext.TabPanel, {

	initComponent: function() {
		if(this.initLoadTabs) {
			this.on('afterrender',function() {
				Ext.each(this.initLoadTabs,function(cnf) {
					this.loadTab(cnf);
				},this);
			},this);
		}
		
		if(!this.plugins) { this.plugins = []; };
		this.plugins.push('tabpanel-closeall');
		
		Ext.ux.RapidApp.AppTab.TabPanel.superclass.initComponent.call(this);
	},

	itemId: 'load-target',

	layoutOnTabChange: true,
	enableTabScroll: true,
	
	// "navsource" property is meant to be used to store a reference to the navsource
	// container (i.e. AppTree) that calls "loadContent". This needs to be set by the
	// navsource itself
	navsource: null,
	setNavsource: function(cmp) {
		this.navsource = cmp;
	},
	getNavsource: function() {
		return this.navsource;
	},
	
	loadContent: function() {
		this.loadTab.apply(this,arguments);
	},

	loadTab: function(cnf) {
		
		Ext.applyIf(cnf,{
			xtype: 'autopanel',
			itemId: 'tab-' + Math.floor(Math.random()*100000),
			layout: 'fit',
			closable: true,
			autoLoad: {}
		});
		
		var setTitle,setIconCls;
		if(!cnf.title) {
			cnf.title = 'Loading';
			setTitle = 'Unnamed Tab';
		}
		if(!cnf.iconCls) {
			cnf.iconCls = 'icon-loading';
			setIconCls = 'icon-document';
		}
		
		Ext.applyIf(cnf.autoLoad, {
			text: 'Loading...',
			nocache: true,
			params: {}
		});
		
		if (cnf.params) {
			Ext.apply(cnf.autoLoad.params,cnf.params);
		}
		
		// Check if this Tab is already loaded, and set active and return if it is:
		var existTab = this.getComponent(cnf.itemId);
		if (existTab) {
			return this.activate(existTab);
		}
		
		// --- Backwards compat with AppTreeExplorer/AppGrid:
		if (!cnf.autoLoad.url) {
			if (cnf.url) { cnf.autoLoad.url = cnf.url; }
		}
		// ---
		
		
		if(!cnf.cmpListeners) { cnf.cmpListeners = {}; }
		if(!cnf.cmpListeners.beforerender) { cnf.cmpListeners.beforerender = Ext.emptyFn; }
		cnf.cmpListeners.beforerender = Ext.createInterceptor(
			cnf.cmpListeners.beforerender,
			function() {
				var tab = this.ownerCt;
				if(this.tabTitle) { setTitle = this.tabTitle; }
				if(this.tabIconCls) { setIconCls = this.tabIconCls; }
				
				if(setTitle) { tab.setTitle(setTitle); }
				if(setIconCls) { tab.setIconClass(setIconCls); }
			}
		);
		
		var new_tab = this.add(cnf);
		
		
		//console.dir(new_tab)
		
		return this.activate(new_tab);
	},
	
	closeActive: function() {
		var activePanel = this.getActiveTab();
		this.remove(activePanel);
	}
	
});
Ext.reg('apptabpanel', Ext.ux.RapidApp.AppTab.TabPanel);

// This is designed to be a function that can be supplied to a treepanel 
// click handler. This assumes the node has a compatible 'loadContentCnf'
// attribute and that the tree has a reference to a compatable 'loadTargetObj'
// (defined as a property). 
Ext.ux.RapidApp.AppTab.treenav_click = function(node,event) {
	var tree = node.getOwnerTree();
	var loadTarget = tree.loadTargetObj;
	
	// Update the loadTarget with a refernece back to us. This is needed in case
	// an app needs to tell us to reload (such as in the case of saving AppGrid2 searches
	loadTarget.setNavsource(tree);
	
	// Do nothing if the node has no loadContentCnf
	if (! node.attributes.loadContentCnf) { return; }
	
	return loadTarget.loadContent(node.attributes.loadContentCnf);
}


Ext.ux.RapidApp.AppTab.findParent_loadTarget = function(cnt) {
	var loadTarget = null;
	var parent = cnt.findParentBy(function(cmp) {
		if (!cmp.getComponent) { return false;} 
		loadTarget = cmp.getComponent('load-target');
		if(loadTarget) { return true; }
		return false;
	});
	return loadTarget;
};

Ext.ux.RapidApp.AppTab.cnt_init_loadTarget = function(cnt) {
	cnt.loadTargetObj = Ext.ux.RapidApp.AppTab.findParent_loadTarget(cnt);
	// If a lodTarget wasn't found above, ball back to the global id:
	if(!cnt.loadTargetObj) {
		cnt.loadTargetObj = Ext.getCmp('main-load-target');
	}
}



/*
Ext.ux.RapidApp.AppTab.cnt_init_loadTarget = function(cnt) {
	var loadTarget;
	var parent = cnt.findParentBy(function(cmp) {
		loadTarget = cmp.getComponent('load-target');
		if(loadTarget) { return true; }
		return false;
	});
	cnt.loadTargetObj = loadTarget;
	//tree.loadTargetObj = tree.ownerCt.ownerCt.getComponent('load-target');
}
*/

Ext.ux.RapidApp.AppTab.gridrow_nav = function(grid,index,e) {
	var loadTarget = grid.loadTargetObj;
	var Record = grid.getStore().getAt(index);
	return Ext.ux.RapidApp.AppTab.tryLoadTargetRecord(loadTarget,Record,grid);
}

Ext.ux.RapidApp.AppTab.tryLoadTargetRecord = function(loadTarget,Record,cmp) {
	var orig_params = Ext.apply({},Record.data);
	if(orig_params.loadContentCnf) {
		var loadCfg = Ext.decode(orig_params.loadContentCnf);	
		delete orig_params.loadContentCnf;
		
		if(cmp && cmp.filteredRecordData) {
			orig_params = cmp.filteredRecordData(orig_params);
		}
	
		if (!loadCfg.params) { loadCfg.params = {}; }
		Ext.apply(loadCfg.params,{ orig_params: Ext.encode(orig_params) });
		
		return loadTarget.loadContent(loadCfg);
	}
}




Ext.ux.RapidApp.AppTab.AppGrid2Def = {
	
	viewConfig: {
		emptyText: '<div style="font-size:16px;color:#d0d0d0;padding-top:10px;padding-left:25px">' +
			'(No Data)</div>',
		
		// -- http://www.sencha.com/learn/legacy/Ext_FAQ_Grid#Maintain_GridPanel_scroll_position_across_Store_reloads
		onLoad: Ext.emptyFn,
		listeners: {
			beforerefresh: function(v) {
				v.scrollTop = v.scroller.dom.scrollTop;
				v.scrollHeight = v.scroller.dom.scrollHeight;
			},
			refresh: function(v) {
				v.scroller.dom.scrollTop = v.scrollTop + 
				(v.scrollTop == 0 ? 0 : v.scroller.dom.scrollHeight - v.scrollHeight);
			}
		}
		// --
	},
	
	getOptionsMenu: function() {
		return Ext.getCmp(this.options_menu_id);
	},

	filteredRecordData: function(data) {
		// Return data as-is if primary_columns is not set:
		if(! Ext.isArray(this.primary_columns) ) { return data; }
		// Return a new object filtered to keys of primary_columns
		return Ext.copyTo({},data,this.primary_columns);
	},
	
	saveStateProperties: [
		'filterdata', 				// MultiFilters
		'filterdata_frozen', 	// Frozen MultiFilters
		'column_summaries'		// Column Summaries
	],
	
	// Function to get the current grid state needed to save a search
	// TODO: factor to use Built-in ExtJS "state machine"
	getCurSearchData: function () {
		var grid = this;
		var colModel = grid.getColumnModel();
						
		var columns = {};
		var column_order = [];
		Ext.each(colModel.config,function(item) {
			if (item.name) {
				columns[item.name] = Ext.copyTo({},item,grid.column_allow_save_properties);
				column_order.push(item.name);
			}
		},this);
		
		// view_config gets saved into 'saved_state' when a search is saved:
		var view_config = {
			columns: columns,
			column_order: column_order
		};
		var sort = grid.getState().sort;
		if(sort) { view_config.sort = sort; }
		
		var store = grid.getStore();
		
		
		
		/*
		//MultiFilter data:
		if(store.filterdata) { view_config.filterdata = store.filterdata; }
		if(store.filterdata_frozen) { view_config.filterdata = store.filterdata; }
		
		//GridSummary data
		if(store.column_summaries) { view_config.column_summaries = store.column_summaries; }
		*/
		
		view_config.pageSize = grid.getBottomToolbar().pageSize;
		
		// Copy designated extra properties to be saved into view_config (saved_state):
		Ext.copyTo(
			view_config, store,
			grid.saveStateProperties
		);
		
		return view_config;
	},
	
	storeReloadButton: false,
	titleCount: false,

	initComponent: function() {
		
		this.store.on('beforeload',this.reloadColumns,this);

		// -- Force default sort to be DESC instead of ASC:
		var orig_store_singleSort = this.store.singleSort;
		this.store.singleSort = function(field,dir) {
			if(!dir && (!this.sortInfo || this.sortInfo.field != field)) {
				if(!this.sortToggle || !this.sortToggle[field]) { 
					this.sortToggle[field] = 'ASC';
					this.sortInfo = {
						field: field,
						direction: 'ASC'
					};
				}
				arguments[1] = this.sortToggle[field].toggle('ASC','DESC');
			}
			orig_store_singleSort.apply(this,arguments);
		}
		// --
		
		// -- Workaround - manual single-use loadMask for the very first load
		// Need to investigate more why this is needed, and why the 'loadMask' grid
		// setting doesn't work on the first store load. I think it is related to
		// load order and possibly autoPanel. 
		// TODO: generalize/move this into datastore-plus
		if(!this.collapsed) {
			this.on('afterrender',function() {
				var lMask = new Ext.LoadMask(this.getEl(),{ msg: "Loading Data Set" });
				lMask.show();
				var hide_fn;
				hide_fn = function(){ 
					lMask.hide(); 
					this.store.un('load',hide_fn);
					this.store.un('exception',hide_fn); 
				};
				this.store.on('load',hide_fn,this);
				this.store.on('exception',hide_fn,this);
			},this);
		}
		// --
		
		
		if(this.storeReloadButton) {
			this.tools = [{
				id: 'refresh',
				handler: function() {
					this.getStore().reload();
				},
				scope: this
			}]
		}
		
		// If the store has pageSize set then it came from a saved search and
		// we use it:
		if (this.store.pageSize) { this.pageSize = this.store.pageSize; }
		
		// -- vv -- 
		// Enable Ext.ux.RapidApp.Plugin.GridHmenuColumnsToggle plugin:
		if(!this.plugins){ this.plugins = []; }
		this.plugins.push('grid-hmenu-columns-toggle');
		// -- ^^ --
		
		if(this.use_column_summaries) { this.plugins.push('appgrid-summary'); }
		if(this.use_autosize_columns || this.auto_autosize_columns) { 
			this.plugins.push('appgrid-auto-colwidth'); 
		}
		
		// Toggle All:
		this.plugins.push('appgrid-toggle-all-cols');
		this.plugins.push('appgrid-filter-cols');
		
		this.plugins.push('appgrid-batch-edit'); 
		
		// remove columns with 'no_column' set to true:
		var new_columns = [];
		var num_not_hidden_cols = 0;
		Ext.each(this.columns,function(column,index,arr) {
			if(!column.no_column) {
				if(!column.hidden) { num_not_hidden_cols++; }
				
				// check for special 'allow_edit' attribute:
				if(typeof column.allow_edit != "undefined" && !column.allow_edit) { 
					if(!column.allow_batchedit) {
						column.editable = false;
					}
				}
				
				// autoExpandColumn feature relies on the "id" property. Here we set it
				// automatically to be the same as the column name.
				if(this.autoExpandColumn && this.autoExpandColumn == column.name) {
					column.id = column.name;
				}
				
				if(column.summary_functions) { column.summaryType = 'dummy'; }
				
				new_columns.push(column);
			}
		},this);
		this.columns = new_columns;
		
		// -- If every single column is hidden, the the hmenu won't be available. Override
		// the hidden setting on only the very first column in this case:
		if(num_not_hidden_cols == 0 && this.columns.length > 0) {
			this.columns[0].hidden = false;
		}
		// --
		
		var bbar_items = [];
		if(Ext.isArray(this.bbar)) { bbar_items = this.bbar; }
		
		
		//if(this.persist_immediately && this.store.api.update) {
		//	this.on('afteredit',function(){ this.getStore().save(); },this);
		//}
		
		this.bbar = {
			xtype:	'toolbar',
			items: bbar_items
		};
		
		if(this.pageSize) {
			Ext.apply(this.bbar,{
				xtype:	'rapidapp-paging',
				store: this.store,
				pageSize: this.pageSize,
				displayInfo : true,
				//prependButtons: true,
				items: bbar_items
			});
			if(this.maxPageSize) { this.bbar.maxPageSize = this.maxPageSize; }
		}
		
		// ----- MultiFilters: ----- //
		if (this.use_multifilters) {
			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(new Ext.ux.MultiFilter.Plugin);
		}
		// ------------------------- //
		
		
		// ------ Grid Quick Search --------- //
		if (this.gridsearch && this.tbar) {

			var grid_search_cnf = {
				//iconCls:'icon-zoom',
				autoFocus:false,
				mode: 'local', // local or remote
				width: 250,
				position: 'top'
			};

			if (this.gridsearch_remote) { grid_search_cnf['mode'] = 'remote'; }

			if(!this.plugins){ this.plugins = []; }
			//this.plugins.push(new Ext.ux.grid.Search(grid_search_cnf));
			this.plugins.push(new Ext.ux.RapidApp.Plugin.GridQuickSearch(grid_search_cnf));
		}
		// ---------------------------- //
		

		// ---- Delete support:
		if (this.delete_url) {
			this.checkbox_selections = true;
			var storeId = this.store.storeId;
			var deleteBtn = new Ext.Button({
				text: 'delete',
				iconCls: 'icon-bullet_delete',
				handler: function(btn) {
					var grid = btn.ownerCt.ownerCt;
					var Records = grid.getSelectionModel().getSelections();
					var rows = [];
					Ext.each(Records,function(item) {
						rows.push(grid.filteredRecordData(item.data));
					});
					
					// Don't do anything if no records are selected:
					if(rows.length == 0) { return; }

					Ext.ux.RapidApp.confirmDialogCall(
						'Confirm delete', 'Really delete ' + rows.length + ' selected records?',
						function() {
							Ext.Ajax.request({
								url: grid.delete_url,
								params: {
									rows: Ext.encode(rows)
								},
								success: function(response) {
									grid.getStore().reload();
								}
							});
						}
					);
				}
			});
			this.bbar.items.unshift(
				'Selection:',
				deleteBtn,
				'-'
			);
		}
		
		// Remove the bbar if its empty and there is no pageSize set (and there are no store buttons):
		if (this.bbar.items.length == 0 && !this.pageSize && !this.setup_bbar_store_buttons) { 
			delete this.bbar; 
		}
		
		if(this.checkbox_selections) {
			this.sm = new Ext.grid.CheckboxSelectionModel();
			this.columns.unshift(this.sm);
		}

		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.initComponent.call(this);
	},
	
	onRender: function() {
		
		this.reloadColumnsTask = new Ext.util.DelayedTask(function(){
			this.reloadColumns();
		},this);
		
		this.storeReloadTask = new Ext.util.DelayedTask(function(){
			this.reloadColumns();
			this.store.reload();
		},this);
		
		this.getColumnModel().on('hiddenchange',function(colmodel,colIndex,hidden) {
			// Only reload the store when showing columns that aren't already loaded
			if(hidden || this.loadedColumnIndexes[colIndex]) { 
				// Need to set reloadColumns even if no store reload is needed so
				// that clicking to sort on a column will use the new column data
				// on its request to the store:
				//this.reloadColumns();
				this.reloadColumnsTask.delay(100);
				return; 
			}
			//this.reloadColumnsTask.delay(100);
			//this.reloadColumns(); // <-- this has to be done effectively twice to make sure lastOptions are changed
			
			//store reload task with delay for clicking several columns at once:
			this.storeReloadTask.delay(750); 
		},this);
		
		var store_load_parms = {};
		
		if (this.sort) {
			//Ext.apply(store_load_parms,{
			//	sort: this.sort
			//});
			this.applyState({ sort: this.sort });
		}
		
		if (this.pageSize) {
			Ext.apply(store_load_parms,{
				start: 0,
				limit: parseFloat(this.pageSize)
			});
		}
		
		if(this.store.autoLoad && this.store.autoLoad.params) {
			Ext.apply(this.store.autoLoad.params,store_load_parms);
		}
		// alternate 'store_autoLoad' setting - see DataStore2.pm and datastore-plus plugin:
		else if(this.store.store_autoLoad && this.store.store_autoLoad.params) {
			Ext.apply(this.store.store_autoLoad.params,store_load_parms);
		}
		else {
			this.store.load({ params: store_load_parms });
		}
		
		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.onRender.apply(this, arguments);
	},
	
	currentVisibleColnames: function() {
		var cm = this.getColumnModel();
		
		// Reset loadedColumnIndexes back to none
		this.loadedColumnIndexes = {};
		
		var columns = cm.getColumnsBy(function(c){
			if(c.hidden || c.dataIndex == "") { return false; }
			return true;
		},this);
		
		var colDataIndexes = [];
		var seen = {};
		Ext.each(columns,function(i) {
			if(!seen[i.dataIndex]) {
				colDataIndexes.push(i.dataIndex);
				seen[i.dataIndex] = true;
			}
			this.loadedColumnIndexes[cm.findColumnIndex(i.dataIndex)] = true;
		},this);
		
		return colDataIndexes;
		
	},
	
	reloadColumns: function(store,opts) {
		if(!store){ store = this.store; }

		var colDataIndexes = this.currentVisibleColnames();
		
		var params = { columns: Ext.encode(colDataIndexes) };
		if(opts && opts.params) {
			Ext.apply(params,opts.params);
		}
		
		if(this.baseParams) {
			Ext.apply(params,this.baseParams);
		}
		
		Ext.apply(store.baseParams,params);
		// Set lastOptions as well so reload() gets the new columns:
		Ext.apply(store.lastOptions.params,params);
	}
};

Ext.ux.RapidApp.AppTab.AppGrid2 = Ext.extend(Ext.grid.GridPanel,Ext.ux.RapidApp.AppTab.AppGrid2Def);
Ext.reg('appgrid2', Ext.ux.RapidApp.AppTab.AppGrid2);

Ext.ux.RapidApp.AppTab.AppGrid2Ed = Ext.extend(Ext.grid.EditorGridPanel,Ext.ux.RapidApp.AppTab.AppGrid2Def);
Ext.reg('appgrid2ed', Ext.ux.RapidApp.AppTab.AppGrid2Ed);

Ext.ns('Ext.ux.RapidApp.AppTab.AppGrid2');

Ext.ux.RapidApp.AppTab.AppGrid2.ExcelExportMenu = Ext.extend(Ext.menu.Menu,{

	url: null,

	initComponent: function() {

		this.items = [
			{
				//text: 'This Page, Active Columns',
				text: 'Current Page',
				iconCls: 'icon-table-selection-row',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler.call(this,cmp,cmp.url,false,false);
				},
				scope: this
			},
			
			/*
			{
				text: 'This Page, All Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,false,true);
				}
			}*/
			
			{
				//text: 'All Pages, Active Columns',
				text: 'All Pages',
				iconCls: 'icon-table-selection-all',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,true,false);
				}
			}
			
			/*,
			{
				text: 'All Pages, All Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,true,true);
				}
			}
			*/
		];
		
		Ext.ux.RapidApp.AppTab.AppGrid2.ExcelExportMenu.superclass.initComponent.call(this);
	}
});



Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler = function(cmp,url,all_pages,all_columns) {
	
	var btn = Ext.getCmp(cmp.buttonId);
	var grid = btn.findParentByType("appgrid2") || btn.findParentByType("appgrid2ed");
	
	Ext.Msg.show({
		title: "Excel Export",
		msg: "Export current view to Excel File? <br><br>(This might take up to a few minutes depending on the number of rows)",
		buttons: Ext.Msg.YESNO, fn: function(sel){
			if(sel != "yes") return; 
			
			var store = grid.getStore();
			//var params = {};
			
			// -- Get the params that the store last used to fetch from the server
			// There is no built-in method to get this info, so this logic is basically
			// copied from the load method of Ext.data.Store:
			var options = Ext.apply({}, store.lastOptions);
			if(store.sortInfo && store.remoteSort){
				var pn = store.paramNames;
				options.params = Ext.apply({}, options.params);
				options.params[pn.sort] = store.sortInfo.field;
				options.params[pn.dir] = store.sortInfo.direction;
			}
			// --
			Ext.apply(options.params,store.baseParams);
			
			/*
			if(store.filterdata) {
				var encoded = Ext.encode(store.filterdata);
				Ext.apply(options.params, {
					'multifilter': encoded 
				});
			}
			*/
			
			if(all_pages) { 
				if (options.params.limit) { delete options.params.limit; } 
				if (options.params.start) { delete options.params.start; } 
			}
			
			if(all_columns && options.params.columns) { delete options.params.columns; }
			
			return Ext.ux.postwith(url,options.params);
		},
		scope: cmp
	});
}


Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.confirmDialogCall = function(title,msg,fn) {
	Ext.Msg.show({
			title: title,
			msg: msg,
			buttons: Ext.Msg.YESNO,
			icon: Ext.MessageBox.QUESTION,
			fn: function(buttonId) { 
				if (buttonId=="yes") {
					return fn();
				}
			}
	});
}


/*
 If this is used as the column renderer for an AppGrid2 column,
 the same icon used in the tab when a row is opened will be displayed
 to the left of the value of the cell for the given column (assumes 16x16 icon)
 this is pulled out of the 'loadContentCnf' JSON encoded data
*/
Ext.ux.RapidApp.AppTab.iconClsColumnRenderer = function(value, metaData, record, rowIndex, colIndex, store) {
  if (record.data.loadContentCnf) {
    var loadCfg = Ext.decode(record.data.loadContentCnf);
    if(loadCfg.iconCls) {
      metaData.css = 'grid-cell-with-icon ' + loadCfg.iconCls;
    }
  }
  return value;
}
