Ext.ns('Ext.ux.RapidApp.Plugin');

/* disabled and replaced by "listener_callbacks"

// Generic plugin that loads a list of event handlers. These 
// should be passed as an array of arrays, where the first
// element of each inner array is the event name, and the rest
// of the items are the handlers (functions) to register

Ext.ux.RapidApp.Plugin.EventHandlers = Ext.extend(Ext.util.Observable,{

	init: function(cmp) {
		if (! Ext.isArray(cmp.event_handlers)) { return true; }
		
		Ext.each(cmp.event_handlers,function(item) {
			if (! Ext.isArray(item)) { throw "invalid element found in event_handlers (should be array of arrays)"; }
			
			var event = item.shift();
			Ext.each(item,function(handler) {
				//Add handler:
				cmp.on(event,handler);
			});
		});
	}
});
Ext.preg('rappeventhandlers',Ext.ux.RapidApp.Plugin.EventHandlers);
*/


/* 2011-03-25 by HV:
 This is my solution to the problem described here:
 http://www.sencha.com/forum/showthread.php?92215-Toolbar-resizing-problem
*/
Ext.ux.RapidApp.Plugin.AutoWidthToolbars = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		if(! cmp.getTopToolbar) { return; }
		cmp.on('afterrender',function(c) {
			var tbar = c.getTopToolbar();
			if(tbar) {
				this.setAutoSize(tbar);
			}
			var bbar = c.getBottomToolbar();
			if(bbar) {
				this.setAutoSize(bbar);
			}
		},this);
	},
	setAutoSize: function(toolbar) {
		var El = toolbar.getEl();
		El.setSize('auto');
		El.parent().setSize('auto');
	}
});
Ext.preg('autowidthtoolbars',Ext.ux.RapidApp.Plugin.AutoWidthToolbars);


Ext.ux.RapidApp.Plugin.ClickableLinks = Ext.extend(Ext.util.Observable, {
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	init: function(cmp){
		this.cmp = cmp;
		
		// if HtmlEditor:
		if(this.cmp.onEditorEvent) {
			var onEditorEvent_orig = this.cmp.onEditorEvent;
			var plugin = this;
			this.cmp.onEditorEvent = function(e) {
				if(e.type == 'click') {  plugin.onClick.apply(this,arguments);  }
				onEditorEvent_orig.apply(this,arguments);
			}
		}
		else {
			this.cmp.on('render', this.onRender, this);
		}
	},
	
	onRender: function() {
		var el = this.cmp.getEl();

		Ext.EventManager.on(el, {
			'click': this.onClick,
			buffer: 100,
			scope: this
		});		
	},
	
	onClick: function(e,el,o) {
		// -- New: limit to only Anchor (<a>) tags. Needed for IE
		var tag = el ? el.nodeName : null;
		if(tag != 'A') { return; }
		// --
		
		var Element = new Ext.Element(el);
		var href = Element.getAttribute('href');
		if (href && href != '#') {
			document.location.href = href;
		}
	}
});
Ext.preg('clickablelinks',Ext.ux.RapidApp.Plugin.ClickableLinks);


Ext.ns('Ext.ux.RapidApp.Plugin.Combo');
Ext.ux.RapidApp.Plugin.Combo.Addable = Ext.extend(Ext.util.Observable, {
	
	createItemClass: 'appsuperbox-create-item',
	createItemHandler: null,
	
	constructor: function(cnf) { 	
		Ext.apply(this,cnf); 	
	},
	
	init: function(cmp){
		this.cmp = cmp;
		
		Ext.apply(this.cmp,{ classField: 'cls' });
		
		Ext.copyTo(this,this.cmp,[
			'createItemClass',
			'createItemHandler',
			'default_cls'
		]);
		
		Ext.applyIf(this.cmp,{
			tpl: this.getDefaultTpl()
		});
		
		if(Ext.isString(this.cmp.tpl)) {
			var tpl = this.getTplPrepend() + this.cmp.tpl;
			this.cmp.tpl = tpl;
		}
		
		if (this.createItemHandler) {
			this.initCreateItems();
		}
	},
		
	initCreateItems: function() {
		var plugin = this;
		this.cmp.onViewClick = function() {
			var event = arguments[arguments.length - 1]; // <-- last passed argument, the event object;
			if(event) {
				var target = event.getTarget(null,null,true);
				
				// Handle create item instead of normal handler:
				if (target.hasClass(plugin.createItemClass)) {
					this.collapse();
					return plugin.createItemHandler.call(this,plugin.createItemCallback);
				}
			}

			// Original handler:
			this.constructor.prototype.onViewClick.apply(this,arguments);
		};
	},
	
	createItemCallback: function(data) {
		if(! data[this.classField] && this.default_cls) {
			data[this.classField] = this.default_cls;
		}
		var Store = this.getStore();
		var recMaker = Ext.data.Record.create(Store.fields.items);
		var newRec = new recMaker(data);
		Store.insert(0,newRec);
		this.onSelect(newRec,0);
	},
	
	getTplPrepend: function() {
		return '<div style="float:right;"><div class="' + this.createItemClass + '">Create New</div></div>';
	},
	
	getDefaultTpl: function() {
		return 
			'<div class="x-combo-list-item">shit &nbsp;</div>' +
			'<tpl for="."><div class="x-combo-list-item">{' + this.cmp.displayField + '}</div></tpl>';
	}
});
Ext.preg('combo-addable',Ext.ux.RapidApp.Plugin.Combo.Addable);

Ext.ux.RapidApp.Plugin.Combo.AppSuperBox = Ext.extend(Ext.ux.RapidApp.Plugin.Combo.Addable, {
	
	itemLabel: 'items',
	
	init: function(cmp){
		this.cmp = cmp;
		
		if(this.cmp.fieldLabel) { this.itemLabel = this.cmp.fieldLabel; }
		
		Ext.apply(this.cmp,{
			xtype: 'superboxselect', // <-- no effect, the xtype should be set to this in the consuming class
			extraItemCls: 'x-superboxselect-x-flag',
			expandBtnCls: 'ra-icon-roles_expand_sprite',
			listEmptyText: '(no more available ' + this.itemLabel + ')',
			emptyText: '(none)',
			listAlign: 'tr?',
			itemSelector: 'li.x-superboxselect-item',
			stackItems: true
		});
		
		Ext.ux.RapidApp.Plugin.Combo.AppSuperBox.superclass.init.apply(this,arguments);
	},
	
	getDefaultTpl: function() {
		return new Ext.XTemplate(
			'<div class="x-superboxselect x-superboxselect-stacked">',
					'<ul>',
						'<li style="padding-bottom:2px;">',
							'<div style="float:right;"><div class="' + this.createItemClass + '">Create New</div></div>',
							'<div>',
								'Add ' + this.itemLabel + ':',
							'</div>',
						'</li>',
						'<tpl for=".">',
							'<li class="x-superboxselect-item x-superboxselect-x-flag {' + this.cmp.classField + '}">',
								'{' + this.cmp.displayField + '}',
							'</li>',
						'</tpl>',
					'</ul>',
				'</div>'
		);
	}
	
});
Ext.preg('appsuperbox',Ext.ux.RapidApp.Plugin.Combo.AppSuperBox);


Ext.ns('Ext.ux.RapidApp.Plugin');
Ext.ux.RapidApp.Plugin.ReloadServerEvents = Ext.extend(Ext.util.Observable, {
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	init: function(cmp){
		this.cmp = cmp;
		if(Ext.isArray(this.cmp.reloadEvents)) {
			this.cmp.on('render', this.onRender, this);
		}
	},
	
	onRender: function() {

		var handler = {
			id: this.cmp.id,
			func: function() {
				var store = null;
				if(Ext.isFunction(this.getStore)) { store = this.getStore(); }
				if(! store) { store = this.store; }
				if(store && Ext.isFunction(store.reload)) {
					store.reload();
				}
			}
		};
		
		Ext.each(this.cmp.reloadEvents,function(event) {
			Ext.ux.RapidApp.EventObject.attachServerEvents(handler,event);
		});
	}
	
});
Ext.preg('reload-server-events',Ext.ux.RapidApp.Plugin.ReloadServerEvents);


/*  Modified from Ext.ux.grid.Search for appgrid2 */

// Check RegExp.escape dependency
if('function' !== typeof RegExp.escape) {
	throw('RegExp.escape function is missing. Include Ext.ux.util.js file.');
}

/**
 * Creates new Search plugin
 * @constructor
 * @param {Object} A config object
 */
//Ext.ux.RapidApp.Plugin.GridQuickSearch = function(config) {
//	Ext.apply(this, config);
//	Ext.ux.RapidApp.Plugin.GridQuickSearch.superclass.constructor.call(this);
//}; // eo constructor

