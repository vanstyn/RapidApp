Ext.Updater.defaults.disableCaching = true;
Ext.Ajax.timeout = 120000; // 2 minute timeout (default is 30 seconds)

Ext.ns('Ext.log');
Ext.log = function() {};






Ext.ns('Ext.ux.form.FormConnectorField');
Ext.ux.form.FormConnectorField = Ext.extend(Ext.form.Hidden, {

	/**
	* @cfg {String} connectFormId Id of the Ext.form.FormPanel component this field should link to.
	*/
	connectFormId: null,

	/**
	* @cfg {Function} serializer Function to use to encode form field values into the returned field
	* value of this field. Defaults to Ext.encode
	*/
	serializer: Ext.encode,

	deserializer: Ext.decode,

	getConnectedFormHandler: function() {
		return Ext.getCmp(this.connectFormId).getForm();
	},

	getConnectedForm: function() {
		if(!this.connectedForm) {
			this.connectedForm = this.getConnectedFormHandler();
		}
		return this.connectedForm;
	},

	getValue: function() {
		var data = this.getConnectedForm().getFieldValues();
		return this.serializer(data);
	},

	getRawValue: function() {
		return this.getValue();
	},

	setValue: function(val) {
		var data = this.deserializer(val);
		this.getConnectedForm().setValues(data);
	}
});





// --------
// http://www.sencha.com/forum/showthread.php?33475-Tip-Long-menu-overflow/page2
Ext.override(Ext.menu.Menu, {
    // See http://extjs.com/forum/showthread.php?t=33475&page=2
    showAt : function(xy, parentMenu, /* private: */_e) {
        this.parentMenu = parentMenu;
        if (!this.el) {
            this.render();
        }
        if (_e !== false) {
            this.fireEvent("beforeshow", this);
            xy = this.el.adjustForConstraints(xy);
        }
        this.el.setXY(xy);

        // Start of extra logic to what is in Ext source code...
        // See http://www.extjs.com/deploy/ext/docs/output/Menu.jss.html
        // get max height from body height minus y cordinate from this.el
        var maxHeight = Ext.getBody().getHeight() - xy[1];
        if (this.el.getHeight() > maxHeight) {
            // set element with max height and apply vertical scrollbar
            this.el.setHeight(maxHeight);
            this.el.applyStyles('overflow-y: auto;');
        }
        // .. end of extra logic to what is in Ext source code

        this.el.show();
        this.hidden = false;
        this.focus();
        this.fireEvent("show", this);
    }
});
// --------


// Mouse-over/hover fix:
// http://www.sencha.com/forum/showthread.php?69090-Ext.ux.form.SuperBoxSelect-as-seen-on-facebook-and-hotmail&p=515731#post515731
Ext.override(Ext.ux.form.SuperBoxSelectItem, {
	enableElListeners : function() {
		this.el.on('click', this.onElClick, this, {stopEvent:true});
		//this.el.addClassOnOver('x-superboxselect-item x-superboxselect-item-hover');
		this.el.addClassOnOver('x-superboxselect-item-hover');
	}
});


// Override to get rid of the input cursor if editable is false
Ext.override(Ext.ux.form.SuperBoxSelect,{
	initComponent_orig: Ext.ux.form.SuperBoxSelect.prototype.initComponent,
	initComponent: function () {
		this.initComponent_orig.apply(this,arguments);
		this.on('afterrender',function(combo) {
			if(combo.editable === false && combo.hideInput === true) {
				combo.inputEl.removeClass("x-superboxselect-input");
				combo.inputEl.setVisible(false);
			}
		});
	}
});


Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.errMsgHandler = function(title,msg) {
	Ext.Msg.alert(title,Ext.util.Format.nl2br(msg));
}

Ext.ux.RapidApp.ajaxCheckException = function(conn,response,options) {
	try {
		var exception = response.getResponseHeader('X-RapidApp-Exception');
		if (exception) {
			var res = Ext.decode(response.responseText);
			if (res) {
				var title = res.title || 'Error';
				var msg = res.msg || 'unknown error - Ext.ux.RapidApp.ajaxCheckException';
				Ext.ux.RapidApp.errMsgHandler(title,msg);
			}
		}
		else {
			var warning = response.getResponseHeader('X-RapidApp-Warning');
			if (warning) {
				var data = Ext.decode(warning);
				var title = data.title || 'Warning';
				var msg = data.msg || 'Unknown (X-RapidApp-Warning)';
				Ext.ux.RapidApp.errMsgHandler(title,msg);
			}
		}
	}
	catch(err) {}
}

Ext.ux.RapidApp.ajaxRequestContentType = function(conn,options) {
	if (!options.headers) { options.headers= {}; }
	options.headers['X-RapidApp-RequestContentType']= 'JSON';
};

Ext.Ajax.on('requestcomplete',Ext.ux.RapidApp.ajaxCheckException);
Ext.Ajax.on('requestexception',Ext.ux.RapidApp.ajaxCheckException);
Ext.Ajax.on('beforerequest',Ext.ux.RapidApp.ajaxRequestContentType);


Ext.override(Ext.data.Connection,{

	handleResponse_orig: Ext.data.Connection.prototype.handleResponse,
	handleResponse : function(response){

		var call_orig = true;
		var options = response.argument.options;

		var thisConn = this;
		var success_callback_repeat = function(params) {
			
			// Optional changes/additions to the original request params:
			if(params) { Ext.apply(options.params,params); }
			
			call_orig = false;
			thisConn.request(options);
		};

		var auth = response.getResponseHeader('X-RapidApp-Authenticated');
		if (auth) {
			Ext.ns('Ext.ux.RapidApp');
			var orig = Ext.ux.RapidApp.Authenticated;
			if (auth != '0') { Ext.ux.RapidApp.Authenticated = auth; }
			if (orig && orig != auth && auth == '0') {
				call_orig = false;
				Ext.ux.RapidApp.ReAuthPrompt(success_callback_repeat);
			}
		}
		
		var customprompt = response.getResponseHeader('X-RapidApp-CustomPrompt');
		if (customprompt) {
			call_orig = false;
			Ext.ux.RapidApp.handleCustomPrompt(customprompt,success_callback_repeat);
		}

		if(response.getResponseHeader('X-RapidApp-Exception')) return;

		if(call_orig) {
			this.handleResponse_orig.apply(this,arguments);
		}
	}
});



Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.handleCustomPrompt = function(headerdata,success_callback) {

	// Defaults
	var data = {
		title: 'Untitled X-RapidApp-CustomPrompt',
		param_name: 'customprompt',
		height: 300,
		width: 400,
		buttons: ['Ok'],
		buttonIcons: {},
		items: [
			{
				xtype: 'label',
				html: 'No data available'
			}
		]
	};
	
	Ext.apply(data,Ext.decode(headerdata));
	
	var btn_handler = function(btn) {
	
		var customprompt = { button: btn.text };
		var formpanel = win.getComponent('formpanel');
		var form = formpanel.getForm();
		customprompt.data = form.getFieldValues();
		
		// Recall the original request, adding in the customprompt data:
		var newopts = {};
		newopts[data.param_name] = Ext.encode(customprompt);
		btn.ownerCt.ownerCt.close();
		return formpanel.success_callback(newopts);
	}
	
	// Custom buttons:
	var buttons = [];
	Ext.each(data.buttons,function(text) {
		var btn = {
			xtype: 'button',
			text: text,
			handler: btn_handler
		}
		
		if(data.buttonIcons[text]) {
			btn.iconCls = data.buttonIcons[text];
		}
		
		buttons.push(btn);
	});
	
	// Cancel:
	buttons.push({
		xtype: 'button',
		text: 'Cancel',
		handler: function(btn) {
			btn.ownerCt.ownerCt.close();
		}
	});
	
	var formpanel = {
		xtype: 'form',
		itemId: 'formpanel',
		frame: true,
		labelAlign: 'right',
		anchor: '100% 100%',
		items: data.items,
		success_callback: success_callback // <-- storing this here so we can use it in the btn handler
	};

	var win = new Ext.Window({
		title: data.title,
		layout: 'anchor',
		width: data.width,
		height: data.height,
		closable: true,
		modal: true,
		autoScroll: true,
		items: formpanel,
		buttons: buttons
	});

	win.show();
};




//This is currently set by RapidApp::AppAuth:
Ext.ux.RapidApp.loginUrl = '/main/banner/auth/login';

