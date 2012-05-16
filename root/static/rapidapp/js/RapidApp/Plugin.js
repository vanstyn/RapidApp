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

Ext.ns('Ext.ux.RapidApp.Plugin.HtmlEditor');
Ext.ux.RapidApp.Plugin.HtmlEditor.SimpleCAS_Image = Ext.extend(Ext.ux.form.HtmlEditor.Image,{
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	maxImageWidth: null,
	
	resizeWarn: false,
	
	onRender: function() {
		var btn = this.cmp.getToolbar().addButton({
				text: 'Insert Image',
				iconCls: 'x-edit-image',
				handler: this.selectImage,
				scope: this,
				tooltip: {
					title: this.langTitle
				},
				overflowText: this.langTitle
		});
	},
	
	selectImage: function() {
		var upload_field = {
			xtype: 'fileuploadfield',
			emptyText: 'Select image',
			fieldLabel:'Select Image',
			name: 'Filedata',
			buttonText: 'Browse',
			width: 300
		};
		
		var fieldset = {
			style: 'border: none',
			hideBorders: true,
			xtype: 'fieldset',
			labelWidth: 70,
			border: false,
			items:[ upload_field ]
		};
		
		var callback = function(form,res) {
			var img = Ext.decode(res.response.responseText);
			
			if(this.resizeWarn && img.resized) {
				Ext.Msg.show({
					title:'Notice: Image Resized',
					msg: 
						'The image has been resized by the server.<br><br>' +
						'Original Size: <b>' + img.orig_width + 'x' + img.orig_height + '</b><br><br>' +
						'New Size: <b>' + img.width + 'x' + img.height + '</b>'
					,
					buttons: Ext.Msg.OK,
					icon: Ext.MessageBox.INFO
				});
			}
			
			img.link_url = '/simplecas/fetch_content/' + img.checksum + '/' + img.filename;
			this.insertImage(img);
		};
		
		var url = '/simplecas/upload_image';
		if(this.maxImageWidth) { url += '/' + this.maxImageWidth; }
		
		Ext.ux.RapidApp.WinFormPost.call(this,{
			title: 'Insert Image',
			width: 430,
			height:140,
			url: url,
			useSubmit: true,
			fileUpload: true,
			fieldset: fieldset,
			success: callback
		});
	},

	insertImage: function(img) {
		if(!this.cmp.activated) {
			this.cmp.onFirstFocus();
		}
		this.cmp.insertAtCursor(
			'<img src="' + img.link_url + '" width=' + img.width + ' height=' + img.height + '>'
		);
	}
});
Ext.preg('htmleditor-casimage',Ext.ux.RapidApp.Plugin.HtmlEditor.SimpleCAS_Image);

Ext.ux.RapidApp.Plugin.HtmlEditor.DVSelect = Ext.extend(Ext.util.Observable, {
	
	// This should be defined in consuming class
	dataview: { xtype: 'panel', 	html: '' },
	
	// This should be defined in consuming class
	getInsertStr: function(Records) {},
	
	title: 'Select Item',
	height: 400,
	width: 500,
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	init: function(cmp){
		this.cmp = cmp;
		this.cmp.on('render', this.onRender, this);
		
		if(Ext.isIE) {
			// Need to do this in IE because if the user tries to insert an image before the editor
			// is "activated" it will go no place. Unlike FF, in IE the only way to get it activated
			// is to click in it. The editor will automatically enable its toolbar buttons again when
			// its activated.
			this.cmp.on('afterrender',this.disableToolbarInit, this,{delay:1000, single: true});
		}
	},
	
	disableToolbarInit: function() {
		if(!this.cmp.activated) {
			this.cmp.getToolbar().disable();
		}
	},
	
	onRender: function() {
		
		this.btn = this.cmp.getToolbar().addButton({
				iconCls: 'x-edit-image',
				handler: this.loadDVSelect,
				text: this.title,
				scope: this
				//tooltip: {
				//	title: this.langTitle
				//},
				//overflowText: this.langTitle
		});
	},
	
	insertContent: function(str) {
		if(!this.cmp.activated) {
			// This works in FF, but not in IE:
			this.cmp.onFirstFocus();
		}
		this.cmp.insertAtCursor(str);

	},
	
	loadDVSelect: function() {
		
		if (this.dataview_enc) { this.dataview = Ext.decode(this.dataview_enc); }
		
		this.dataview.itemId = 'dv';
		
		this.win = new Ext.Window({
			title: this.title,
			layout: 'fit',
			width: this.width,
			height: this.height,
			closable: true,
			modal: true,
			items: this.dataview,
			buttons: [
				{
					text : 'Select',
					scope: this,
					handler : function() {
						
						var dv = this.win.getComponent('dv');
						
						var recs = dv.getSelectedRecords();
						if (recs.length == 0) { return; }
						
						var str = this.getInsertStr(recs);
						this.win.close();
						return this.insertContent(str);
					}
				},
				{
					text : 'Cancel',
					scope: this,
					handler : function() {
						this.win.close();
					}
				}
			]
		});
		
		this.win.show();
	}
});
Ext.preg('htmleditor-dvselect',Ext.ux.RapidApp.Plugin.HtmlEditor.DVSelect);