Ext.ux.RapidApp.Plugin.GridQuickSearch = Ext.extend(Ext.util.Observable, {
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	/**
	 * @cfg {Boolean} autoFocus Try to focus the input field on each store load if set to true (defaults to undefined)
	 */

	/**
	 * @cfg {String} searchText Text to display on menu button
	 */
	 searchText:'Quick Search'

	/**
	 * @cfg {String} searchTipText Text to display as input tooltip. Set to '' for no tooltip
	 */ 
	,searchTipText:'Type a text to search and press Enter'

	/**
	 * @cfg {String} selectAllText Text to display on menu item that selects all fields
	 */
	,selectAllText:'Select All'

	/**
	 * @cfg {String} position Where to display the search controls. Valid values are top and bottom
	 * Corresponding toolbar has to exist at least with mimimum configuration tbar:[] for position:top or bbar:[]
	 * for position bottom. Plugin does NOT create any toolbar.(defaults to "bottom")
	 */
	,position:'bottom'

	/**
	 * @cfg {String} iconCls Icon class for menu button (defaults to "ra-icon-magnifier")
	 */
	//,iconCls:'ra-icon-magnifier'
	,iconCls: null

	/**
	 * @cfg {String/Array} checkIndexes Which indexes to check by default. Can be either 'all' for all indexes
	 * or array of dataIndex names, e.g. ['persFirstName', 'persLastName'] (defaults to "all")
	 */
	,checkIndexes:'all'

	/**
	 * @cfg {Array} disableIndexes Array of index names to disable (not show in the menu), e.g. ['persTitle', 'persTitle2']
	 * (defaults to [] - empty array)
	 */
	,disableIndexes:[]

	/**
	 * Field containing search text (read-only)
	 * @property field
	 * @type {Ext.form.TwinTriggerField}
	 */

	/**
	 * @cfg {String} dateFormat How to format date values. If undefined (the default) 
	 * date is formatted as configured in colummn model
	 */

	/**
	 * @cfg {Boolean} showSelectAll Select All item is shown in menu if true (defaults to true)
	 */
	,showSelectAll:true

	/**
	 * Menu containing the column module fields menu with checkboxes (read-only)
	 * @property menu
	 * @type {Ext.menu.Menu}
	 */

	/**
	 * @cfg {String} menuStyle Valid values are 'checkbox' and 'radio'. If menuStyle is radio
	 * then only one field can be searched at a time and selectAll is automatically switched off. 
	 * (defaults to "checkbox")
	 */
	,menuStyle:'checkbox'

	/**
	 * @cfg {Number} minChars Minimum characters to type before the request is made. If undefined (the default)
	 * the trigger field shows magnifier icon and you need to click it or press enter for search to start. If it
	 * is defined and greater than 0 then maginfier is not shown and search starts after minChars are typed.
	 * (defaults to undefined)
	 */

	/**
	 * @cfg {String} minCharsTipText Tooltip to display if minChars is > 1
	 */
	,minCharsTipText:'Type at least {0} characters'

	/**
	 * @cfg {String} mode Use 'remote' for remote stores or 'local' for local stores. If mode is local
	 * no data requests are sent to server the grid's store is filtered instead (defaults to "remote")
	 */
	,mode:'remote'

	/**
	 * @cfg {Array} readonlyIndexes Array of index names to disable (show in menu disabled), e.g. ['persTitle', 'persTitle2']
	 * (defaults to undefined)
	 */

	/**
	 * @cfg {Number} width Width of input field in pixels (defaults to 100)
	 */
	,width:250

	/**
	 * @cfg {String} xtype xtype is usually not used to instantiate this plugin but you have a chance to identify it
	 */
	,xtype:'gridsearch'

	/**
	 * @cfg {Object} paramNames Params name map (defaults to {fields:"fields", query:"query"}
	 */
	,paramNames: {
		fields:'fields',
		query:'query',
		quicksearch_mode: 'quicksearch_mode'
	}

	/**
	 * @cfg {String} shortcutKey Key to fucus the input field (defaults to r = Sea_r_ch). Empty string disables shortcut
	 */
	,shortcutKey:'r'

	/**
	 * @cfg {String} shortcutModifier Modifier for shortcutKey. Valid values: alt, ctrl, shift (defaults to "alt")
	 */
	,shortcutModifier:'alt'

	/**
	 * @cfg {String} align "left" or "right" (defaults to "left")
	 */

	/**
	 * @cfg {Number} minLength Force user to type this many character before he can make a search 
	 * (defaults to undefined)
	 */

	/**
	 * @cfg {Ext.Panel/String} toolbarContainer Panel (or id of the panel) which contains toolbar we want to render
	 * search controls to (defaults to this.grid, the grid this plugin is plugged-in into)
	 */
	
	// {{{
	/**
	 * @private
	 * @param {Ext.grid.GridPanel/Ext.grid.EditorGrid} grid reference to grid this plugin is used for
	 */
	// ,fieldNameMap: {},
	
	,init:function(grid) {
		this.grid = grid;
		
		Ext.apply(this,grid.grid_search_cnf || {});
		
		grid.quicksearch_plugin = this;
		
		// -- New: disable plugin if there are no quick_search columns (2012-04-11 by HV)
		if(!this.getQuickSearchColumns().length > 0) { return; }
		// --
		
		this.fieldNameMap = {};
		
		// -- query_search_use_column support, added by HV 2011-12-26
		var columns = this.grid.initialConfig.columns;
		Ext.each(columns,function(column) {
			if(column.query_search_use_column){
				this.fieldNameMap[column.name] = column.query_search_use_column;
			}
		},this);
		// --

		// setup toolbar container if id was given
		if('string' === typeof this.toolbarContainer) {
			this.toolbarContainer = Ext.getCmp(this.toolbarContainer);
		}

		// do our processing after grid render and reconfigure
		grid.onRender = grid.onRender.createSequence(this.onRender, this);
		grid.reconfigure = grid.reconfigure.createSequence(this.reconfigure, this);
	}, // eo function init
	// }}}
	// {{{
	/**
	 * adds plugin controls to <b>existing</b> toolbar and calls reconfigure
	 * @private
	 */
	onRender:function() {
	
		var panel = this.toolbarContainer || this.grid;
		var tb = 'bottom' === this.position ? panel.bottomToolbar : panel.topToolbar;
		
		// If there is no toolbar, then we can't setup, so we abort:
		if(!tb) { return; }
		
		// -- Optional extra override for checked columns. init_quick_search_columns is
		// set in AppGrid2 via HTTP Query param 'quick_search_cols'
		var store = this.grid.getStore();
		store.quickSearchCheckIndexes = this.grid.init_quick_search_columns || store.quickSearchCheckIndexes;
		// --
		
		store.quicksearch_mode = store.quicksearch_mode || this.grid.quicksearch_mode;
		this.grid.quicksearch_mode = store.quicksearch_mode;
		
		store.on('beforeload',this.applyStoreParams,this);
		
		// add menu
		this.menu = new Ext.menu.Menu();

		// handle position
		if('right' === this.align) {
			tb.addFill();
		}
		else {
			if(0 < tb.items.getCount()) {
				// The separator is ugly, removed (2012-04-11 by HV)
				//tb.addSeparator();
			}
		}
		
		this.grid.quicksearch_mode = this.grid.quicksearch_mode || 'like';
		
		this.searchText = (this.grid.quicksearch_mode == 'exact') ?
			'Exact Search' : this.searchText;
		
		this.modeMenu = new Ext.menu.Menu();
		this.modeMenu.add(
			{
				xtype: 'menucheckitem',
				text: 'Normal',
				group: 'quick_search_mode',
				header: 'Quick Search',
				mode: 'like',
				checked: (this.grid.quicksearch_mode == 'like' ? true : false)
			},
			{
				xtype: 'menucheckitem',
				text: 'Exact (faster)',
				group: 'quick_search_mode',
				header: 'Exact Search',
				mode: 'exact',
				checked: (this.grid.quicksearch_mode == 'exact' ? true : false)
			}
		);
		
		this.outerMenu = new Ext.menu.Menu();
		this.outerMenu.add(
			{
				text: 'Mode',
				iconCls: 'ra-icon-preferences',
				hideOnClick: false,
				menu: this.modeMenu
			},
			{
				text: 'Search Columns',
				iconCls: 'x-cols-icon',
				hideOnClick: false,
				menu: this.menu
			}
		);
		
		// Only enable the new 'outerMenu' if allow_set_quicksearch_mode is true:
		var menu = this.grid.allow_set_quicksearch_mode ? this.outerMenu : this.menu;
		
		var btnConfig = {
			text: this.searchText,
			menu: menu,
			iconCls:this.iconCls
		};
		
		
		//this.menu.on('hide',this.persistCheckIndexes,this);
		menu.on('hide',this.persistCheckIndexes,this);
		
		// -- Optional config: disable pressing of the button (making it act only as a label):
		if(this.grid.quicksearch_disable_change_columns) {
			delete btnConfig.menu;
			Ext.apply(btnConfig,{
				enableToggle: false,
				allowDepress: false,
				handleMouseEvents: false,
				cls:'ra-override-cursor-default'
			});
		}
		// --

		this.button = new Ext.Button(btnConfig);
		tb.add(this.button);

		// add input field (TwinTriggerField in fact)
		this.field = new Ext.form.TwinTriggerField({
			 width:this.width
			,selectOnFocus:undefined === this.selectOnFocus ? true : this.selectOnFocus
			,trigger1Class:'x-form-clear-trigger'
			,trigger2Class:this.minChars ? 'x-hide-display' : 'x-form-search-trigger'
			,onTrigger1Click:this.onTriggerClear.createDelegate(this)
			,onTrigger2Click:this.minChars ? Ext.emptyFn : this.onTriggerSearch.createDelegate(this)
			,minLength:this.minLength
		});
		
		// -----
		if(this.grid.preload_quick_search) {
			// -- Highlight Fx on the field to call attention to it when it is preloaded
			this.grid.on('firstload',function(){
				this.el.pause(.2);
				this.el.frame("FFDF00", 2, { duration: .5 });
			},this.field);
			// --
			
			this.field.setValue(this.grid.preload_quick_search);
			var plugin = this, store = this.grid.store;
			var onBeforeload;
			onBeforeload = function(ds,options) {
				// immediately remove ourselves on first call. This should be the initial
				// load of the store after being initialized
				store.un('beforeload',onBeforeload,plugin);
				// Called only on the very first load (removes itself above)
				// sets the store params without calling reload (since the load is
				// already in progress). This allows a single load, including the
				// preload_quick_search
				plugin.applyStoreParams.call(plugin);
				
			}
			store.on('beforeload',onBeforeload,plugin);
		}
		// -----

		// install event handlers on input field
		this.field.on('render', function() {
			// register quick tip on the way to search
			
			/*
			if((undefined === this.minChars || 1 < this.minChars) && this.minCharsTipText) {
				Ext.QuickTips.register({
					 target:this.field.el
					,text:this.minChars ? String.format(this.minCharsTipText, this.minChars) : this.searchTipText
				});
			}
			*/
			
			if(this.minChars) {
				this.field.el.on({scope:this, buffer:300, keyup:this.onKeyUp});
			}

			// install key map
			var map = new Ext.KeyMap(this.field.el, [{
				 key:Ext.EventObject.ENTER
				,scope:this
				,fn:this.onTriggerSearch
			},{
				 key:Ext.EventObject.ESC
				,scope:this
				,fn:this.onTriggerClear
			}]);
			map.stopEvent = true;
		}, this, {single:true});

		tb.add(this.field);

		// re-layout the panel if the toolbar is outside
		if(panel !== this.grid) {
			this.toolbarContainer.doLayout();
		}

		// reconfigure
		this.reconfigure();

		// keyMap
		if(this.shortcutKey && this.shortcutModifier) {
			var shortcutEl = this.grid.getEl();
			var shortcutCfg = [{
				 key:this.shortcutKey
				,scope:this
				,stopEvent:true
				,fn:function() {
					this.field.focus();
				}
			}];
			shortcutCfg[0][this.shortcutModifier] = true;
			this.keymap = new Ext.KeyMap(shortcutEl, shortcutCfg);
		}

		if(true === this.autoFocus) {
			this.grid.store.on({scope:this, load:function(){this.field.focus();}});
		}

	} // eo function onRender
	// }}}
	// {{{
	/**
	 * field el keypup event handler. Triggers the search
	 * @private
	 */
	,onKeyUp:function(e, t, o) {

		// ignore special keys 
		if(e.isNavKeyPress()) {
			return;
		}

		var length = this.field.getValue().toString().length;
		if(0 === length || this.minChars <= length) {
			this.onTriggerSearch();
		}
	} // eo function onKeyUp
	// }}}
	// {{{
	/**
	 * Clear Trigger click handler
	 * @private 
	 */
	,onTriggerClear:function() {
		// HV: added the baseParams check below. this fixes a bug, it is probably needed
		// because of odd things we're doing in AppGrid2/Store
		if(this.field.getValue() || this.grid.store.lastOptions.params.query || this.grid.store.baseParams.query) {
			this.field.setValue('');
			this.field.focus();
			this.onTriggerSearch();
			
		}
	} // eo function onTriggerClear
	// }}}
	// {{{
	/**
	 * Search Trigger click handler (executes the search, local or remote)
	 * @private 
	 */
	,onTriggerSearch:function() {
		if(!this.field.isValid()) {
			return;
		}
		var val = this.field.getValue();
		var store = this.grid.store;

		// grid's store filter
		if('local' === this.mode) {
			store.clearFilter();
			if(val) {
				store.filterBy(function(r) {
					var retval = false;
					this.menu.items.each(function(item) {
						if(!item.checked || retval) {
							return;
						}
						var rv = r.get(item.dataIndex);
						rv = rv instanceof Date ? rv.format(this.dateFormat || r.fields.get(item.dataIndex).dateFormat) : rv;
						var re = new RegExp(RegExp.escape(val), 'gi');
						retval = re.test(rv);
					}, this);
					if(retval) {
						return true;
					}
					return retval;
				}, this);
			}
			else {
			}
		}
		// ask server to filter records
		else {
			//applyStoreParams now called in 'beforeload' handler
			//this.applyStoreParams();
			// reload store
			
			// clear start (necessary if we have paging) - resets to page 1
			// (moved from applyStoreParams since it is now called in beforeload)
			if(store.lastOptions && store.lastOptions.params) {
				store.lastOptions.params[store.paramNames.start] = 0;
			}
			
			store.reload();
		}
	}

	,applyStoreParams: function() {
		var val = this.field.disabled ? '' : this.field.getValue();
		var store = this.grid.store;
		
		// get fields to search array
		var fields = [];
		this.menu.items.each(function(item) {
			if(item.checked) {
				var col_name = item.dataIndex;
				if(this.fieldNameMap[col_name]) { col_name = this.fieldNameMap[col_name]; }
				fields.push(col_name);
			}
		},this);

		// add fields and query to baseParams of store
		delete(store.baseParams[this.paramNames.fields]);
		delete(store.baseParams[this.paramNames.query]);
		delete(store.baseParams[this.paramNames.quicksearch_mode]);
		if (store.lastOptions && store.lastOptions.params) {
			delete(store.lastOptions.params[this.paramNames.fields]);
			delete(store.lastOptions.params[this.paramNames.query]);
			delete(store.lastOptions.params[this.paramNames.quicksearch_mode]);
		}
		//if(fields.length && !this.field.disabled) {
			store.baseParams[this.paramNames.fields] = Ext.encode(fields);
			store.baseParams[this.paramNames.query] = val;
			store.baseParams[this.paramNames.quicksearch_mode] = this.grid.quicksearch_mode;
		//}
	}


	// eo function onTriggerSearch
	// }}}
	// {{{
	/**
	 * @param {Boolean} true to disable search (TwinTriggerField), false to enable
	 */
	,setDisabled:function() {
		this.field.setDisabled.apply(this.field, arguments);
	} // eo function setDisabled
	// }}}
	// {{{
	/**
	 * Enable search (TwinTriggerField)
	 */
	,enable:function() {
		this.setDisabled(false);
	} // eo function enable
	// }}}
	// {{{
	/**
	 * Disable search (TwinTriggerField)
	 */
	,disable:function() {
		this.setDisabled(true);
	} // eo function disable
	// }}}
	// {{{
	/**
	 * (re)configures the plugin, creates menu items from column model
	 * @private 
	 */
	,reconfigure:function() {
		var store = this.grid.getStore()
	
		// NEW: Try to load checkIndex list from a property in the grid store
		// (added for saved state integration, 2012-09-18 by HV)
		this.checkIndexes = store.quickSearchCheckIndexes || this.checkIndexes;
		
		// Added for saved state integration 2012-12-16 by HV:
		this.grid.quicksearch_mode = store.quicksearch_mode;
		
		// {{{
		// remove old items
		var menu = this.menu;
		menu.removeAll();
		
		
		// add Select All item plus separator
		if(this.showSelectAll && 'radio' !== this.menuStyle) {
			menu.add(new Ext.menu.CheckItem({
				 text:this.selectAllText
				,checked:!(this.checkIndexes instanceof Array)
				,hideOnClick:false
				,handler:function(item) {
					var checked = ! item.checked;
					item.parentMenu.items.each(function(i) {
						if(item !== i && i.setChecked && !i.disabled) {
							i.setChecked(checked);
						}
					});
				}
			}),'-');
		}

		// }}}
		// {{{
		// add new items
		//var cm = this.grid.colModel;
		var columns = this.getQuickSearchColumns();
		
		var group = undefined;
		if('radio' === this.menuStyle) {
			group = 'g' + (new Date).getTime();	
		}
		//Ext.each(cm.config, function(config) {
		Ext.each(columns, function(config) {
			
			var disable = false;
			Ext.each(this.disableIndexes, function(item) {
				disable = disable ? disable : item === config.dataIndex;
			});
			if(!disable) {
				menu.add(new Ext.menu.CheckItem({
					 text:config.header
					,hideOnClick:false
					,group:group
					,checked:'all' === this.checkIndexes
					,dataIndex:config.dataIndex
				}));
			}
		}, this);
		// }}}
		// {{{
		// check items
		if(this.checkIndexes instanceof Array) {
			Ext.each(this.checkIndexes, function(di) {
				var item = menu.items.find(function(itm) {
					return itm.dataIndex === di;
				});
				if(item) {
					item.setChecked(true, true);
				}
			}, this);
		}
		// }}}
		// {{{
		// disable items
		if(this.readonlyIndexes instanceof Array) {
			Ext.each(this.readonlyIndexes, function(di) {
				var item = menu.items.find(function(itm) {
					return itm.dataIndex === di;
				});
				if(item) {
					item.disable();
				}
			}, this);
		}
		// }}}
		
		this.persistCheckIndexes();
	}, 
	
	getQuickSearchColumns: function() {
		if(!this.QuickSearchColumns) {
			var columns = this.grid.initialConfig.columns;
			var quick_search_columns = [];
			Ext.each(columns, function(config) {
				var disable = false;
				if(config.header && config.dataIndex && !config.no_quick_search) {
					quick_search_columns.push(config);
				}
			},this);
			this.QuickSearchColumns = quick_search_columns;
		}
		return this.QuickSearchColumns;
	},
	
	applySearchMode: function(){
		var item;
		this.modeMenu.items.each(function(i) {
			if(i.checked) { item = i; }
		},this);
		if(!item || !item.header || !item.mode) {
			// Fallback/default: should never get here:
			item = { header: 'Quick Search', mode: 'like' };
		}
		
		this.searchText = item.header;
		this.grid.quicksearch_mode = item.mode;
		this.grid.store.quicksearch_mode = item.mode;
	},
	
	persistCheckIndexes: function(){
		
		this.applySearchMode();
		
		var indexes = [];
		var headers = [];
		var all = true;
		this.menu.items.each(function(item) {
			if(item.checked && item.dataIndex) {
				headers.push(item.text);
				indexes.push(item.dataIndex);
			}
			else {
				if(item.dataIndex) { all = false; }
			}
		},this);
		
		// -- New: Persist checkIndexes for saved state integration:
		this.grid.store.quickSearchCheckIndexes = indexes;
		// --
		
		var sup = all ? 'all' : indexes.length;
		
		var btnText = this.searchText + 
			'<span class="superscript-green" style="font-weight:bold;padding-left:1px;">' + sup + '</span>';
			
		if(indexes.length == 1) {
			var header = headers[0] || indexes[0];
			btnText = this.searchText + ' | ' + header; 
		}
		
		this.button.setText(btnText);
		
		//
		this.field.setDisabled(!indexes.length);
		
	}

}); 