Ext.ux.RapidApp.ReAuthPrompt = function(success_callback) {

	 var fieldset = {
		xtype: 'fieldset',
		style: 'border: none',
		hideBorders: true,
		labelWidth: 80,
		border: false,
		defaults: {
			xtype: 'textfield',
			labelStyle: 'text-align:right'
		},
		items: [
			{
				 xtype: 'label',
				 text: 'Your session has expired or is invalid. Please re-enter your password below:'
			},
			{
				 xtype: 'spacer',
				 height: 15
			},
			{
				name: 'username',
				fieldLabel: 'username',
				value: Ext.ux.RapidApp.Authenticated,
				readOnly: true,
				style: {
					/*
						the normal text field has padding-top: 2px which makes the text sit towards
						the bottom of the field. We set top and bottom here to move one of the px to the
						bottom so the text will be vertically centered but take up the same vertical
						size as a normal text field:
					*/
					'background-color': 'transparent',
					'border-color': 'transparent',
					'background-image':'none',
					'padding-top':'1px',
					'padding-bottom':'1px'
				}
			},
			{
				name: 'password',
				fieldLabel: 'password',
				inputType: 'password',
				listeners: {
					afterrender: function(field) {
						field.focus('',10);
						field.focus('',200);
						field.focus('',500);
					}
				 }
			}
		]
	};

	Ext.ux.RapidApp.WinFormPost({
		title: "Session Expired",
		height: 200,
		width: 300,
		url: Ext.ux.RapidApp.loginUrl,
		fieldset: fieldset,
		closable: false,
		submitBtnText: 'Login',
		success: function(response,opts) {
			//var res = Ext.decode(response.responseText);
			//if (res.success == 0) {
			//	Ext.ux.RapidApp.ReAuthPrompt();
			//}
			if(success_callback) return success_callback();
		},
		failure: function() {
			 Ext.ux.RapidApp.ReAuthPrompt();
		},
		cancelHandler: function() {
			window.location.reload();
		}
	});
}



Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.validateCsvEmailStr = function(v) {
	var str = new String(v);
	var arr = str.split(',');

	for (i in arr) {
		var email = arr[i];
		// For some stupid reason the last arg returned from split is a function! So we have to do this:
		if(typeof(email) == 'string') {
			var trimmed = Ext.util.Format.trim(email);
			var result = Ext.form.VTypes.email(trimmed);
			if(! result) return false;
		}
	}

	return true;
}



Ext.ux.RapidApp.CustomPickerField = Ext.extend(Ext.form.TriggerField, {


	initComponent: function() {
		this.setEditable(false);

		var config = {
			win_title: this.win_title,
			win_height: this.win_height,
			win_width: this.win_width,
			load_url: this.load_url,
			select_handler: this.select_handler
		};
		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.RapidApp.CustomPickerField.superclass.initComponent.apply(this, arguments);
		//}
	},

	//setEditable: false,

	getValue: function() {
		return this.dataValue;
	},

	setValue: function(val) {
		var new_val = val;
		if(this.setValue_translator) {
			new_val = this.setValue_translator(val,this);
		}
		Ext.ux.RapidApp.CustomPickerField.superclass.setValue.call(this, new_val);
	},

	onTriggerClick: function() {

		var thisTF = this;

		var autoLoad = {
			url: this.load_url
		};

		if (this.dataValue) {
			autoLoad.params = {
				node: this.dataValue
			};
		}

		var win = new Ext.Window({
			title: this.win_title,
			layout: 'fit',
			width: this.win_width,
			height: this.win_height,
			closable: true,
			modal: true,
			items: {
				xtype: 'autopanel',
				itemId: 'app',
				autoLoad: autoLoad,
				layout: 'fit'
			},
			buttons: [
				{
					text: 'Select',
					handler: function(btn) {
						var app = btn.ownerCt.ownerCt.getComponent('app').items.first();

						var data = thisTF.select_handler(app);

						thisTF.dataValue = data.value;

						thisTF.setValue(data.display);
						btn.ownerCt.ownerCt.close();


						//console.dir(data);


					}

				},
				{
					text: 'Cancel',
					handler: function(btn) {
						btn.ownerCt.ownerCt.close();

					}

				}


			]
		});

		win.show();
	}


});
Ext.reg('custompickerfield',Ext.ux.RapidApp.CustomPickerField);



Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.confirmDialogCall = function(title,msg,fn,params) {

	var args = Array.prototype.slice.call(arguments);

	var title = args.shift();
	var msg = args.shift();
	var fn = args.shift();

	return Ext.Msg.show({
		title: title,
		msg: msg,
		buttons: Ext.Msg.YESNO, fn: function(sel) {
			if (sel != 'yes') return;
			fn(args);
		},
		scope: this
	});
}



/* http://mentaljetsam.wordpress.com/2008/06/02/using-javascript-to-post-data-between-pages/ */
Ext.ns('Ext.ux.postwith');
Ext.ux.postwith = function (to,p) {
	var myForm = document.createElement("form");
	myForm.method="post" ;
	myForm.action = to ;
	for (var k in p) {
		var myInput = document.createElement("input") ;
		myInput.setAttribute("name", k) ;
		myInput.setAttribute("value", p[k]);
		myForm.appendChild(myInput) ;
	}
	document.body.appendChild(myForm) ;
	myForm.submit() ;
	document.body.removeChild(myForm) ;
}



Ext.ns('Ext.ux.iconFromFileName');
Ext.ux.iconFromFileName = function(name) {

	 var parts = name.split('.');
	 var ext = parts.pop().toLowerCase();

	 var icon_file = 'document.png';

	 if(ext == 'pdf') { icon_file = 'page_white_acrobat.png'; }
	 if(ext == 'zip') { icon_file = 'page_white_compressed.png'; }
	 if(ext == 'xls') { icon_file = 'page_white_excel.png'; }
	 if(ext == 'xlsx') { icon_file = 'page_excel.png'; }
	 if(ext == 'ppt') { icon_file = 'page_white_powerpoint.png'; }
	 if(ext == 'txt') { icon_file = 'page_white_text.png'; }
	 if(ext == 'doc') { icon_file = 'page_white_word.png'; }
	 if(ext == 'docx') { icon_file = 'page_word.png'; }
	 if(ext == 'iso') { icon_file = 'page_white_cd.png'; }

	 return icon_file;
}



Ext.ns('Ext.ux.Bool2yesno');
Ext.ux.Bool2yesno = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	if (val > 0) { return 'Yes'; }
	return 'No';
}


Ext.ns('Ext.ux.showNull');
Ext.ux.showNull = function(val) {
	if (val == null) { return '<span style="color:darkgrey;">(not set)</span>'; }
	if (val === "") { return '<span style="color:darkgrey;">(empty string)</span>'; }
	return val;
}

Ext.ns('Ext.ux.showNullusMoney');
Ext.ux.showNullusMoney = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	return Ext.util.Format.usMoney(val);
}


/*
Ext.ux.RapidApp.WinFormPost

 * @cfg {String} title Window title
 * @cfg {String} height Window height
 * @cfg {String} width Window width
 * @cfg {Object} fieldset form config
 * @cfg {String} url URL to post to
 * @cfg {Object} params base params to submit with
 * @cfg {Boolean} encode_values true to encode the form data in JSON
 * @cfg {Object} valuesParamName POST param to store JSON serialized form data in
 * @cfg {Function} success success callback function
 * @cfg {Function} failure failure callback function
 * @cfg {Boolean} eval_response if true the response will be evaled

*/
Ext.ns('Ext.ux.RapidApp.WinFormPost');
Ext.ux.RapidApp.WinFormPost = function(cfg) {

	var rand = Math.floor(Math.random()*100000);
	var winId = 'win-' + rand;
	var formId = 'winformpost-' + rand;

	if(! cfg.title)						{ cfg.title = ''; 						}
	if(! cfg.height)						{ cfg.height = 400; 						}
	if(! cfg.width)						{ cfg.width = 350; 						}
	if(! cfg.params)						{ cfg.params = {};					}
	if(! cfg.valuesParamName)			{ cfg.valuesParamName = 'json_form_data';		}
	if(! cfg.submitBtnText)			{ cfg.submitBtnText = 'Save';		}
	if(! cfg.cancelHandler)			{ cfg.cancelHandler = function(){ Ext.getCmp(winId).close(); }	}
	if(! typeof(cfg.closable))		{ cfg.closable = true;	}

	cfg.fieldset['anchor'] = '100% 100%';


	var success_fn = function(response,options) {
		Ext.getCmp(winId).close();
		// Call the success function if it was passed in the cfg:
		if (cfg.success) { cfg.success.apply(this,arguments); }
		if (cfg.eval_response && response.responseText) { return eval(response.responseText); }
	};

	var failure_fn = function(response,options) {

		if (cfg.failure) { cfg.failure.apply(this,arguments); }
	};

	var win = new Ext.Window({
		title: cfg.title,
		id: winId,
		layout: 'fit',
		width: cfg.width,
		height: cfg.height,
		closable: cfg.closable,
		modal: true,
		items: {
			xtype: 'form',
			anchor : cfg.fieldset['anchor'],
			id: formId,
			frame: true,
			items: cfg.fieldset,
			fileUpload: cfg.fileUpload,
			baseParams: cfg.baseParams,
			buttons: [
				{
					text	: cfg.submitBtnText,
					handler	: function(btn) {
						var form = Ext.getCmp(formId).getForm();

						if (cfg.useSubmit) {
							return form.submit({
								url: cfg.url,
								params: cfg.params,
								success: success_fn,
								failure: failure_fn
							});
						}
						else {

							var values;
							if (cfg.noRaw) {
								values = form.getFieldValues();
							}
							else {
								values = form.getValues();
							}

							var params = cfg.params;
							if (cfg.encode_values) {
								params[cfg.valuesParamName] = Ext.util.JSON.encode(values);
							}
							else {
								for (i in values) {
									if(!params[i]) { params[i] = values[i]; }
								}
							}

							return Ext.Ajax.request({
								url: cfg.url,
								params: params,
								success: success_fn,
								failure: failure_fn
							});
						}
					}
				},
				{
					text		: 'Cancel',
					handler	: cfg.cancelHandler
				}
			],
			listeners: {
				afterrender: function(fp) {
					new Ext.KeyMap(fp.el, {
						key: Ext.EventObject.ENTER,
						shift: false,
						alt: false,
						fn: function(keyCode, e){
								if(e.target.type === 'textarea' && !e.ctrlKey) {
									return true;
								}
								this.el.select('button').item(0).dom.click();
								return false;
						},
						scope: this
					});
				}
			}
		}
	});
	win.show();
}





