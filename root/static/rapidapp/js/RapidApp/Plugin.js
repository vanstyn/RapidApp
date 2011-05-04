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
Ext.ux.RapidApp.Plugin.Combo.AppSuperBox = Ext.extend(Ext.util.Observable, {
	constructor: function(cnf) { 	Ext.apply(this,cnf); 	},
	
	createItemClass: 'create-item',
	createItemHandler: null,
	
	init: function(cmp){
		this.cmp = cmp;
		
		Ext.apply(this.cmp,{
			xtype: 'superboxselect' // <-- no effect, the xtype should be set to this in the consuming class
		});
		
		if (this.createItemHandler) {
			this.initCreateItems();
		}
	},
		
	initCreateItems: function() {
		var plugin = this;
		this.cmp.onViewClick = function() {
			var event = arguments[arguments.length - 1]; // <-- last passed argument, the event object;
			var target = event.getTarget(null,null,true);
			
			// Handle create item instead of normal handler:
			if (target.hasClass(plugin.createItemClass)) {
				this.collapse();
				return plugin.createItemHandler.call(this,plugin.createItemCallback);
			}

			// Original handler:
			this.constructor.prototype.onViewClick.apply(this,arguments);
		};
		
	},
	
	createItemCallback: function(data) {
		var Store = this.getStore();
		var recMaker = Ext.data.Record.create(Store.fields.items);
		var newRec = new recMaker(data);
		Store.insert(0,newRec);
		this.addRecord(newRec);
	}
	
});
Ext.preg('appsuperbox',Ext.ux.RapidApp.Plugin.Combo.AppSuperBox);