/*
 Ext.ux.RapidApp.Plugin.GridHmenuColumnsToggle
 2011-06-08 by HV

 Plugin for Ext.grid.GridPanel that converts the 'Columns' hmenu submenu item
 into a Ext.ux.RapidApp.menu.ToggleSubmenuItem (instead of Ext.menu.Item)

 See the Ext.ux.RapidApp.menu.ToggleSubmenuItem class for more details.
*/
Ext.ux.RapidApp.Plugin.GridHmenuColumnsToggle = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		cmp.on('afterrender',this.onAfterrender,this);
	},
	
	onAfterrender: function() {
		
		var hmenu = this.cmp.view.hmenu;
		if(!hmenu) { return; }
		
		var colsItem = hmenu.getComponent('columns');
		if (!colsItem) { return; }
		colsItem.hide();
		
		hmenu.add(Ext.apply(Ext.apply({},colsItem.initialConfig),{
			xtype: 'menutoggleitem',
			itemId:'columns-new'
		}));
	}
});
Ext.preg('grid-hmenu-columns-toggle',Ext.ux.RapidApp.Plugin.GridHmenuColumnsToggle);


/*
 Ext.ux.RapidApp.Plugin.GridHmenuClearSort
 2012-07-21 by HV

 Plugin for Ext.grid.GridPanel that adds "Clear Current Sort" to Hmenu
*/
Ext.ux.RapidApp.Plugin.GridHmenuClearSort = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		cmp.on('afterrender',this.onAfterrender,this);
	},
	
	getClearSortButton: function(){
		return {
			text: 'Clear Current Sort',
			itemId: 'clear-sort',
			iconCls: 'ra-icon-remove-sort',
			handler: function() {
				this.cmp.store.setDefaultSort(null);
				this.cmp.store.reload();
			},
			scope: this
		};
	},
	
	beforeMenuShow: function(hmenu){
		var clearSortItem = hmenu.getComponent('clear-sort');
		if (!clearSortItem) { return; }
		var store = this.cmp.getStore();
		var curSort = store ? store.getSortState() : null;
		clearSortItem.setVisible(curSort);
	},
	
	onAfterrender: function() {
		var hmenu = this.cmp.view.hmenu;
		if(!hmenu) { return; }
		hmenu.insert(2,this.getClearSortButton());
		hmenu.on('beforeshow',this.beforeMenuShow,this);
	}
});
Ext.preg('grid-hmenu-clear-sort',Ext.ux.RapidApp.Plugin.GridHmenuClearSort);



// For use with Fields, returns empty strings as null
Ext.ux.RapidApp.Plugin.EmptyToNull = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		var nativeGetValue = cmp.getValue;
		cmp.getValue = function() {
			var value = nativeGetValue.call(cmp);
			if (value == '') { return null; }
			return value;
		}
	}
});
Ext.preg('emptytonull',Ext.ux.RapidApp.Plugin.EmptyToNull);

// For use with Fields, returns nulls as empty string
Ext.ux.RapidApp.Plugin.NullToEmpty = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		var nativeGetValue = cmp.getValue;
		cmp.getValue = function() {
			var value = nativeGetValue.call(cmp);
			if (value == null) { return ''; }
			return value;
		}
	}
});
Ext.preg('nulltoempty',Ext.ux.RapidApp.Plugin.NullToEmpty);

// For use with Fields, returns false/true as 0/1
Ext.ux.RapidApp.Plugin.BoolToInt = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		var nativeGetValue = cmp.getValue;
		cmp.getValue = function() {
			var value = nativeGetValue.call(cmp);
			if (value == false) { return 0; }
			if (value == true) { return 1; }
			return value;
		}
	}
});
Ext.preg('booltoint',Ext.ux.RapidApp.Plugin.BoolToInt);


// Plugin adds '[+]' to panel title when collapsed if titleCollapse is on
Ext.ux.RapidApp.Plugin.TitleCollapsePlus = Ext.extend(Ext.util.Observable,{
	
	addedString: '',
	
	init: function(cmp) {
		this.cmp = cmp;
		
		if (this.cmp.titleCollapse && this.cmp.title) {
			this.cmp.on('beforecollapse',function(){
				this.updateCollapseTitle.call(this,'collapse');
			},this);
			this.cmp.on('beforeexpand',function(){
				this.updateCollapseTitle.call(this,'expand');
			},this);
			this.cmp.on('afterrender',this.updateCollapseTitle,this);
		}
	},
	
	updateCollapseTitle: function(opt) {
		if (!this.cmp.titleCollapse || !this.cmp.title) { return; }
		
		if(opt == 'collapse') { return this.setTitlePlus(true); }
		if(opt == 'expand') { return this.setTitlePlus(false); }
		
		if(this.cmp.collapsed) {
			this.setTitlePlus(true);
		}
		else {
			this.setTitlePlus(false);
		}
	},
	
	getTitle: function() {
		return this.cmp.title.replace(this.addedString,'');
	},
	
	setTitlePlus: function(bool) {
		var title = this.getTitle();
		if(bool) {
			this.addedString = 
				'&nbsp;<span style="font-weight:lighter;font-family:monospace;color:gray;">' + 
					'&#91;&#43;&#93;' +
				'</span>';
			return this.cmp.setTitle(title + this.addedString);
		}
		this.addedString = '';
		return this.cmp.setTitle(title);
	}
});
Ext.preg('titlecollapseplus',Ext.ux.RapidApp.Plugin.TitleCollapsePlus);



// Automatically expands label width according to the longest fieldLabel
// in a form panel's items, if needed
Ext.ux.RapidApp.Plugin.DynamicFormLabelWidth = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		if(!cmp.labelWidth) { return; } // <-- a labelWidth must be set for plugin to be active
		var longField = this.getLongestField();
		if(!longField){ return; }
		
		Ext.applyIf(longField,this.cmp.defaults || {});
		longField.hidden = true;
		
		var label = new Ext.form.Label({
			renderTo: document.body,
			cls: 'x-hide-offsets',
			text: 'I',
			hidden: true,
			style: longField.labelStyle || ''
		});
		label.show();
		var metrics = Ext.util.TextMetrics.createInstance(label.getEl());
		var calcWidth = metrics.getWidth(longField.fieldLabel) + 10;
		label.destroy();
		
		if(calcWidth > cmp.labelWidth) {
			cmp.labelWidth = calcWidth;
		}
	},
	
	getLongestField: function() {
		var longField = null;
		var longLen = 0;
		this.cmp.items.each(function(item){
			if(!Ext.isString(item.fieldLabel)) { return; }
			var curLen = item.fieldLabel.length;
			if(curLen > longLen) {
				longLen = curLen;
				longField = item;
			}
		},this);
		if(!longField){ return null; }
		return Ext.apply({},longField); //<-- return a copy instead of original
	}
});
Ext.preg('dynamic-label-width',Ext.ux.RapidApp.Plugin.DynamicFormLabelWidth);



// This is stupid, but needed to support an auto height Grid with autoScroll
// to be able to scroll left/right:
Ext.ux.RapidApp.Plugin.gridAutoHeight = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		cmp.on('resize',this.setAutoHeight,this);
		cmp.on('viewready',this.onViewReady,this);
	},
	
	onViewReady: function() {
		this.setAutoHeight.call(this);
		var view = this.cmp.getView();
		view.on('refresh',this.setAutoHeight,this);
	},
	
	setAutoHeight: function() {
		var grid = this.cmp;
		var el1 = grid.getEl().child('div.x-grid3');
		if(el1) { el1.setHeight('auto'); }
		var el2 = grid.getEl().child('div.x-grid3-scroller');
		if(el2) { el2.setHeight('auto'); }
	}
});
Ext.preg('grid-autoheight',Ext.ux.RapidApp.Plugin.gridAutoHeight);




// Plugin for ManagedIframe
// Sets the height based on the iframe height after it's loaded
Ext.ux.RapidApp.Plugin.autoHeightIframe = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		this.cmp.on('domready',this.onDocumentLoaded,this);
	},
	
	onDocumentLoaded: function(el) {
		this.setHeight.defer(100,this,[el]);
	},
	
	setHeight:function(el) {
		var height = el.dom.contentDocument.activeElement.scrollHeight;
		this.cmp.setHeight(height + 35);
	}
});
Ext.preg('iframe-autoheight',Ext.ux.RapidApp.Plugin.autoHeightIframe);



Ext.ux.RapidApp.Plugin.ReadOnlyField = Ext.extend(Ext.util.Observable,{
	
	styles: {
		'background-color': 'transparent',
		'border-color': 'transparent',
		'background-image': 'none',
		
		// the normal text field has padding-top: 2px which makes the text sit towards
		// the bottom of the field. We set top and bot here to move one of the px to the
		// bottom so the text will be vertically centered but take up the same vertical
		// size as a normal text field:
		'padding-top': '1px',
		'padding-bottom': '1px'
	},
	
	getStyleString: function() {
		var str = '';
		Ext.iterate(this.styles,function(k,v) {
			str += k + ':' + v + ';';
		},this);
		return str;
	},
	
	init: function(cmp) {
		this.cmp = cmp;
		
		cmp.style = cmp.style || '';
		
		if(Ext.isObject(cmp.style)) {
			Ext.apply(cmp.style,this.styles);
		}
		else {
			cmp.style += this.getStyleString();
		}
		
		cmp.readOnly = true;
		cmp.allowBlank = true;
	}
	
});
Ext.preg('read-only-field',Ext.ux.RapidApp.Plugin.ReadOnlyField);