Ext.ux.RapidApp.Plugin.HtmlEditor.LoadHtmlFile = Ext.extend(Ext.util.Observable, {
	
	title: 'Load Html',
	height: 400,
	width: 500,
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	init: function(cmp){
		this.cmp = cmp;
		this.cmp.on('render', this.onRender, this);
	},
	
	onRender: function() {
		
		this.btn = this.cmp.getToolbar().addButton({
				iconCls: 'icon-page-white-world',
				handler: this.selectHtmlFile,
				text: this.title,
				scope: this
				//tooltip: {
				//	title: this.langTitle
				//},
				//overflowText: this.langTitle
		});
	},
	
	replaceContent: function(str) {
		if(!this.cmp.activated) {
			// This works in FF, but not in IE:
			this.cmp.onFirstFocus();
		}
		this.cmp.setValue(str);
	},
	
	selectHtmlFile: function() {
		var upload_field = {
			xtype: 'fileuploadfield',
			emptyText: 'Select html file',
			fieldLabel:'Html File',
			name: 'Filedata',
			buttonText: 'Browse',
			width: 300
		};
		
		var fieldset = {
			style: 'border: none',
			hideBorders: true,
			xtype: 'fieldset',
			labelWidth: 70,
			border: false,
			items:[ upload_field ]
		};
		
		var callback = function(form,res) {
			var packet = Ext.decode(res.response.responseText);
			this.replaceContent(packet.content);
		};
		
		Ext.ux.RapidApp.WinFormPost.call(this,{
			title: 'Load html file',
			width: 430,
			height:140,
			url:'/simplecas/texttranscode/transcode_html',
			useSubmit: true,
			fileUpload: true,
			fieldset: fieldset,
			success: callback
			//failure: callback
		});
	}
});
Ext.preg('htmleditor-loadhtml',Ext.ux.RapidApp.Plugin.HtmlEditor.LoadHtmlFile);


Ext.ux.RapidApp.Plugin.HtmlEditor.InsertFile = Ext.extend(Ext.util.Observable, {
	
	title: 'Insert File',
	height: 400,
	width: 500,
	
	constructor: function(cnf) {
		Ext.apply(this,cnf);
	},
	
	init: function(cmp){
		this.cmp = cmp;
		this.cmp.on('render', this.onRender, this);
		
		var getDocMarkup_orig = this.cmp.getDocMarkup;
		this.cmp.getDocMarkup = function() {
			return '<link rel="stylesheet" type="text/css" href="/static/rapidapp/css/filelink.css" />' +
				getDocMarkup_orig.apply(this,arguments);
		}
	},
	
	onRender: function() {
		this.btn = this.cmp.getToolbar().addButton({
				iconCls: 'icon-page-white-world',
				handler: this.selectFile,
				text: this.title,
				scope: this
				//tooltip: {
				//	title: this.langTitle
				//},
				//overflowText: this.langTitle
		});
	},
	
	insertContent: function(str) {
		if(!this.cmp.activated) {
			// This works in FF, but not in IE:
			this.cmp.onFirstFocus();
		}
		this.cmp.insertAtCursor(str);
	},
	
	selectFile: function() {
		var upload_field = {
			xtype: 'fileuploadfield',
			emptyText: 'Select file',
			fieldLabel:'Select File',
			name: 'Filedata',
			buttonText: 'Browse',
			width: 300
		};
		
		var fieldset = {
			style: 'border: none',
			hideBorders: true,
			xtype: 'fieldset',
			labelWidth: 70,
			border: false,
			items:[ upload_field ]
		};
		
		var callback = function(form,res) {
			var packet = Ext.decode(res.response.responseText);
			var url = '/simplecas/fetch_content/' + packet.checksum + '/' + packet.filename;
			var link = '<a class="' + packet.css_class + '" href="' + url + '">' + packet.filename + '</a>';
			this.insertContent(link);
		};
		
		Ext.ux.RapidApp.WinFormPost.call(this,{
			title: 'Insert file',
			width: 430,
			height:140,
			url:'/simplecas/upload_file',
			useSubmit: true,
			fileUpload: true,
			fieldset: fieldset,
			success: callback
		});
	}
});
Ext.preg('htmleditor-insertfile',Ext.ux.RapidApp.Plugin.HtmlEditor.InsertFile);



Ext.ns('Ext.ux.RapidApp.Plugin');
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
			expandBtnCls: 'icon-roles_expand_sprite',
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
Ext.ux.RapidApp.Plugin.GridQuickSearch = function(config) {
	Ext.apply(this, config);
	Ext.ux.RapidApp.Plugin.GridQuickSearch.superclass.constructor.call(this);
}; // eo constructor

