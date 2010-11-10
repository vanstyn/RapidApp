Ext.ns('Ext.ux.RapidApp.AppTab');


Ext.ux.RapidApp.AppTab.TabPanel = Ext.extend(Ext.TabPanel, {

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
	
	if (!loadCfg.params) { loadCfg.params = {}; }
	Ext.apply(loadCfg.params,{ orig_params: Ext.encode(Record.data) });
	
	return loadTarget.loadContent(loadCfg);
}


Ext.ux.RapidApp.AppTab.AppGrid2 = Ext.extend(Ext.grid.GridPanel,{

	baseLoadContentCnf: {},

	initComponent: function() {
	
		if(this.pageSize) {
			this.bbar = {
				xtype:	'paging',
				store: this.store,
				pageSize: this.pageSize,
				displayInfo : true,
				prependButtons: true
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

			// For some reason I don't understand, reloading the store directly
			// does not make it see the new non-hidden column names, but calling
			// the refresh function on the paging toolbar does:
			var ptbar = thisGrid.getBottomToolbar();
			ptbar.doRefresh();
			//var Store = thisGrid.getStore();
			//Store.reload();
		});
		
		
		var load_parms = {};
		if (this.pageSize) {
			load_parms = {
				params: {
					start: 0,
					limit: parseFloat(this.pageSize)
				}
			};
			this.store.load(load_parms);
		}
		
		
		
		Ext.ux.RapidApp.AppTab.AppGrid2.superclass.onRender.apply(this, arguments);
	}
	
});
Ext.reg('appgrid2', Ext.ux.RapidApp.AppTab.AppGrid2);