Ext.ux.RapidApp.Plugin.AppGridSummary = Ext.extend(Ext.ux.grid.GridSummary, {
	
	showMenu : true,
	menuSummaryText : 'Summary Function',
	headerIcoDomCfg: {
		tag: 'div',
		cls: 'ra-icon-function-small',
		style: 'float:left;width:10px;height:12px;'
	},
	allow_cust_funcs: true,
	
	// These functions will use the same renderer for the normal column, all others
	// will render raw data:
	orig_renderer_funcs: ['min','max','sum','avg'],
	
	init: function(grid) {
		Ext.ux.RapidApp.Plugin.AppGridSummary.superclass.init.apply(this,arguments);
		
		grid.appgridsummary = this;
		if(typeof grid.allow_custom_summary_functions !== "undefined") {
			this.allow_cust_funcs = grid.allow_custom_summary_functions;
		}
		
		this.orig_renderer_map = {};
		Ext.each(this.orig_renderer_funcs,function(f){ 
			this.orig_renderer_map[f.toUpperCase()] = true; 
		},this);
		
		this.store = grid.getStore();
		
		if(grid.init_state && grid.init_state.column_summaries) {
			this.store.column_summaries = grid.init_state.column_summaries;
		}
		
		/*
		var plugin = this, store = this.store;
		grid.applyColumnSummaryParams = function(){
			if(store.column_summaries) {
				var params = { 'column_summaries': plugin.getEncodedParamVal()  };
				Ext.apply(store.baseParams,params);
				// Set lastOptions as well so reload() gets the changes:
				Ext.apply(store.lastOptions.params,params);
			}
			return true;
		}
		this.store.on('beforeload',grid.applyColumnSummaryParams);
		*/
		
		// -- Make sure these exist to prevent possible undef errors later on:
		//this.store.baseParams = this.store.baseParams || {};
		//this.store.lastOptions = this.store.lastOptions || {};
		//this.store.lastOptions.params = this.store.lastOptions.params || {};
		// --
		
		this.store.on('beforeload',function(store,options) {
			if(store.baseParams) { 
				delete store.baseParams.column_summaries; 
			}
			if(store.lastOptions && store.lastOptions.params) { 
				delete store.lastOptions.params.column_summaries; 
			}
			if(store.column_summaries) {
				var column_summaries = this.getEncodedParamVal();
				
				// Forcefully set both baseParams and lastOptions so make sure
				// no param caching is happening in the Ext.data.Store
				store.baseParams.column_summaries = column_summaries;
				store.lastOptions.params.column_summaries = column_summaries;
				
				// this is required for very first load to see changes 
				// (not sure why this is needed beyond the above lines)
				Ext.apply(options.params, {column_summaries: column_summaries});
			}
			return true;
		},this);
		

		grid.on('reconfigure',this.updateColumnHeadings,this);
		
		// NEW: needed when using new "Open New Tab" feature to hook into toggling
		// tabs (without this the old tab would have the heading icons stripped
		// TODO: look into cleaning up the mechanism that sets the heading icons
		if(grid.ownerCt) {
			grid.ownerCt.on('show',this.updateColumnHeadings,this);
		}
		
		this.cm.on('hiddenchange',this.autoToggle,this);
		
		if (grid.rendered) {
			this.onRender();
		} else {
			grid.on({
				scope: this,
				single: true,
				afterrender: this.onRender
			});
		}
	},
	
	getEncodedParamVal: function() {
		var column_summaries = this.store.column_summaries || {};
		var data = {};
				
		Ext.iterate(column_summaries,function(k,v){
			if(v['function']) { data[k] = v['function']; }
		},this);
		return Ext.encode(data);
	},
	
	onRender: function() {
		// Always start with summary line hidden:
		this.autoToggle();
		
		if(this.getSummaryCols()) {
			this.grid.getView().on('refresh', this.onRefresh, this);
			this.createMenu();
			this.updateColumnHeadings();
		}
	},
	
	onRefresh : function () {
		this.updateColumnHeadings();
	},
	
	getSummaryCols: function() {
		if(!this.summaryCols) {
			var summaryCols = {};
			var count = 0;
			var columns = this.grid.initialConfig.columns;
			Ext.each(columns,function(column){
				
				if(column.no_summary) { return; }
				
				if(this.allow_cust_funcs){
					column.summary_functions = column.summary_functions || [];
				}
				
				if(Ext.isArray(column.summary_functions)) {
					summaryCols[column.name] = column.summary_functions;
					count++
				}
			},this);
			this.summaryCols = summaryCols;
			if(count == 0) { this.summaryCols = null; }
		}
		return this.summaryCols;
	},
	
	getComboField: function() {
		if(!this.comboField) {
			var cnf = {
				id: this.grid.id + '-summary-combo-field',
				storedata: [],
				editable: false,
				forceSelection: true,
				name: 'combo',
				fieldLabel: 'Select Function',
				hideLabel: true,
				xtype: 'static-combo',
				width: 200,
				listeners:{
					select: {
						scope: this,
						fn: function(combo,record,index) {
							
							var func = record.data.valueField,
								title = record.data.displayField;
							
							var currentVal = combo.getValue();
							
							var setVal = func, setTitle = title;
							if(func == '(None)' || func == 'Custom Function:') { 
								// Don't clear the custom func if its already set
								//if(currentVal == func && func == 'Custom Function:') {  
								//} else {
									setVal = null;
									setTitle = null;
								//}
							}
							
							var field = this.getFunctionsField(), 
								tfield = this.getTitleField();
							
							field.setValue(setVal);
							tfield.setValue(setTitle);
							
							if (func == 'Custom Function:') {
								field.setVisible(true);
								tfield.setVisible(true);
							}
							else {
								this.applySelection();
							}
						}
					},
					beforequery: function(qe){
						delete qe.combo.lastQuery;
					},
					expand: {
						scope: this,
						fn: function() { this.setPreventMenuHide(true); }
					},
					collapse: {
						scope: this,
						fn: function() { this.setPreventMenuHide.defer(300,this,[false]); }
					}
				}
			};
			this.comboField = Ext.ComponentMgr.create(cnf,'static-combo');
		}
		return this.comboField;
	},
	
	menuHideAllowed: function() {
		var bool = this.preventMenuHide ? true : false;
		return bool;
	},
	
	setPreventMenuHide: function(bool) {
		this.preventMenuHide = bool ? false : true;
	},
	
	getFunctionsField: function() {
		if(!this.functionsField) {
			var cnf = {
				id: this.grid.id + '-summary-funcs-field',
				name: 'function',
				fieldLabel: 'Custom Function',
				emptyText: '(Enter Function Code)',
				emptyClass: 'field-empty-text',
				fieldClass: 'blue-text-code',
				//style: { 'font-family': 'Courier', color: 'blue' },
				hideLabel: true,
				xtype: 'textfield',
				width: 200,
				enableKeyEvents:true,
				listeners:{
					keyup:{
						scope: this,
						buffer: 150,
						fn: function(field, e) {
							if (Ext.EventObject.ENTER == e.getKey()){
								this.applySelection();
							}
						}
					}
				}
			};
			this.functionsField = Ext.ComponentMgr.create(cnf,'textfield');
		}
		return this.functionsField;
	},
	
	getTitleField: function() {
		if(!this.titleField) {
			var cnf = {
				id: this.grid.id + '-title-field',
				name: 'title',
				fieldLabel: 'Title',
				emptyText: '(Optional)',
				emptyClass: 'field-empty-text',
				//hideLabel: true,
				xtype: 'textfield',
				//width: 170,
				anchor: "100%",
				enableKeyEvents:true,
				listeners:{
					keyup:{
						scope: this,
						buffer: 150,
						fn: function(field, e) {
							if (Ext.EventObject.ENTER == e.getKey()){
								this.applySelection();
							}
						}
					}
				}
			};
			this.titleField = Ext.ComponentMgr.create(cnf,'textfield');
		}
		return this.titleField;
	},
	
	createMenu : function () {
		var view = this.grid.getView(),
			hmenu = view.hmenu;

		if (this.showMenu && hmenu) {
			
			this.sep = hmenu.addSeparator();
			this.summaryMenu = new Ext.menu.Menu({
				id: this.grid.id + '-summary-menu',
				layout: 'form',
				showSeparator: false,
				labelAlign: 'right',
				labelWidth: 30,
				items: [
					this.getComboField(),
					this.getFunctionsField(),
					this.getTitleField()
				]
			});
			
			this.clearAllItem = hmenu.add({
				iconCls: 'ra-icon-function-clear',
				itemId: 'clear-all',
				text: 'Clear All Summaries',
				handler: this.clearAllSummaries,
				scope: this
			});
			
			this.menu = hmenu.add({
				hideOnClick: false,
				iconCls: 'ra-icon-checkbox-no',
				itemId: 'summary',
				text: this.menuSummaryText,
				menu: this.summaryMenu
			});

			hmenu.on('beforeshow', this.onMenu, this);
			hmenu.on('beforehide',this.menuHideAllowed,this);
			this.summaryMenu.on('beforehide',this.menuHideAllowed,this);
		}
	},
	
	applySelection: function() {
		var colname = this.getActiveColName(),
			field = this.getFunctionsField(),
			tfield = this.getTitleField();
		
		if(!colname || !field) { return false; }
		
		this.setPreventMenuHide(false);
		
		if(field.validate()) {
			var func_str = field.getValue();
			var title = tfield.getValue();
			if(!title || title == '') { 
				title = this.getColSummaryFuncTitle(colname,func_str) || func_str; 
			}
			this.grid.view.hmenu.hide();
			this.setColSummary(colname,func_str,title);
			return true;
		}
		else {
			field.markInvalid();
			return false;
		}
	},
	
	getColSummaryFuncs: function(colname) {
		var summaryCols = this.getSummaryCols() || {};
		return summaryCols[colname] || [];
	},
	
	getColSummaryFuncTitle: function(colname,f) {
		var funcs = this.getColSummaryFuncs(colname);
		var title = null;
		Ext.each(funcs,function(func) {
			if(func['function'] == f) { title = func.title; }
		},this);
		return title;
	},
	
	loadSelection: function() {
		var colname = this.getActiveColName(),
			field = this.getFunctionsField(),
			combo = this.getComboField(),
			tfield = this.getTitleField(),
			menu = this.menu;
		
		if(!field) { return false; }
		
		var summary_data = this.getColSummary(colname);
		
		var funcs = this.getColSummaryFuncs(colname);
		
		var storedata = [];
		storedata.push([
			'(None)',
			'(None)',
			'field-empty-text',
			'padding-bottom:6px;'
		]);
		
		var seen_funcs = {};
		Ext.each(funcs,function(func){
			if(!func['function'] || seen_funcs[func['function']]) { return; }
			seen_funcs[func['function']] = true;
			func.title = func.title || func['function'];
			storedata.push([func['function'],func.title,'x-no-class','']);
		},this);
		
		storedata.push([
			'Custom Function:',
			'Custom Function:',
			'blue-text-code-bold',
			'padding-top:6px;font-size:1.15em;'
		]);
		
		combo.getStore().loadData(storedata);
		
		if(summary_data) {
			var val = summary_data['function'], title = summary_data['title'];
			if(val && val !== '') {
				//menu.setIconClass('ra-icon-checkbox-yes');
				menu.setIconClass('ra-icon-function');
				field.setValue(val);
				tfield.setValue(title);
				if(seen_funcs[val]) {
					combo.setValue(val);
					field.setVisible(false);
					tfield.setVisible(false);
				}
				else {
					combo.setValue('Custom Function:');
					field.setVisible(true);
					tfield.setVisible(true);
				}
			}
		}
		else {
			combo.setValue('(None)');
			menu.setIconClass('ra-icon-checkbox-no');
			field.setVisible(false);
			tfield.setVisible(false);
			tfield.setValue(null);
			return field.setValue(null);
		}
	},
	
	updateColumnHeadings: function () {
    this.hdIcos = this.hdIcos || {};
		var view = this.grid.getView(),
			hds, i, len, summary_data;
		if (view.mainHd) {

			hds = view.mainHd.select('td');
			for (i = 0, len = view.cm.config.length; i < len; i++) {
				var itm = hds.item(i);
				
				if(this.hdIcos[i]) { this.hdIcos[i].remove(); delete this.hdIcos[i]; }
				summary_data = this.getColSummary(view.cm.config[i].name);
				if (summary_data) {
					this.hdIcos[i] = itm.child('div').insertFirst(this.headerIcoDomCfg);
				}
			}
		}
	},
	
	getActiveColName: function() {
		var view = this.grid.getView();
		if (!view || view.hdCtxIndex === undefined) {
			return null;
		}
		var col = view.cm.config[view.hdCtxIndex];
		if(!col){ return null; }
		return col.name;
	},
	
	getColFuncList : function () {
		var colname = this.getActiveColName(),
			summaryCols = this.getSummaryCols();
		
		if (!summaryCols || !colname) { return null; }
		return summaryCols[colname];
	},
	
	onMenu: function(){
		this.setPreventMenuHide(false);
		this.summaryMenu.hide();
		var funcs = this.getColFuncList();
		if(funcs) {
			this.loadSelection();
		}
		this.menu.setVisible(funcs !== undefined);
		this.sep.setVisible(funcs !== undefined);
		this.clearAllItem.setVisible(this.hasActiveSummaries());
	},
	
	autoToggle: function() {
		this.toggleSummary(this.hasActiveSummaries() ? true : false);
	},
	
	hasActiveSummaries: function() {
		var column_summaries = this.store.column_summaries;
		if(!column_summaries) { return false; }
		var cm = this.grid.getColumnModel();
		for(i in cm.config) {
			var c = cm.config[i];
			if(c && column_summaries[c.name] && !c.hidden) {
				return true;
			}
		}
		return false;
	},
	
	getColSummary: function(colname) {
		var summary, column_summaries = this.store.column_summaries;
		if(!colname || !column_summaries || !column_summaries[colname]){
			summary = null;
		}
		else {
			summary = column_summaries[colname];
		}
		return summary;
	},
	
	setColSummary: function(colname,func_str,title) {
		title = title || func_str;
		
		var cur = this.getColSummary(colname);
		if(cur && cur['function'] == func_str && cur['title'] == title) {
			return; //<-- nothing changed
		}
		
		if(!func_str || func_str == '') {
			if(!cur) { return; }
			return this.removeColSummary(colname);
		}
		
		var store = this.store;
		if(!store.column_summaries) { store.column_summaries = {}; }
		
		store.column_summaries[colname] = {
			'function': func_str,
			'title': title
		};
		
		this.onSummaryDataChange();
	},
	
	removeColSummary: function(colname) {
		var column_summaries = this.store.column_summaries;
		if(!colname || !column_summaries || !column_summaries[colname]){
			return;
		}
		delete column_summaries[colname];
		this.onSummaryDataChange();
	},
	
	getSummaryColumnList: function() {
		var column_summaries = this.store.column_summaries;
		if(!column_summaries) { return []; }
		var columns = [];
		Ext.iterate(column_summaries,function(k,v){
			columns.push(k);
		},this);
		return columns;
	},
	
	onSummaryDataChange: function() {
		var store = this.store;
		var columns = this.getSummaryColumnList();
		if(columns.length == 0) {
			delete store.column_summaries;
		};
		this.updateColumnHeadings();
		store.reload();
		this.autoToggle();
	},
	
	// override Ext.ux.grid.GridSummary.calculate:
	calculate: function() {
		var jsonData = this.store.reader.jsonData;
		return (jsonData && jsonData.column_summaries) ? jsonData.column_summaries : {};
	},
	
	renderSummary : function(o, cs, cm) {
		cs = cs || this.view.getColumnData();
		var cfg = cm.config,
			buf = [],
			last = cs.length - 1;
		
		for (var i = 0, len = cs.length; i < len; i++) {
			var c = cs[i], cf = cfg[i], p = {};
				
			p.id = c.id;
			p.style = c.style;
			p.css = i === 0 ? 'x-grid3-cell-first ' : (i == last ? 'x-grid3-cell-last ' : '');
			
			var summary = this.getColSummary(c.name) || {};
			var func = summary['function'];
			if(func) { func = func.toUpperCase(); }

			if (o.data[c.name]) {
				p.value = o.data[c.name];
				if(this.orig_renderer_map[func]) {
					p.value = c.renderer(o.data[c.name], p, o);
				}
				
				if(o.data[c.name] == 'BadFunc!' || o.data[c.name] == 'FuncError!') {
					p.value = '<span style="font-size:.9em;font-family:Courier;color:red;">' +
						o.data[c.name] +
					'</span>';
				}
				
				var title = summary.title;
					
				if(title && title !== '') {
					var html = '<div style="padding-top:6px;padding-bottom:5px;font-size:.9em;color:darkgray">' + 
						Ext.DomHelper.markup(this.headerIcoDomCfg) + 
						'<div>' + title + '</div></div>' +
					'<div>' + p.value + '</div>';
					
					p.value = html;
				}
				
			} else {
				 p.value = '';
			}
			if (p.value === undefined || p.value === "") {
				 p.value = "&#160;";
			}

			
			buf[buf.length] = this.cellTpl.apply(p);
		}
		
		var tstyle = 
			'width:' + this.view.getTotalWidth() + ';' +
			'height:44px;';

		return this.rowTpl.apply({
			tstyle: tstyle,
			cells: buf.join('')
		});
	},
	
	clearAllSummaries: function() {
		if(this.grid.store.column_summaries) {
			delete this.grid.store.column_summaries;
		}
		this.onSummaryDataChange();
	}
	
});
Ext.preg('appgrid-summary',Ext.ux.RapidApp.Plugin.AppGridSummary);


// ------- http://extjs.com/forum/showthread.php?p=97676#post97676
// Note that the "shallow" options below were added by HV, and only consider the headers...
// this was done because this can take a long time with big grids
Ext.override(Ext.CompositeElementLite, {
	getTextWidth: function() {
		var i, e, els = this.elements, result = 0;
		for(i = 0; e = Ext.get(els[i]); i++) {
			result = Math.max(result, e.getTextWidth.apply(e, arguments));
		}
		return result;
	 },
	 getTextWidthShallow: function() {
		var i, e, els = this.elements, result = 0;
		for(i = 0; e = Ext.get(els[i]); i++) {
			result = Math.max(result, e.getTextWidth.apply(e, arguments));
			return result;
		}
		return result;
	 }
});
// -------