Ext.ns('Ext.ux.EditRecordField');
Ext.ux.EditRecordField = function(config) {

	var rand = Math.floor(Math.random()*100000);
	var winId = 'win-' + rand;
	var formId = 'editrec-' + rand;
	var minFieldWidth = 175;

	var win_init_w = 200;
	var win_init_h = 100;

	var field = {
		xtype		: 'textfield',
		hideLabel	: true
	};

	if (config.fieldType) { field['xtype'] = config.fieldType; }

	if (config.field_cnf) { //<-- field_cnf override
		field = config.field_cnf;

		// -----------------
		if (field['xtype'] == 'fieldset') { return Ext.ux.EditRecordFieldSet(config.Record,field); }
		// -----------------

		if (field['width']) {
			win_init_w = field['width'] + 100;
			delete field['width'];
		}
	}

	field['value'] = config.Record.data[config.fieldName];
	field['save_field_name'] = config.fieldName;
	if (config.save_field_name) { field['save_field_name'] = config.save_field_name; }

	if (config.fieldType && !field['xtype']) { field['xtype'] = config.fieldType; }
	if (config.fieldName && !field['name']) { field['name'] = config.fieldName; }
	if (config.monitorValid && !field['monitorValid']) { field['monitorValid'] = config.monitorValid; }

	if (!field['id']) { field['id'] = 'field-' + rand; }

	//field['value'] = record_val;
	//if (config.initValue) { field['value'] = config.initValue; } //<-- this is needed for certain combo fields

	field['anchor'] = '100%';
	if (field['xtype'] == 'textarea') {
		field['anchor'] = '100% 100%';
	}

	var win = new Ext.Window({
		id: winId,
		width: win_init_w,
		height: win_init_h,
		layout: 'fit',
		title: config.fieldLabel + ':',
		modal: true,
		items: {
			xtype: 'form',
			anchor : field['anchor'],
			id: formId,
			frame: true,
			items: field,
			buttons: [
				{
					text		: 'Save',
					handler	: function() {
						var oField = Ext.getCmp(field['id']);
						var cur_val = oField.getValue();
						config.Record.set(field['save_field_name'],cur_val);
						config.Record.store.save();
						Ext.getCmp(winId).close();
					}
				},
				{
					text		: 'Cancel',
					handler	: function() {
						Ext.getCmp(winId).close();
					}
				}
			]
		},
		listeners: {
			afterrender: function(win) {
				var oField = Ext.getCmp(field['id']);
				if (!config.field_cnf) { //<-- don't run text metrics if there is a cust field_cnf

					var TM = Ext.util.TextMetrics.createInstance(oField.el);
					var wid;
					if (oField.getXType() == 'textarea') {
						wid = 400;
						TM.setFixedWidth(wid);
						var hig = TM.getHeight(field['value']) + 20;
						if (hig < 300) { hig = 300; }
						if (hig > 600) { hig = 600; }

						win.setHeight(hig);
					}
					else {
						wid = TM.getWidth(field['value']) + 50;
					}

					if (wid > 500) { wid = 500; }

					if (wid > minFieldWidth) {
						win.setWidth(wid);
					}
				}
			}
		}
	});
	win.show();
}



Ext.ns('Ext.ux.EditRecordFieldSet');
Ext.ux.EditRecordFieldSet = function(Record,fieldset) {

	var rand = Math.floor(Math.random()*100000);
	var winId = 'win-' + rand;
	var formId = 'editrec-' + rand;
	var minFieldWidth = 175;

	var win_init_w = 550;
	var win_init_h = 200;

	for (i in fieldset.items) {
		fieldset.items[i]['value'] = Record.data[fieldset.items[i]['name']];
		if (!fieldset.items[i]['save_field_name']) { fieldset.items[i]['save_field_name'] = fieldset.items[i]['name']; }
		if (!fieldset.items[i]['id']) { fieldset.items[i]['id'] = 'field-' + i + '-' + rand; }
	}

	fieldset['anchor'] = '100% 100%';

	var win = new Ext.Window({
		id: winId,
		width: win_init_w,
		height: win_init_h,
		layout: 'fit',
		//title: 'FIELDSET ' + fieldset.fieldLabel + ':',
		modal: true,
		items: {
			xtype: 'form',
			anchor : fieldset['anchor'],
			id: formId,
			frame: true,
			items: fieldset,
			buttons: [
				{
					text	: 'Save',
					handler	: function() {

						for (i in fieldset.items) {

							var oField = Ext.getCmp(fieldset.items[i]['id']);
							if (oField) {
								try {
									var cur_val = oField.getValue();
									if (cur_val != fieldset.items[i]['value']) {
										Record.set(fieldset.items[i]['save_field_name'],cur_val);
									}
								} catch (err) {}
							}

						}

						Record.store.save();
						Ext.getCmp(winId).close();
					}
				},
				{
					text		: 'Cancel',
					handler	: function() {
						Ext.getCmp(winId).close();
					}
				}
			]
		}
	});
	win.show();
}






Ext.ns('Ext.ux.Msg.EditRecordField');
Ext.ux.Msg.EditRecordField = function(config) {

	var msgCnf = {
		prompt: true,
		title: config.fieldLabel + ':',
		//msg: config.fieldLabel + ':',
		buttons: Ext.MessageBox.OKCANCEL,
		fn: function(btn,text) {
			if (btn == 'ok') {
				config.Record.set(config.fieldName,text);
				config.Record.store.save();
			}
		},
		value: config.Record.data[config.fieldName],
		width: 250
	}

	if (config.fieldType == 'textarea') {
		msgCnf['width'] = 350;
		msgCnf['multiline'] = 200;
	}

	Ext.Msg.show(msgCnf);
}




Ext.override(Ext.Container, {
	onRender: function() {
		Ext.Container.superclass.onRender.apply(this, arguments);
		if (this.onRender_eval) { eval(this.onRender_eval); }
	}
});




Ext.override(Ext.BoxComponent, {
	initComponent: function() {


		// All-purpose override allowing eval code in config
		var thisB = this;
		if (thisB.afterRender_eval) { this.on('afterrender', function() { eval(thisB.afterRender_eval); }) }
		var config = this;
		if (this.init_evalOverrides) {
			for ( var i in this.init_evalOverrides ) {
				config[i] = eval(this.init_evalOverrides[i]);
			}
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		}
		Ext.BoxComponent.superclass.initComponent.apply(this, arguments);
	}
	//,afterRender: function() {
		//this.superclass.afterRender.call(this);
	//	if (this.afterRender_eval) { eval(this.afterRender_eval); }

	//}
});




Ext.ns('Ext.ux.FindNodebyId');
Ext.ux.FindNodebyId = function(node,id) {
	this.node = node;
	this.id = id;

	alert(this.node.id);
	if (this.node.id == this.id) { return this.node; }
	//if (this.node.isLeaf()) { return false; }

	if (this.node.childNodes) {
		for ( var i in this.node.childNodes ) {
			var child = this.node.childNodes[i];
			var checknode = Ext.ux.FindNodebyId(child,this.id);
			if (checknode) { return checknode; }
		}
	}
	return false;
}


Ext.ns('Ext.ux.FetchEval');
Ext.ux.FetchEval = function(url,params) {
	if (!params) { params = {}; }
	Ext.Ajax.request({
		disableCaching: true,
		url: url,
		params: params,
		success: function(response, opts) {
			if(response.responseText) { return eval(response.responseText); }
		},
		failure: function(response, opts) {
			alert('Ext.ux.FetchEval (' + url + ') AJAX request failed.' );
		}
	});
}



// ------- http://extjs.com/forum/showthread.php?p=97676#post97676
Ext.override(Ext.CompositeElementLite, {
	 getTextWidth: function() {
		  var i, e, els = this.elements, result = 0;
		  for(i = 0; e = Ext.get(els[i]); i++) {
				result = Math.max(result, e.getTextWidth.apply(e, arguments));
		  }
		  return result;
	 }
});
// -------


/* This is crap since 'anchor' exists
Ext.override(Ext.form.FormPanel, {
	plugins: [new Ext.ux.form.FieldAutoExpand()]
});
*/

