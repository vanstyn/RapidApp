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
			title: 'Unnamed Tab',
			iconCls: 'icon-default',
			itemId: 'tab-' + Math.floor(Math.random()*100000),
			layout: 'fit',
			closable: true,
			autoLoad: {}
		});
		
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
		
		var new_tab = this.add(cnf);
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
	
	var loadCfg = Ext.decode(Record.data.loadContentCnf);
	var rec_data = {};
	Ext.apply(rec_data,Record.data);
	delete rec_data.loadContentCnf;
	
	var orig_params = grid.filteredRecordData(rec_data);
	
	if (!loadCfg.params) { loadCfg.params = {}; }
	Ext.apply(loadCfg.params,{ orig_params: Ext.encode(orig_params) });
	
	return loadTarget.loadContent(loadCfg);
}



	
Ext.ux.RapidApp.AppTab.AppGrid2Def = {

	filteredRecordData: function(data) {
		// Return data as-is if primary_columns is not set:
		if(! Ext.isArray(this.primary_columns) ) { return data; }
		// Return a new object filtered to keys of primary_columns
		return Ext.copyTo({},data,this.primary_columns);
	},
	
	// Function to get the current grid state needed to save a search
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
		});
		
		var view_config = {
			columns: columns,
			column_order: column_order
		};
		var sort = grid.getState().sort;
		if(sort) { view_config.sort = sort; }
		
		var filterdata = grid.getStore().filterdata;
		if(filterdata) { view_config.filterdata = filterdata; }
		
		return view_config;
	},

	initComponent: function() {
		
		// -- vv -- 
		// Enable Ext.ux.RapidApp.Plugin.GridHmenuColumnsToggle plugin:
		if(!this.plugins){ this.plugins = []; }
		this.plugins.push('grid-hmenu-columns-toggle');
		// -- ^^ --
		
		// remove columns with 'no_column' set to true:
		var new_columns = []
		Ext.each(this.columns,function(column,index,arr) {
			if(!column.no_column) { new_columns.push(column); }
		},this);
		this.columns = new_columns;
		
		var bbar_items = [];
		if(Ext.isArray(this.bbar)) { bbar_items = this.bbar; }
		
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
				prependButtons: true,
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
		
		
		// ------ Grid Search --------- //
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
		
		// Remove the bbar if its empty and there is no pageSize set:
		if (this.bbar.items.length == 0 && !this.pageSize) { delete this.bbar; }
		
		if(this.checkbox_selections) {
			this.sm = new Ext.grid.CheckboxSelectionModel();
			this.columns.unshift(this.sm);
		}

		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.initComponent.call(this);
	},
	
	onRender: function() {

		var thisGrid = this;
		this.store.on('beforeload',function(Store,opts) {
			
			var columns = thisGrid.getColumnModel().getColumnsBy(function(c){
				if(c.hidden || c.dataIndex == "") { return false; }
				return true;
			});
			
			var colIndexes = [];
			Ext.each(columns,function(i) {
				colIndexes.push(i.dataIndex);
			});
			
			//Store.setBaseParam("columns",Ext.encode(colIndexes));
			Store.baseParams["columns"] = Ext.encode(colIndexes);
		});
		
		this.getColumnModel().on('hiddenchange',function(colmodel) {
			this.getStore().reload();
		},this);
		
		var store_load_parms = {};
		
		if (this.sort) {
			Ext.apply(store_load_parms,{
				sort: this.sort
			});
			this.applyState({ sort: this.sort });
		}
		
		if (this.pageSize) {
			Ext.apply(store_load_parms,{
				start: 0,
				limit: parseFloat(this.pageSize)
			});
		}
		
		this.store.load({ params: store_load_parms });
		
		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.onRender.apply(this, arguments);
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
				text: 'This Page, Active Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,false,false);
				}
			},
			{
				text: 'This Page, All Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,false,true);
				}
			},
			{
				text: 'All Pages, Active Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,true,false);
				}
			},
			{
				text: 'All Pages, All Columns',
				handler: function(item) {
					var cmp = item.ownerCt;
					Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler(cmp,cmp.url,true,true);
				}
			}
		];
		
		Ext.ux.RapidApp.AppTab.AppGrid2.ExcelExportMenu.superclass.initComponent.call(this);
	}
});



Ext.ux.RapidApp.AppTab.AppGrid2.excelExportHandler = function(cmp,url,all_pages,all_columns) {

	var grid = cmp.findParentByType("appgrid2");
			
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
			
			if(store.filterdata) {
				var encoded = Ext.encode(store.filterdata);
				Ext.apply(options.params, {
					'multifilter': encoded 
				});
			}
			
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