Ext.ux.RapidApp.Plugin.AppGridAutoColWidth = Ext.extend(Ext.util.Observable,{
	
	init: function(grid) {
		grid.on('render',this.onRender,grid);
		grid.autosize_maxwidth = grid.autosize_maxwidth || 500;
		
		Ext.apply(grid,{
			// ------- http://extjs.com/forum/showthread.php?p=97676#post97676
			autoSizeColumnHeaders: function(){
				return this.doAutoSizeColumns(true);
			},
			autoSizeColumns: function(){
				// Not using Ext.LoadMask because it doesn't work right; I think because
				// it listens to events that the resize causes to fire. All it really does
				// is call El.mask and El.unmask anyway...
				var El = this.getEl();
				El.mask("Autosizing Columns...",'x-mask-loading');

				this.doAutoSizeColumns.defer(10,this,[false,El]);
			},
			doAutoSizeColumns: function(shallow,El) {
				var cm = this.colModel;
				if(!cm) { return; }
				
				// Shrink all columns to a floor value first because we can only "size-up"
				if(!shallow) { this.setAllColumnsSize(10); }
				
				cm.suspendEvents();
				var col_count = cm.getColumnCount();
				for (var i = 0; i < col_count; i++) {
					this.autoSizeColumn(i,shallow);
				}
				cm.resumeEvents();
				this.view.refresh(true);
				this.store.removeListener('load',this.autoSizeColumns,this);
				this.store.removeListener('load',this.autoSizeColumnHeaders,this);
				if(El) {
					El.unmask();
				}
			},
			autoSizeColumn: function(c,shallow) {
				var cm = this.colModel;
				var colid = cm.getColumnId(c);
				var column = cm.getColumnById(colid);
				
				// Skip hidden columns unless autoSizeHidden is true:
				if(!this.autosize_hidden && column.hidden) {
					return;
				}
				
				var col = this.view.el.select("td.x-grid3-td-" + colid + " div:first-child");
				if (col) {

					var add = 6;
					var w = add;
					if(shallow) {
						w += col.getTextWidthShallow();
					}
					else {
						w += col.getTextWidth();
					}
					w += Ext.get(col.elements[0]).getFrameWidth('lr');
					
					w = this.autosize_maxwidth < w ? this.autosize_maxwidth : w;

					//if (w > this.autosize_maxwidth) { w = this.autosize_maxwidth; }
					if (column.width && w < column.width) { w = column.width; }

					cm.setColumnWidth(c, w);
					return w;
				}
			},
			setAllColumnsSize: function(size) {
				var cm = this.colModel;
				cm.suspendEvents();
				var col_count = cm.getColumnCount();
				for (var i = 0; i < col_count; i++) {
          var colid = cm.getColumnId(i);
          var column = cm.getColumnById(colid);
          // Skip hidden columns unless autoSizeHidden is true:
          if(!this.autosize_hidden && column.hidden) {
            continue;
          }
					cm.setColumnWidth(i, size);
				}
				cm.resumeEvents();
			}
			// ------------------------
		});
	},
	
	onRender: function() {
		
		if(typeof this.use_autosize_columns != 'undefined' && !this.use_autosize_columns) {
			// if use_autosize_columns is defined and set to false, abort setup even if
			// other params are set below:
			return;
		}
		
		if(typeof this.auto_autosize_columns != 'undefined' && !this.auto_autosize_columns) {
			// if auto_autosize_columns is defined and set to false:
			this.auto_autosize_columns_deep = false;
		}
			
		if(this.auto_autosize_columns_deep) {
			// This can be slow, but still provided as an option 'auto_autosize_columns_deep'
			this.store.on('load',this.autoSizeColumns,this);
		}
		else if (this.auto_autosize_columns){
			// this only does headers, faster:
			this.store.on('load',this.autoSizeColumnHeaders,this); 
		}
			
		if(this.use_autosize_columns) {
			//var menu = this.getOptionsMenu();
			var hmenu = this.view.hmenu;
			if(!hmenu) { return; }

			var index = 0;
			var colsItem = hmenu.getComponent('columns');
			if(colsItem) {
				index = hmenu.items.indexOf(colsItem);
			}
			
			hmenu.insert(index,{
				text: "AutoSize Columns",
				iconCls: 'ra-icon-left-right',
				handler:this.autoSizeColumns, //<-- this does the full autosize which could be slow
				scope: this
			});
		}
	}
	
});
Ext.preg('appgrid-auto-colwidth',Ext.ux.RapidApp.Plugin.AppGridAutoColWidth);



// Base plugin class for plugins that add special items to the col menu:
Ext.ux.RapidApp.Plugin.AppGridColMenuPlug = Ext.extend(Ext.util.Observable,{
	
	maxSeparatorPosition: 4,
	
	init: function(grid) {
		this.grid = grid;
		grid.on('render',this.onRender,this);
	},
	
	getColItem: Ext.emptyFn,
	
	getColCount: function() {
		return this.view.colMenu.items.getCount();
	},
	
	getExistingSeparatorIndex: function() {
		var items = this.colMenu.items.items;
		for (ndx in items) {
			if(ndx > this.maxSeparatorPosition) { return -1; }
			if(this.isSeparator(items[ndx])) { return ndx; }
		}
		return -1;
	},
	
	isSeparator: function(item) {
		if((Ext.isObject(item) && item.itemCls == 'x-menu-sep') || item == '-') {
			return true;
		}
		return false;
	},
	
	getInsertPosition: function() {
		var pos = this.getExistingSeparatorIndex();
		if(pos == -1) { 
			this.colMenu.insert(0,'-');
			return 0;
		}
		return pos;
	},
	
	onRender: function() {
		this.view = this.grid.getView();
		this.cm = this.grid.getColumnModel();
		this.colMenu = this.view.colMenu;
		if(!this.colMenu) { return; }
		
		this.colMenu.on('beforeshow',function(){
			
			//Disable the menu keyNav to allow arrow keys to work in fields within the menu:
			if(this.colMenu.keyNav){ this.colMenu.keyNav.disable(); }
			
			var colItem = this.getColItem();
			if(!colItem) { return; }
			var pos = this.getInsertPosition();
			this.colMenu.insert(pos,colItem);
		},this);
	}
});



// Adds a special "Toggle All" checkbox to the top of the grid Columns menu:
Ext.ux.RapidApp.Plugin.AppGridToggleAllCols = Ext.extend(Ext.ux.RapidApp.Plugin.AppGridColMenuPlug,{
	
	getColItem: function() {
		var grid = this.grid, colCount = this.getColCount();
		return new Ext.menu.CheckItem({
			text: 'Toggle All (' + colCount + ' columns)',
			checked: true,
			hideOnClick: false,
			handler: this.toggleCheckHandler,
			scope: grid
		});
	},
	
	// 'this' scope expected to be 'grid':
	toggleCheckHandler: function(item) {
		var checked = ! item.checked, cm = this.getColumnModel();
					
		var msg = checked ? 'Toggling all on' : 'Toggling all off';
		
		var first_skipped = false;
		var fn;
		var totalCount = item.parentMenu.items.getCount();
		var mask =  myMask = new Ext.LoadMask(item.parentMenu.getEl(), {msg:msg});
		mask.show();
		fn = function(ndx) {
			
			mask.el.mask(msg + " (" + Math.round(((ndx+1)/totalCount)*100) + "%)", mask.msgCls);
			
			var i = item.parentMenu.items.itemAt(ndx);
			if(!i || !item.parentMenu.isVisible()) { mask.hide(); return; }
			if(item !== i && i.setChecked && !i.disabled) {
				if(i.checked == checked) { return fn.defer(0,this,[ndx+1]); }
				// when unchecking all, leave one checked
				if(!checked && i.checked && !first_skipped) {
					first_skipped = true;
					return fn.defer(0,this,[ndx+1]);
				}
				i.setChecked(checked,true);
				var itemId = i.getItemId(), index = cm.getIndexById(itemId.substr(4));
				if (index != -1) { cm.setHidden(index, !checked); }
			}
			fn.defer(1,this,[ndx+1]);
		};
		fn.defer(0,this,[0]);
	}
	
});
Ext.preg('appgrid-toggle-all-cols',Ext.ux.RapidApp.Plugin.AppGridToggleAllCols);


Ext.ux.RapidApp.Plugin.AppGridFilterCols = Ext.extend(Ext.ux.RapidApp.Plugin.AppGridColMenuPlug,{
	
	testMatch: function(item,str) {
		// If the string is not set, match is true per default:
		if(!str || str == '' || !item.text) { return true; }
		
		str = str.toLowerCase();
		var text = item.text.toLowerCase();
		
		// Test menu item text
		if(text.indexOf(str) != -1) { return true; }
		var column = this.menuItemToColumn(item);
		if (column) {
			// Test column name
			if(column.name) {
				var text = column.name.toLowerCase();
				if(text.indexOf(str) != -1) { return true; }
			}
			// Test column header:
			if(column.header) {
				var text = column.header.toLowerCase();
				if(text.indexOf(str) != -1) { return true; }
			}
		}
		return false;
	},
	
	menuItemToColumn: function(item) {
		var colModel = this.cm,
			itemId = item.getItemId(),
			colId = itemId.substr(4);
		
		return colModel.config[colId];
	},
	
	filterByString: function(str) {
		if(str == '') { str = null; }
		if(!this.colMenu.isVisible()) { return; }
		
		var past_sep,past_label,add_at,remove,match_count = 0;
		this.colMenu.items.each(function(item,ndx){
			if(!past_sep) {
				if(this.isSeparator(item)){ past_sep = true; }
				return;
			}
			else if (!past_label) {
				if(str) { add_at = ndx; }
				past_label = true;
				if(item.isFilterLabel) {
					remove = item;
					return;
				}
			}
			
			var match = this.testMatch(item,str);
			if(match) { match_count++; }
			
			if(!item.hidden) {
				if(!match) {
					item.setVisible(false);
					item.isFiltered = true;
				}
			}
			else {
				if(match && item.isFiltered) {
					delete item.isFiltered;
					item.setVisible(true);
				}
			}
		},this);
		
		//if(remove) { this.colMenu.remove(remove,true); }
		if(remove) { 
			var liEl = remove.el.parent('li');
			this.colMenu.remove(remove,true);
			// this appears to be an Ext bug:
			if(liEl && liEl.dom) { Ext.removeNode(liEl.dom); }
		}
		
		if(add_at) {
			this.colMenu.insert(add_at,{
				isFilterLabel: true,
				xtype: 'label',
				html: '<b><i><center>Filtered (' + match_count + ' columns)</center></i></b>'
			});
		}
	},
	
	getColItem: function() {
		return {
			xtype:'textfield',
			emptyText: 'Type to Filter Column List',
			emptyClass: 'field-empty-text',
			width: '200px',
			enableKeyEvents:true,
			listeners: {
				render: {
					scope: this,
					fn: function(field) {
						field.filterTask = new Ext.util.DelayedTask(function(f){
							this.filterByString(f.getValue());
						},this,[field]);
					}
				},
				keyup: {
					scope: this,
					buffer: 150,
					fn: function(field, e) {
						if(field.filterTask) { field.filterTask.delay(500); }
					}
				}
			}
		};
	}
});
Ext.preg('appgrid-filter-cols',Ext.ux.RapidApp.Plugin.AppGridFilterCols);