Ext.extend(Ext.ux.RapidApp.Plugin.GridQuickSearch, Ext.util.Observable, {
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
	 * @cfg {String} iconCls Icon class for menu button (defaults to "icon-magnifier")
	 */
	//,iconCls:'icon-magnifier'
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
	,width:100

	/**
	 * @cfg {String} xtype xtype is usually not used to instantiate this plugin but you have a chance to identify it
	 */
	,xtype:'gridsearch'

	/**
	 * @cfg {Object} paramNames Params name map (defaults to {fields:"fields", query:"query"}
	 */
	,paramNames: {
		 fields:'fields'
		,query:'query'
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
	 ,fieldNameMap: {},
	
	init:function(grid) {
		this.grid = grid;
		
		// -- New: disable plugin if there are no quick_search columns (2012-04-11 by HV)
		if(!this.getQuickSearchColumns().length > 0) { return; }
		// --
		
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

		// add menu button
		tb.add({
			 text:this.searchText
			,menu:this.menu
			,iconCls:this.iconCls
		});

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
			// clear start (necessary if we have paging)
			if(store.lastOptions && store.lastOptions.params) {
				store.lastOptions.params[store.paramNames.start] = 0;
			}

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
			if (store.lastOptions && store.lastOptions.params) {
				delete(store.lastOptions.params[this.paramNames.fields]);
				delete(store.lastOptions.params[this.paramNames.query]);
			}
			if(fields.length) {
				store.baseParams[this.paramNames.fields] = Ext.encode(fields);
				store.baseParams[this.paramNames.query] = val;
			}

			// reload store
			store.reload();
		}

	} // eo function onTriggerSearch
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
		var calcWidth = metrics.getWidth(longField.fieldLabel) + 5;
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



/*
 Ext.ux.RapidApp.Plugin.CmpDataStorePlus
 2011-11-02 by HV

 Plugin for components with stores (such as AppGrid2, AppDV).
 This plugin contains generalized extra functionality applicable
 to any components with stores (note that Ext.data.Store itself
 cannot use plugins because its not a component)
*/
Ext.ux.RapidApp.Plugin.CmpDataStorePlus = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		cmp.datastore_plus_plugin = this;

		delete cmp.store.tiedChildStores;
		
		// bubbles up the parent components and records us as a tied child store:
		cmp.bubbleTieStoreParents = function() {
			this.bubble(function() {
				if(this.bubbleTieStoreParents) {
					if(!this.store.tiedChildStores) {
						this.store.tiedChildStores = {};
						this.store.tiedChildStores[this.store.storeId] = this.store;
					}
					this.store.tiedChildStores[cmp.store.storeId] = cmp.store;
				}
			});
		};
		this.cmp.on('render',cmp.bubbleTieStoreParents,cmp);
		
		
		this.cmp.origInitEvents = this.cmp.initEvents;
		this.cmp.initEvents = function() {
			cmp.origInitEvents.call(cmp);
			if(cmp.loadMask){
				cmp.loadMask = new Ext.LoadMask(cmp.bwrap,
						  Ext.apply({store:cmp.store}, cmp.loadMask));
			}
		}
		
		
		// -- instead of standard store 'autoLoad' param, 'store_autoLoad' happens
		// on 'render' in order to be delayed, in the case of the component being
		// within a collapsed panel, etc. This is partnered with the setting set
		// within DataStore2
		if(cmp.store.store_autoLoad) {
			var onFirstShow;
			onFirstShow = function(){
				// only load if its the first load and not collapsed:
				if(!cmp.store.lastOptions && !cmp.collapsed){
					cmp.store.load(cmp.store.store_autoLoad);
				}
			}
			cmp.on('render',onFirstShow,this);
			cmp.on('expand',onFirstShow,this);
		}
		// --
		
		
		if(!cmp.persist_immediately) { cmp.persist_immediately = {}; }
		if(cmp.persist_all_immediately) {
			cmp.persist_immediately = {
				create: true,
				update: true,
				destroy: true
			};
		}
		var miss = false;
		if(cmp.store.api.create && !cmp.persist_immediately.create) { miss = true; }
		if(cmp.store.api.update && !cmp.persist_immediately.update) { miss = true; }
		if(cmp.store.api.destroy && !cmp.persist_immediately.destroy) { miss = true; }
		cmp.persist_all_immediately = true;
		if(miss) { cmp.persist_all_immediately = false; }
		
		Ext.copyTo(this,cmp,[
			'store_buttons',
			'show_store_button_text',
			'store_button_cnf',
			'store_exclude_buttons',
			'close_unsaved_confirm',
			'persist_all_immediately',
			'persist_immediately',
			'store_add_initData',
			'use_add_form',
			'add_form_url_params',
			'add_form_window_cnf',
			'autoload_added_record',
			'add_records_first',
			'store_exclude_api',
			'store_write_mask'
		]);
		
		this.exclude_btn_map = {};
		Ext.each(this.store_exclude_buttons,function(item) { this.exclude_btn_map[item] = true; },this);
		
		this.initAdditionalStoreMethods.call(this,this.cmp.store,this);
		
		this.cmp.loadedStoreButtons = {};
			
		
		// --vv-- Displays the number of records in the title (superscript)	
		var titleCmp = cmp;
		if(!cmp.title && cmp.ownerCt && (cmp.ownerCt.titleCountLocal || cmp.ownerCt.titleCount )){
			titleCmp = cmp.ownerCt;
		}
		if(titleCmp.title && ( titleCmp.titleCountLocal || titleCmp.titleCount )) {
			cmp.store.on('buttontoggle',function() {
				var count = titleCmp.titleCountLocal ? cmp.store.getCount() : cmp.store.getTotalCount();
				if(count == 0) { count = ''; }
				titleCmp.setTitle(
					titleCmp.initialConfig.title + 
						'&nbsp;<span class="superscript-navy">' + count + '</span>'
				);
			},cmp);
		}
		// --^^--
		
		var plugin = this;
		this.cmp.getStoreButton = function(name,showtext) {
			return plugin.getStoreButton.call(plugin,name,showtext);
		};
		
		if(this.cmp.setup_bbar_store_buttons) {
			this.cmp.on('render',this.insertStoreButtonsBbar,this);
		}
		
		if(this.cmp.setup_tbar_store_buttons) {
			this.cmp.on('render',this.insertStoreButtonsTbar,this);
		}
		
		// Only applies to editor grids; no effect/impact on other components
		// without the beforeedit/afteredit events
		this.cmp.on('beforeedit',this.beforeCellEdit,this);
		this.cmp.on('afteredit',this.cmp.store.saveIfPersist,this);
		
		/**********************/
		/** For Editor Grids **/
		if(Ext.isFunction(cmp.startEditing)){

			cmp.startEditing_orig = cmp.startEditing;
			
			cmp.startEditing = function(row,col) {
				var ed = this.colModel.getCellEditor(col, row);
				if(ed) {
					var field = ed.field;
					if(field && !field.DataStorePlusApplied) {
						
						// For combos and other fields with a select listener, automatically
						// finish the edit on select
						field.on('select',cmp.stopEditing.createDelegate(cmp));
						
						// For cycle-field/menu-field:
						field.cycleOnShow = false;
						field.manuOnShow = false;
						
						//Call 'expand' for combos and other fields with an expand method (cycle-field)
						if(Ext.isFunction(field.expand)) {
							ed.on('startedit',function(){
								this.expand();
								// If it is specifically a combo, call expand again to make sure
								// it really expands
								if(Ext.isFunction(this.doQuery)) {
									this.expand.defer(50,this);
								}
							},field);
						}
						
						field.DataStorePlusApplied = true;
					}
				}
				return cmp.startEditing_orig.apply(cmp,arguments);
			}
		}
		/**********************/
		/**********************/
		
		
		
		
		
		

		if(Ext.isFunction(this.cmp.getSelectionModel)) {
			// Give Grids getSelectedRecords() so they work like DataViews:
			if(!Ext.isFunction(this.cmp.getSelectedRecords)) {
				this.cmp.getSelectedRecords = function() {
					
					var sm = this.getSelectionModel();
					return sm.getSelections.apply(sm,arguments);
				}
			}
			
			// Give grids the selectionchange event so they work like dataviews:
			var sm = this.cmp.getSelectionModel();
			this.cmp.relayEvents(sm,['selectionchange']);
		}
		
		if(this.close_unsaved_confirm) {
			this.cmp.bubble(function(){
				//this.on('beforedestroy',plugin.beforeDestroy,plugin);
				this.on('beforeremove',plugin.beforeRemoveConfirm,plugin);
			});
		}
		
		// Override 'renderRows' of GridViews to get freshly added rows
		// to show up as dirty. Fields associated with a modified value of
		// undefined don't show up as dirty in the original code. This fixes
		// that:
		this.cmp.on('viewready',function(){
			var view = this.cmp.getView();
			if(!view.renderRowsOrig) { view.renderRowsOrig = view.renderRows; }
			view.renderRows = function(startRow,endRow){
				var grid = view.grid,
				store    = grid.store,
				rowCount = store.getCount(),
				records;
		  
				if (rowCount < 1) { return ''; }
		  
				startRow = startRow || 0;
				endRow   = Ext.isDefined(endRow) ? endRow : rowCount - 1;
				records  = store.getRange(startRow, endRow);
				
				Ext.each(records,function(record) {
					Ext.iterate(record.modified,function(k,v) {
						if(typeof v == 'undefined') { record.modified[k] = null; }
					},this);
				},this);
				return view.renderRowsOrig(startRow,endRow);
			};
		},this);
		
		// Automatically tries to load newly created (from backend) records
		// into loadTarget. This is roughly the same as a double-click on a
		// grid row:
		if(this.autoload_added_record) {
			cmp.store.on('write',function(store,action,result,res,Record){
				if(action == "create" && Ext.isObject(Record) && !Record.phantom && Record.data.loadContentCnf){
					var loadTarget = Ext.getCmp("main-load-target");
					return Ext.ux.RapidApp.AppTab.tryLoadTargetRecord(loadTarget,Record,cmp);
				}
			});
		}
		
		// -- Display a page-wide mask during save
		if(this.store_write_mask) {
			var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Saving Changes..."});
			var show_mask = function() { myMask.show(); }
			var hide_mask = function() { myMask.hide(); }
			
			cmp.store.on('beforewrite',show_mask,this);
			cmp.store.on('write',hide_mask,this);
			cmp.store.on('exception',hide_mask,this);
		}
		// --
		
		
		// --- Cache the last total count, and supply it back to the server. If the
		// server module supports cache_total_count it will return the cached total back
		// instead of calculating it, increasing performance. When changing pages, sorts, 
		// or other options that don't change the number of rows in the set, there is no
		// reason to calculate the total count over and over
		if(cmp.cache_total_count) {
			// Changes in any request params between requests will clear the cached total 
			// count except for these params:
			var excl_params = [
				'cached_total_count',
				//'columns',
				'start',
				'limit',
				'sort',
				'dir',
				'column_summaries'
			];
		
			var get_params_str = function(params) {
				var params = params || {};
				var p = Ext.apply({},params);
				for (i in excl_params) { delete p[excl_params[i]]; }
				return Ext.encode(p);
			};
		
			cmp.store.on('load',function(store) {
				delete store.cached_total_count;
				delete store.cached_total_count_params;
				if(store.reader && store.reader.jsonData) {
					var total_count = store.reader.jsonData.results;
					if(total_count) { 
						store.cached_total_count = total_count; 
						store.cached_total_count_params = get_params_str(
							store.lastOptions.params
						);
					}
				}
			},this);
		
			cmp.store.on('beforeload',function(store,options) {
				delete store.baseParams.cached_total_count;
				delete store.lastOptions.params.cached_total_count;
				if(
					store.cached_total_count && 
					get_params_str(store.cached_total_count_params) ==
					get_params_str(store.lastOptions.params)
				){
					var cached_total_count = store.cached_total_count;
					store.lastOptions.params.cached_total_count = cached_total_count;
					Ext.apply(options.params, {cached_total_count: cached_total_count});
				}
				return true;
			},this);
		}
		// ---
		
	},
	
	store_add_initData: {},
	close_unsaved_confirm: true,
	show_store_button_text: false,
	store_buttons: [ 'add', 'delete', 'reload', 'save', 'undo' ],
	store_button_cnf: {},
	store_exclude_buttons: [],
	exclude_btn_map: {},
	use_add_form: false,
	add_form_url_params: {},
	add_form_window_cnf: {},
	autoload_added_record: false,
	add_records_first: false,
	store_exclude_api: [],
	store_write_mask: true,
		
	initAdditionalStoreMethods: function(store,plugin) {
		
		Ext.each(plugin.store_exclude_api,function(item){
			if(store.api[item]) { delete store.api[item]; }
		});
		
		store.on('beforewrite',function(ds,action,records,options,arg) {
			if(action == 'create'){
				var colnames = [];
				store.fields.each(function(field){ colnames.push(field.name); });
				options.params.create_columns = Ext.encode(colnames);
			}
		});
		
		store.addEvents('beforeremove');
		store.removeOrig = store.remove;
		store.remove = function(record) {
			if(store.fireEvent('beforeremove',store,record) !== false) {
				return store.removeOrig.apply(store,arguments);
			}
			return -1;
		};
		
		store.getPhantomRecords = function() {
			var records = [];
			store.each(function(Record){
				if(Record.phantom) { records.push(Record); } 
			});
			return records;
		};
		
		store.hasPhantomRecords = function() {
			if(store.getPhantomRecords().length > 0) { return true; }
			return false;
		};
		
		store.addNotAllowed = function() {
			return store.hasPhantomRecords();
		},
		
		store.getNonPhantomModifiedRecords = function() {
			var records = [];
			Ext.each(store.getModifiedRecords(),function(Record){
				if(!Record.phantom) { records.push(Record); } 
			});
			return records;
		};
		
		store.hasPendingChanges = function() {
			if(store.getModifiedRecords().length > 0 || store.removed.length > 0) { 
				return true; 
			}
			return false;
		};
		
		store.getParentStore = function() {
			var parent = plugin.cmp.findParentBy(function(p) {
				if(p.store && p.store.getParentStore) { return true; }
				return false;
			});
			if(parent) { return parent.store; }
			return null;
		};
		
		store.eachTiedChild = function(fn) {
			Ext.iterate(store.tiedChildStores,function(id,str) {
				fn(str);
			});
		};
		
		store.hasAnyPendingChanges = function() {
			var pend = false;
			store.eachTiedChild(function(s) {
				if(s.hasPendingChanges()) { pend = true; }
			});
			return pend;
		};
		
		store.saveAll = function() {
			store.eachTiedChild(function(s) {
				if(s.hasPendingChanges()) { s.save.call(s); }
			});
		};
		
		store.reloadAll = function() {
			store.eachTiedChild(function(s) { s.reload.call(s); });
		};
		
		store.undoChangesAll = function() {
			store.eachTiedChild(function(s) { 
				if(s.hasPendingChanges()) { s.undoChanges.call(s); }
			});
		};
		
		store.undoChanges = function() {
			var store = this;
			Ext.each(store.getPhantomRecords(),function(Rec){ store.remove(Rec); });
			store.rejectChanges();
			store.fireEvent('buttontoggle',store);
		};
		store.on('beforeload',store.undoChanges,store);
		
		store.getLastRecord = function() {
			var count = store.getCount();
			if(!count) { return null; }
			var index = count - 1;
			return store.getAt(index);
		};
		
		store.prepareNewRecord = function(initData) {
			return new store.recordType(
				Ext.apply({},initData || plugin.store_add_initData)
			);
		};
		
		store.addRecord = function(initData) {
			var newRec = store.prepareNewRecord(initData);
			var ret;
			if(plugin.add_records_first) {
				ret = store.insert(0,newRec);
			}
			else {
				ret = store.add(newRec);
			}
			if(plugin.persist_immediately.create) { store.saveIfPersist(); }
			return ret;
		};
		
		
		
		store.addRecordForm = function(initData) {
			if(plugin.use_add_form == 'tab') {
				return store.addRecordFormTab(initData);
			}
			else {
				return store.addRecordFormWindow(initData);
			}
		};
		
		store.addRecordFormWindow = function(initData) {
			var newRec = store.prepareNewRecord(initData);
			
			var win;
			var close_handler = function(btn) { win.close(); };
			
			plugin.getAddFormPanel(newRec,close_handler,function(formpanel){
			
				var title;
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
					title = plugin.store_button_cnf.add.text;
				}
				else {
					title = 'Add Record'
				}
				if(formpanel.title) { title = formpanel.title; }
				var height = formpanel.height || 500;
				var width = formpanel.width || 700;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				
				win = new Ext.Window(Ext.apply({
					title: title,
					layout: 'fit',
					width: width,
					height: height,
					closable: true,
					modal: true,
					items: formpanel
				},plugin.add_form_window_cnf));
				
				return win.show();
			});
		};
		
		store.addRecordFormTab = function(initData) {
			var loadTarget = Ext.getCmp('main-load-target');
			
			// Fall back to Window if the load target can't be found for a Tab:
			if(!loadTarget) { return store.addRecordFormWindow(initData); }
			
			var newRec = store.prepareNewRecord(initData);
			
			var tab;
			var close_handler = function(btn) { loadTarget.remove(tab); };
			
			plugin.getAddFormPanel(newRec,close_handler,function(formpanel){

				var title, iconCls;
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
					title = plugin.store_button_cnf.add.text;
				}
				else {
					title = 'Add Record'
				}
				
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.iconCls) {
					iconCls = plugin.store_button_cnf.add.iconCls;
				}
				
				title = formpanel.title || title;
				iconCls = formpanel.iconCls || iconCls;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				delete formpanel.iconCls;
				
				tab = loadTarget.add({
					title: title,
					iconCls: iconCls,
					layout: 'fit',
					closable: true,
					items: formpanel
				});
				
				loadTarget.activate(tab);
			});
		};
		
		
		store.removeRecord = function(Record) {
			var ret = store.removeOrig(Record);
			if(plugin.persist_immediately.destroy) { store.saveIfPersist(); }
			return ret;
		};
		
		store.doTransactionIfPersist = function(action) {
			if(!plugin.persist_immediately[action]) { return; }
			return store.doTransactionOrig.apply(store,arguments);
		};
		
		store.saveIfPersist = function() {
			if(!store.doTransactionOrig) {
				store.doTransactionOrig = store.doTransaction;
			}
			store.doTransaction = store.doTransactionIfPersist;
			var ret = store.save.apply(store,arguments);
			store.doTransaction = store.doTransactionOrig;
			return ret;
		};
		
		store.addEvents('buttontoggle');
		store.fireButtonToggleEvent = function(){
			store.fireEvent('buttontoggle',store);
		}
		store.on('load',store.fireButtonToggleEvent,store);
		store.on('read',store.fireButtonToggleEvent,store);
		store.on('write',store.fireButtonToggleEvent,store);
		store.on('datachanged',store.fireButtonToggleEvent,store);
		store.on('clear',store.fireButtonToggleEvent,store);
		store.on('update',store.fireButtonToggleEvent,store);
		store.on('remove',store.fireButtonToggleEvent,store);
		store.on('add',store.fireButtonToggleEvent,store);
		
		store.addTrackedToggleFunc = function(func) {
			store.on('buttontoggle',func,store);
		};
		//store.on('buttontoggle',function(){ console.log('buttontoggle'); });
		
		store.buttonConstructor = function(cnf,showtext) {
			if(cnf.text && !cnf.tooltip) {
				cnf.tooltip = cnf.text;
				delete cnf.text;
			}
			
			if (showtext && !cnf.text) {
				cnf.text = cnf.tooltip;
				cnf.tooltip = null;
			}
			
			if (!showtext && cnf.text) {
				delete cnf.text;
			}
			
			return new Ext.Button(cnf);
		};
		
		store.allSaveCompleted = function() {
			var completed = true;
			store.eachTiedChild(function(s) {
				if(s.save_inprogress) { completed = false; }
			});
			return completed;
		};
		
		store.fireIfSaveAll = function() {
			if(store.allSaveCompleted()) { 
				store.fireEvent('saveall');
				var pstore = store.getParentStore();
				if(pstore) {
					pstore.fireIfSaveAll();
				}
			}
		};
		
		store.addEvents('saveall');
		store.on('beforesave',function() {
			store.save_inprogress = true; 
		});
		this.cmp.on('afterrender',function(){
			store.eachTiedChild(function(s) {
				s.on('save',function() {
					s.save_inprogress = false;
					store.fireIfSaveAll();
				});
			});
		});
		
		store.on('exception',store.undoChanges,store);
	},
	
	// Only applies to Editor Grids implementing the 'beforeedit' event
	beforeCellEdit: function(e) {
		var column = e.grid.getColumnModel().getColumnById(e.column);
		if(!column) { return; }
		
		// Adding a new record (phantom):
		if(e.record.phantom) {
			// Prevent editing if allow_add is set to false:
			if(typeof column.allow_add !== "undefined" && !column.allow_add) {
				e.cancel = true; //<-- redundant with return false but set for good measure
				return false;
			}
		}
		// Editing an existing record:
		else {
			// Prevent editing if allow_edit is set to false:
			if(typeof column.allow_edit !== "undefined" && !column.allow_edit) {
				e.cancel = true; //<-- redundant with return false but set for good measure
				return false;
			}
		}
		
	},
	
	getStoreButton: function(name,showtext) {
		
		if(this.exclude_btn_map[name]) { return; }
		
		if(!this.cmp.loadedStoreButtons[name]) {
			var constructor = this.getStoreButtonConstructors.call(this)[name];
			if(! constructor) { return; }
			
			var cnf = this.store_button_cnf[name] || {};
				
			if(cnf.text && !cnf.tooltip) { cnf.tooltip = cnf.text; }
			if(typeof cnf.showtext != "undefined") { showtext = cnf.showtext; }
			
			var btn = constructor(cnf,this.cmp,showtext);
			if(!btn) { return; }
			
			this.cmp.loadedStoreButtons[name] = btn;
		}

		return this.cmp.loadedStoreButtons[name];
	},
	
	getStoreButtonConstructors: function() {
		var plugin = this;
		return {
			add: function(cnf,cmp,showtext) {
				
				if(!cmp.store.api.create) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Add',
					iconCls: 'icon-add',
					handler: function(btn) {
						var store = cmp.store;
						if(store.proxy.getConnection().isLoading()) { return; }
						if(cmp.use_add_form) {
							store.addRecordForm();
						}
						else {
							store.addRecord();
						}
					}
				},cnf || {}),showtext);
					
				cmp.store.addTrackedToggleFunc(function(store) {
					if (store.addNotAllowed()) {
						btn.setDisabled(true);
					}
					else {
						btn.setDisabled(false);
					}
				});
					
				return btn;
			},
			
			'delete': function(cnf,cmp,showtext) {
				
				if(!cmp.store.api.destroy) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Delete',
					iconCls: 'icon-delete',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						if(store.proxy.getConnection().isLoading()) { return; }
						//store.remove(cmp.getSelectionModel().getSelections());
						store.removeRecord(cmp.getSelectedRecords());
						//store.saveIfPersist();
						//if(cmp.persist_immediately) { store.save(); }
					}
				},cnf || {}),showtext);
				
				cmp.on('afterrender',function() {
				
					var toggleBtn = function() {
						if (this.getSelectedRecords.call(this).length > 0) {
							btn.setDisabled(false);
						}
						else {
							btn.setDisabled(true);
						}
					};
					
					this.on('selectionchange',toggleBtn,this);
				},cmp);
					
				return btn;
			},
			
			reload: function(cnf,cmp,showtext) {
				
				return cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Reload',
					iconCls: 'x-tbar-loading',
					handler: function(btn) {
						var store = cmp.store;
						store.reloadAll();
					}
				},cnf || {}),showtext);
			},
			
			save: function(cnf,cmp,showtext) {

				if(cmp.persist_all_immediately) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Save',
					iconCls: 'icon-save',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						//store.save();
						store.saveAll();
					}
				},cnf || {}),showtext);

				cmp.cascade(function(){
					if(!this.store || !this.store.addTrackedToggleFunc){ return; }
					this.store.addTrackedToggleFunc(function(store) {
						if (cmp.store.hasAnyPendingChanges()) {
							btn.setDisabled(false);
						}
						else {
							btn.setDisabled(true);
						}
					});
				});
				
				return btn;
			},
			
			undo: function(cnf,cmp,showtext) {

				if(cmp.persist_all_immediately) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Undo',
					iconCls: 'icon-arrow-undo',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						//store.undoChanges.call(store);
						store.undoChangesAll.call(store);
					}
				},cnf || {}),showtext);
				
					
				cmp.cascade(function(){
					if(!this.store || !this.store.addTrackedToggleFunc){ return; }
					this.store.addTrackedToggleFunc(function(store) {
						if (cmp.store.hasAnyPendingChanges()) {
							btn.setDisabled(false);
						}
						else {
							btn.setDisabled(true);
						}
					});
				});
					
				/*
				cmp.store.addTrackedToggleFunc(function(store) {
					if (store.hasPendingChanges()) {
						btn.setDisabled(false);
					}
					else {
						btn.setDisabled(true);
					}
				});
				*/
					
				return btn;
			}
		};
	},
	
	insertStoreButtonsBbar: function() {
		var index = 0;
		var skip_reload = false;
		var bbar;

		if(Ext.isFunction(this.cmp.getBottomToolbar)) { 
			bbar = this.cmp.getBottomToolbar();
		}
		else if (Ext.isFunction(this.cmp.ownerCt.getBottomToolbar)) {
			bbar = this.cmp.ownerCt.getBottomToolbar();
		}
		
		if(!bbar) { return; }
		
		bbar.items.each(function(cmp,indx) {
			if(cmp.tooltip == 'Refresh') { 
				index = indx + 1; 
				skip_reload = true;
			};
		});
		
		//console.dir(bbar);
		
		var showtext = false;
		if(this.show_store_button_text) { showtext = true; }
		
		var bbar_items = [];
		Ext.each(this.store_buttons,function(btn_name) {
			// Skip redundant reload if we have a paging toolbar
			if(btn_name == 'reload' && skip_reload) { return; }
			
			var btn = this.getStoreButton(btn_name,showtext);
			if(!btn) { return; }
			bbar_items.unshift(btn);
		},this);
		Ext.each(bbar_items,function(btn) { bbar.insert(index,btn); },this);
		
	},
	
	insertStoreButtonsTbar: function() {
		var tbar;

		if(Ext.isFunction(this.cmp.getTopToolbar)) { 
			tbar = this.cmp.getTopToolbar();
		}
		else if (Ext.isFunction(this.cmp.ownerCt.getTopToolbar)) {
			tbar = this.cmp.ownerCt.getTopToolbar();
		}
		
		if(!tbar) { return; }
		
		var showtext = false;
		if(this.show_store_button_text) { showtext = true; }
		
		var tbar_items = [ '->' ]; //<-- right-align buttons
		Ext.each(this.store_buttons,function(btn_name) {
			var btn = this.getStoreButton(btn_name,showtext);
			if(!btn) { return; }
			tbar_items.unshift(btn);
		},this);
		Ext.each(tbar_items,function(btn) { tbar.insert(0,btn); },this);
		
	},
	
	beforeRemoveConfirm: function(c,component) {
		if(component != this.cmp) {
			var parent = this.cmp.findParentBy(function(p) {
				if(p.confirmRemoveInProg) { return false; }
				
				if(p == component) { return true; }
				// if we're here, it's a sibling removal:
				return false;
			},this);
			// This is a sibling removal, or our tied parent already handled the remove, which we need to ignore:
			if(component != parent) { return true; }
		}
		
		component.confirmRemoveInProg = true;
		
		var store = this.cmp.store;
		if(!store || !store.hasAnyPendingChanges()) { 
			c.un('beforeremove',this.beforeRemoveConfirm,this);
			return true; 
		}
		
		Ext.Msg.show({
			title: 'Save Changes?',
			msg: '<b>There are unsaved changes on this page.</b><br><br>Save before closing?<br>',
			icon: Ext.Msg.WARNING,
			buttons: { yes: 'Save', no: 'Discard Changes', cancel: 'Cancel' }, 
			fn: function(sel) {
				if (sel == 'cancel') {
					delete component.confirmRemoveInProg;
					return;
				}
				else if (sel == 'yes') {
					var onsave;
					onsave = function() {
						store.un('saveall',onsave);
						c.un('beforeremove',this.beforeRemoveConfirm,this);
						// Complete the original remove:
						c.remove(component);
					};
					store.on('saveall',onsave);
					store.saveAll();
				}
				else {
					store.undoChangesAll();
					c.un('beforeremove',this.beforeRemoveConfirm,this);
					// Complete the original remove:
					c.remove(component);
				};
			},
			scope: this
		});
		
		return false;
	},
	
	getAddFormPanel: function(newRec,close_handler,callback) {
		
		var plugin = this;
		var store = this.cmp.store;
		
		close_handler = close_handler || Ext.emptyFn;
		
		var cancel_handler = function(btn) {
			close_handler(btn);
		};
		
		var save_handler = function(btn) {
			var form = btn.ownerCt.ownerCt.getForm();
			
			// Use a copy of the new record in case the save fails and we need to try again:
			var newRecord = newRec.copy();
			newRecord.phantom = true; //<-- the copy doesn't have this set like the original... why?
			
			form.updateRecord(newRecord);
			store.add(newRecord);
			
			if(plugin.persist_immediately.create) {
				
				var after_write_fn = Ext.emptyFn;
				var remove_handler = Ext.emptyFn;
				
				remove_handler = function() { 
					store.un('write',after_write_fn);
					// Remove ourselves as we are also a single-use handler:
					store.un('exception',remove_handler);
				}
				
				after_write_fn = function(store,action) {
					if(action == 'create') {
						// Remove ourselves as we are a single-use handler:
						remove_handler();
						// close the add form only after successful create on the server:
						close_handler(btn);
					}
				}
				
				store.on('write',after_write_fn,store);
				
				// Also remove this single-use handler on exception:
				store.on('exception',remove_handler,store);
				
				store.saveIfPersist(); 
			}
			else {
				close_handler(btn);
			}
		};
		
		var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Loading Form..."});
		var show_mask = function() { myMask.show(); }
		var hide_mask = function() { myMask.hide(); }
		
		var params = {};
		if(store.lastOptions.params) { Ext.apply(params,store.lastOptions.params); }
		if(store.baseParams) { Ext.apply(params,store.baseParams); }
		if(plugin.cmp.baseParams) { Ext.apply(params,plugin.cmp.baseParams); }
		Ext.apply(params,plugin.add_form_url_params);
		
		show_mask();
		Ext.Ajax.request({
			url: plugin.cmp.add_form_url,
			params: params,
			failure: hide_mask,
			success: function(response,options) {
				
				var formpanel = Ext.decode(response.responseText);
				
				Ext.each(formpanel.items,function(field) {
					// Important: autoDestroy must be false on the store or else store-driven
					// components (i.e. combos) will be broken as soon as the form is closed 
					// the first time
					if(field.store) { field.store.autoDestroy = false; }
				},this);
				
				Ext.each(formpanel.buttons,function(button) {
					if(button.name == 'save') {
						button.handler = save_handler;
					}
					else if(button.name == 'cancel') {
						button.handler = cancel_handler;
					}
				},this);
				
				formpanel.Record = newRec;
				
				hide_mask();
				callback(formpanel);
			},
			scope: this
		});
	}
	// --- ^^ ---

});
Ext.preg('datastore-plus',Ext.ux.RapidApp.Plugin.CmpDataStorePlus);


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
		cls: 'icon-function-small',
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
		
		
		this.store.on('beforeload',function(store,options) {
			delete store.baseParams.column_summaries;
			delete store.lastOptions.params.column_summaries;
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
			this.menu = hmenu.add({
				hideOnClick: false,
				iconCls: 'icon-checkbox-no',
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
				//menu.setIconClass('icon-checkbox-yes');
				menu.setIconClass('icon-function');
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
			menu.setIconClass('icon-checkbox-no');
			field.setVisible(false);
			tfield.setVisible(false);
			tfield.setValue(null);
			return field.setValue(null);
		}
	},
	
	hdIcos: {},
	
	updateColumnHeadings: function () {
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
	
	maxColWidth: 1500,
	
	init: function(grid) {
		grid.on('render',this.onRender,grid);
		grid.maxColWidth = grid.maxColWidth || this.maxColWidth;
		
		Ext.apply(grid,{
			// ------- http://extjs.com/forum/showthread.php?p=97676#post97676
			autoSizeColumnsShallow: function() { 
				return this.autoSizeColumns(true); 
			},
			autoSizeColumns: function(shallow) {
				if (this.colModel) {

					this.colModel.suspendEvents();
					for (var i = 0; i < this.colModel.getColumnCount(); i++) {
						this.autoSizeColumn(i,shallow);
					}
					this.colModel.resumeEvents();
					this.view.refresh(true);
					this.store.removeListener('load',this.autoSizeColumns,this);

				}
			},
			autoSizeColumn: function(c,shallow) {
				var colid = this.colModel.getColumnId(c);
				var column = this.colModel.getColumnById(colid);
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

					if (this.MaxColWidth && w > this.MaxColWidth) { w =  this.MaxColWidth; }
					if (column.width && w < column.width) { w = column.width; }

					this.colModel.setColumnWidth(c, w);
					return w;
				}
			}
			// ------------------------
		});
	},
	
	onRender: function() {
		
		if(this.auto_autosize_columns) {
			this.store.on('load',this.autoSizeColumnsShallow,this); //<-- this only does headers, faster...
		}
		
		if(this.use_autosize_columns) {
			var menu = this.getOptionsMenu();
			if(!menu) { return; }
			menu.add({
				text: "AutoSize Columns",
				iconCls: 'icon-left-right',
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
			iconCls: 'icon-table-edit-row',
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
				iconCls: 'icon-table-sql-edit',
				hideOnClick: false,
				menu: [
					{
						itemId: 'all',
						text: 'All Active Records',
						iconCls: 'icon-table-edit-all',
						scope: this,
						handler: this.doBatchEditAll
					},
					{
						itemId: 'selected',
						text: 'Selected Records',
						iconCls: 'icon-table-edit-row',
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
		
		var win,fp;
		
		fp = new Ext.form.FormPanel({
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
					iconCls: 'icon-save',
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

						this.postUpdate(editSpec,data,win);
					}
				},
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						win.close();
					}
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
		
		win = new Ext.Window({
			title: title,
			layout: 'fit',
			width: 600,
			height: 500,
			minWidth: 475,
			minHeight: 350,
			closable: true,
			modal: true,
			items: fp
		});
		
		win.show();
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
					newEl = existBtn.insertSibling({ tag: 'div', style: 'float:right;' },'after');
					var relBtn = new Ext.Button({
						iconCls: 'icon-clock-run',
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


Ext.ux.RapidApp.Plugin.tabpanelCloseAllRightClick = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		this.cmp.on('contextmenu',this.onContextmenu,this);
	},

	onContextmenu: function(tp,tab,e) {
		
		if(tp.items.getCount() < 2){ return; }
		
		//stop browser menu:
		e.stopEvent();
		
		var menuItems = [{
			text: 'Close All Tabs',
			iconCls: 'icon-tool-close',
			scope: this,
			handler: this.closeAll
		},{
			text: 'Close All BUT This',
			iconCls: 'icon-tool-close',
			scope: this,
			handler: this.closeAll.createDelegate(this,[tab])
		}];

		var menu = new Ext.menu.Menu({ items: menuItems });
		var pos = e.getXY();
		pos[0] = pos[0] + 10;
		pos[1] = pos[1] + 5;
		menu.showAt(pos);
	},
	
	closeAll: function(keeptab) {
		var tabpanel = this.cmp;
		tabpanel.items.each(function(item) {
			if (item.closable && item != keeptab) {
				tabpanel.remove(item);
			}
		});
	}
});
Ext.preg('tabpanel-closeall',Ext.ux.RapidApp.Plugin.tabpanelCloseAllRightClick);


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



