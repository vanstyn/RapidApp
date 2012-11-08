
/* http://noteslog.com/post/crc32-for-javascript/
=============================================================================== 
Crc32 is a JavaScript function for computing the CRC32 of a string 
............................................................................... 
 
Version: 1.2 - 2006/11 - http://noteslog.com/category/javascript/ 
 
------------------------------------------------------------------------------- 
Copyright (c) 2006 Andrea Ercolino 
http://www.opensource.org/licenses/mit-license.php 
=============================================================================== 
*/ 
(function() { 
    var table = "00000000 77073096 EE0E612C 990951BA 076DC419 706AF48F E963A535 9E6495A3 0EDB8832 79DCB8A4 E0D5E91E 97D2D988 09B64C2B 7EB17CBD E7B82D07 90BF1D91 1DB71064 6AB020F2 F3B97148 84BE41DE 1ADAD47D 6DDDE4EB F4D4B551 83D385C7 136C9856 646BA8C0 FD62F97A 8A65C9EC 14015C4F 63066CD9 FA0F3D63 8D080DF5 3B6E20C8 4C69105E D56041E4 A2677172 3C03E4D1 4B04D447 D20D85FD A50AB56B 35B5A8FA 42B2986C DBBBC9D6 ACBCF940 32D86CE3 45DF5C75 DCD60DCF ABD13D59 26D930AC 51DE003A C8D75180 BFD06116 21B4F4B5 56B3C423 CFBA9599 B8BDA50F 2802B89E 5F058808 C60CD9B2 B10BE924 2F6F7C87 58684C11 C1611DAB B6662D3D 76DC4190 01DB7106 98D220BC EFD5102A 71B18589 06B6B51F 9FBFE4A5 E8B8D433 7807C9A2 0F00F934 9609A88E E10E9818 7F6A0DBB 086D3D2D 91646C97 E6635C01 6B6B51F4 1C6C6162 856530D8 F262004E 6C0695ED 1B01A57B 8208F4C1 F50FC457 65B0D9C6 12B7E950 8BBEB8EA FCB9887C 62DD1DDF 15DA2D49 8CD37CF3 FBD44C65 4DB26158 3AB551CE A3BC0074 D4BB30E2 4ADFA541 3DD895D7 A4D1C46D D3D6F4FB 4369E96A 346ED9FC AD678846 DA60B8D0 44042D73 33031DE5 AA0A4C5F DD0D7CC9 5005713C 270241AA BE0B1010 C90C2086 5768B525 206F85B3 B966D409 CE61E49F 5EDEF90E 29D9C998 B0D09822 C7D7A8B4 59B33D17 2EB40D81 B7BD5C3B C0BA6CAD EDB88320 9ABFB3B6 03B6E20C 74B1D29A EAD54739 9DD277AF 04DB2615 73DC1683 E3630B12 94643B84 0D6D6A3E 7A6A5AA8 E40ECF0B 9309FF9D 0A00AE27 7D079EB1 F00F9344 8708A3D2 1E01F268 6906C2FE F762575D 806567CB 196C3671 6E6B06E7 FED41B76 89D32BE0 10DA7A5A 67DD4ACC F9B9DF6F 8EBEEFF9 17B7BE43 60B08ED5 D6D6A3E8 A1D1937E 38D8C2C4 4FDFF252 D1BB67F1 A6BC5767 3FB506DD 48B2364B D80D2BDA AF0A1B4C 36034AF6 41047A60 DF60EFC3 A867DF55 316E8EEF 4669BE79 CB61B38C BC66831A 256FD2A0 5268E236 CC0C7795 BB0B4703 220216B9 5505262F C5BA3BBE B2BD0B28 2BB45A92 5CB36A04 C2D7FFA7 B5D0CF31 2CD99E8B 5BDEAE1D 9B64C2B0 EC63F226 756AA39C 026D930A 9C0906A9 EB0E363F 72076785 05005713 95BF4A82 E2B87A14 7BB12BAE 0CB61B38 92D28E9B E5D5BE0D 7CDCEFB7 0BDBDF21 86D3D2D4 F1D4E242 68DDB3F8 1FDA836E 81BE16CD F6B9265B 6FB077E1 18B74777 88085AE6 FF0F6A70 66063BCA 11010B5C 8F659EFF F862AE69 616BFFD3 166CCF45 A00AE278 D70DD2EE 4E048354 3903B3C2 A7672661 D06016F7 4969474D 3E6E77DB AED16A4A D9D65ADC 40DF0B66 37D83BF0 A9BCAE53 DEBB9EC5 47B2CF7F 30B5FFE9 BDBDF21C CABAC28A 53B39330 24B4A3A6 BAD03605 CDD70693 54DE5729 23D967BF B3667A2E C4614AB8 5D681B02 2A6F2B94 B40BBE37 C30C8EA1 5A05DF1B 2D02EF8D";     
 
    /* Number */ 
    crc32 = function( /* String */ str, /* Number */ crc ) { 
        if( crc == window.undefined ) crc = 0; 
        var n = 0; //a number between 0 and 255 
        var x = 0; //an hex number 
 
        crc = crc ^ (-1); 
        for( var i = 0, iTop = str.length; i < iTop; i++ ) { 
            n = ( crc ^ str.charCodeAt( i ) ) & 0xFF; 
            x = "0x" + table.substr( n * 9, 8 ); 
            crc = ( crc >>> 8 ) ^ x; 
        } 
        return crc ^ (-1); 
    }; 
})();
/*
=============================================================================== 
*/