Ext.ux.RapidApp.Plugin.AppGridBatchEdit = Ext.extend(Ext.util.Observable,{
	
	init: function(grid) {
		this.grid = grid;
		grid.on('render',this.onRender,this);
		grid.on('rowcontextmenu',this.onRowcontextmenu,this);
	},
	
	onRender: function() {
		
		var grid = this.grid, 
			store = grid.getStore(), 
			menu = grid.getOptionsMenu();
		
		if(!grid.batch_update_url || !store.api.update || !menu) { 
			return; 
		}
		
		menu.add(this.getMenu());
		
		store.on('load',this.updateEditMenus,this);
		grid.getSelectionModel().on('selectionchange',this.updateEditMenus,this);
	},
	
	onRowcontextmenu: function(grid,rowIndex,e) {
		count = this.selectedCount();
		if(count <= 1) { return; }
		
		//stop browser menu:
		e.stopEvent();
		
		var menuItems = [{
			text: 'Batch Modify Selected Records (' + count + ')',
			iconCls: 'ra-icon-table-edit-row',
			scope: this,
			handler: this.doBatchEditSelected
		}];

		var menu = new Ext.menu.Menu({ items: menuItems });
		var pos = e.getXY();
		pos[0] = pos[0] + 10;
		pos[1] = pos[1] + 5;
		menu.showAt(pos);
	},
	
	getMenu: function() {
		if(!this.editMenu) {
			this.editMenu = new Ext.menu.Item({
				text: 'Batch Modify',
				iconCls: 'ra-icon-table-sql-edit',
				hideOnClick: false,
				menu: [
					{
						itemId: 'all',
						text: 'All Active Records',
						iconCls: 'ra-icon-table-edit-all',
						scope: this,
						handler: this.doBatchEditAll
					},
					{
						itemId: 'selected',
						text: 'Selected Records',
						iconCls: 'ra-icon-table-edit-row',
						scope: this,
						handler: this.doBatchEditSelected
					}
				]
			});
		}
		return this.editMenu;
	},
	
	getStoreParams: function() {
		var store = this.grid.getStore();
		
		var params = {};
		Ext.apply(params,store.lastOptions.params);
		Ext.apply(params,store.baseParams);
			
		return params;
	},
	
	getSelectedIds: function() {
		var selections = this.grid.getSelectionModel().getSelections();
		var ids = [];
		Ext.each(selections,function(item){
			ids.push(item.id);
		},this);
		
		return ids;
	},
	
	getBatchEditSpec: function(sel) {
		
		var opt = { read_params: this.getStoreParams() };
		
		if(sel) {
			var ids = this.getSelectedIds();
			Ext.apply(opt,{
				selectedIds: ids,
				count: ids.length
			});
		}
		else {
			opt.count = this.grid.getStore().getTotalCount();
		}
		
		return opt;
	},
	
	
	selectedCount: function() {
		return this.grid.getSelectionModel().getSelections().length;
	},
	
	updateEditMenus: function() {
		var menu = this.getMenu().menu;
		if(!menu) { return; }
		
		//console.log(this.getEditColumns().length);
		
		var allItem = menu.getComponent('all');
		var count = this.grid.getStore().getTotalCount();
		allItem.setText('All Active Records (' + count + ')');
		allItem.setDisabled(count <= 1);
		
		var selItem = menu.getComponent('selected');
		count = this.selectedCount();
		selItem.setText('Selected Records (' + count + ')');
		selItem.setDisabled(count <= 1);
		
	},
	
	getEditColumns: function() {
		var columns = [];
		var cm = this.grid.getColumnModel();
		for (i in cm.config) {
			var c = cm.config[i];
			// Only show editable, non-hidden columns:
			var valid = false;
			if(!c.hidden && cm.isCellEditable(i,0)) { valid = true; }
			if(typeof c.allow_batchedit != 'undefined' && !c.allow_batchedit) { valid = false; }
			
			if(valid) { 
				columns.push(c); 
			}
		}
		return columns;
	},
	
	getBatchEditFields: function(fp) {
		//var fp = fp;
		var fields = [];
		var columns = this.getEditColumns();
		Ext.each(columns,function(column) {

			var Field,field;
			if(Ext.isFunction(column.editor.cloneConfig)) {
				field = column.editor.cloneConfig();
				//Field = column.editor;
				if(field.store){ field.store.autoDestroy = false; }
			}
			else {
				//Field = Ext.ComponentMgr.create(field,'textfield');
				Ext.apply(field,column.editor);
			}
			
			Ext.apply(field,{
				name: column.name,
				fieldLabel: column.header || column.name,
				flex: 1,
				disabled: true
			});
			
			// Turn into a component object now:
			Field = Ext.ComponentMgr.create(field,'textfield');
			
			// If this is a textarea with "grow" on:
			// http://www.sencha.com/forum/showthread.php?104490-Solved-Auto-growing-textarea-in-CompositeField&p=498813&viewfull=1#post498813
			Field.on('autosize', function(textarea){
				textarea.ownerCt.doLayout(); // == compositeField.innerCt.doLayout()
			});

			var Toggle = new Ext.form.Checkbox({ itemId: 'toggle' });
			Toggle.on('check',function(checkbox,checked){
				var disabled = !checked
				var labelEl = Field.getEl().parent('div.x-form-item').first('label');
				Field.setDisabled(disabled);
				fp.updateSelections();
				if(disabled){ 
					Field.clearInvalid();
					labelEl.setStyle('font-weight','normal');
					labelEl.setStyle('font-style','normal');
					labelEl.setStyle('color','black');
				}
				else{
					Field.validate();
					labelEl.setStyle('font-weight','bold');
					labelEl.setStyle('font-style','italic');
					labelEl.setStyle('color','green');
				}
			},fp);
			
			var comp_field = {
				xtype: 'compositefield',
				items: [Toggle,Field]
			};
			
			fields.push(
				{ xtype: 'spacer', height: 10 },
				comp_field
			);
			
		},this);
		
		return fields;
	},
	
	doBatchEditAll: function() { this.doBatchEdit(); },
	doBatchEditSelected: function() { this.doBatchEdit(true); },
	
	doBatchEdit: function(sel) {
		var editSpec = this.getBatchEditSpec(sel);
		
		var fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 130,
			labelPad: 15,
			bodyStyle: 'padding: 10px 25px 5px 5px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			//monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			getSaveBtn: function() {
				for (i in fp.buttons) {
					if(fp.buttons[i].name == 'save') { return fp.buttons[i]; }
				}
				return null;
			},
			
			getCount: function() {
				var count = 0;
				fp.items.each(function(itm){
					if(!itm.items) { return; }
					var cb = itm.items.find( // have to reproduce: itm.getComponent('toggle')
						function(i){ if (i.itemId == 'toggle'){ return true; }},
					this);
					if(cb && cb.getValue()) { count++; }
				},this);
				return count;
			},
			
			updateSelections: function() {
				fp.stopMonitoring();
				var count = fp.getCount();
				var saveBtn = fp.getSaveBtn();
				saveBtn.setText('Apply Changes (' + count + ' fields)');
				
				if(count > 0) {
					fp.startMonitoring();
				}
				else {
					saveBtn.setDisabled(true);
				}
			},
			
			buttons: [
				{
					name: 'save',
					text: 'Apply Changes (0 fields)',
					iconCls: 'ra-icon-save-ok',
					width: 175,
					formBind: true,
					disabled: true,
					scope: this,
					handler: function(btn) {
						var data = {};
						fp.getForm().items.each(function(comp_field){
							// get the field out of the composit field. expects 2 items, the checkbox then the field
							// need to do it this way to make sure we call the field's getValue() function
							f = comp_field.items.items[1];
							if(f && !f.disabled && f.name && Ext.isFunction(f.getValue)) {
								data[f.name] = f.getValue();
							}
						},this);
						
						this.postUpdate(editSpec,data,this.win);
					}
				},
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
		
		var txt = 'Changes will be applied (identically) to all ' + editSpec.count + ' records in the active search.';
		if(sel) { txt = 'Changes will be applied (identically) to the ' + editSpec.count + ' selected records.'; }

		var items = this.getBatchEditFields(fp);
		
		if(items.length == 0) {
			return Ext.Msg.show({
				icon: Ext.Msg.WARNING,
				title: 'No editable columns to Batch Modify',
				msg: 
					'None of the currently selected columns are batch editable - nothing to Batch Modify.' +
					'<br><br>Select at least one editable column from the Columns menu and try again.',
				buttons: Ext.Msg.OK
			});
		}
		
		items.unshift(
			{ html: '<div class="ra-batch-edit-heading">' +
				'Batch Modify <span class="num">' + editSpec.count + '</span> Records:' +
			'</div>' },
			{ html: '<div class="ra-batch-edit-sub-heading">' +
				'Click the checkboxes below to enter field values to change/update in each record.<br>' + txt +
				'<div class="warn-line"><span class="warn">WARNING</span>: This operation cannot be undone.</div>' +
			'</div>'}
		);
			
		items.push(
			{ xtype: 'spacer', height: 15 },
			{ html: '<div class="ra-batch-edit-sub-heading">' +
				'<div class="warn-line">' +
					'<i><span class="warn">Note</span>: available fields limited to visible + editable columns</i>' +
				'</div>'
			}
		);
		
		fp.add(items);

		var title = 'Batch Modify Active Records';
		if(sel) { title = 'Batch Modify Selected Records'; }
		
		if(this.win) {
			this.win.close();
		}
		
		this.win = new Ext.Window({
			title: title,
			layout: 'fit',
			width: 600,
			height: 500,
			minWidth: 475,
			minHeight: 350,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
		
		this.win.show();
	},
	
	postUpdate: function(editSpec,data,win){
		
		/* --------------------------------------------------------------------------------- */
		// If selectedIds is set, it means we're updating records in the local store and
		// we can update them them locally, no need to go to the server with a custom
		// batch_edit call (use a regular store/api update). This is essentially a 
		// *completely* different mechanism, although it is transparent to the user:
		if(editSpec.selectedIds) { return this.localUpdate(editSpec.selectedIds,data,win); }
		/* --------------------------------------------------------------------------------- */
		
		//var Conn = new Ext.data.Connection();
		var Conn = Ext.ux.RapidApp.newConn({ timeout: 300000 }); //<-- 5 minute timeout
		
		var myMask = new Ext.LoadMask(win.getEl(), {msg:"Updating Multiple Records - This may take several minutes..."});
		var showMask = function(){ myMask.show(); }
		var hideMask = function(){ myMask.hide(); }
		
		Conn.on('beforerequest', showMask, this);
		Conn.on('requestcomplete', hideMask, this);
		Conn.on('requestexception', hideMask, this);
		
		editSpec.update = data;
		
		Conn.request({
			url: this.grid.batch_update_url,
			params: { editSpec: Ext.encode(editSpec) },
			scope: this,
			success: function(){
				win.close();
				this.grid.getStore().reload();
			}
		});
	},
	
	localUpdate: function(ids,data,win) {
		var store = this.grid.getStore();
			
		Ext.each(ids,function(id) {
			var Record = store.getById(id);
			Record.beginEdit();
			for (i in data) { 
				Record.set(i,data[i]); 
			}
			Record.endEdit();
		},this);
		
		// create a single-use load mask for the update:
		if(store.hasPendingChanges()) { //<-- it is *possible* nothing was changed
			
			var colnames = this.grid.currentVisibleColnames.call(this.grid);
			for (i in data) { colnames.push(i); }
			store.setBaseParam('columns',Ext.encode(colnames));
			store.setBaseParam('batch_update',true);
			
			var lMask = new Ext.LoadMask(win.getEl(),{ msg:"Updating Multiple Records - Please Wait..."});
			lMask.show();
			var hide_fn;
			hide_fn = function(){ 
				lMask.hide(); 
				store.un('write',hide_fn);
				win.close();
			};
			store.on('write',hide_fn,this);
			store.save();
			delete store.baseParams.batch_update; //<-- remove the tmp added batch_update param
		}
		else {
			// if we're here it means there was nothing to change (all the records already had the values
			// that were specified). Call store save for good measure and close the window:
			store.save();
			return win.close();
		}
	}
});
Ext.preg('appgrid-batch-edit',Ext.ux.RapidApp.Plugin.AppGridBatchEdit);





/*
 Ext.ux.RapidApp.Plugin.RelativeDateTime
 2012-04-08 by HV

 Plugin for DateTime fields that allows and processes relative date strings.
*/
Ext.ux.RapidApp.Plugin.RelativeDateTime = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		var plugin = this;
		
		// Override parseDate, redirecting to parseRelativeDate for strings 
		// starting with '-' or '+', otherwise, use native behavior
		var native_parseDate = cmp.parseDate;
		cmp.parseDate = function(value) {
			if(plugin.isDurationString.call(plugin,value)) {
				var ret = plugin.parseRelativeDate.apply(plugin,arguments);
				if(ret) { return ret; }
			}
			if(native_parseDate) { return native_parseDate.apply(cmp,arguments); }
		}
		
		if(cmp.noReplaceDurations) {
			var native_setValue = cmp.setValue;
			cmp.setValue = function(value) {
				if(plugin.isDurationString.call(plugin,value)) {
					// Generic setValue function on the non-inflated value:
					return Ext.form.TextField.superclass.setValue.call(cmp,value);
				}
				return native_setValue.apply(cmp,arguments);
			};
		}
		
		cmp.beforeBlur = function() {
			var value = cmp.getRawValue(),
				v = cmp.parseDate(value);
			
			if(plugin.isDurationString.call(plugin,value)) {
				if(v) {
					// save the duration string before it gets overwritten:
					cmp.lastDurationString = value;
					
					// Don't inflate/replace duration strings with parsed dates in the field
					if(cmp.noReplaceDurations) { return; }
				}
				else {
					cmp.lastDurationString = null;
				}
			}
			
			//native DateField beforeBlur behavior:
			if(v) {
				// This is the place where the actual value inflation occurs. In the native class,
				// this is destructive, in that after this point, the original raw value is 
				// replaced and lost. That is why we save it in 'durationString' above, and also
				// why we optionally skip this altogether if 'noReplaceDurations' is true:
				cmp.setValue(v);
			}
		};
		
		cmp.getDurationString = function() {
			var v = cmp.getRawValue();
			// If the current value is already a valid duration string, return it outright:
			if(plugin.parseRelativeDate.call(plugin,v)) { 
				cmp.lastDurationString = v;
				return v; 
			}
			
			if(!cmp.lastDurationString) { return null; }
			
			// check to see that the current/inflated value still matches the last
			// duration string by parsing and rendering it and the current field value. 
			// If they don't match, it could mean that a different, non duration value 
			// has been entered, or, if the value is just different (such as in places
			// where the field is reused in several places, like grid editors):
			var dt1 = cmp.parseDate(v);
			var dt2 = cmp.parseDate(cmp.lastDurationString);
			if(dt1 && dt2 && cmp.formatDate(dt1) == cmp.formatDate(dt2)) {
				return cmp.lastDurationString;
			}
			
			cmp.lastDurationString = null;
			return null;
		};
		
		
		if(Ext.isFunction(cmp.onTriggerClick)) {
			var native_onTriggerClick = cmp.onTriggerClick;
			cmp.onTriggerClick = function() {
				if(cmp.disabled){ return; }
				
				// Sets cmp.menu before the original onTriggerClick has a chance to:
				plugin.getDateMenu.call(plugin);
				
				native_onTriggerClick.apply(cmp,arguments);
			}
		}
		
	},
	
	startDateKeywords: {
		
		now: function() {
			return new Date();
		},
		
		thisminute: function() {
			var dt = new Date();
			dt.setSeconds(0);
			dt.setMilliseconds(0);
			return dt;
		},
		
		thishour: function() {
			var dt = new Date();
			dt.setMinutes(0);
			dt.setSeconds(0);
			dt.setMilliseconds(0);
			return dt;
		},
		
		thisday: function() {
			var dt = new Date();
			return dt.clearTime();
		},
		
		today: function() {
			var dt = new Date();
			return dt.clearTime();
		},
		
		thisweek: function() {
			var dt = new Date();
			var day = parseInt(dt.format('N'));
			//day++; if(day > 7) { day = 1; } //<-- shift day 1 from Monday to Sunday
			var subtract = 1 - day;
			return dt.add(Date.DAY,subtract).clearTime();
		},
		
		thismonth: function() {
			var dt = new Date();
			return dt.getFirstDateOfMonth();
		},
		
		thisquarter: function() {
			var dt = new Date();
			dt = dt.getFirstDateOfMonth();
			var month = parseInt(dt.format('n'));
			var subtract = 0;
			if(month > 0 && month <= 3) {
				subtract = month - 1;
			}
			else if(month > 3 && month <= 6) {
				subtract = month - 4;
			}
			else if(month > 6 && month <= 9) {
				subtract = month - 7;
			}
			else {
				subtract = month - 10;
			}
			return dt.add(Date.MONTH,0 - subtract).clearTime();
		},
		
		thisyear: function() {
			var dt = new Date();
			var date_string = '1/01/' + dt.format('Y') + ' 00:00:00';
			return new Date(date_string);
		}
	},
	
	getKeywordStartDt: function(keyword) {
		keyword = keyword.replace(/\s*/g,''); // <-- strip whitespace
		keyword = keyword.toLowerCase();
		var fn = this.startDateKeywords[keyword] || function(){ return null; };
		return fn();
	},
	
	isDurationString: function(str) {
		if(str && Ext.isString(str)) {
			if(str.search(/[\+\-]/) != -1){ return true; };
			if(this.getKeywordStartDt(str)){ return true; };
		}
		return false;
	},
	
	parseRelativeDate: function(value) {
		var dt = this.getKeywordStartDt(value);
		if(dt) { return dt; } //<-- if the supplied value is a start keyword alone
		
		// find the offset of the sign char (the first + or -):
		var pos = value.search(/[\+\-]/);
		if(pos == -1) { return null; }
		if(pos > 0) {
			// If we are here then it means a custom start keyword was specified:
			var keyword = value.substr(0,pos);
			dt = this.getKeywordStartDt(keyword);
		}
		else {
			// Default start date/keyword "now":
			dt = this.getKeywordStartDt('now');
		}
		
		if(!dt) { return null; }
		
		var sign = value.substr(pos,1);
		if(sign != '+' && sign != '-') { return null; }
		var str = value.substr(pos+1);

		var parts = this.extractDurationParts(str);
		if(!parts) { return null; }
		
		var invalid = false;
		Ext.each(parts,function(part){
			if(invalid) { return; }
			
			if(sign == '-') { part.num = '-' + part.num; }
			var num = parseInt(part.num);
			if(num == NaN) { invalid = true; return; }
			
			var newDt = this.addToDate(dt,num,part.unit);

			if(!newDt) { invalid = true; return; }
			dt = newDt;
		},this);
		
		return invalid ? null : dt;
	},
	
	extractDurationParts: function(str) {
		
		// strip commas and whitespace:
		str = str.replace(/\,/g,'');
		str = str.replace(/\s*/g,'');
		
		var parts = [];
		while(str.length > 0) {
			var pos,num,unit;
			
			// find the offset of the first letter after some numbers
			pos = str.search(/\D/);
			
			// If there are no numbers (pos == 0) or we didn't find any letters (pos == -1)
			// this is an invalid duration string, return:
			if(pos <= 0) { return null; }
			
			// this is the number:
			num = str.substr(0,pos);
			
			// remove it off the front of the string before proceding:
			str = str.substr(pos);
			
			// find the offset of the next number after some letters
			pos = str.search(/\d/);
			
			// if no numbers were found, this must be the last part
			if(pos == -1) {
				// this is the unit:
				unit = str;
				
				// empty the string
				str = '';
			}
			else {
				// this is the unit:
				unit = str.substr(0,pos);
				
				// remove it off the front of the string before proceding:
				str = str.substr(pos);
			}
			
			// Make sure num is a valid int/number:
			if(!/^\d+$/.test(num)) { return null; }
			
			parts.push({num:num,unit:unit});
		}
		
		return parts;
	},
	
	unitMap: {
		y			: Date.YEAR,
		year		: Date.YEAR,
		years		: Date.YEAR,
		yr			: Date.YEAR,
		yrs		: Date.YEAR,
		
		m			: Date.MONTH,
		mo			: Date.MONTH,
		month		: Date.MONTH,
		months	: Date.MONTH,
		
		d			: Date.DAY,
		day		: Date.DAY,
		days		: Date.DAY,
		dy			: Date.DAY,
		dys		: Date.DAY,
		
		h			: Date.HOUR,
		hour		: Date.HOUR,
		hours		: Date.HOUR,
		hr			: Date.HOUR,
		hrs		: Date.HOUR,
		
		i			: Date.MINUTE,
		mi			: Date.MINUTE,
		min		: Date.MINUTE,
		mins		: Date.MINUTE,
		minute	: Date.MINUTE,
		minutes	: Date.MINUTE,
		
		s			: Date.SECOND,
		sec		: Date.SECOND,
		secs		: Date.SECOND,
		second	: Date.SECOND,
		second	: Date.SECOND
	},
	
	addToDate: function(dt,num,unit) {
		dt = dt || new Date();
		
		unit = unit.toLowerCase();
		
		// custom support for "weeks":
		if(unit == 'w' || unit == 'week' || unit == 'weeks' || unit == 'wk' || unit == 'wks') {
			unit = 'days';
			num = num*7;
		}
		
		// custom support for "quarters":
		if(unit == 'q' || unit == 'quarter' || unit == 'quarters' || unit == 'qtr' || unit == 'qtrs') {
			unit = 'months';
			num = num*3;
		}
		
		var interval = this.unitMap[unit];
		if(!interval) { return null; }
		
		return dt.add(interval,num);
	},
	
	getDateMenu: function() {
		
		if(!this.cmp.menu) {
			
			var menu = new Ext.menu.DateMenu({
				hideOnClick: false,
				focusOnSelect: false
			});
			
			menu.on('afterrender',function(){
				var el = menu.getEl();
				var existBtn = el.child('td.x-date-bottom table');
				
				if(existBtn) {
					existBtn.setStyle('float','left');
					
					if(this.cmp.allowBlank) { this.addSelectNoneBtn(existBtn); }
					
					newEl = existBtn.insertSibling({ tag: 'div', style: 'float:right;' },'after');
					var relBtn = new Ext.Button({
						iconCls: 'ra-icon-clock-run',
						text: 'Relative Date',
						handler: this.showRelativeDateMenu,
						scope: this
					});
					relBtn.render(newEl);
				}

			},this);
			
			this.cmp.menu = menu;
		}
		
		return this.cmp.menu;
	},
	
	addSelectNoneBtn: function(existBtn) {
		
		var newEl = existBtn.insertSibling({ tag: 'div', style: 'float:left;' },'after');
		var noneBtn = new Ext.Button({
			text: '<span style="font-size:.9em;color:grey;">(None)</span>',
			handler: function(){ 
				this.cmp.setValue(null); 
				this.cmp.resumeEvents();
				this.cmp.fireEvent('blur');
				this.cmp.menu.hide();
			},
			scope: this
		});
		noneBtn.render(newEl);
		
	},
	
	showRelativeDateMenu: function(btn,e) {
		var dmenu = this.cmp.menu, rmenu = this.getRelativeDateMenu();
		// the dmenu automatically hides itself:
		rmenu.showAt(dmenu.getPosition());
	},
	
	getRelativeDateMenu: function() {
		var plugin = this;
		if(!this.relativeDateMenu) {
			var menu = new Ext.menu.Menu({
				style: 'padding-top:5px;padding-left:5px;padding-right:5px;',
				width: 330,
				layout: 'anchor',
				showSeparator: false,
				items: [
					{ 
						xtype: 'label',
						html: '<div class="ra-relative-date">' + 
							'<div class="title">Relative Date/Time</div>' + 
							'<div class="sub">' + 
								'Enter a time length/duration for a date/time <i>relative</i> to the current time. ' +
								'Prefix with a minus <span class="mono">(-)</span> for a date in the past or a plus ' + 
								'<span class="mono">(+)</span> for a date in the future.  ' +
							'</div>' +
							'<div class="sub">' + 
								'You may optionally prepend a referece date keyword &ndash; <span class="mono">today</span>, <span class="mono">this minute</span>, <span class="mono">this hour</span>, <span class="mono">this week</span>, <span class="mono">this month</span>, <span class="mono">this quarter</span> or <span class="mono">this year</span> &ndash; for an even date/threshold to use instead of the current date and time.' +
							'</div>' +
							'<div class="sub">' + 
								'The date calculation of your input is shown as you type.' +
							'</div>' +
							'<div class="examples">Example inputs:</div>' + 
							
							'<table width="85%"><tr>' +
						
							'<td>' +
							'<ul>' +
								'<li>-1 day</li>' +
								'<li>+20 hours, 30 minutes</li>' +
								'<li>today -3d4h18mins</li>' +
								'<li>+2m3d5h</li>' +
								'<li>this hour - 2 hours</li>' +
							'</ul>' + 
							'</td>' +
							
							'<td>' +
							'<ul>' +
								'<li>this quarter+1wks</li>' +
								'<li>-2 years</li>' +
								'<li>this week</li>' +
								'<li>this year - 2 years</li>' +
								'<li>this minute - 30 mins</li>' +
							'</ul>' + 
							'</td>' +
							
							'</tr></table>' +
							
						'</div>' 
					}
				]
			});
			
			menu.okbtn = new Ext.Button({
				text: 'Ok',
				scope: this,
				handler: this.doMenuSaveRelative,
				disabled: true
			});
			
			menu.renderValLabel = new Ext.form.Label({
				html: '&uarr;&nbsp;enter',
				cls: 'ra-relative-date-renderval'
			});
			
			menu.field = new Ext.form.TextField({
				anchor: '100%',
				fieldClass: 'blue-text-code',
				validator: function(v) {
					if(!v) { 
						menu.okbtn.setDisabled(true);
						menu.renderValLabel.setText(
							'<sup>&uarr;</sup>&nbsp;&nbsp;&nbsp;&nbsp;input relative date above&nbsp;&nbsp;&nbsp;&nbsp;<sup>&uarr;</sup>',
						false);
						return true; 
					}
					var dt = plugin.parseRelativeDate.call(plugin,v);
					var test = dt ? true : false;
					menu.okbtn.setDisabled(!test); 
					
					var renderVal = test ? '=&nbsp;&nbsp;' +
						dt.format('D, F j, Y (g:i a)') : 
						'<span>invalid relative date</span>';
					menu.renderValLabel.setText(renderVal,false);
					
					return test;
				},
				enableKeyEvents:true,
				listeners:{
					keyup:{
						scope: this,
						buffer: 10,
						fn: function(field, e) {
							if (field.isVisible() && Ext.EventObject.ENTER == e.getKey()){
								this.doMenuSaveRelative();
							}
						}
					}
				}
			});
			
			menu.add(menu.field,menu.renderValLabel);
			
			menu.add({
				xtype: 'panel',
				buttonAlign: 'center',
				border: false,
				buttons: [
					{
						xtype: 'button',
						text: 'Cancel',
						handler: function() {
							menu.hide();
						}
					},
					menu.okbtn
				]
			});
			
			menu.on('show',function(){
				
				//Disable the menu keyNav to allow arrow keys to work in fields within the menu:
				menu.keyNav.disable();
				
				this.cmp.suspendEvents();
				var field = menu.field;
				field.setValue(this.cmp.getDurationString());
				field.focus(false,50);
				field.focus(false,200);
				field.setCursorPosition(1000000);
			},this);
			
			menu.on('beforehide',function(){
				
				var field = menu.field;
				
				var value = field.getValue();
				if(!value || value == '' || !field.isValid()) {
					// If the input field isn't valid then the real field wasnt updated
					// (by ENTER keystroke in input field listener) and it didn't call blur.
					// refocus the field:
					this.cmp.focus(false,50);
				}
				
				return true;
			},this);
			
			menu.on('hide',function(){
				this.cmp.resumeEvents();
			},this);
			
			this.relativeDateMenu = menu;
		}
		return this.relativeDateMenu;
	},
	
	doMenuSaveRelative: function() {
		
		var menu = this.relativeDateMenu;
		if(!menu || !menu.isVisible()) { return; }
		var field = menu.field;
		if(!field) { return; }
		
		var v = field.getValue();
		if(v && v != '' && field.isValid()){
			this.cmp.setValue(v);
			this.cmp.resumeEvents();
			this.cmp.fireEvent('blur');
			menu.hide();
		}
	}
	
});
Ext.preg('form-relative-datetime',Ext.ux.RapidApp.Plugin.RelativeDateTime);