/*
Ext.override(Ext.BoxComponent, {
	initComponent: function() {

		var thisC = this;
		if (thisC.autoLoadJsonConf) {


			Ext.Ajax.request({
				disableCaching: true,
				url: thisC.autoLoadJsonConf['url'],
				params: thisC.autoLoadJsonConf['params'],
				success: function(response, opts) {

					alert(response.responseText);

					var imported_data = Ext.util.JSON.decode(response.responseText);
					//var imported_data = eval('(' + response.responseText + ')');
					Ext.apply(this, Ext.apply(this.initialConfig, imported_data));
				},
				failure: function(response, opts) {
					alert('AJAX autoLoadJsonConf FAILED!!!!!!');
				}
			});
		}
		Ext.BoxComponent.superclass.initComponent.apply(this, arguments);
	}
});



Ext.override(Ext.BoxComponent, {
	initComponent: function() {

		var thisC = this;

		if (Ext.isArray(this.items)) {
			for (i in this.items) {
				if(this.items[i]['autoLoadJsonConf']) {
					var urlspec = this.items[i]['autoLoadJsonConf'];

					Ext.Ajax.request({
						disableCaching: true,
						url: urlspec['url'],
						params: urlspec['params'],
						success: function(response, opts) {

							alert(response.responseText);

							var imported_data = eval('(' + response.responseText + ')');
							thisC.insert(i,imported_data);
							thisC.doLayout();

							Ext.apply(this, Ext.apply(this.initialConfig, imported_data));
						},
						failure: function(response, opts) {
							alert('AJAX autoLoadJsonConf FAILED!!!!!!');
						}
					});

					delete this.items[i];


				}
			}
		}







		var thisC = this;
		if (thisC.autoLoadJsonConf) {


			Ext.Ajax.request({
				disableCaching: true,
				url: thisC.autoLoadJsonConf['url'],
				params: thisC.autoLoadJsonConf['params'],
				success: function(response, opts) {

					alert(response.responseText);

					var imported_data = Ext.util.JSON.decode(response.responseText);
					//var imported_data = eval('(' + response.responseText + ')');
					Ext.apply(this, Ext.apply(this.initialConfig, imported_data));
				},
				failure: function(response, opts) {
					alert('AJAX autoLoadJsonConf FAILED!!!!!!');
				}
			});
		}
		Ext.BoxComponent.superclass.initComponent.apply(this, arguments);
	}
});

*/


Ext.ux.DynContainer = Ext.extend(Ext.Container, {

	initComponent: function() {

		var id = this.id;
		var imported_data;
		var thisC = this;
		//if (thisC.itemsurl) {
		var config = {
			loadData: function(loadurl,params) {

				//alert('Loading: ' + loadurl);

				Ext.Ajax.request({
					disableCaching: true,
					//url: thisC.itemsurl,
					url: loadurl,
					params: params,
					success: function(response, opts) {

						imported_data = eval('(' + response.responseText + ')');

						thisC.removeAll();
						thisC.add(imported_data);
						thisC.doLayout();

					},
					failure: function(response, opts) {
						alert('AJAX FAILED!!!!!!');
					}
				});
			}
		};
		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.DynContainer.superclass.initComponent.apply(this, arguments);
		//}
	},
	onRender: function() {
		Ext.ux.DynContainer.superclass.onRender.apply(this, arguments);
		var params = {};
		if(this.urlparams) { params = this.urlparams; delete params["url"]; }
		this.loadData(this.itemsurl,params);
	}
});
Ext.reg('dyncontainer',Ext.ux.DynContainer);


Ext.override(Ext.Container, {
	onRender: function() {
		Ext.Container.superclass.onRender.apply(this, arguments);

		var thisC = this;

		if (this.ajaxitems && Ext.isArray(this.ajaxitems)) {

			for (i in this.ajaxitems) {
				if (this.ajaxitems[i]['url']) {

					alert(this.ajaxitems[i]['url']);

					Ext.Ajax.request({
						disableCaching: true,
						url: this.ajaxitems[i]['url'],
						params: this.ajaxitems[i]['params'],
						success: function(response, opts) {
							var imported_data = eval('(' + response.responseText + ')');
							thisC.add(new Ext.Container(imported_data));
							thisC.doLayout();
						},
						failure: function(response, opts) {
							alert('AJAX ajaxitems FAILED!!!!!!');
						}
					});
				}
			}
		}
	}
});



/*
Ext.ux.AutoPanel = Ext.extend(Ext.Panel, {
	initComponent: function() {
		var id = this.id;
		var imported_data;
			var config = {
				//onRemove: function(c) {
					//alert('foo');
				//	var Forms = c.findByType('form');
				//	for (f in Forms) {
				//		try { Forms[f].destroy(); } catch(err) {}
				//	}
				//},
				renderer: {
					disableCaching: true,
					render: function(el, response, updater, callback) {
						if (!updater.isUpdating()) {
							try {
								imported_data = eval('(' + response.responseText + ')');
							}
							catch(err) {
								return eval(response.responseText);
							}
							var container = Ext.getCmp(id);
							/*
							//Destroy any Forms if they exist:
							if (container && container.rendered) {
								//alert(container.rendered);
								//alert(container.getXType());
								//var childForm = container.findByType('form');
								var Forms = container.findByType('form');
								for (f in Forms) { try {
									var BasicForm = Forms[f].getForm();
									var fields = BasicForm.getFieldValues();
									for (i in fields) {
										BasicForm.remove(i);
									}


									//try { Forms[f].removeAll(true); Forms[f].destroy(); } catch(err) {}
								} catch(err) {} }


								//if (childForm && typof(childForm) == 'object') { alert("'" + childForm + "'"); }

								//if (childForm && childForm != '')  { alert('"' + eval(typeof(childForm.prototype.destroy)) + '"'); }

								//if (childForm && childForm != '')  { childForm.destroy(); }

								//if (childForm) { alert('"' + Ext.type(childForm) + '"'); }

								//if (childForm) { alert('"' + Ext.util.JSON.encode(childForm) + '"'); }

								//if (childForm) { try { childForm.destroy(); } catch(err) { } }

								//if (childForm) { try { childForm.destroy(); } catch(err) { alert('"' + err + '"'); } }
							}
							// ---
							*/
							/*

							// --- NEW TRY LINE:
							try { container.removeAll(true); } catch(err) { try { container.removeAll(true); } catch(err) {} }
							container.insert(0,imported_data);
							container.doLayout();
							if (imported_data.rendered_eval) { eval(imported_data.rendered_eval); }
						}
					}
				}
			};
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.AutoPanel.superclass.initComponent.apply(this, arguments);
	}
});
Ext.reg('autopanel',Ext.ux.AutoPanel);
*/






Ext.ux.AutoPanel = Ext.extend(Ext.Panel, {
	initComponent: function() {

		var id = this.id;
		var imported_data;
			var config = {
				renderer: {
					disableCaching: true,
					render: function(el, response, updater, callback) {
						if (!updater.isUpdating()) {
							try {
								imported_data = eval('(' + response.responseText + ')');
							}
							catch(err) {
								return eval(response.responseText);
							}
							var container = Ext.getCmp(id);

							el.dom.innerHTML = '';
							// --- NEW TRY LINE:
							try { container.removeAll(true); } catch(err) { try { container.removeAll(true); } catch(err) {} }
							container.insert(0,imported_data);
							container.doLayout();
							if (imported_data.rendered_eval) { eval(imported_data.rendered_eval); }
						}
					}
				}
			};
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.AutoPanel.superclass.initComponent.apply(this, arguments);
	}
});
Ext.reg('autopanel',Ext.ux.AutoPanel);



/*
Ext.ux.JsonAutoPanel = Ext.extend(Ext.Panel, {
	initComponent: function() {

		var id = this.id;
		var imported_data;
			var config = {
				renderer: {
					disableCaching: true,
					render_old: function(el, response, updater, callback) {
						if (!updater.isUpdating()) {
							try {
								imported_data = eval('(' + response.responseText + ')');
							}
							catch(err) {
								return eval(response.responseText);
							}
							var container = Ext.getCmp(id);


							// --- NEW TRY LINE:
							try { container.removeAll(true); } catch(err) { try { container.removeAll(true); } catch(err) {} }
							container.insert(0,imported_data);
							container.doLayout();
							if (imported_data.rendered_eval) { eval(imported_data.rendered_eval); }
						}
					},
					render_blah: function(el, response, updateManager, callback) {
						var responseText = response.responseText;
						responseText = responseText.trim();
						//if (response.getResponseHeader['Content-Type'].indexOf('json') > -1) {
							// response is JSON
							// clear loading text
							el.dom.innerHTML = '';
							//var data = Ext.util.JSON.decode(responseText);

							var data = eval('(' + response.responseText + ')');

							var pnl = response.argument.options.container || response.argument.scope;

							alert(typeof(pnl));

							if (pnl.add) {

								alert('foo');

								pnl.add(data);
								pnl.doLayout();
							}
							if (callback) {
								callback(data);
							}

						//} else {
							// response is HTML, call regular update
						//	el.update(response.responseText, updateManager.loadScripts, callback);
						//}
					},
					render: function(el, response, updater, callback) {
						if (!updater.isUpdating()) {
							try {
								imported_data = eval('(' + response.responseText + ')');
							}
							catch(err) {
								return eval(response.responseText);
							}
							//var container = Ext.getCmp(id);

							el.dom.innerHTML = '';
							var newComponent = new Ext.Container(imported_data);
							newComponent.render(el);


							// --- NEW TRY LINE:
							//try { container.removeAll(true); } catch(err) { try { container.removeAll(true); } catch(err) {} }
							//container.insert(0,imported_data);
							//container.doLayout();
							//if (imported_data.rendered_eval) { eval(imported_data.rendered_eval); }
						}
					}
				}
			};
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.JsonAutoPanel.superclass.initComponent.apply(this, arguments);
	}
});
Ext.reg('jsonautopanel',Ext.ux.JsonAutoPanel);




*/





