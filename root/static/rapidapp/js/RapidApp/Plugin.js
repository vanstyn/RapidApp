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
		
		return this.uploadDialog();
		
	},
		/*
		var btn = this.getUploadBtn();
		var callback = function(form,res) {
			var attachment = Ext.decode(res.response.responseText);
			if(! attachment.mime_type == 'image') {
				Ext.Msg.alert('Not an image',
					attachment.filename + ' is not an image<br><br>' +
					'(Detected Content-Type: "' + attachment.mime_type + '/' + attachment.mime_subtype + ')'
				);
			}
			else {
				this.insertImage(attachment);
			}
		}
		
		var cur_fieldset = Ext.decode(Ext.encode(btn.winform_cnf.fieldset));
		cur_fieldset.items[0].emptyText = 'Select image';
		cur_fieldset.items[0].fieldLabel = 'Select Image';
		cur_fieldset.labelWidth = 80;
		
		var cnfOverride = {
			success_callbacks: [ { scope: this, handler: callback } ],
			title: 'Insert Image',
			fieldset: cur_fieldset,
			width: 440
		};
		
		btn.handler(btn,cnfOverride);
	},
	
	getUploadBtn: function(cmp) {
	
		if(!cmp) { cmp = this.cmp; }
		if (cmp.upload_btn) { return cmp.upload_btn; }
		
		// vv --- UGLY TEMPORARY HACK! :
		var assembly_page = cmp.ownerCt.ownerCt;
		if(!assembly_page.components) {
			assembly_page = cmp.ownerCt.ownerCt.ownerCt;
		}
		var attachments_grid = assembly_page.components[0][1];
		// ^^ ---
		
		var upload_btn = attachments_grid.getBottomToolbar().getComponent('upload-btn');
		
		return upload_btn;
	},
	*/
	
	uploadDialog: function() {
		
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
		
		Ext.ux.RapidApp.WinFormPost.call(this,{
			title: 'Insert Image',
			width: 430,
			height:140,
			url:'/simplecas/upload_image',
			useSubmit: true,
			fileUpload: true,
			fieldset: fieldset,
			success: function(file, server_data, result) {
			
				console.dir(arguments);
			},
			failure: function(file, server_data) {
			
				console.dir(arguments);
			}
			
			
			
		
		});
	
	
	},
	
	insertImage: function(attachment) {
		
		return;
		this.cmp.insertAtCursor(
			'<img ' +
				'src="' + attachment.link_url + '" ' +
				'width=' + attachment.width + ' ' +
				'height=' + attachment.height + ' ' +
				'title="' + attachment.filename + '" ' +
				'alt="' + attachment.filename + '"' +
			'>'
		);
	}

});