// This is basically a clone of the logic in grid col filters plugin, reproduced for
// general purpose menus. There are a few special issues with the col menu that it needs
// to still be separate, for now, but this duplicate logic needs to be consolidated
// at some point:
Ext.ux.RapidApp.Plugin.MenuFilter = Ext.extend(Ext.util.Observable,{
	
	maxSeparatorPosition: 4,
	
	init: function(menu) {
		this.menu = menu;
		menu.on('beforeshow',this.onBeforeshow,this);
		menu.on('show',this.onShow,this);
	},
	
	onBeforeshow: function() {

		//Disable the menu keyNav to allow arrow keys to work in fields within the menu:
		if(this.menu.keyNav){ this.menu.keyNav.disable(); }
		
		if(!this.menu.getComponent('filteritem')) {
			var filteritem = this.getColItem();
			if(!filteritem) { return; }
			//var pos = this.getInsertPosition();
			//this.menu.insert(pos,filteritem);
			this.menu.insert(0,filteritem,'-');
		}
	},
	
	onShow: function() {
		this.autoSizeField.defer(20,this);
		
		if(this.menu.autoFocusFilter) { 
			this.focusFilter();
		}
	},
	
	autoSizeField: function() {
		var field = this.menu.getComponent('filteritem');
		if(field) {
			field.setWidth(this.menu.getWidth() - 25);
		}
	},
	
	focusFilter: function() {
		var field = this.menu.getComponent('filteritem');
		if(field) { 
			field.focus(false,50);
			field.focus(false,200);
		}
	},
	
	getColCount: function() {
		return this.menu.items.getCount();
	},
	
	isSeparator: function(item) {
		if((Ext.isObject(item) && item.itemCls == 'x-menu-sep') || item == '-') {
			return true;
		}
		return false;
	},
	
	/*
	getExistingSeparatorIndex: function() {
		var items = this.menu.items.items;
		for (ndx in items) {
			if(ndx > this.maxSeparatorPosition) { return -1; }
			if(this.isSeparator(items[ndx])) { return ndx; }
		}
		return -1;
	},
	
	getInsertPosition: function() {
		var pos = this.getExistingSeparatorIndex();
		if(pos == -1) { 
			this.menu.insert(0,'-');
			return 0;
		}
		return pos;
	},
	*/
	
	testMatch: function(item,str) {
		// If the string is not set, match is true per default:
		if(!str || str == '' || !item.text) { return true; }
		
		str = str.toLowerCase();
		var text = item.text.toLowerCase();
		
		// Test menu item text
		if(text.indexOf(str) != -1) { return true; }
		
		return false;
	},
	
	filterByString: function(str) {
		if(str == '') { str = null; }
		if(!this.menu.isVisible()) { return; }
		
		var past_sep,past_label,add_at,remove,match_count = 0;
		this.menu.items.each(function(item,ndx){
			if(!past_sep) {
				if(this.isSeparator(item)){ past_sep = true; }
				return;
			}
			else if (!past_label) {
				if(str) { add_at = ndx; }
				past_label = true;
				if(item.isFilterLabel) {
					remove = item;
					return;
				}
			}
			
			var match = this.testMatch(item,str);
			if(match) { match_count++; }
			
			if(!item.hidden) {
				if(!match) {
					item.setVisible(false);
					item.isFiltered = true;
				}
			}
			else {
				if(match && item.isFiltered) {
					delete item.isFiltered;
					item.setVisible(true);
				}
			}
		},this);
		
		if(remove) { 
			var liEl = remove.el.parent('li');
			this.menu.remove(remove,true);
			// this appears to be an Ext bug:
			if(liEl && liEl.dom) { Ext.removeNode(liEl.dom); }
		}
		
		if(add_at) {
			this.menu.insert(add_at,{
				isFilterLabel: true,
				xtype: 'label',
				html: '<b><i><center>Filtered (' + match_count + ' items)</center></i></b>'
			});
		}
		
		this.menu.doLayout();
	},
	
	getColItem: function() {
		return {
			xtype:'textfield',
			itemId: 'filteritem',
			emptyText: 'Type to Filter List',
			emptyClass: 'field-empty-text',
			width: 100, //<-- should be less than the minWidth of menu for proper auto-sizing
			enableKeyEvents:true,
			listeners: {
				render: {
					scope: this,
					fn: function(field) {
						field.filterTask = new Ext.util.DelayedTask(function(f){
							this.filterByString(f.getValue());
						},this,[field]);
					}
				},
				keyup: {
					scope: this,
					buffer: 150,
					fn: function(field, e) {
						if(field.filterTask) { field.filterTask.delay(500); }
					}
				}
			}
		};
	}
});
Ext.preg('menu-filter',Ext.ux.RapidApp.Plugin.MenuFilter);



