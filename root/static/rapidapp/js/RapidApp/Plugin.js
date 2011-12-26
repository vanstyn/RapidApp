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
	,init:function(grid) {
		this.grid = grid;

		// setup toolbar container if id was given
		if('string' === typeof this.toolbarContainer) {
			this.toolbarContainer = Ext.getCmp(this.toolbarContainer);
		}

		// do our processing after grid render and reconfigure
		grid.onRender = grid.onRender.createSequence(this.onRender, this);
		grid.reconfigure = grid.reconfigure.createSequence(this.reconfigure, this);
	} // eo function init
	// }}}
	// {{{
	/**
	 * adds plugin controls to <b>existing</b> toolbar and calls reconfigure
	 * @private
	 */
	,onRender:function() {
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
				tb.addSeparator();
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
		if(this.field.getValue()) {
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
					fields.push(item.dataIndex);
				}
			});

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
		var columns = this.grid.initialConfig.columns;
		
		var group = undefined;
		if('radio' === this.menuStyle) {
			group = 'g' + (new Date).getTime();	
		}
		//Ext.each(cm.config, function(config) {
		Ext.each(columns, function(config) {
			var disable = false;
			if(config.header && config.dataIndex && !config.no_quick_search) {
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

	} // eo function reconfigure
	// }}}

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
			'autoload_added_record'
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

	},
	
	store_add_initData: {},
	close_unsaved_confirm: true,
	show_store_button_text: false,
	store_buttons: [ 'add', 'delete', 'reload', 'save', 'undo' ],
	store_button_cnf: {},
	store_exclude_buttons: [],
	exclude_btn_map: {},
	use_add_form: false,
	autoload_added_record: false,
		
	initAdditionalStoreMethods: function(store,plugin) {
		
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
			var ret = store.add(newRec);
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
			
			var formpanel = plugin.getAddFormPanel(newRec,close_handler);
			
			var title = 'Add Record';
			if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
				title = plugin.store_button_cnf.add.text;
			}
			win = new Ext.Window({
				title: title,
				layout: 'fit',
				width: 700,
				height: 500,
				closable: true,
				modal: true,
				items: formpanel
			});
			
			return win.show();
		};
		
		store.addRecordFormTab = function(initData) {
			var loadTarget = Ext.getCmp('main-load-target');
			
			// Fall back to Window if the load target can't be found for a Tab:
			if(!loadTarget) { return store.addRecordFormWindow(initData); }
			
			var newRec = store.prepareNewRecord(initData);
			
			var tab;
			var close_handler = function(btn) { loadTarget.remove(tab); };
			
			var formpanel = plugin.getAddFormPanel(newRec,close_handler);
			
			var title = 'Add Record';
			if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
				title = plugin.store_button_cnf.add.text;
			}
			tab = loadTarget.add({
				title: title,
				layout: 'fit',
				closable: true,
				items: formpanel
			});
			
			loadTarget.activate(tab);
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
	},
	
	// Only applies to Editor Grids implementing the 'beforeedit' event
	beforeCellEdit: function(e) {
		var column = e.grid.getColumnModel().getColumnById(e.column);
		
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
	
	// --- vv --- Code for an optional form for adding records
	addFormItems: null,
	getAddFormItems: function() {
		if(!Ext.isArray(this.addFormItems)) {

			var items = [];
			
			var column_list = this.cmp.initialConfig.columns;
			
			Ext.each(column_list,function(col){
				// If there is no editor then there is no field to display.
				// Because the backend automatically creates editors, we do *not*
				// setup a default editor. We trust/rely on the backend. If it
				// wanted us to have an editor, it would have provided one.
				if(!Ext.isObject(col.editor)) { return; }
				
				// Skip columns with 'no_column' set to true except if 'allow_add' is true:
				if(col.no_column && !col.allow_add) { return; }
				
				// Skip if allow_add is defined but set to false:
				if(typeof col.allow_add !== "undefined" && !col.allow_add) { return; }
			
				var field = Ext.apply({},col.editor);
					
				// Important: autoDestroy must be false on the store or else store-driven
				// components (i.e. combos) will be broken as soon as the form is closed 
				// the first time
				if(field.store) { field.store.autoDestroy = false; }

				field.name = col.name || col.dataIndex;
				field.fieldLabel = col.header || field.name;
				items.push(field);
			},this);

			this.addFormItems = items;
		}
		return this.addFormItems; 
	},
	getAddFormPanel: function(newRec,close_handler,cnf) {
	
		close_handler = close_handler || Ext.emptyFn;
		cnf = cnf || {};
		
		var store = this.cmp.store;
		var plugin = this;
		
		var save_handler = function(btn) {
			var form = btn.ownerCt.ownerCt.getForm();
			form.updateRecord(newRec);
			var ret = store.add(newRec);
			if(plugin.persist_immediately.create) { store.saveIfPersist(); }
			close_handler(btn);
		};
		
		var cancel_handler = function(btn) {
			close_handler(btn);
		};
		
		var formpanel = Ext.apply({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			labelWidth: 70,
			bodyStyle: 'padding: 25px 10px 5px 5px;',
			defaults: {
				xtype: 'textfield',
				width: 250
			},
			items: this.getAddFormItems(),
			plugins: ['dynamic-label-width'],
			autoScroll: true,
			//monitorValid: true,
			buttonAlign: 'center',
			minButtonWidth: 100,
			buttons: [
				{
					text: 'Save',
					iconCls: 'icon-save',
					handler: save_handler,
					//formBind: true
				},
				{
					text: 'Cancel',
					handler: cancel_handler
				}
			],
			listeners: {
				beforerender: function(){
					var form = this.getForm();
					form.loadRecord(newRec);
				}
			}
		},cnf);
		
		return formpanel;
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


Ext.ux.RapidApp.Plugin.tabpanelCloseAllBtn = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		this.cmp.on('render',this.onRender,this);
	},
	onRender:function() {
		
		
		//TODO!!!
		
		
		//var stripEl = this.cmp.header;
		
		//console.dir(stripEl);
		
	},
	closeAll: function() {
		var tabpanel = this.cmp;
		tabpanel.items.each(function(item) {
			if (item.closable) {
				tabpanel.remove(item);
			}
		});
	}
});
Ext.preg('tabpanel-closeall',Ext.ux.RapidApp.Plugin.tabpanelCloseAllBtn);