Ext.ux.DynGridPanel = Ext.extend(Ext.grid.GridPanel, {

	border: false,
	initComponent: function() {

		var store = new Ext.data.JsonStore(this.store_config);

		var Toolbar = {
			xtype : 'paging',
			store : store,
			displayInfo : true,
			prependButtons: true
		};
		if(this.pageSize) { Toolbar['pageSize'] = parseFloat(this.pageSize); }
		if(this.paging_bbar) { Toolbar['items'] = this.paging_bbar; }


		// --------- this doesn't work:
		//var new_column_model = [];
		//for ( var i in this.column_model ) {
		//	if (!this.column_model[i].exclude) {
		//		new_column_model.push(this.column_model[i]);
		//	}
		//}
		//this.column_model = new_column_model;


		// ----- MultiFilters: ----- //
		if (this.use_multifilters) {
			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(new Ext.ux.MultiFilter.Plugin);
		}
		// ------------------------- //


		// ----- RowExpander ------ //
		if (this.expander_template) {
			var expander_config = {};
			expander_config.tpl = new Ext.Template(this.expander_template);
			if (this.getRowClass_eval) { expander_config.getRowClass_eval = this.getRowClass_eval; }
			var expander = new Ext.ux.grid.RowExpanderEX(expander_config);
			this.column_model.unshift(expander);
			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(expander);
			this.expander = expander;
		}
		// ----------------------- //






		// ----- RowActions ------ //
		var thisG = this;
		if (this.rowactions && this.rowactions.actions) {
			var new_actions = [];
			for (var i in thisG.rowactions.actions) {
				var action_config = thisG.rowactions.actions[i];
				if(this.rowactions.callback_eval) {
					action_config.callback = function(grid, record, action, groupId) { eval(thisG.rowactions.callback_eval); }
				}
				new_actions.push(action_config);
			}
			this.rowactions.actions = new_actions;
			var action = new Ext.ux.grid.RowActions(this.rowactions);
			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(action);
			this.column_model.push(action);
		}
		// ----------------------- //



		// ---------------------------- //
		// ------ Grid Search --------- //
		if (this.gridsearch) {

			var grid_search_cnf = {
				iconCls:'icon-zoom',
				//,readonlyIndexes:['note']
				//,disableIndexes:['pctChange']
				//minChars:3, 		// characters to type before the request is made. If undefined (the default)
										// the trigger field shows magnifier icon and you need to click it or press enter for search to start.
				autoFocus:false,
				mode: 'local', // local or remote
				width: 300,
				position: 'top'
				//,menuStyle:'radio'
			};

			if (this.gridsearch_remote) { grid_search_cnf['mode'] = 'remote'; }

			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(new Ext.ux.grid.Search(grid_search_cnf));
		}
		// ---------------------------- //


	 // ------ Grid Filter --------- //
		//if(this.gridfilter) {

			var grid_filter_cnf = {
				encode: true, // json encode the filter query
				local: true   // defaults to false (remote filtering)
			}

			if (this.gridfilter_remote) { grid_filter_cnf['local'] = false; }


			if(this.init_state) {
				grid_filter_cnf['init_state'] = this.init_state;
				//{
				//	filters: this.init_filters
				//};


				//console.dir(this.init_state);
			}

			var GridFilters = new Ext.ux.grid.GridFilters(grid_filter_cnf);

			if(!this.plugins){ this.plugins = []; }
			this.plugins.push(GridFilters);
		//}
	// ---------------------------- //

		var sm = new Ext.grid.RowSelectionModel();

		// ------- SelectionModel -------- //
		if (this.row_checkboxes) {
			sm = new Ext.grid.CheckboxSelectionModel();
			this.column_model.unshift(sm);
		}
		// ------------------------------- //

		var config = {
			stateful: false,
			enableColumnMove: true,
			store: store,
			columns: this.column_model,
			selModel: sm,
			layout: 'fit',
			id: this.gridid,
			loadMask: true,
			storeReload: function(grid) {
				grid.store.reload();
			},

			// ------- http://extjs.com/forum/showthread.php?p=97676#post97676
			autoSizeColumns: function() {
				if (this.colModel) {

					this.colModel.suspendEvents();
					for (var i = 0; i < this.colModel.getColumnCount(); i++) {
						this.autoSizeColumn(i);
					}
					this.colModel.resumeEvents();
					this.view.refresh(true);
					this.store.removeListener('load',this.autoSizeColumns,this);

				}
			},
			autoSizeColumn: function(c) {
				var colid = this.colModel.getColumnId(c);
				var column = this.colModel.getColumnById(colid);
				var col = this.view.el.select("td.x-grid3-td-" + colid + " div:first-child");
				if (col) {

					var add = 6;
					var w = col.getTextWidth() + Ext.get(col.elements[0]).getFrameWidth('lr') + add;

					if (this.MaxColWidth && w > this.MaxColWidth) { w =  this.MaxColWidth; }
					if (column.width && w < column.width) { w = column.width; }

					this.colModel.setColumnWidth(c, w);
					return w;
				}
			}
			// ------------------------
		};

		if (Toolbar) { config['bbar'] = Toolbar; }



		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.DynGridPanel.superclass.initComponent.apply(this, arguments);
	},

	onRender: function() {

		//var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Loading data, please wait..."});
		//myMask.show();


		// ------- Remote Columns -------- //
		var thisGrid = this;
		if (this.remote_columns) {
			this.store.on('beforeload',function(Store,opts) {
				var columns = thisGrid.getColumnModel().getColumnsBy(function(c){
					if(c.hidden || c.dataIndex == "" || c.dataIndex == "icon") { return false; }
					return true;
				});
				var colIndexes = [];
				for (i in columns) {
					colIndexes.push(columns[i].dataIndex);
				}
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
		}
		// ------------------------------- //


		var load_parms = null;
		if (this.pageSize) {
			load_parms = {
				params: {
					start: 0,
					limit: parseFloat(this.pageSize)
				}
			};
		}

		this.store.load(load_parms);

		Ext.ux.DynGridPanel.superclass.onRender.apply(this, arguments);

		var thisC = this;

		function StartReloadInterval(mystore,i) {
			function ReloadStore() { mystore.reload(); }
			setInterval(ReloadStore,i);
		}
		if (this.reload_interval > 0) {
			StartReloadInterval(thisC.store,thisC.reload_interval);
		}

		if (this.UseAutoSizeColumns) {
			//this.store.on('load',thisC.autoSizeColumns,thisC);
			this.store.on('load',function(grid) {
				var sizeFunc = function(){thisC.autoSizeColumns();}
				sizeFunc();
			});
		}



		// ---- this is old:
		/*
		this.on('celldblclick',function(grid, rowIndex, columnIndex, e) {

			var viewPan = Ext.getCmp('viewingPanel');
			viewPan.expand();
			viewPan.doLayout();
			//alert(data);
		});
		*/
		// -----------------

		this.on('cellclick',function(grid, rowIndex, columnIndex, e) {
			var record = grid.getStore().getAt(rowIndex);  // Get the Record
			var col_model = grid.getColumnModel();
			var fieldName = col_model.getDataIndex(columnIndex); // Get field name

			if (this.expander && this.expander_click_rows) {
				if (this.expander_click_rows[columnIndex]) {
					this.expander.toggleRow(rowIndex);
				}
			}

			//var colid = col_model.getColumnId(fieldName);
			//var column = col_model.getColumnById(colid);

		});


		// ------ Cell Doubleclick -------- //
		if(this.celldblclick_eval) {
			//alert(thisC.rowbodydblclick_eval);
			//this.on('rowbodydblclick', function(grid, rowIndex, e) {
			this.on('celldblclick', function(grid, rowIndex, columnIndex, e) {
				var record = grid.getStore().getAt(rowIndex);
				var fieldName = grid.getColumnModel().getDataIndex(columnIndex);
				eval(this.celldblclick_eval);
			});
		}
		// -------------------------------- //

		//window.busy = false;

		//myMask.hide();

	},
	getFilters: function(grid) {
		for (i in grid.plugins) {
			if (grid.plugins[i]['filters']) {
				return grid.plugins[i];
			}
		}
		return null;
	}
});
Ext.reg('dyngrid',Ext.ux.DynGridPanel);



//var orig_gf_init = Ext.ux.grid.GridFilters.prototype.init;

Ext.override(Ext.ux.grid.GridFilters, {

	initOrig: Ext.ux.grid.GridFilters.prototype.init,

	init: function(grid) {
		this.initOrig.apply(this, arguments);

		if (this.init_state) {

			for (i in this.init_state.filters) {
				for (p in this.init_state.filters[i]) {
					var orig = this.init_state.filters[i][p];
					if (p == 'before' || p == 'after' || p == 'on') {
						this.init_state.filters[i][p] = Date.parseDate(orig,"Y-m-d\\TH:i:s");
					}
				}
			}

			this.applyState(grid,this.init_state);
			grid.applyState(this.init_state);
			//console.dir(this.init_state);
		}
	},

	getState: function () {
		var filters = {};
		this.filters.each(function (filter) {
			if (filter.active) {
				filters[filter.dataIndex] = filter.getValue();
			}
		});
		return filters;
	}
});




/*
Ext.override(Ext.ux.GridFilters, {
	initComponent: function() {

		var config = {
			getState: function () {
				var filters = {};
				this.filters.each(function (filter) {
					if (filter.active) {
						filters[filter.dataIndex] = filter.getValue();
					}
				});
				return filters;
			}
		};
		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.GridFilters.superclass.initComponent.apply(this, arguments);
	}
});
*/





Ext.ux.DButton = Ext.extend(Ext.Button, {

	initComponent: function() {

		if (this.handler_func) {
			var config = {
				handler: function(btn) { eval(this.handler_func); }
			};
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		}
		Ext.ux.DButton.superclass.initComponent.apply(this, arguments);
	},
	afterRender: function() {
		if (this.submitFormOnEnter) {
			var formPanel = this.findParentByType('form');
			if (!formPanel) {
				formPanel = this.findParentByType('submitform');
			}
			new Ext.KeyMap(formPanel.el, {
				key: Ext.EventObject.ENTER,
				shift: false,
				alt: false,
				fn: function(keyCode, e){
						if(e.target.type === 'textarea' && !e.ctrlKey) {
							return true;
						}
						this.el.select('button').item(0).dom.click();
						return false;
				},
				scope: this
			});
		}
		Ext.ux.DButton.superclass.afterRender.apply(this, arguments);
	}
});
Ext.reg('dbutton',Ext.ux.DButton);


Ext.ux.TreePanelExt = Ext.extend(Ext.tree.TreePanel, {

	onRender: function() {
		if (this.click_handler_func) {
			this.on('click',function(node,e) { if (node) { eval(this.click_handler_func); }});
		}

		Ext.ux.TreePanelExt.superclass.onRender.apply(this, arguments);
	},
	afterRender: function() {
		Ext.ux.TreePanelExt.superclass.afterRender.apply(this, arguments);

		if (this.expand) { this.expandAll(); }

		if (this.afterRender_eval) {

			eval(this.afterRender_eval);

			/*
			var eval_str = this.afterRender_eval;
			var task = new Ext.util.DelayedTask(function() { eval(eval_str); });
			task.delay(500);
			*/

		}
	}
});
Ext.reg('treepanelext',Ext.ux.TreePanelExt );


// learned about this from: http://www.diloc.de/blog/2008/03/05/how-to-submit-ext-forms-the-right-way/
Ext.ux.JSONSubmitAction = function(form, options){
	 Ext.ux.JSONSubmitAction.superclass.constructor.call(this, form, options);
};
Ext.extend(Ext.ux.JSONSubmitAction, Ext.form.Action.Submit, {

	type : 'jsonsubmit',

	run : function(){
		  var o = this.options,
				method = this.getMethod(),
				isGet = method == 'GET';
		  if(o.clientValidation === false || this.form.isValid()){
				if (o.submitEmptyText === false) {
					 var fields = this.form.items,
						  emptyFields = [];
					 fields.each(function(f) {
						  if (f.el.getValue() == f.emptyText) {
								emptyFields.push(f);
								f.el.dom.value = "";
						  }
					 });
				}

				var orig_p = this.form.orig_params;
				var new_p = this.form.getFieldValues();

				var ajax_params = o.base_params ? o.base_params : {};
				ajax_params['json_params'] = Ext.util.JSON.encode(new_p);
				if (this.form.orig_params) {
					ajax_params['orig_params'] = Ext.util.JSON.encode(orig_p);
				}






				//Ext.getCmp('dataview').getStore().reload();

				//var cmp = this.form.findField('dataview');
				//alert(cmp.getXtype());

				//this.cascade(function (cmp) {
				//	try { if (cmp.getXtype()) { alert(cmp.getXtype()); } } catch(err) {}
				//});


				Ext.Ajax.request(Ext.apply(this.createCallback(o), {
					 //form:this.form.el.dom,  <--- need to remove this line to prevent the form items from being submitted
					 url:this.getUrl(isGet),
					 method: method,
					 headers: o.headers,
					 //params:!isGet ? this.getParams() : null,
					 params: ajax_params,
					 isUpload: this.form.fileUpload
				}));
				if (o.submitEmptyText === false) {
					 Ext.each(emptyFields, function(f) {
						  if (f.applyEmptyText) {
								f.applyEmptyText();
						  }
					 });
				}
		  }else if (o.clientValidation !== false){ // client validation failed
				this.failureType = Ext.form.Action.CLIENT_INVALID;
				this.form.afterAction(this, false);
		  }
	 }
});
//add our action to the registry of known actions
Ext.form.Action.ACTION_TYPES['jsonsubmit'] = Ext.ux.JSONSubmitAction;


Ext.ux.SubmitFormPanel = Ext.extend(Ext.form.FormPanel, {

	initComponent: function() {




		var thisC = this;

		var config = {
			resultProcessor: function(form, action) {
				thisC.el.unmask();
				if (action.result.success) {
					if (thisC.show_result) { Ext.MessageBox.alert('Success',action.result.msg); }
					if (thisC.onSuccess_eval) {
						eval(thisC.onSuccess_eval);





						//alert(this.getComponent('itemdataview').getXType());


						//var store = thisC.getComponent('itemdataview').store;
						//store.reload;

						//var store = Ext.getCmp('mydataview').store;
						//store.reload;

						//alert(Ext.util.JSON.encode(action.params));
						//Ext.Msg.alert('blah',Ext.util.JSON.encode(thisC.base_params));

						//Ext.StoreMgr.each( function(store) {
						//	for ( var i in thisC.base_params ) {
						//		store.setBaseParam(i, thisC.base_params[i]);
						//	}
						//	store.reload();
						//});
					}
				}
				else {
					if (thisC.onFail_eval) { eval(thisC.onFail_eval); }
					if (thisC.show_result) { Ext.MessageBox.alert('Failure',action.result.msg); }
				}
			},

			submitProcessor: function() {

				var do_action = this.do_action ? this.do_action : 'submit';
				var base_params = this.base_params ? this.base_params : {};





				//Ext.StoreMgr.each( function(store) {
				//	for ( var i in base_params ) {
				//		store.setBaseParam(i, base_params[i]);
				//	}
				//	store.reload();
				//});

				this.el.mask('Please wait','x-mask-loading');
				//this.getForm().submit({
				//this.getForm().doAction('jsonsubmit',{
				this.getForm().doAction(do_action,{
					url: this.url,
					base_params: base_params,
					nocache: true,
					success: this.resultProcessor,
					failure: this.resultProcessor
				});
			}
		};

		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.ux.SubmitFormPanel.superclass.initComponent.apply(this, arguments);
	},

	afterRender: function() {

		//if (this.map_enter_submit) {
		//	var map = new Ext.KeyMap(document, {
		//		key: 13,
		//		//scope: this,
		//		fn: function() { alert('enter!'); }
		//	});
		//}




		this.on('actioncomplete', function(form,action) {
			if(action.type == 'load') {
			// save the orig params so they are available later in the jsonsubmit action
			form.orig_params = form.getFieldValues();

				//find any stores within this container and reload them:
				this.cascade(function(cmp) {
					var xtype = cmp.getXType();
					if(xtype == "dyngrid" || xtype == "dataview") {
						Ext.log(cmp.getXType());
						try { cmp.getStore().reload(); } catch(err) { Ext.log(err); }
					}
				});
			}
		});



/*
		this.on('actioncomplete', function(form,action) {
			if(action.type == 'load') {
				form.orig_params = form.getFieldValues();



				var store = this.getComponent('itemdataview').getStore();
				//var store = Ext.getCmp('mydataview').getStore();
				//alert(Ext.util.JSON.encode(store.baseParams));
				var new_p = this.getForm().getFieldValues();
				for ( i in store.baseParams ) {
					if (new_p[i]) { store.setBaseParam(i,new_p[i]); }
				}
				//alert(Ext.util.JSON.encode(store.baseParams));
				store.reload();


			}
		});
*/



/*
		this.on('activate', function(form,action) {
			if (this.action_load) {
				var action_load = this.action_load;
				action_load['waitTitle'] = 'Loading';
				action_load['waitMsg'] = 'Loading data';
				var form = this.getForm();
				form.load(action_load);
			}

		});
*/


		// Load the form data: //
		if (this.action_load) {
			var action_load = this.action_load;
			action_load['waitTitle'] = 'Loading';
			action_load['waitMsg'] = 'Loading data';
			var form = this.getForm();
			form.load(action_load);
		}


		if (this.focus_field_id) {
			var field = Ext.getCmp(this.focus_field_id);
			if (field) { field.focus('',10); }
		}
		Ext.ux.SubmitFormPanel.superclass.afterRender.apply(this, arguments);
	}
});
Ext.reg('submitform',Ext.ux.SubmitFormPanel );















// Tweaks to Saki's "CheckTree" (http://checktree.extjs.eu/) -- 2010-03-27 by HV
Ext.override(Ext.ux.tree.CheckTreePanel, {
	// This is required in order to get initial checked state:
	afterRender:function() {
		Ext.ux.tree.CheckTreePanel.superclass.afterRender.apply(this, arguments);
		this.updateHidden();
	 },

	 // This adds unchecked items to the posted list... Unchecked start with '-', checked start with '+'
	 getValue:function() {
		var a = [];
		this.root.cascade(function(n) {
			if(true === n.attributes.checked) {
				if(false === this.deepestOnly || !this.isChildChecked(n)) {
					a.push('+' + n.id);
				}
			}
			else {
				a.push('-' + n.id);
			}
		}, this);
		a.shift(); // Remove root element
		return a;
	}
});


/* Override to force it to not display the checkbox if "checkbox" is null */
Ext.override(Ext.ux.tree.CheckTreeNodeUI, {

	renderElements:function(n, a, targetNode, bulkRender){

		/* This override was required to support NO checkbox */
		var checkbox_class = 'x-tree-checkbox';
		if (n.attributes.checked == null) { checkbox_class = 'x-tree-checkbox-no-checkbox'; }
		/* ------------------------------------------------- */

		this.indentMarkup = n.parentNode ? n.parentNode.ui.getChildIndent() :'';
		var checked = n.attributes.checked;
		var href = a.href ? a.href : Ext.isGecko ? "" :"#";
		  var buf = [
			 '<li class="x-tree-node"><div ext:tree-node-id="',n.id,'" class="x-tree-node-el x-tree-node-leaf x-unselectable ', a.cls,'" unselectable="on">'
			,'<span class="x-tree-node-indent">',this.indentMarkup,"</span>"
			,'<img src="', this.emptyIcon, '" class="x-tree-ec-icon x-tree-elbow" />'
			,'<img src="', a.icon || this.emptyIcon, '" class="x-tree-node-icon',(a.icon ? " x-tree-node-inline-icon" :""),(a.iconCls ? " "+a.iconCls :""),'" unselectable="on" />'
			,'<img src="'+this.emptyIcon+'" class="' + checkbox_class +(true === checked ? ' x-tree-node-checked' :'')+'" />'
			,'<a hidefocus="on" class="x-tree-node-anchor" href="',href,'" tabIndex="1" '
			,a.hrefTarget ? ' target="'+a.hrefTarget+'"' :"", '><span unselectable="on">',n.text,"</span></a></div>"
			,'<ul class="x-tree-node-ct" style="display:none;"></ul>'
			,"</li>"
		].join('');
		var nel;
		if(bulkRender !== true && n.nextSibling && (nel = n.nextSibling.ui.getEl())){
			this.wrap = Ext.DomHelper.insertHtml("beforeBegin", nel, buf);
		}else{
			this.wrap = Ext.DomHelper.insertHtml("beforeEnd", targetNode, buf);
		}
		this.elNode = this.wrap.childNodes[0];
		this.ctNode = this.wrap.childNodes[1];
		var cs = this.elNode.childNodes;
		this.indentNode = cs[0];
		this.ecNode = cs[1];
		this.iconNode = cs[2];
		this.checkbox = cs[3];
		this.cbEl = Ext.get(this.checkbox);
		this.anchor = cs[4];
		this.textNode = cs[4].firstChild;
	} // eo function renderElements
});




/*
Ext.override(Ext.chart.LineChart, {
	initComponent: function() {
		var config = this;
		if (this.xAxis && this.xAxis['xtype']) {
			if(this.xAxis['xtype'] == 'categoryaxis') { config['xAxis'] = new Ext.chart.CategoryAxis(this.xAxis); }
			if(this.xAxis['xtype'] == 'numericaxis') { config['xAxis'] = new Ext.chart.NumericAxis(this.xAxis); }
		}
		if (this.yAxis && this.yAxis['xtype']) {
			if(this.yAxis['xtype'] == 'categoryaxis') { config['yAxis'] = new Ext.chart.CategoryAxis(this.yAxis); }
			if(this.yAxis['xtype'] == 'numericaxis') { config['yAxis'] = new Ext.chart.NumericAxis(this.yAxis); }
		}
		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.chart.LineChart.superclass.initComponent.apply(this, arguments);
	}
});
*/


var pxMatch = /(\d+(?:\.\d+)?)px/;
Ext.override(Ext.Element, {
		  getViewSize : function(contentBox){
				var doc = document,
					 me = this,
					 d = me.dom,
					 extdom = Ext.lib.Dom,
					 isDoc = (d == doc || d == doc.body),
					 isBB, w, h, tbBorder = 0, lrBorder = 0,
					 tbPadding = 0, lrPadding = 0;
				if (isDoc) {
					 return { width: extdom.getViewWidth(), height: extdom.getViewHeight() };
				}
				isBB = me.isBorderBox();
				tbBorder = me.getBorderWidth('tb');
				lrBorder = me.getBorderWidth('lr');
				tbPadding = me.getPadding('tb');
				lrPadding = me.getPadding('lr');

				// Width calcs
				// Try the style first, then clientWidth, then offsetWidth
				if (w = me.getStyle('width').match(pxMatch)){
					 if ((w = Math.round(w[1])) && isBB){
						  // Style includes the padding and border if isBB
						  w -= (lrBorder + lrPadding);
					 }
					 if (!contentBox){
						  w += lrPadding;
					 }
					 // Minimize with clientWidth if present
					 d.clientWidth && (d.clientWidth < w) && (w = d.clientWidth);
				} else {
					 if (!(w = d.clientWidth) && (w = d.offsetWidth)){
						  w -= lrBorder;
					 }
					 if (w && contentBox){
						  w -= lrPadding;
					 }
				}

				// Height calcs
				// Try the style first, then clientHeight, then offsetHeight
				if (h = me.getStyle('height').match(pxMatch)){
					 if ((h = Math.round(h[1])) && isBB){
						  // Style includes the padding and border if isBB
						  h -= (tbBorder + tbPadding);
					 }
					 if (!contentBox){
						  h += tbPadding;
					 }
					 // Minimize with clientHeight if present
					 d.clientHeight && (d.clientHeight < h) && (h = d.clientHeight);
				} else {
					 if (!(h = d.clientHeight) && (h = d.offsetHeight)){
						  h -= tbBorder;
					 }
					 if (h && contentBox){
						  h -= tbPadding;
					 }
				}

				return {
					 width : w,
					 height : h
				};
		  }
});

Ext.override(Ext.layout.ColumnLayout, {
	 onLayout : function(ct, target, targetSize){
		  var cs = ct.items.items, len = cs.length, c, i;

		  if(!this.innerCt){
				// the innerCt prevents wrapping and shuffling while
				// the container is resizing
				this.innerCt = target.createChild({cls:'x-column-inner'});
				this.innerCt.createChild({cls:'x-clear'});
		  }
		  this.renderAll(ct, this.innerCt);

		  var size = targetSize || target.getViewSize(true);

		  if(size.width < 1 && size.height < 1){ // display none?
				return;
		  }

		  var w = size.width - this.scrollOffset,
				h = size.height,
				pw = w;

		  this.innerCt.setWidth(w);

		  // some columns can be percentages while others are fixed
		  // so we need to make 2 passes

		  for(i = 0; i < len; i++){
				c = cs[i];
				if(!c.columnWidth){
					 pw -= (c.getSize().width + c.getPositionEl().getMargins('lr'));
				}
		  }

		  pw = pw < 0 ? 0 : pw;

		  for(i = 0; i < len; i++){
				c = cs[i];
				if(c.columnWidth){
					 c.setSize(Math.floor(c.columnWidth * pw) - c.getPositionEl().getMargins('lr'));
				}
		  }
		  // Do a second pass if the layout resulted in a vertical scrollbar (changing the available width)
		  if (!targetSize && ((size = target.getViewSize(true)).width != w)) {
				this.onLayout(ct, target, size);
		  }
	 }
});


//Ext.reg('categoryaxis',Ext.chart.CategoryAxis );
//Ext.reg('numericaxis',Ext.chart.NumericAxis );

//Ext.QuickTips = function(){};

//Ext.override(Ext.QuickTips, function() {});



//Ext.override(Ext.ux.Printer.BaseRenderer, { stylesheetPath: '/static/js/Ext.ux.Printer/print.css' });

/*
 * Prints the contents of an Ext.Panel
*/
// Ext.ux.Printer.PanelRenderer = Ext.extend(Ext.ux.Printer.BaseRenderer, {

/*
  * Generates the HTML fragment that will be rendered inside the <html> element of the printing window
 */
//	generateBody: function(panel) {
//		return String.format("<div class='x-panel-print'>{0}</div>", panel.body.dom.innerHTML);
//	}
//});

//Ext.ux.Printer.registerRenderer("panel", Ext.ux.Printer.PanelRenderer);





































Ext.ux.FloatClear = Ext.extend(Ext.Component, {
	cls: 'x-clear'
});
Ext.reg('float-clear', Ext.ux.FloatClear);

Ext.ux.FloatingFormLayout = Ext.extend(Ext.layout.FormLayout, {
	getLabelStyle: function(s, field) {
		var labelStyle = this.labelStyle;
		if (this.labelAlign !== 'top') {
			if (field.labelWidth) {
				labelStyle = 'width:' + field.labelWidth + 'px;';
			}
		}
		var ls = '', items = [labelStyle, s];
		for (var i = 0, len = items.length; i < len; ++i) {
			if (items[i]) {
				ls += items[i];
				if (ls.substr(-1, 1) != ';') {
					ls += ';';
				}
			}
		}
		return ls;
	},

	getElementStyle: function(field) {
		if (this.labelAlign === 'top' || !field.labelWidth) {
			return this.elementStyle;
		} else {
			var pad = Ext.isNumber(this.labelPad) ? this.labelPad : 5;
			return 'padding-left:' + (field.labelWidth + pad) + 'px';
		}
	},

	getTemplateArgs: function(field) {
		var noLabelSep = !field.fieldLabel || field.hideLabel;

		return {
			id: field.id,
			label: field.fieldLabel,
			itemCls: (field.itemCls || this.container.itemCls || '') + (field.hideLabel ? ' x-hide-label' : ''),
			clearCls: field.clearCls || 'x-form-clear-left',
			labelStyle: this.getLabelStyle(field.labelStyle, field),
			elementStyle: this.getElementStyle(field) || '',
			labelSeparator: noLabelSep ? '' : (Ext.isDefined(field.labelSeparator) ? field.labelSeparator : this.labelSeparator)
		};
	}
});
Ext.Container.LAYOUTS['floating-form'] = Ext.ux.FloatingFormLayout;

Ext.ux.FloatingFormPanel = Ext.extend(Ext.form.FormPanel, {
	cls: 'floating-form',
	layout: 'floating-form',
	lookupComponent: function(comp) {
		if (Ext.isString(comp)) {
			switch (comp) {
				case "|":
					comp = new Ext.ux.FloatClear();
					break;
			}
		}
		return Ext.ux.FloatingFormPanel.superclass.lookupComponent.call(this, comp);
	}
});
Ext.reg('floating-form', Ext.ux.FloatingFormPanel);


Ext.ns('Ext.ux');
Ext.ux.ComponentDataView = Ext.extend(Ext.DataView, {
	 defaultType: 'textfield',
	 initComponent : function(){
		  Ext.ux.ComponentDataView.superclass.initComponent.call(this);
		  this.components = [];
	 },
	 refresh : function(){
		  Ext.destroy(this.components);
		  this.components = [];
		  Ext.ux.ComponentDataView.superclass.refresh.call(this);
		  this.renderItems(0, this.store.getCount() - 1);
	 },
	 onUpdate : function(ds, record){
		  var index = ds.indexOf(record);
		  if(index > -1){
				this.destroyItems(index);
		  }
		  Ext.ux.ComponentDataView.superclass.onUpdate.apply(this, arguments);
		  if(index > -1){
				this.renderItems(index, index);
		  }
	 },
	 onAdd : function(ds, records, index){
		  var count = this.all.getCount();
		  Ext.ux.ComponentDataView.superclass.onAdd.apply(this, arguments);
		  if(count !== 0){
				this.renderItems(index, index + records.length - 1);
		  }
	 },
	 onRemove : function(ds, record, index){
		  this.destroyItems(index);
		  Ext.ux.ComponentDataView.superclass.onRemove.apply(this, arguments);
	 },
	 onDestroy : function(){
		  Ext.ux.ComponentDataView.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 },
	 renderItems : function(startIndex, endIndex){
		  var ns = this.all.elements;
		  var args = [startIndex, 0];
		  for(var i = startIndex; i <= endIndex; i++){
				var r = args[args.length] = [];
				for(var items = this.items, j = 0, len = items.length, c; j < len; j++){
					 c = items[j].render ?
						  c = items[j].cloneConfig() :
						  Ext.create(items[j], this.defaultType);
					 r[j] = c;
					 if(c.renderTarget){
						  c.render(Ext.DomQuery.selectNode(c.renderTarget, ns[i]));
					 }else if(c.applyTarget){
						  c.applyToMarkup(Ext.DomQuery.selectNode(c.applyTarget, ns[i]));
					 }else{
						  c.render(ns[i]);
					 }
					 if(Ext.isFunction(c.setValue) && c.applyValue){
						  c.setValue(this.store.getAt(i).get(c.applyValue));
						  c.on('blur', function(f){
							this.store.getAt(this.index).data[this.dataIndex] = f.getValue();
						  }, {store: this.store, index: i, dataIndex: c.applyValue});
					 }
				}
		  }
		  this.components.splice.apply(this.components, args);
	 },
	 destroyItems : function(index){
		  Ext.destroy(this.components[index]);
		  this.components.splice(index, 1);
	 }
});
Ext.reg('compdataview', Ext.ux.ComponentDataView);



Ext.ux.ComponentListView = Ext.extend(Ext.ListView, {
	 defaultType: 'textfield',
	 initComponent : function(){
		  Ext.ux.ComponentListView.superclass.initComponent.call(this);
		  this.components = [];
	 },
	 refresh : function(){
		  Ext.destroy(this.components);
		  this.components = [];
		  Ext.ux.ComponentListView.superclass.refresh.apply(this, arguments);
		  this.renderItems(0, this.store.getCount() - 1);
	 },
	 onUpdate : function(ds, record){
		  var index = ds.indexOf(record);
		  if(index > -1){
				this.destroyItems(index);
		  }
		  Ext.ux.ComponentListView.superclass.onUpdate.apply(this, arguments);
		  if(index > -1){
				this.renderItems(index, index);
		  }
	 },
	 onAdd : function(ds, records, index){
		  var count = this.all.getCount();
		  Ext.ux.ComponentListView.superclass.onAdd.apply(this, arguments);
		  if(count !== 0){
				this.renderItems(index, index + records.length - 1);
		  }
	 },
	 onRemove : function(ds, record, index){
		  this.destroyItems(index);
		  Ext.ux.ComponentListView.superclass.onRemove.apply(this, arguments);
	 },
	 onDestroy : function(){
		  Ext.ux.ComponentDataView.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 },
	 renderItems : function(startIndex, endIndex){
		  var ns = this.all.elements;
		  var args = [startIndex, 0];
		  for(var i = startIndex; i <= endIndex; i++){
				var r = args[args.length] = [];
				for(var columns = this.columns, j = 0, len = columns.length, c; j < len; j++){
					 var component = columns[j].component;
					 c = component.render ?
						  c = component.cloneConfig() :
						  Ext.create(component, this.defaultType);
					 r[j] = c;
					 var node = ns[i].getElementsByTagName('dt')[j].firstChild;
					 if(c.renderTarget){
						  c.render(Ext.DomQuery.selectNode(c.renderTarget, node));
					 }else if(c.applyTarget){
						  c.applyToMarkup(Ext.DomQuery.selectNode(c.applyTarget, node));
					 }else{
						  c.render(node);
					 }
					 if(c.applyValue === true){
						c.applyValue = columns[j].dataIndex;
					 }
					 if(Ext.isFunction(c.setValue) && c.applyValue){
						  c.setValue(this.store.getAt(i).get(c.applyValue));
						  c.on('blur', function(f){
							this.store.getAt(this.index).data[this.dataIndex] = f.getValue();
						  }, {store: this.store, index: i, dataIndex: c.applyValue});
					 }
				}
		  }
		  this.components.splice.apply(this.components, args);
	 },
	 destroyItems : function(index){
		  Ext.destroy(this.components[index]);
		  this.components.splice(index, 1);
	 }
});
Ext.reg('complistview', Ext.ux.ComponentListView);


Ext.override(Ext.ux.ComponentListView, {
	 onDestroy : function(){
		  Ext.ux.ComponentListView.superclass.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 }
});

Ext.override(Ext.ux.ComponentDataView, {
	 onDestroy : function(){
		  Ext.ux.ComponentDataView.superclass.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 }
});


Ext.ns('Ext.ux');
Ext.ux.TplTabPanel = Ext.extend(Ext.TabPanel, {
	 initComponent: function () {
		  //Ext.apply(this,{store:this.store});
		  Ext.ux.TplTabPanel.superclass.initComponent.apply(this, arguments);

		  var tb = this;
		  var itemArr = [];

		  var cnt = tb.store.getCount();

		  Ext.each(this.tabsTpl, function (j) {
				for (var i = 0; i < tb.store.getCount(); i++) {


					 var c = j.render ? c = j.cloneConfig() : Ext.ComponentMgr.create(j);


					 function myfn() {
						  Ext.apply(this, tb.store.getAt(i).get(this.applyValues));
					 }
					 c.cascade(myfn);
					 Ext.ComponentMgr.register(c);

					 tb.items.add(c.id, c);

				}
		  });

	 }
});
Ext.reg('tabtpl', Ext.ux.TplTabPanel);



//http://www.sencha.com/forum/showthread.php?77984-Field-help-text-plugin.
Ext.ux.FieldHelp = Ext.extend(Object, (function(){
	 function syncInputSize(w, h) {
		  this.el.setSize(w, h);
	 }

	 function afterFieldRender() {
		  if (!this.wrap) {
				this.wrap = this.el.wrap({cls: 'x-form-field-wrap'});
				this.positionEl = this.resizeEl = this.wrap;
				this.actionMode = 'wrap';
				this.onResize = this.onResize.createSequence(syncInputSize);
		  }
		  this.wrap[this.helpAlign == 'top' ? 'insertFirst' : 'createChild']({
				cls: 'x-form-helptext',
				html: this.helpText
		  });
	 }

	 return {
		  constructor: function(t, align) {
				this.helpText = t.text; // <-- changed from t to t.text (HV)
				this.align = align;
		  },

		  init: function(f) {
				f.helpAlign = this.align;
				f.helpText = this.helpText;
				f.afterRender = f.afterRender.createSequence(afterFieldRender);
		  }
	 };
})());
Ext.preg('fieldhelp',Ext.ux.FieldHelp);