/*
 Ext.ux.RapidApp.Plugin.GridEditAdvancedConfig
 2012-11-08 by HV

 Plugin that allows editing of the special 'advanced_config' of the component
*/
Ext.ux.RapidApp.Plugin.GridEditAdvancedConfig = Ext.extend(Ext.util.Observable,{
	init: function(grid) {
		this.grid = grid;
		grid.on('afterrender',this.onAfterRender,this);
	},
	
	onAfterRender: function(){
		menu = this.grid.getOptionsMenu();
		if(menu) { menu.add(this.getMenuItem()); }
		
		// Designed to work specifically with AppTab's context menu system:
		if(this.grid.ownerCt) {
			this.grid.ownerCt.getTabContextMenuItems = 
				this.getTabContextMenuItems.createDelegate(this);
		}
	},
	
	getTabContextMenuItems: function() {
		return [ this.getMenuItem() ];
	},
	
	getMenuItem: function() {
		return {
			xtype: 'menuitem',
			text: 'Edit Advanced Config',
			iconCls: 'ra-icon-bullet-wrench',
			handler: this.showAdvancedConfigWin,
			scope: this
		};
	},
	
	showAdvancedConfigWin: function() {
		
		var json = this.grid.store.advanced_config_json;
		json = json || (
			this.grid.store.advanced_config ? 
				Ext.encode(this.grid.store.advanced_config) : ''
		);
		
		var fp;
		
		var saveFn = function(btn) {
			var form = fp.getForm();
			var cb = form.findField('active');
			var jsonf = form.findField('json_data');
			
			// Doing this instead of just called getFieldValues() because that doesn't
			// return the json_data when the field is disabled
			var data = {};
			if(cb && jsonf) {
				data.active = cb.getValue();
				data.json_data = jsonf.getValue();
				this.grid.store.advanced_config_active = data.active;
				this.grid.store.advanced_config_json = data.json_data;
			}
			
			this.win.close();
			
			// Apply the config immediately:
			if(btn.name == 'apply' && this.grid.ownerCt && this.grid.ownerCt.ownerCt) {
				var tab = this.grid.ownerCt, tp = tab.ownerCt;
				if(Ext.isFunction(tp.loadContent) && Ext.isObject(tab.loadContentCnf)) {
					var cnf = tab.loadContentCnf;
					var extra_cnf = {
						update_cmpConfig: function(conf) {
							if(conf.store) {
								conf.store.advanced_config_active = data.active;
								conf.store.advanced_config_json = data.json_data;
							}
						}
					};
					tp.remove(tab);
					tp.loadContent(cnf,extra_cnf);
				}
			}
		};
		
		fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 160,
			labelPad: 15,
			bodyStyle: 'padding: 10px 10px 5px 5px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			items: [
				{
					name: 'active',
					xtype: 'checkbox',
					fieldLabel: 'Advanced Config Active',
					labelStyle: 'font-weight: bold;color:navy;',
					checked: this.grid.store.advanced_config_active ? true : false,
					listeners: {
						check: function(cb,checked) {
							var json_field = cb.ownerCt.getComponent('json_data');
							json_field.setDisabled(!checked);
						}
					}
				},
				{ xtype: 'spacer', height: 10 },
				{
					name: 'json_data',
					itemId: 'json_data',
					xtype: 'textarea',
					style: 'font-family: monospace;',
					fieldLabel: 'Advanced Config JSON',
					hideLabel: true,
					disabled: this.grid.store.advanced_config_active ? false : true,
					value: json,
					anchor: '-0 -35',
					validator: function(v) {
						if(!v || v == '') { return false; }
						var obj, err;
						try{ obj = Ext.decode(v) }catch(e){ err = e; };
						if(err){ return err; }
						return Ext.isObject(obj);
					}
				}
			],
			
			buttons: [
				{
					name: 'apply',
					text: 'Save &amp; Apply',
					iconCls: 'ra-icon-save-ok',
					width: 175,
					formBind: true,
					scope: this,
					handler: saveFn
				},
				{
					name: 'save',
					text: 'Save',
					iconCls: 'ra-icon-save-ok',
					width: 100,
					formBind: true,
					scope: this,
					handler: saveFn
				},
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
		
		if(this.win) {
			this.win.close();
		}
		
		this.win = new Ext.Window({
			title: 'Edit Advanced Config (Experts Only)',
			layout: 'fit',
			width: 600,
			height: 400,
			minWidth: 400,
			minHeight: 250,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
		
		this.win.show();
	}
});
Ext.preg('grid-edit-advanced-config',Ext.ux.RapidApp.Plugin.GridEditAdvancedConfig);



/*
 Ext.ux.RapidApp.Plugin.GridEditRawColumns
 2013-05-27 by HV

 Plugin that allows editing the grid 'view' column configs
*/
Ext.ux.RapidApp.Plugin.GridEditRawColumns = Ext.extend(Ext.util.Observable,{
	init: function(grid) {
		this.grid = grid;
		grid.on('afterrender',this.onAfterRender,this);
	},
	
	onAfterRender: function(){
		menu = this.grid.getOptionsMenu();
		if(menu) { menu.add(this.getMenuItem()); }
		
		// Designed to work specifically with AppTab's context menu system:
		if(this.grid.ownerCt) {
			this.grid.ownerCt.getTabContextMenuItems = 
				this.getTabContextMenuItems.createDelegate(this);
		}
	},
	
	getTabContextMenuItems: function() {
		return [ this.getMenuItem() ];
	},
	
	getMenuItem: function() {
		return {
			xtype: 'menuitem',
			text: 'Edit Column Configs',
			iconCls: 'ra-icon-bullet-wrench',
			handler: this.showAdvancedConfigWin,
			scope: this
		};
	},
	
	showAdvancedConfigWin: function() {
		
    var column_configs = this.grid.getColumnModel().config;
    var columns = {};
    Ext.each(column_configs,function(col){
      var cnf = Ext.copyTo({},col,this.grid.column_allow_save_properties);
      columns[col.name] = cnf;
    },this);
    
    var json = JSON.stringify(columns,undefined,2);
		var fp;
		var saveFn = function(btn) {
			var form = fp.getForm();
			var jsonf = form.findField('json_data');
      
			var data = {};
			if(jsonf) {
				data.json_data = jsonf.getValue();
				data.decoded = Ext.decode(data.json_data);
			}
			
			this.win.close();
			
			// Apply the config immediately:
			if(btn.name == 'apply' && this.grid.ownerCt && this.grid.ownerCt.ownerCt) {
				var tab = this.grid.ownerCt, tp = tab.ownerCt;
				if(Ext.isFunction(tp.loadContent) && Ext.isObject(tab.loadContentCnf)) {
					var cnf = tab.loadContentCnf;
					tp.remove(tab);
					tp.loadContent(cnf,{
						update_cmpConfig: function(conf) {
              
              Ext.each(conf.columns,function(col){
                var saved_col = data.decoded[col.name];
                if(saved_col) {
                  Ext.apply(col,saved_col);
                }
              },this);
						}
					});
				}
			}
		};
		
		fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 160,
			labelPad: 15,
			bodyStyle: 'padding: 10px 10px 5px 5px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			items: [
							{
					name: 'json_data',
					itemId: 'json_data',
					xtype: 'textarea',
					style: 'font-family: monospace;',
					fieldLabel: 'Columns JSON',
					hideLabel: true,
					value: json,
					anchor: '-0 -35',
					validator: function(v) {
						if(!v || v == '') { return false; }
						var obj, err;
						try{ obj = Ext.decode(v) }catch(e){ err = e; };
						if(err){ return err; }
						return Ext.isObject(obj);
					}
				}
			],
			
			buttons: [
				{
					name: 'apply',
					text: 'Apply & Reload',
					iconCls: 'ra-icon-save-ok',
					width: 175,
					formBind: true,
					scope: this,
					handler: saveFn
				},
				
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
		
		if(this.win) {
			this.win.close();
		}
		
		this.win = new Ext.Window({
			title: 'Edit Raw Column Configs (Experts Only)',
			layout: 'fit',
			width: 800,
			height: 600,
			minWidth: 400,
			minHeight: 250,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
		
		this.win.show();
	}
});
Ext.preg('grid-edit-raw-columns',Ext.ux.RapidApp.Plugin.GridEditRawColumns);



Ext.ux.RapidApp.Plugin.GridCustomHeaders = Ext.extend(Ext.util.Observable,{
	
	init: function(grid) {
    this.grid = grid;
		grid.on('render',this.onRender,this);
	},
  
  promptChangeHeader: function() {
    var column = this.getActiveCol();
    if(!column) { return; }
    
    var blank_str = '&#160;';
    var current_header = column.header;
    if (current_header == blank_str) {
      current_header = '';
    }
    
    var fp;
    fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 70,
			labelPad: 15,
			bodyStyle: 'padding: 10px 10px 5px 5px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			items: [
				{
          name: 'colname',
          xtype: 'displayfield',
          fieldLabel: 'Column',
          style: 'bottom:-1px;',
          cls: 'blue-text-code',
          value: column.name
        },
        { xtype: 'spacer', height: 5 },
        {
					name: 'header',
					itemId: 'header',
					xtype: 'textfield',
					fieldLabel: 'Header',
					value: current_header,
					anchor: '-0'
				}
			],
			
			buttons: [
				{
					name: 'apply',
					text: 'Save',
					iconCls: 'ra-icon-save-ok',
					width: 90,
					formBind: true,
					scope: this,
					handler: function() {
            var form = fp.getForm();
            var f = form.findField('header');
            var value = f.getValue();
            if(value != column.header) {
              value = value ? value : blank_str;
              var cm = this.grid.getColumnModel();
              var indx = cm.getIndexById(column.id);
              cm.setColumnHeader(indx,value);
              this.grid.store.custom_headers[column.name] = value;
            }
            this.win.close();
          }
				},
				
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
		
		if(this.win) {
			this.win.close();
		}
    
    this.win = this.win = new Ext.Window({
			title: 'Change Column Header',
			layout: 'fit',
			width: 400,
			height: 175,
			minWidth: 300,
			minHeight: 150,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
    
    this.win.show(); 
  },
      
	getActiveCol: function() {
    var view = this.grid.getView();
    if (!view || view.hdCtxIndex === undefined) {
      return null;
    }
    return view.cm.config[view.hdCtxIndex];
  },
      
	onRender: function() {
  
    if(!this.grid.store.custom_headers) {
      this.grid.store.custom_headers = {};
    }
		
    var hmenu = this.grid.view.hmenu;
    if(!hmenu) { return; }

    var index = 0;
    var colsItem = hmenu.getComponent('columns');
    if(colsItem) {
      index = hmenu.items.indexOf(colsItem);
    }
    
    hmenu.insert(index,{
      text: "Change Header",
      iconCls: 'ra-icon-textfield-edit',
      handler:this.promptChangeHeader, 
      scope: this
    });
	}
});
Ext.preg('grid-custom-headers',Ext.ux.RapidApp.Plugin.GridCustomHeaders);


Ext.ux.RapidApp.Plugin.GridToggleEditCells = Ext.extend(Ext.util.Observable,{
	
	init: function(grid) {
    this.grid = grid;
		grid.on('render',this.onRender,this);
	},
  
  onText: '<span style="color:#666666;">Cell Editing On</span>',
  offText: '<span style="color:#666666;">Cell Editing Off</span>',
  onIconCls: 'ra-icon-textfield-check',
  offIconCls: 'ra-icon-textfield-cross',
  
  toggleEditing: function(btn) {
    if(this.grid.store.disable_cell_editing) {
      this.btn.setText(this.onText);
      this.btn.setIconClass(this.onIconCls);
      this.grid.store.disable_cell_editing = false;
    }
    else {
      this.btn.setText(this.offText);
      this.btn.setIconClass(this.offIconCls);
      this.grid.store.disable_cell_editing = true;
    }
  },
  
  beforeEdit: function() {
    return this.grid.store.disable_cell_editing ? false : true;
  },
  
  countEditableColumns: function() {
    var count = 0;
    var cm = this.grid.getColumnModel();
    Ext.each(cm.config,function(col,index){
      // Note: this is specific to the RapidApp1/DataStorePlus API which
      // will change in RapidApp2
      if(typeof col.allow_edit !== "undefined" && !col.allow_edit) { return; }
      // Sadly, isCellEditable() is not consistent because of special DataStorePlus
      // code for 'allow_edit' which is handled above
      if(cm.isCellEditable(index,0)) { count++; }
    },this);
    return count;
  },
      
	onRender: function() {
  
    // allow starting the toggle to off if it hasn't been set yet:
    if( this.grid.toggle_edit_cells_init_off && 
        typeof this.grid.store.disable_cell_editing == 'undefined'
    ) { this.grid.store.disable_cell_editing = true; }
  
    if(!this.grid.store.api.update || this.grid.disable_toggle_edit_cells) {
      return;
    }
    
    // Check that there are actually editable columns:
    if(this.countEditableColumns() == 0) { return; }
    
    var tbar = this.grid.getTopToolbar();
    if(! tbar) { return; }
    var optionsBtn = tbar.getComponent('options-button');
    if(! optionsBtn) { return; }
    
    var index = tbar.items.indexOf(optionsBtn) + 1;
    
    this.btn = new Ext.Button({
      text: this.onText,
      iconCls: this.onIconCls,
      handler:this.toggleEditing, 
      scope: this
    });
    
    if(this.grid.store.disable_cell_editing) {
      this.btn.setText(this.offText);
      this.btn.setIconClass(this.offIconCls);
    }
    tbar.insert(index,this.btn);
    
    this.grid.on('beforeedit',this.beforeEdit,this);
	}
	
});
Ext.preg('grid-toggle-edit-cells',Ext.ux.RapidApp.Plugin.GridToggleEditCells);


// This plugin is uses with the top-level Viewport to convert links to
// hashpath URLs to stay within the Ext/RapidApp tab system. For instance,
// clicking <a href="/foo">foo</a> would be translated to '#!/foo'
//
// Designed to work with normal panels or ManagedIFrames:
Ext.ux.RapidApp.Plugin.LinkClickCatcher = Ext.extend(Ext.util.Observable,{
  
  init: function(cmp) {
    this.cmp = cmp;
    if(Ext.ux.RapidApp.HashNav.INITIALIZED) {
    
      var eventName = this.isIframe() ? 'domready' : 'afterrender';
      this.cmp.on(eventName,function(){
        
        var El = this.cmp.getEl();
        
        // For the special ManagedIFrame case, reach into the iframe
        // and get the inner <body> element to attach the listener:
        if(this.isIframe()) {
          var iFrameEl = this.cmp.getFrame();
          var doc = iFrameEl.dom.contentWindow.document;
          El = new Ext.Element(doc.body);
        }
        
        El.on('click',this.clickInterceptor,this);
        
      },this);
    }
  },
  
  isIframe: function() { return Ext.isFunction(this.cmp.getFrame); },
  
  externalUrlRe: new RegExp('^\\w+://'),
  
  clickInterceptor: function(event) {
    var node = event.getTarget(null,null,true);

    if(! node) { return; }
    
    // Is a link (<a> tag) or is a child of a link tag:
    node = node.is('a') ? node : node.parent('a');
    if(! node) { return; }
    
    var targetAttr = node.getAttribute('target');
    if(targetAttr) {
      // If we're in an iFrame, ignore links with a target defined *IF* they
      // are iFrame-specific (target='_top' or '_parent'). We never want an
      // iFrame to reload to a new URL, but this won't happen with _top/_parent
      // and in these cases we can still safely honor the target
      if(this.isIframe()) {
        if(targetAttr == '_top' && targetAttr !== '_parent') { return; }
      }
      // If we're not in an iFrame, ignore links with any target at all
      // (i.e. target="_blank", etc):
      else {
        return;
      }
    }
    
    var href = node.getAttribute('href');
    
    // URL is local (does not start with http://, https://, etc)
    if(! this.externalUrlRe.test(href)) {
      // Stop the link click event and convert to hashpath:
      event.stopEvent();
      var hashpath = Ext.ux.RapidApp.HashNav.urlToHashPath(href);
      window.location.hash = hashpath;
    }
  }
  
});
Ext.preg('ra-link-click-catcher',Ext.ux.RapidApp.Plugin.LinkClickCatcher);