Ext.ns('Ext.ux.RapidApp.AppTab');

Ext.ux.RapidApp.AppTab.TabPanel = Ext.extend(Ext.TabPanel, {
	
	itemId: 'load-target',

	layoutOnTabChange: true,
	enableTabScroll: true,
	useContextMenu: true,
	
	applyActiveTab: function(tp,tab) {
		if(this.id == 'main-load-target'){
			var tab = tab || this.getActiveTab();
			
			if(tab) {
				// disabled unfished 'tabPath' feature
				//var load = tab.tabPath || tab.autoLoad;
				var load = tab.autoLoad;
				Ext.ux.RapidApp.HashNav.setHashpath(load);
			}
			
			var title = tab ? tab.title : null;
			Ext.ux.RapidApp.HashNav.updateTitle(title);
		}
	},

	initComponent: function() {
		
		// init tab checksum (crc) map:
		this.tabCrcMap = {};
		
		if(this.initLoadTabs) {
			this.on('afterrender',function() {
				Ext.each(this.initLoadTabs,function(cnf) {
					this.loadTab(cnf);
				},this);
			},this);
		}
		
		this.addEvents( 'navload' );
		
		if(this.useContextMenu) {
			this.on('contextmenu',this.onContextmenu,this);
		}
		
		// ------------------------------------------------------------
		// -- special HashNav behaviors if this is the main-load-target
		if(this.id == 'main-load-target'){
			// Handle direct nav on first load: (See Ext.ux.RapidApp.HashNav in History.js)
			this.on('afterrender',function(){
				
				var hash = Ext.ux.RapidApp.HashNav.INIT_LOCATION_HASH;
				if(hash && hash.search('#!/') == 0){
					Ext.ux.RapidApp.HashNav.handleHashChange(hash);
				}
				else {
					this.applyActiveTab();
				}
				
				this.on('tabchange',this.applyActiveTab,this);

			},this);
		}
		// --
		// ------------------------------------------------------------
		
		Ext.ux.RapidApp.AppTab.TabPanel.superclass.initComponent.call(this);
	},
	
	getContextMenuItems: function(tp,tab) {
		var items = [];
		
		var close_item = {
			itemId: 'close_item',
			text: 'Close Other Tabs',
			iconCls: 'icon-tabs-delete',
			scope: tp,
			handler: tp.closeAll.createDelegate(tp,[tab]),
			hideShow: function(){
				if (this.itemId != 'close_item') {
					// Whoever called us was supposed to set the scope to the
					// close_item but didn't
					return;
				}
				this.setVisible(tp.items.getCount() >= 2);
			}
		};

		var open_item = tab.loadContentCnf ? {
			itemId: 'open_item',
			text: 'Open in a New Tab',
			iconCls: 'icon-tab-go',
			scope: tp,
			handler: tp.openAnother.createDelegate(tp,[tab])
		} : null;
		
		if(close_item)	{ items.push(close_item); }
		if(open_item)	{ items.push(open_item); }
		
		return items;
	},
	
	onContextmenu: function(tp,tab,e) {
		// stop browser menu event to prevent browser right-click context menu
		// from opening:
		e.stopEvent();
		
		if(!tab.closable) { return; }
		
		var items = this.getContextMenuItems(tp,tab);
		if(items.length == 0) { return; }
		
		var menuItems = [];
		Ext.each(items,function(item){
			if(tp.items.getCount() < 2 && item.itemId == 'close_item') {
				return;
			}
			if(item.itemId == 'open_item') { 
				item.text = 'Open Another <b>' + tab.title + '</b>';
			}
			menuItems.push(item);
		},this);
		
		menuItems = menuItems.length == 2 ? [menuItems[0],'-',menuItems[1]] : menuItems;
		
		// Make sure the tab is activated so it is clear which is the Tab that
		// will *not* be closed
		tp.activate(tab);

		var menu = new Ext.menu.Menu({ items: menuItems });
		var pos = e.getXY();
		pos[0] = pos[0] + 10;
		pos[1] = pos[1] + 5;
		menu.showAt(pos);
	},
	
	closeAll: function(tab) {
		this.items.each(function(item) {
			if (item.closable && item != tab) {
				this.remove(item);
			}
		},this);
	},
	
	openAnother: function(tab) {
		var cnf = Ext.apply({},tab.loadContentCnf);
		if(cnf.id) { delete cnf.id; }
		if(cnf.itemId) { delete cnf.itemId; }
		cnf.newtab = true;
		this.loadTab(cnf);
	},

	
	
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
		this.fireEvent( 'navload' );
		this.loadTab.apply(this,arguments);
	},

	loadTab: function(cnf) {
		if(cnf.newtab) { //<-- the newtab param is set by the "open another tab" plugin
			delete cnf.newtab;
			cnf.seq = cnf.seq || 0;
			cnf.seq++;
			cnf.autoLoad = cnf.autoLoad || {};
			cnf.autoLoad.params = cnf.autoLoad.params || {};
			cnf.autoLoad.params['_seq'] = cnf.seq.toString();
		}
		
		var orig_cnf = Ext.decode(Ext.encode(cnf));
		
		// What was this for? Removed 2012-08-19 by HV because this breaks cnf.closable = false
		// prune falsy properties (object version of Ext.clean)
		//Ext.iterate(cnf,function(k,v){
		//	if(!v) { delete cnf[k]; }
		//},this);
		
		cnf = Ext.apply({
			loadContentCnf: orig_cnf, //<-- save the cnf used
			xtype: 'autopanel',
			//itemId: 'tab-' + Math.floor(Math.random()*100000),
			layout: 'fit',
			closable: true,
			title: 'Loading',
			iconCls: 'icon-loading',
			autoLoad: {}
		},cnf);
			
		Ext.applyIf(cnf.autoLoad, {
			text: 'Loading...',
			nocache: true,
			params: {}
		});
		
		cnf.autoLoad.url = cnf.autoLoad.url || cnf.url;
		Ext.apply(cnf.autoLoad.params,cnf.params||{});
		
		// ------------------------
		// Generate a checksum (using a crc algorithm) of the
		// *actual* url/params of the target. This allows dynamically checking
		// if a supplied loadContent is already open (see existTab below)
		//var tabCrc = 'tab-crc' + crc32(Ext.encode(
		//	[cnf.autoLoad.url,cnf.autoLoad.params]
		//));
		var tabCrc = this.getLoadCrc(cnf.autoLoad);
		
		// Check if this Tab is already loaded, and set active and return if it is:
		var existTab = this.getComponent(this.tabCrcMap[tabCrc]) || 
			this.getComponent(cnf.id) || this.getComponent(cnf.itemId);
		if (existTab) {
			//console.dir(existTab);
			return this.activate(existTab);
		}
		// ------------------------
		
		var tp = this;
		
		if(!cnf.cmpListeners) { cnf.cmpListeners = {}; }
		if(!cnf.cmpListeners.beforerender) { cnf.cmpListeners.beforerender = Ext.emptyFn; }
		cnf.cmpListeners.beforerender = Ext.createInterceptor(
			cnf.cmpListeners.beforerender,
			function() {
				var tab = this.ownerCt;
				
				// optional override if supplied in cnf:
				var setTitle = cnf.tabTitle || this.tabTitle;
				var setIconCls = cnf.tabIconCls || this.tabIconCls;
				
				if(!setIconCls && tab.iconCls == 'icon-loading') {
					setIconCls = 'icon-page';
				}
				
				if(!setTitle && tab.title == 'Loading') {
					var max_len = 10;
					var url_st = cnf.autoLoad.url.split('').reverse().join('');
					var str = url_st;
					if(url_st.length > max_len) { 
						str = url_st.substring(0,max_len) + '...'; 
					}
					setTitle = 'Untitled (' + str.split('').reverse().join('') + ')';
				}
				
				if(setTitle) { tab.setTitle(setTitle); }
				if(setIconCls) { tab.setIconClass(setIconCls); }
				
				/* 'tabPath' - unfinished feature
				if(this.tabPath) {
					tab.tabPath = this.tabPath;
					var tabId = tab.itemId || tab.getId();
					var Crc = tp.getLoadCrc(tab.tabPath);
					if(Crc) {
						tp.tabCrcMap[Crc] = tabId;
					}
				}
				*/
				
				tp.applyActiveTab.call(tp);
			}
		);
		
		var new_tab = this.add(cnf);
		var tabId = new_tab.itemId || new_tab.getId();
		if(tabCrc) { 
			// Map the crc checksum to the id of the tab for lookup later (above)
			this.tabCrcMap[tabCrc] = tabId;
		}
		
		return this.activate(new_tab);
	},
	
	getLoadCrc: function(load) {
		if(Ext.isString(load) || Ext.isObject(load)) {
			var autoLoad = Ext.isString(load) ? {url:load,params:{}} : load;
			return 'tab-crc' + crc32(Ext.encode(
				[autoLoad.url,autoLoad.params]
			));
		}
		return null;
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
	if(!loadTarget) { return; }
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
	
	// Override Ext.Component.getId() auto id generation
	getId : function(){
		return this.id || (this.id = 'appgrid-' + (++Ext.Component.AUTO_ID));
	},
	
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
		'filterdata', 						// MultiFilters
		'filterdata_frozen', 			// Frozen MultiFilters
		'column_summaries',				// Column Summaries
		'quickSearchCheckIndexes',		// Quick Search checked columns
		'open_record_column_hidden',	// Hidden state of special open record column
		'advanced_config',
		'advanced_config_active'
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
			column_order: column_order,
			sort: grid.getState().sort || null
		};

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
		
		if(this.force_read_only && this.store.api) {
			this.store.api.create = null;
			this.store.api.update = null;
			this.store.api.destroy = null;
		}
	
		this.addEvents('firstload');
		
		this.on('afterrender',this.addExtraToOptionsMenu,this);
		
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
		
		// Check to make sure store_autoLoad has not been set to a false value in
		// either the store or the grid config (which is now allowed to override the
		// store setting, see datastore-plus code)
		var store_autoLoad_disabled = (
			(typeof this.store_autoLoad != 'undefined' && !this.store_autoLoad) || 
			!this.store.store_autoLoad
		) ? true : false;
		
		// -- Workaround - manual single-use loadMask for the very first load
		// Need to investigate more why this is needed, and why the 'loadMask' grid
		// setting doesn't work on the first store load. I think it is related to
		// load order and possibly autoPanel. 
		// TODO: generalize/move this into datastore-plus
		if(!this.collapsed && !store_autoLoad_disabled) {
			this.on('afterrender',function() {
				var lMask = new Ext.LoadMask(this.getEl(),{ msg: "Loading Data Set" });
				lMask.show();
				var hide_fn;
				hide_fn = function(){ 
					this.fireEvent('firstload');
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
		
		// Override for consistency: push buttons to the right to match general positioning
		// when the paging toolbar is active
		if(this.force_disable_paging) { bbar_items.push('->'); }
		
		this.bbar = {
			xtype:	'toolbar',
			items: bbar_items
		};
		
		if(this.pageSize && !this.force_disable_paging) {
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
		
		// ----- Clear Sort: ----- //
		this.plugins.push('grid-hmenu-clear-sort');
		// ----------------------- //
		
		
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
		

		// ---- Delete support: LEGACY - this code is depricated by DataStorePlus 'destroy'
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
		
		// Optional override to force disable the bbar:
		if(this.force_disable_bbar && this.bbar) { 
			delete this.bbar; 
		}
		
		// Optional override to force disable the tbar:
		if(this.force_disable_tbar && this.tbar) { 
			delete this.tbar; 
		}
		
		this.init_open_record_handler();
		
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
			
			if(colmodel.config[colIndex] && 
			 colmodel.config[colIndex].dataIndex == '___open_action_col') {
				// Update the store open_record_column_hidden param with the current status 
				// (needed for saved searches):
				this.store.open_record_column_hidden = hidden;
				// Don't reload the store for the open record column:
				return;
			}
			
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
	
	init_open_record_handler: function() {
		if(this.open_record_url) {
			if(this.open_record_via_rest) {
				this.row_open_handler = function(grid,index,e){
					this.rest_open_record(index);
				};
			}
			else {
				// Original LoadContentCnf double-click handler, moved out of AppGrid2.pm:
				this.row_open_handler = Ext.ux.RapidApp.AppTab.gridrow_nav;
			}
			
			if(this.open_record_column) {
				// optionally set the hidden status param from the store 
				// (i.e. loaded from saved search)
				this.open_record_column_hidden = 
					(typeof this.store.open_record_column_hidden == 'undefined') ?
						this.open_record_column_hidden : this.store.open_record_column_hidden;
					
				this.columns.unshift({
					xtype: 'actioncolumn',
					width: 30,
					name: '___open_action_col',
					dataIndex: '___open_action_col',
					sortable: false,
					menuDisabled: true,
					resizable: false,
					hidden: this.open_record_column_hidden,
					header: '<span ' +
							'style="padding-left:0px;height:12px;color:#666666;" ' +
							'class="with-icon icon-magnify-tiny"' + 
						'>' +
						// using a bunch of &nbsp; instead of padding-left for IE. Idea is to push the 
						// header text to the right far enough so it can't be seen in the column header,
						// but can still be seen in the columns menu to toggle on/off. The column header
						// appears to show 
						'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' +
						'<i>Open Item Column</i></span>',
					items: [{
						icon: '/static/rapidapp/images/magnifier.png',
						tooltip: 'Open Item',
						handler: this.row_open_handler,
						scope: this
					}]
				});
			}
			
			this.on('rowdblclick',this.row_open_handler,this);
		}
	},
	
	rest_open_record: function(rec) {
		// Support argument as either index or actual Record:
		var Record = Ext.isNumber(rec) ? this.store.getAt(rec) : rec;
		var key = this.open_record_rest_key ? this.open_record_rest_key : 'id';
		var val = this.open_record_rest_key ? Record.data[key] : Record.id;
		
		if(!val) { throw 'rest_open_record(): failed to identify Record value!'; }
		
		//var hashpath = '#!' + this.open_record_url + '/' + key + '/' + val;
		var hashpath = '#!' + this.open_record_url + '/' + val;
		window.location.hash = hashpath;
	},
	
	alwaysRequestColumns: {},
	
	currentVisibleColnames: function() {
		var cm = this.getColumnModel();
		
		// Reset loadedColumnIndexes back to none
		this.loadedColumnIndexes = {};
		
		var columns = cm.getColumnsBy(function(c){
			if(this.alwaysRequestColumns[c.name]) { return true; }
			if(
				c.hidden || c.dataIndex == "" || 
				c.dataIndex == '___open_action_col'
			){ 
				return false; 
			}
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
	},
	
	// Pulls a copy of the Tab right-click context menu into the Grid Options menu
	addExtraToOptionsMenu: function() {
		if(this.addExtraToOptionsMenuCalled) { return; }
		this.addExtraToOptionsMenuCalled = true;
		
		var optionsMenu = this.getOptionsMenu();
		if(!optionsMenu) { return; }

		var ourTab = this.ownerCt;
		if(!ourTab || !ourTab.loadContentCnf) { return; }
		
		var ourTp = ourTab.ownerCt;
		if(!ourTp || !Ext.isFunction(ourTp.getContextMenuItems)) { return; }
		
		var contextItems = ourTp.getContextMenuItems.call(ourTp,ourTp,ourTab);
		if(!contextItems || contextItems.length == 0) { return; }
		
		optionsMenu.insert(0,'-');
		Ext.each(contextItems.reverse(),function(itm){ optionsMenu.insert(0,itm); },this);
		
		// Optional hook into an items 'hideShow' function. Used by close to check if there
		// are other tabs to close and hide itself
		optionsMenu.items.each(function(item){
			if(Ext.isFunction(item.hideShow)) {
				optionsMenu.on('beforeshow',item.hideShow,item);
			}
		},this);
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
	
	var export_filename = grid.title || grid.ownerCt.title || 'export';
	
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
			
			//return Ext.ux.postwith(url,options.params);
			
			options.params.export_filename = export_filename;
			
			var timeout = 900000; // 15-minutes

			if(Ext.isGecko) { // FireFox
				// Interactive window download:
				return Ext.ux.RapidApp.winDownload(
					url,options.params,"Exporting data to Excel...",timeout
				);
			}
			else {
				// Background download, since non-FF browsers can't detect download complete and
				// close the window:
				return Ext.ux.iframeBgDownload(url,options.params,timeout);
			}
			
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
