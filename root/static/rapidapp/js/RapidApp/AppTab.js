Ext.ns('Ext.ux.RapidApp.AppTab');


Ext.ux.RapidApp.AppTab.TabPanel = Ext.extend(Ext.TabPanel, {

	//initComponent: function() {
	//	Ext.ux.RapidApp.AppTab.TabPanel.superclass.call(this);
	//},

	itemId: 'load-target',

	layoutOnTabChange: true,
	enableTabScroll: true,
	
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
	
	return loadTarget.loadContent(node.attributes.loadContentCnf);
}

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


Ext.ux.RapidApp.AppTab.gridrow_nav = function(grid,index,e) {
	var loadTarget = grid.loadTargetObj;
	var Record = grid.getStore().getAt(index);
	
	var loadCfg = Ext.decode(Record.data.loadContentCnf);
	delete Record.data.loadContentCnf;
	
	var orig_params = grid.filteredRecordData(Record.data);
	
	if (!loadCfg.params) { loadCfg.params = {}; }
	Ext.apply(loadCfg.params,{ orig_params: Ext.encode(orig_params) });
	
	return loadTarget.loadContent(loadCfg);
}


Ext.ux.RapidApp.AppTab.AppGrid2 = Ext.extend(Ext.grid.GridPanel,{

	filteredRecordData: function(data) {
		// Return data as-is if primary_columns is not set:
		if(! Ext.isArray(this.primary_columns) ) { return data; }
		// Return a new object filtered to keys of primary_columns
		return Ext.copyTo({},data,this.primary_columns);
	},

	initComponent: function() {
	
		if(this.pageSize) {
			this.bbar = {
				xtype:	'paging',
				store: this.store,
				pageSize: this.pageSize,
				displayInfo : true,
				prependButtons: true,
				items: []
			};
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
				iconCls:'icon-zoom',
				autoFocus:false,
				mode: 'local', // local or remote
				width: 300,
				position: 'top'
			};

			if (this.gridsearch_remote) { grid_search_cnf['mode'] = 'remote'; }

			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(new Ext.ux.grid.Search(grid_search_cnf));
		}
		// ---------------------------- //
		

		// ---- Delete support:
		if (this.delete_url) {
			this.sm = new Ext.grid.CheckboxSelectionModel();
			this.columns.unshift(this.sm);
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
			this.bbar.items.push(
				'Selection:',
				deleteBtn,
				'-'
			);
		}
		
		var testBtn = new Ext.Button({
			text: 'testBtn',
			handler: function(btn) {
				var grid = btn.ownerCt.ownerCt;
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
				
				console.dir(view_config);
				//console.log(Ext.encode(view_config));
				console.dir(grid);
				//console.dir(grid.getState());
			}
		});
		
		this.bbar.items.push(testBtn);

		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.initComponent.call(this);
	},
	
	onRender: function() {
		
		//console.dir(this);
		
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

			// For some reason I don't understand, reloading the store directly
			// does not make it see the new non-hidden column names, but calling
			// the refresh function on the paging toolbar does:
			var ptbar = thisGrid.getBottomToolbar();
			ptbar.doRefresh();
			//var Store = thisGrid.getStore();
			//Store.reload();
		});
		
		
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
	
});
Ext.reg('appgrid2', Ext.ux.RapidApp.AppTab.AppGrid2);


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