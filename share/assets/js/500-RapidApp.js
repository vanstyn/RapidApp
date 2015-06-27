Ext.Updater.defaults.disableCaching = true;

Ext.ns('Ext.log');
Ext.log = function() {};

Ext.ns('Ext.ux.RapidApp');

// This should be set dynamically by the server:
Ext.ux.RapidApp.VERSION = Ext.ux.RapidApp.VERSION || 0;
Ext.ux.RapidApp.AJAX_URL_PREFIX = Ext.ux.RapidApp.AJAX_URL_PREFIX || '';

// Window Group for Custom Prompts to make them higher than other windows and load masks
Ext.ux.RapidApp.CustomPromptWindowGroup = new Ext.WindowGroup();
Ext.ux.RapidApp.CustomPromptWindowGroup.zseed = 20050;
	
/* Global Server Event Object */
Ext.ux.RapidApp.EventObjectClass = Ext.extend(Ext.util.Observable,{
	constructor: function(config) {
		this.addEvents('serverevent');
		Ext.ux.RapidApp.EventObjectClass.superclass.constructor.call(this,config);
		this.on('serverevent',this.onServerEvent,this);
	},
	
	Fire: function() {
		var a = arguments;
		var arg_list = [ "'serverevent'" ];
		for( i = 0; i < a.length; i++) {
			arg_list.push('a[' + i + ']');
		}
		var eval_str = 'this.fireEvent(' + arg_list.join(',') + ');';
		eval( eval_str );
	},
	
	handlerMap: {},
	
	attachServerEvents: function() {
		var a = Array.prototype.slice.call(arguments, 0);
		var handler = a.shift();
		Ext.each(a,function(event) {
			this.attachHandlerToEvent(handler,event);
		},this);
	},
	
	attachHandlerToEvent: function(handler,event) {
		if(! Ext.isObject(handler) || ! Ext.isFunction(handler.func) || ! Ext.isString(handler.id)) {
			throw "handler must be an object with func and id";
		}
		
		if (! Ext.isArray(this.handlerMap[event])) { this.handlerMap[event] = []; }

		var skip = false;
		Ext.each(this.handlerMap[event],function(item) {
			// Skip adding if its already in the list:
			if (handler.id == item.id) {
				skip = true;
			};
		});
		
		if(skip) { return; }
		
		return this.handlerMap[event].push(handler);
	},
	
	onServerEvent: function() {
		var events = Array.prototype.slice.call(arguments, 0);
		var handlers = [];
		var seenIds = {};
		
		Ext.each(events,function(event) {
			if(Ext.isArray(this.handlerMap[event])) {
				Ext.each(this.handlerMap[event],function(handler) {
					if(!seenIds[handler.id]++) {
						handlers.push(handler);
					}
				},this);
			}
		},this);
		
		return this.callHandlers(handlers);
	},
	
	callHandlers: function(handlers) {
		Ext.each(handlers,function(handler) {
			var scope = Ext.getCmp(handler.id);
			if (scope) {
				handler.func.call(scope);
			}
			else {
				// TODO: remove the invalid id from handlerMap
				
			}
		},this);
	}
});
Ext.ux.RapidApp.EventObject = new Ext.ux.RapidApp.EventObjectClass();
	

Ext.ns('Ext.ux.RapidApp.userPrefs');
Ext.ux.RapidApp.userPrefs.timezone= 'America/New_York';
Ext.ux.RapidApp.userPrefs.timezoneOffset= -5*60;
Ext.ux.RapidApp.userPrefs.dateFormat= 'Y M j, g:i a';
Ext.ux.RapidApp.userPrefs.nearDateFormat= 'D M j, g:i a';

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





/*
Ext.ux.RapidApp.errMsgHandler = function(title,msg) {
	Ext.Msg.show({
		title: title,
		msg: Ext.util.Format.nl2br(msg),
		buttons: Ext.Msg.OK,
		icon: Ext.Msg.ERROR,
		minWidth: 275
	});
}
*/


Ext.ux.RapidApp.errMsgHandler = function(title,msg,as_text,extra_opts) {
  extra_opts = extra_opts || {};
	var win;
	
	var body = as_text ? '<pre>' + Ext.util.Format.nl2br(msg) + '</pre>' : msg;

  // This is a bit lazy (string match rather than real API) to change
  // the icon for the case of a Database Error, but it is fast/simple
  var headCls = ['ra-exception-heading'];
  if(title.search('Database Error ') == 0){
    headCls.push('ra-icon-data-warning-32x32');
    // While at it, convert the known dash (-) sequence into a pretty <hr>
    body = body.replace(
      "----------------",
      '<hr color="#808080" size="1">'
    );
  }
  else if(extra_opts.warn_icon) {
    headCls.push('ra-icon-warning-32x32');
  }
	
	win = new Ext.Window({
		manager: Ext.ux.RapidApp.CustomPromptWindowGroup,
    title: extra_opts.win_title || 'Exception',
		width: extra_opts.win_width || 600,
		height: extra_opts.win_height || 400,
		modal: true,
		closable: true,
		layout: 'fit',
		items: {
			xtype: 'panel',
			frame: true,
			headerCfg: {
				tag: 'div',
				cls: headCls.join(' '),
				html: title
			},
			autoScroll: true,
			html: '<div class="ra-exception-body">' + body + '</div>',
			bodyStyle: 'padding:5px;'
		},
		buttonAlign: 'center',
		buttons: [{
			text: 'Ok',
			handler: function() { win.close(); }
		}],
		listeners: {
			render: function(){
				// Catch navload events and auto-close the exception window:
				var loadTarget = Ext.getCmp("main-load-target");
				if(loadTarget){
					loadTarget.on('navload',this.close,this);
					this.on('beforeclose',function(){
						loadTarget.un('navload',this.close);
					},this);
				}
			}
		}
	});
	win.show();
}


Ext.ux.RapidApp.checkLocalTimezone = function(conn,options) {
	if (!options.headers) { options.headers= {}; }
	var dt= new Date();
	Ext.ux.RapidApp.userPrefs.timezoneOffset= -dt.getTimezoneOffset();
	options.headers['X-RapidApp-TimezoneOffset']= Ext.ux.RapidApp.userPrefs.timezoneOffset;
};
Ext.Ajax.on('beforerequest',Ext.ux.RapidApp.checkLocalTimezone);



/**
 * This function performs special handling for custom HTTP headers (or in the case of form uploads, custom
 *   JSON attributes) which may either continue the current request, or end it, or restart it with additional
 *   parameters.
 * This is called by our overridden Ext.data.Connection.handleResponse, and our custom
 *   Ext.data.Connection.doFormUpload.
 */
Ext.ux.RapidApp.handleCustomServerDirectives= function(response, continue_current_callback, success_callback_repeat) {
	var auth = response.getResponseHeader('X-RapidApp-Authenticated');
	if (auth != null)
		if (!Ext.ux.RapidApp.updateAuthenticated(auth, success_callback_repeat))
			return;
	
	var customprompt = response.getResponseHeader('X-RapidApp-CustomPrompt');
	if (customprompt)
		return Ext.ux.RapidApp.handleCustomPrompt(customprompt,success_callback_repeat);
	
	// If it was an exception, it got handled/displayed already in ajaxCheckException, so don't process further.
	if(response.getResponseHeader('X-RapidApp-Exception'))
		return;
	
	continue_current_callback();
	
	var servercallback = response.getResponseHeader('X-RapidApp-Callback');
	if (servercallback) {
		// Put the response into "this" and then call the callback handler with "this" scope
		this.response = response;
		Ext.ux.RapidApp.handleServerCallBack.call(this,servercallback);
	}
	
	var serverevents = response.getResponseHeader('X-RapidApp-ServerEvents');
	if (serverevents) {
		Ext.ux.RapidApp.handleServerEvents(serverevents);
	}
}

Ext.ux.RapidApp.handleServerEvents = function(headerdata) {
	var events = Ext.decode(headerdata);
	Ext.ux.RapidApp.EventObject.Fire.apply(Ext.ux.RapidApp.EventObject,events);
}

// returns whether or not to keep processing the request
Ext.ux.RapidApp.updateAuthenticated= function(authValue, success_callback_repeat) {
	var orig = Ext.ux.RapidApp.Authenticated;
	if (authValue != '0') { Ext.ux.RapidApp.Authenticated = authValue; }
	if (orig && orig != authValue && authValue == '0') {
		Ext.ux.RapidApp.ReAuthPrompt(success_callback_repeat);
		return false;
	}
	return true;
}


// Call an arbitrary function specified in the response from the server (X-RapidApp-Callback)
// If "scoped" is true, the function is called with the scope (this) of the Ext.data.Connection 
// that made the Ajax request to the server, and the response is available in 'this.response'
Ext.ux.RapidApp.handleServerCallBack = function(headerdata) {

	var data = {};
	Ext.apply(data,Ext.decode(headerdata));
	
	if (! data.func && ! data.anonfunc) {
		throw "Neither 'func' nor 'anonfunc' was specified in X-RapidApp-Callback header data";
	}
	
	var arr_to_param_str = function(name,arr) {
		var str = '';
		Ext.each(arr,function(item,index) {
			str += name + '[' + index + ']';
			if (arr.length > index + 1) {
				str += ',';
			}
		});
		return str;
	}
	
	var arg_str = '';
	if (data.arguments) {
		arg_str = arr_to_param_str('data.arguments',data.arguments);
	}
	
	var anonfunc;
	if (data.anonfunc && ! data.func) {	
		eval('anonfunc = ' + data.anonfunc + ';');
		data.func = 'anonfunc';
	}
	
	var func;
	if (data.scoped) {
		var scope = this;
		eval('func = function() { return ' + data.func + '.call(scope,' + arg_str + '); };'); 
	}
	else {
		eval('func = function() { return ' + data.func + '(' + arg_str + '); };'); 
	}
	return func();
}

Ext.ux.RapidApp.handleCustomPrompt = function(headerdata,success_callback) {

	var win;
	
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
	
	var default_formpanel_cnf = {
		itemId: 'formpanel',
		frame: true,
		labelAlign: 'right',
		bodyStyle: 'padding:20px 20px 10px 10px;',
		labelWidth: 70,
		defaults: {
			xtype: 'textfield',
			width: 175
		}
	};
	
	Ext.apply(data,Ext.decode(headerdata));
	if(! data.formpanel_cnf) { data.formpanel_cnf = {}; }
	
	if(data.validate) {
		default_formpanel_cnf.monitorValid = true;
	}
	
	
	Ext.apply(default_formpanel_cnf,data.formpanel_cnf);
	data.formpanel_cnf = default_formpanel_cnf;
	
	var btn_handler = function(btn) {
		
		win.callingHandler = true;
		
		var formpanel = win.getComponent('formpanel');
		if(!formpanel) { return; }
		
		var form = formpanel.getForm();
		var data = form.getFieldValues();
		
		var headers = {
			'X-RapidApp-CustomPrompt-Button': btn.text,
			'X-RapidApp-CustomPrompt-Data': Ext.encode(data)
		};
		
		// Recall the original request, adding in the customprompt header ata:
		var newopts = { headers: headers };
		//btn.ownerCt.ownerCt.close();
		win.close();
		return formpanel.success_callback(newopts);
	}
	
	var onEsc = null;
	
	// Custom buttons:
	var buttons = [];
	Ext.each(data.buttons,function(text) {
		var btn = {
			xtype: 'button',
			text: text,
			handler: btn_handler
		}
		
		if(data.EnterButton && data.EnterButton == text) {
			
			var click_fn = btn_handler.createCallback({text: text});
			
			btn.listeners = {
				click: click_fn,
				afterrender: function(b) {
					var fp = b.ownerCt.ownerCt;
					
					new Ext.KeyMap(fp.el, {
						key: Ext.EventObject.ENTER,
						shift: false,
						alt: false,
						fn: function(){ this.el.dom.click(); },
						scope: b
					});
					
				}
			}
		}
		
		if(data.EscButton && data.EscButton == text) {
			onEsc = btn_handler.createCallback({text:text});
		}
		else if(data.validate) {
			btn.formBind = true;
		}
		
		if(data.buttonIcons[text]) {
			btn.iconCls = data.buttonIcons[text];
		}
		
		buttons.push(btn);
	});
	
	// Cancel:
	if(!data.noCancel) {
		buttons.push({
			xtype: 'button',
			text: 'Cancel',
			handler: function(btn) {
				//btn.ownerCt.ownerCt.close();
				win.close();
			}
		});
	}
	
		
	var formpanel = {
		xtype: 'form',
		itemId: 'formpanel',
		autoScroll: true,
		//anchor: '100% 100%',
		items: data.items,
		buttons: buttons,
		success_callback: success_callback // <-- storing this here so we can use it in the btn handler
	};
	
	Ext.apply(formpanel,data.formpanel_cnf);
	
	var window_cnf = {
		manager: Ext.ux.RapidApp.CustomPromptWindowGroup,
		title: data.title,
		layout: 'fit',
		width: data.width,
		height: data.height,
		closable: true,
		modal: true,
		items: formpanel,
		listeners: {
			afterrender: function(w) {
				if(!data.focusField) { return; }
				var fp = w.getComponent('formpanel');
				var field = fp.getForm().findField(data.focusField);
				if(field) { field.focus('',10); field.focus('',200); field.focus('',500); }
			},
			beforeclose: function(w){
				if(onEsc && !w.callingHandler) { 
					w.callingHandler = true; 
					onEsc(); 
				}
			}
		}
	};
	
	if(data.noCancel && !onEsc) { window_cnf.closable = false; }

	win = new Ext.Window(window_cnf);
	win.show();
};




//Default for RapidApp::AuthCore plugin:
Ext.ux.RapidApp.loginUrl = '/auth/reauth';

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
    manager: Ext.ux.RapidApp.CustomPromptWindowGroup,
		title: "Session Expired",
		height: 220,
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

	nodeProperty: 'dataValue',
	
	buttonAlign: 'right',
	
	afterSelectHandler: Ext.emptyFn,
	afterSelectHandler_scope: null,
	
	initComponent: function() {
		
		// Handle an initial value:
		if(this.value) {
			var init_value = this.value.valueOf();
			delete this.value;
			this.on('afterrender',function(cmp) {
				cmp.setValue(init_value);
			});
		}
		
		this.buttons = [
			{
				text: 'Select',
				itemId: 'select',
				handler: function(btn) {
					var app = btn.ownerCt.ownerCt.getComponent('app').items.first();

					var data = this.select_handler(app);
					if(data === false) { return; }

					this.dataValue = data.value;

					this.setValue(data.display);
					btn.ownerCt.ownerCt.close();
					
					var scope = this;
					if(this.afterSelectHandler_scope) { scope = this.afterSelectHandler_scope; }
					this.afterSelectHandler.call(scope,data,app,arguments);
				},
				scope: this
			},
			{
				text: 'Cancel',
				handler: function(btn) {
					btn.ownerCt.ownerCt.close();
				}
			}
		];
		
		//this.setEditable(false);
				//console.dir(this);
		//this.constructor.superclass.constructor.prototype.initComponent.apply(this, arguments);
		Ext.ux.RapidApp.CustomPickerField.superclass.initComponent.apply(this, arguments);
	},

	getValue: function() {
		if (this.dataValue) { return this.dataValue; }
		return Ext.ux.RapidApp.CustomPickerField.superclass.getValue.apply(this, arguments);
	},

	setValue: function(val) {
		var new_val = val;
		if(this.setValue_translator) {
			new_val = this.setValue_translator(val,this);
		}
		Ext.ux.RapidApp.CustomPickerField.superclass.setValue.call(this, new_val);
	},

	getAutoLoad: function() {
		var autoLoad = {
			url: this.load_url
		};

		if (this[this.nodeProperty]) {
			autoLoad.params = {
				node: this[this.nodeProperty]
			};
		}
		
		return autoLoad;
	},
	
	getPickerApp: function() {
		var autoLoad = this.getAutoLoad();
		return {
			xtype: 'autopanel',
			itemId: 'app',
			autoLoad: autoLoad,
			layout: 'fit'
		};
	},
	
	onTriggerClick: function() {
		var win = new Ext.Window({
			Combo: this,
			buttonAlign: this.buttonAlign,
			title: this.win_title,
			layout: 'fit',
			width: this.win_width,
			height: this.win_height,
			closable: true,
			modal: true,
			items: this.getPickerApp(),
			buttons: this.buttons
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
		myInput.setAttribute("name", k);
		myInput.setAttribute("value", p[k]);
		myForm.appendChild(myInput);
	}
	document.body.appendChild(myForm);
	myForm.submit();
	document.body.removeChild(myForm);
};


// http://thomas.bindzus.me/2007/12/24/adding-dynamic-contents-to-iframes/
Ext.ns('Ext.ux.IFrame');
Ext.ux.IFrame = function (parentElement) {

   // Create the iframe which will be returned
   var iframe = document.createElement("iframe");
 
   // If no parent element is specified then use body as the parent element
   if(parentElement == null)
      parentElement = document.body;
 
   // This is necessary in order to initialize the document inside the iframe
   parentElement.appendChild(iframe);
 
   // Initiate the iframe's document to null
   iframe.doc = null;
 
   // Depending on browser platform get the iframe's document, this is only
   // available if the iframe has already been appended to an element which
   // has been added to the document
   if(iframe.contentDocument)
      // Firefox, Opera
      iframe.doc = iframe.contentDocument;
   else if(iframe.contentWindow)
      // Internet Explorer
      iframe.doc = iframe.contentWindow.document;
   else if(iframe.document)
      // Others?
      iframe.doc = iframe.document;
 
   // If we did not succeed in finding the document then throw an exception
   if(iframe.doc == null)
      throw "Document not found, append the parent element to the DOM before creating the IFrame";
 
   // Create the script inside the iframe's document which will call the
   iframe.doc.open();
   iframe.doc.close();
 
   // Return the iframe, now with an extra property iframe.doc containing the
   // iframe's document
   return iframe;
};

Ext.ns('Ext.ux.iFramePostwith');
Ext.ux.iFramePostwith = function (to,p) {
	
	// TODO: in order to detect the completion of the submit there will
	// need to be a server-side process to return js code with an 'onload'
	// event. In the mean time, we don't clean up ourselves, but we do
	// look for and cleanup previous calls. This is a hack-ish workaround
	var id = 'iframe-poster-global-element';
	var old_iframe = document.getElementById(id);
	if(old_iframe){
		document.body.removeChild(old_iframe);
	}
	
	var iframe = new Ext.ux.IFrame(document.body);
	iframe.id = id;
	
	var myForm = iframe.doc.createElement("form");
	myForm.method="post" ;
	myForm.action = to ;

	for (var k in p) {
		var v = (p[k] == null || typeof p[k] == 'undefined') ? '' : p[k];
		var myInput = iframe.doc.createElement("input") ;
		myInput.setAttribute("name", k);
		myInput.setAttribute("value", v);
		myForm.appendChild(myInput) ;
	}
	iframe.doc.body.appendChild(myForm) ;
	myForm.submit() ;
}


/* ####################################################### */
/* ####################################################### */

/*
 --- http://encosia.com/ajax-file-downloads-and-iframes/ ---
 This assumes that the content returned from 'url' will be "Content-disposition: attachment;"
 The purpose is to allow a background download operation that won't be
 cancelled if the user clicks around the app before the response comes back, (which 
 happens with Ext.ux.postwith) and also won't navigate the page if an error occurs during 
 the download. The downside of this is that nothing will be shown to the user if an error or 
 exception occurs, the download will just never happen. To address this limitation, see the 
 alternate method 'Ext.ux.RapidApp.winDownload' below (which has its own, different limitations)
 
 UPDATE: one limitation of this function is with long URLs since it uses a GET instead of a 
 POST. This will fail if the encoded URL is longer than ~2k characters
*/
Ext.ns('Ext.ux.iframeBgDownload');
Ext.ux.iframeBgDownload = function (url,params,timeout) {
	var timer, timeout = timeout || Ext.Ajax.timeout;
	
	if(params) { url += '?' + Ext.urlEncode(params); }
	
	var iframe = document.createElement("iframe");
	
	var cleanup = function() {
		if(timer) { timer.cancel(); } //<-- turn off the timeout timer
		var task = new Ext.util.DelayedTask(function(){
			document.body.removeChild(iframe);
		});
		// give the download dialog plenty of time to be displayed before we
		// remove the iframe:
		task.delay(2000); 
	};
	
	// Start the fail-safe timeout timer:
	// (we need this because we have no way of detecting an exception in the 
	// iframe load)
	timer = new Ext.util.DelayedTask(cleanup);
	timer.delay(timeout);
	
	// This event only gets fired in FireFox (12) for file downloads. IE and 
	// Chrome have to wait for the timeout, which is lame and sucks.
	iframe.onload = cleanup; //<-- cleanup as soon as the iframe load completes
	
	iframe.style.display = "none";
	iframe.src = url;
	document.body.appendChild(iframe); 
}

/*
 This is an alternative to Ext.ux.iframeBgDownload above that displays the download
 interactively in an Ext Window containing an iframe performing the download,
 with a nice loading indicator. In the event of an error or exception from the
 server side, the error output is displayed inline in the iframe.

 This function would be great if only it worked properly in IE and Chrome. It
 works great in FireFox (12), but in other browsers the iframe onload event isn't
 fired if the src is a file download. In those cases, the user has to close the
 download box manually after they receive the file. This is the tradeoff for having
 feedback on processing and errors. If that isn't worth it, and you are OK doing the
 download in the background and discard errors, use Ext.ux.iframeBgDownload instead.
*/
Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.winDownload = function (url,params,msg,timeout) {
	var timer, timeout = timeout || Ext.Ajax.timeout;
	msg = msg || 'Downloading File...';
	
	if(params) { url += '?' + Ext.urlEncode(params); }
	
	var win;
	
	var iframe = document.createElement("iframe");
	iframe.height = '100%';
	iframe.width = '100%';
	iframe.setAttribute("frameborder", '0');
	iframe.setAttribute("allowtransparency", 'true');
	iframe.src = url;
	
	var cleanup = function(){
		if(timer) { timer.cancel(); } //<-- turn off the timeout timer
		if(!win) { return; }
		win.hide(); // <-- hide immediately
		
		var task = new Ext.util.DelayedTask(function(){
			win.close()
		});
		// give the download dialog plenty of time to be displayed before we
		// actually close/destroy the window and iframe:
		task.delay(2000); 
	};
	
	// Unfortunately, this event is only fired in FireFox if it is a
	// file download. In IE and Chrome, it never gets fired and so the
	// window never gets hidden. The user has to close the dialog box
	// themselves.
	iframe.onload = cleanup;
	
	// Silently close the window after timeout. TODO: add an option to
	// update the window/iframe contents with a message instead. That would
	// only be useful in FireFox, since in other browsers we have no way of
	// knowing if the download was successful once the timeout is reached.
	timer = new Ext.util.DelayedTask(cleanup);
	timer.delay(timeout);
	
	win = new Ext.Window({
		title: msg,
		modal: true,
		closable: false,
		width: 400,
		height: 225,
		bodyCssClass: 'loading-background',
		buttonAlign: 'center',
		buttons:[{
			width: 150,
			text: 'Close',
			iconCls: 'ra-icon-cross',
			handler: function(){ win.hide(); win.close(); }
		}],
		listeners: {
			beforeclose: function(){
				if(timer) { timer.cancel(); } //<-- turn off the timeout timer
			}
		},
		contentEl: iframe
	});

	win.show();
}

/*
 Another, simple download function but uses a self-closing (browser) window. 
 Again, assumes url is a file download. This is just left in for reference, 
 because it is rough looking. See Ext.ux.RapidApp.winDownload above which uses 
 an Ext Window and has better error handling and control
*/
Ext.ns('Ext.ux.winIframeDownload');
Ext.ux.winPostwith = function (url,params) {
	if(params) { url += '?' + Ext.urlEncode(params); }
	return window.open(
		url,"winDownload", 
		"height=100,width=200," +
		"menubar=no,status=no,location=no,toolbar=no,resizable=no"
	);
}
/* ####################################################### */
/* ####################################################### */


Ext.ns('Ext.ux.Bool2yesno');
Ext.ux.Bool2yesno = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	if (val > 0) { return 'Yes'; }
	return 'No';
}


Ext.ns('Ext.ux.showNull');
Ext.ux.showNull = function(val) {
	if (val == null) { return '<span class="ra-null-val">(not&nbsp;set)</span>'; }
	if (val === "") { return '<span class="ra-null-val">(empty&nbsp;string)</span>'; }
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
 * @cfg {Boolean} disableBtn disables the button once clicked - note:
                             uncaught exceptions from the server will
                             cause the button to never be re-enabled
 * @cfg {String} disableBtnText Text to set in the 'Save' button when disabled
 * @cfg {Array} extra_buttons List of any additional buttons
*/
Ext.ns('Ext.ux.RapidApp.WinFormPost');
Ext.ux.RapidApp.WinFormPost = function(cfg) {

  var rand = Math.floor(Math.random()*100000);
  var winId = 'win-' + rand;
  var formId = 'winformpost-' + rand;
  
  Ext.applyIf(cfg,{
    title: '',
    height: 400,
    width: 350,
    params: {},
    valuesParamName: 'json_form_data',
    submitBtnText: 'Save',
    cancelHandler: Ext.emptyFn,
    closable: true,
    disableBtnText: 'Wait...'
  });

  cfg.extra_buttons = cfg.extra_buttons || [];
  
	var cancel_fn = function(){ Ext.getCmp(winId).close(); cfg.cancelHandler(); }
	
	cfg.fieldset['anchor'] = '100% 100%';

	var scope = this;

	var success_fn = function(response,options) {
		Ext.getCmp(winId).close();
		// Call the success function if it was passed in the cfg:
		if (cfg.success) { cfg.success.apply(scope,arguments); }
		
		var call_args = arguments;
		
		// Call additional specified success callbacks. These can be functions outright,
		// or objects containing a custom scope and handler:
		if(Ext.isArray(cfg.success_callbacks)) {
			Ext.each(cfg.success_callbacks,function(item) {
				if(Ext.isFunction(item)) {
					//call the function with the same scope as
					item.apply(scope,call_args);
				}
				else if(Ext.isObject(item)) {
					if(item.scope && item.handler) {
						//call the handler with the custom provided scope:
						item.handler.apply(item.scope,call_args);
					}
				}
			});
		}
		
		if (cfg.eval_response && response.responseText) { return eval(response.responseText); }
	};
  
  var Btn;
  Btn = new Ext.Button({
    text	: cfg.submitBtnText,
    handler	: function(btn) {
      if(cfg.disableBtn) {
        btn.setDisabled(true);
        btn.setText(cfg.disableBtnText);
      }
      
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
  });

	var failure_fn = function(response,options) {
    // Re-enable the button (only applies with disableBtn option)
    Btn.setDisabled(false);
    Btn.setText(cfg.submitBtnText);
    if (cfg.failure) { cfg.failure.apply(scope,arguments); }
  };


  var win_buttons = cfg.extra_buttons.concat([
    Btn,
    {
      text    : 'Cancel',
      handler  : cancel_fn,
      itemId : 'cancel'
    }
  ]);

	var win = new Ext.Window({
		manager: cfg.manager,
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
			buttons: win_buttons,
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
				iconCls:'ra-icon-zoom',
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


/* 2011-01-28 by HV:
 Extended Saki's Ext.ux.form.DateTime to updateValue on 'select' and then 
 fire the new event 'updated'
*/
Ext.ns('Ext.ux.RapidApp.form');
Ext.ux.RapidApp.form.DateTime2 = Ext.extend(Ext.ux.form.DateTime ,{
  onTriggerClick: function() {
    this.df.onTriggerClick();
  },
	initComponent: function() {
    
    // Pass in the 'allowBlank' flag because it is used by RapidApp
    // for extra logic, like rendering of select '(None)'
    if(typeof this.allowBlank !== 'undefined') {
      this.dateConfig = this.dateConfig || {};
      this.dateConfig.allowBlank = this.allowBlank;
    }
  
		Ext.ux.RapidApp.form.DateTime2.superclass.initComponent.call(this);
		this.addEvents( 'updated' );
		this.on('change',this.updateValue,this);
		this.on('select',this.updateValue,this);
		this.relayEvents(this.df, ['change','select']);
		this.relayEvents(this.tf, ['change','select']);
		this.setMinMax();
	},
	
	setMinMax: function(newDate) {
		
		if (this.minValue) {
			var val = this.minValue;
			var dt = Date.parseDate(val, this.hiddenFormat);
			this.df.setMinValue(dt);
			
			if (newDate && newDate.getDayOfYear() != dt.getDayOfYear()) {
				this.setTimeFullRange();
			}
			else {
				this.tf.setMinValue(dt);
			}
		}
		if (this.maxValue) {
			var val = this.maxValue;
			var dt = Date.parseDate(val, this.hiddenFormat);
			this.df.setMaxValue(dt);
			
			if (newDate && newDate.getDayOfYear() != dt.getDayOfYear()) {
				this.setTimeFullRange();
			}
			else {
				this.tf.setMaxValue(dt);
			}
		}
	},
	
	setTimeFullRange: function() {
		var MaxDt = new Date();
		MaxDt.setHours(23);
		MaxDt.setMinutes(59);
		MaxDt.setSeconds(59);
		this.tf.setMaxValue(MaxDt);
		
		var MinDt = new Date();
		MinDt.setHours(0);
		MinDt.setMinutes(0);
		MinDt.setSeconds(0);
		this.tf.setMinValue(MinDt);
	},
	
	updateValue: function(cmp,newVal) {
		Ext.ux.RapidApp.form.DateTime2.superclass.updateValue.call(this);
		
		var newDate = null;
		if(newVal && newVal.getDayOfYear) { newDate = newVal; }
		
		this.setMinMax(newDate);
		this.fireEvent('updated',this);
	},
  
  // New: return formatted date string instead of Date object
  // this prevents the system seeing the value as changed when
  // it hasn't and producing a db update
  getValue: function() {
    this.updateValue();
    var dt = this.dateValue ? new Date(this.dateValue) : null;

    // --- NEW: check to see if the formatted date+time value (i.e. the only section
    // of the value the user has access to modify) has actually changed since it
    // was set, and if it hasn't, return the original set value. This prevents us
    // from changing the time portion val of '12:23:45' to '12:23:00' by accident when the
    // timeFormat does not contain the 'seconds' field. We test that '12:23' == '12:23'
    // and then return the original, internally stored value '12:23:45' (which keeps
    // the field from changing in the datastore and triggering a server update)
    if(dt && Ext.isString(this._rawLastSetValue)) {
      var lDt = Date.parseDate(this._rawLastSetValue, this.hiddenFormat);
      if(lDt) {
        var dispFormat = [this.dateFormat,this.timeFormat].join(' ');
        if(dt.format(dispFormat) == lDt.format(dispFormat)) {
          return this._rawLastSetValue;
        }
      }
    }
    // ---

    return dt ? dt.format(this.hiddenFormat) : '';
  },

  setValue: function(val) {
    this._rawLastSetValue = val;
    return Ext.ux.RapidApp.form.DateTime2.superclass.setValue.call(this,val);
  },
  
  // The TimeField is a combo, so we need to pass in calls to assertValue(), which
  // is called by the EditorGrid when hitting ENTER, TAB, etc. Without this, hitting
  // ENTER after manually typing a time value will not persist the change. We also
  // needed to call updateValue() before getValue (see above) for this to work.
  assertValue: function() {
    this.tf.assertValue();
  }
});
Ext.reg('xdatetime2', Ext.ux.RapidApp.form.DateTime2);


/*
 Creates a "tool" button just like the tools from "tools" in Ext.Panel
 Inspired by: http://www.sencha.com/forum/showthread.php?119956-use-x-tool-close-ra-icon-in-toolbar&highlight=tool+button
*/
Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.ClickBox = Ext.extend(Ext.BoxComponent, {

	cls: null,
	overCls: null,
	qtip: null,
	handler: function(){},
	scope: null,
	initComponent: function() {
		
		if(!this.scope) {
			this.scope = this;
		}
		
		this.autoEl = {};
		if(this.cls) { 
			this.autoEl.cls = this.cls;
		}
		if(this.qtip) { 
			this.autoEl['ext:qtip'] = this.qtip; 
		}
		
		Ext.ux.RapidApp.ClickBox.superclass.initComponent.call(this);
		
		this.on('afterrender',function(box) {
		 	var el = box.getEl();
			if(this.overCls) {
				el.addClassOnOver(this.overCls);
			}
			el.on('click', this.handler, this.scope, box);
		},this);
	}
});
Ext.reg('clickbox', Ext.ux.RapidApp.ClickBox);

Ext.ux.RapidApp.BoxToolBtn = Ext.extend(Ext.ux.RapidApp.ClickBox, {

	toolType: 'gear',

	initComponent: function() {
		
    var cls = this.cls;
		this.cls = 'x-tool x-tool-' + this.toolType;
    if(cls){ this.cls += ' ' + cls; }
		this.overCls = 'x-tool-' + this.toolType + '-over';
		if(this.toolQtip) { this.qtip = this.toolQtip; }
		
		Ext.ux.RapidApp.BoxToolBtn.superclass.initComponent.call(this);
	}
});
Ext.reg('boxtoolbtn', Ext.ux.RapidApp.BoxToolBtn);



Ext.ux.RapidApp.ComponentDataView = Ext.extend(Ext.ux.ComponentDataView,{
	initComponent: function() {
		Ext.each(this.items,function(item) {
			item.ownerCt = this;
		},this);
		Ext.ux.RapidApp.ComponentDataView.superclass.initComponent.call(this);
	}
});
Ext.reg('rcompdataview', Ext.ux.RapidApp.ComponentDataView);

Ext.ux.RapidApp.renderUtcDate= function(dateStr) {
	try {
		var dt= new Date(Date.parseDate(dateStr, "Y-m-d g:i:s"));
		var now= new Date();
		var utc= dt.getTime();
		dt.setTime(utc + Ext.ux.RapidApp.userPrefs.timezoneOffset*60*1000);
		var fmt= (now.getTime() - dt.getTime() > 1000*60*60*24*365)? Ext.ux.RapidApp.userPrefs.dateFormat : Ext.ux.RapidApp.userPrefs.nearDateFormat;
		return '<span class="RapidApp-dt"><s>'+utc+'</s>'+dt.format(fmt)+'</span>';
	} catch (err) {
		return dateStr + " GMT";
	}
}




/*  Ext.ux.RapidApp.AjaxCmp
 Works like Ext.ux.AutoPanel except renders directly to the
 Element object instead of being added as an item to the
 Container
*/
Ext.ux.RapidApp.AjaxCmp = Ext.extend(Ext.Component, {
	
	autoLoad: null,
	
	applyCnf: {},
	
	// deleteId: If set to true the ID of the dynamically fetched
	// component will be deleted before its created
	deleteId: false,
	
	initComponent: function() {
		if(!Ext.isObject(this.autoLoad)) { throw 'autoLoad must be an object' };
		if(!Ext.isObject(this.applyCnf)) { throw 'applyCnf must be an object' };
		
		this.ajaxReq = {
			disableCaching: true,
			success: function(response, opts) {
				if(response.responseText) { 
					var cmpconf = Ext.decode(response.responseText);
					if(!Ext.isObject(cmpconf)) { throw 'responseText is not a JSON encoded object'; }
					
					// preserve plugins:
					if (Ext.isArray(cmpconf.plugins) && Ext.isArray(this.applyCnf.plugins)) {
						Ext.each(cmpconf.plugins,function(plugin) {
							this.applyCnf.plugins.push(plugin);
						},this);
					}
					
					Ext.apply(cmpconf,this.applyCnf);
					cmpconf.renderTo = this.getEl();
					
					if(this.deleteId && cmpconf.id) { delete cmpconf.id };
					
					var Cmp = Ext.ComponentMgr.create(cmpconf,'panel');
					this.component = Cmp;
					Cmp.relayEvents(this,this.events);
					Cmp.show();
				}
			},
			scope: this
		};
		Ext.apply(this.ajaxReq,this.autoLoad);
		
		this.on('afterrender',function() {
			Ext.Ajax.request(this.ajaxReq);
		},this);
		Ext.ux.RapidApp.AjaxCmp.superclass.initComponent.apply(this, arguments);
	}
});
Ext.reg('ajaxcmp',Ext.ux.RapidApp.AjaxCmp);

/* 
 This works just like checkbox except it renders a simple div and toggles a class
 instead of using a real "input" type=checkbox element. I needed to create this because
 I couldn't get normal checkbox to work properly within AppDV - 2011-05-29 by HV
*/
Ext.ux.RapidApp.LogicalCheckbox = Ext.extend(Ext.form.Checkbox,{
	defaultAutoCreate : { tag: 'div', cls: 'x-logical-checkbox ra-icon-checkbox-clear' },
	
	onRender: function(ct, position) {
		if(this.value == "0") { this.value = false; }
		if(typeof this.value !== 'undefined') { this.checked = this.value ? true : false; }
		Ext.ux.RapidApp.LogicalCheckbox.superclass.onRender.apply(this,arguments);
	},
	
	setValue: function(v) {
		Ext.ux.RapidApp.LogicalCheckbox.superclass.setValue.apply(this,arguments);
		if (v) {
			this.el.replaceClass('ra-icon-checkbox-clear','ra-icon-checkbox');
		}
		else {
			this.el.replaceClass('ra-icon-checkbox','ra-icon-checkbox-clear');
		}
	},
	onClick: function() {
		if (this.checked) {
			this.setValue(false);
		}
		else {
			this.setValue(true);
		}
	}
});
Ext.reg('logical-checkbox',Ext.ux.RapidApp.LogicalCheckbox);


/*
 Ext.ux.RapidApp.menu.ToggleSubmenuItem
 2011-06-08 by HV

 Works like Ext.menu.Item, except the submenu (if defined) is not displayed on mouse-over.
 The item has to be clicked to display the submenu, and then it stays displayed until the item
 is clicked a second time or if the user clicks outside the menu. This is in contrast to the
 normal Item submenu behavior which operates on mouse-over and disapears if you accidently
 move the mouse outside the border of the item and the menu (which is really easy to do when
 you move the cursor from the item to the menu, and is very frustrating to users).

 This class also provides a loading icon feature which will convert the item icon into a loading
 spinner icon after the item is clicked until the sub menu is shown. This is useful because it
 can sometimes take several seconds to show the menu when there are are lot of items.

 If there is no 'menu' or if a handler is defined, this class behaves exactly the same as
 Ext.menu.Item
*/
Ext.ns('Ext.ux.RapidApp.menu');
Ext.ux.RapidApp.menu.ToggleSubmenuItem = Ext.extend(Ext.menu.Item,{
	
	submenuShowPending: false,
	showMenuLoadMask: null,
	loadingIconCls: 'ra-icon-loading', // <-- set this to null to disable the loading icon feature
	
	initComponent: function() {
		if(this.menu && !this.handler) {
			
			this.itemCls = 'x-menu-item x-menu-item-arrow';
			
			this.origMenu = this.menu;
			delete this.menu;
			
			if (typeof this.origMenu.getEl != "function") {
				this.origMenu = new Ext.menu.Menu(this.origMenu);
			}
			
			this.origMenu.on('show',this.onSubmenuShow,this);
			this.origMenu.allowOtherMenus = true;
			
			this.handler = function(btn) {
				if(this.submenuShowPending) { return; }
				
				if(this.origMenu.isVisible()) {
					this.origMenu.hide();
					this.setShowPending(false);
				}
				else {
					this.setShowPending(true);
					this.origMenu.show.defer(100,this.origMenu,[btn.getEl(),'tr?']);
				}
			}
      
      this.on('afterrender',this.hookParentMenu,this);
		}
		Ext.ux.RapidApp.menu.ToggleSubmenuItem.superclass.initComponent.call(this);
	},
  
  // Manually hook into the parent menu and hide when it does. We broke
  // ties with the parent menu on purpose to achieve the toggle functionality
  // so we need to manually reconnect with the hide event
  hookParentMenu: function() {
    if(this.parentMenu) {
      this.parentMenu.on('hide',this.origMenu.hide,this.origMenu);
    }
  },
	
	onSubmenuShow: function() {
		this.setShowPending(false);
	},
	
	setShowPending: function(val) {
		if(val) {
			this.submenuShowPending = true;
			if(this.loadingIconCls) {
				this.setIconClass(this.loadingIconCls);
			}
		}
		else {
			this.submenuShowPending = false;
			if(this.loadingIconCls) {
				this.setIconClass(this.initialConfig.iconCls);
			}
		}
	}
});
Ext.reg('menutoggleitem',Ext.ux.RapidApp.menu.ToggleSubmenuItem);


/*

Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.GridSelectSetDialog = Ext.extend(Ext.Window, {

	grid: null,
	initSelectedIds: [],
	
	//private:
	selectedIdMap: {},
	localGrid: null,
	localFields: null,
	localStore: null,
		
	layout: 'hbox',
	layoutConfig: {
		align: 'stretch',
		pack: 'start'
	},
		
	initComponent: function() {
		
		this.selectedIdMap = {};
		Ext.each(this.initSelectedIds,function(id){
			this.selectedIdMap[id] = true;
		},this);
		
		var grid = this.grid;
		var cmConfig = grid.getColumnModel().config;
		
		this.localFields = [];
		
		Ext.each(cmConfig,function(item) {
			this.localFields.push({ name: item.dataIndex });
		},this);
		
		this.localStore = new Ext.data.JsonStore({ fields: this.localFields });
		
		var cmp = this;
		
		this.localGrid = {
			flex: 1,
			xtype: 'grid',
			store: this.localStore,
			columns: cmConfig,
			autoExpandColumn: grid.autoExpandColumn,
			viewConfig: grid.viewConfig,
			listeners: {
				rowdblclick: function(grid,index,e) {
					var Record = grid.getStore().getAt(index);
					cmp.unSelect(Record);
				}
			}
		};
		
		grid.flex = 1;
		
		this.items = [
			this.localGrid,
			grid
		];
		
		grid.getStore().on('load',this.applyFilter,this);
		
		grid.on('rowdblclick',function(grid,index,e) {
			var Record = this.grid.getStore().getAt(index);
			this.addSelected(Record);
		},this);
		
		Ext.ux.RapidApp.GridSelectSetDialog.superclass.initComponent.call(this);
	},
	
	applyFilter: function() {
		var Store = this.grid.getStore();
		Store.filter([{
			fn: function(Record) {
				return ! this.selectedIdMap[Record.get(Store.idProperty)];
			},
			scope: this
		}]);
	},
	
	addSelected: function(Record) {
		var Store = this.grid.getStore();
		this.localStore.add(Record);
		this.selectedIdMap[Record.data[Store.idProperty]] = true;
		this.applyFilter();
	},
	
	unSelect: function(Record) {
		var Store = this.grid.getStore();
		this.localStore.remove(Record);
		delete this.selectedIdMap[Record.data[Store.idProperty]];
		this.applyFilter();
	}
	
});
Ext.reg('grid-selectset-dialog',Ext.ux.RapidApp.GridSelectSetDialog);

*/



Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.AppGridSelector = Ext.extend(Ext.Container, {

	grid: null,
	initSelectedIds: [],
	
	dblclickAdd: true,
	dblclickRemove: false,
	
	leftTitle: 'Selected',
	leftIconCls: 'ra-icon-checkbox-yes',
	rightTitle: 'Not Selected',
	rightIconCls: 'ra-icon-checkbox-no',
	
	showCountsInTitles: true,
	
	baseParams: {},
	
	//private:
	selectedIdMap: {},
	localGrid: null,
	localFields: null,
	localStore: null,
		
	// Emulate border layout:
	style: { 'background-color': '#f0f0f0' },
		
	layout: 'hbox',
	layoutConfig: {
		align: 'stretch',
		pack: 'start'
	},

	initComponent: function() {
		
		this.addEvents( 'selectionsave' );
		
		var cmp = this;
		
		this.selectedIdMap = {};
		Ext.each(this.initSelectedIds,function(id){
			this.selectedIdMap[id] = true;
		},this);
		
		var grid = this.grid;
		var cmConfig = grid.getColumnModel().config;
		var store = grid.getStore();

		this.localFields = [];
		
		Ext.each(cmConfig,function(item) {
			this.localFields.push({ name: item.dataIndex });
		},this);
		
		this.localStore = new Ext.data.JsonStore({ 
			fields: this.localFields,
			api: store.api,
			listeners: {
				beforeload: function(Store,opts) {
					Store.baseParams['id_in'] = Ext.encode(cmp.getSelectedIds());
				}
			}
		});
		
		//Apply any baseParams to the store:
		Ext.iterate(this.baseParams,function(k,v) {
			this.localStore.setBaseParam(k,v);
			store.setBaseParam(k,v);
		},this);
		
		this.on('afterrender',function(){ this.localStore.load(); },this);
		
		this.localGrid = new Ext.grid.GridPanel({
			xtype: 'grid',
			store: this.localStore,
			columns: cmConfig,
			autoExpandColumn: grid.autoExpandColumn,
			enableHdMenu: false,
			enableColumnMove: false,
			viewConfig: grid.viewConfig
		});
		
		this.addButton = new Ext.Button({
			text: 'Add',
			iconCls: 'ra-icon-arrow-left',
			iconAlign: 'left',
			handler: function() {
				cmp.addRowsSelected.call(cmp);
			},
			disabled: true
		});
		
		this.removeButton = new Ext.Button({
			text: 'Remove',
			iconCls: 'ra-icon-arrow-right',
			iconAlign: 'right',
			handler: function() {
				cmp.removeRowsSelected.call(cmp);
			},
			disabled: true
		});
		
		this.items = [
			{
				
				itemId: 'left-panel',
				title: this.leftTitle,
				iconCls: this.leftIconCls,
				flex: 1,
				layout: 'fit',
				hideBorders: true,
				items: this.localGrid,
				margins:{
					top: 0,
					right: 5,
					bottom: 0,
					left: 0
				},
				buttons: [
					this.removeButton,
					' ',' ',' ' // <-- spacing
				]
			},
			{
				itemId: 'right-panel',
				title: this.rightTitle,
				iconCls: this.rightIconCls,
				flex: 1,
				layout: 'fit',
				hideBorders: true,
				items: grid,
				buttonAlign: 'left',
				buttons: [
					' ',' ',	' ', // <-- spacing
					this.addButton,
					'->',
					{
						text: 'Save & Close',
						handler: function() {
							cmp.fireEvent('selectionsave',cmp.getSelectedIds());
							cmp.tryClosePage();
						}
					},
					{
						text: 'Cancel',
						handler: function() {
							cmp.tryClosePage();
						}
					}
				]
			}
		];
		
		store.on('load',this.applyFilter,this);
			
		if(this.dblclickRemove) {
			this.localGrid.on('rowdblclick',function(grid,index,e) {
				var Record = grid.getStore().getAt(index);
				cmp.unSelect(Record);
			},this);
		}
		
		if(this.dblclickAdd) {
			grid.on('rowdblclick',function(grid,index,e) {
				var Record = this.grid.getStore().getAt(index);
				this.addSelected(Record);
			},this);
		}
		
		var localSelMod = this.localGrid.getSelectionModel();
		var selMod = this.grid.getSelectionModel();
		
		localSelMod.on('selectionchange',this.onSelectionChange,this);
		selMod.on('selectionchange',this.onSelectionChange,this);
		
		// When one grid is clicked clear the other:
		localSelMod.on('rowselect',function(){ selMod.clearSelections(); },this);
		selMod.on('rowselect',function(){ localSelMod.clearSelections(); },this);
		
		Ext.ux.RapidApp.AppGridSelector.superclass.initComponent.call(this);
	},
	
	applyFilter: function() {
		var Store = this.grid.getStore();
		Store.filter([{
			fn: function(Record) {
				return ! this.selectedIdMap[Record.get(Store.idProperty)];
			},
			scope: this
		}]);
		this.updateTitleCounts();
	},
	
	addRowsSelected: function() {
		var sm = this.grid.getSelectionModel();
		Ext.each(sm.getSelections(),function(Record) {
			this.addSelected(Record);
		},this);
	},
	
	removeRowsSelected: function() {
		var sm = this.localGrid.getSelectionModel();
		Ext.each(sm.getSelections(),function(Record) {
			this.unSelect(Record);
		},this);
	},
	
	addSelected: function(Record) {
		var Store = this.grid.getStore();
		this.localStore.add(Record);
		this.selectedIdMap[Record.data[Store.idProperty]] = true;
		this.applyFilter();
	},
	
	unSelect: function(Record) {
		var Store = this.grid.getStore();
		this.localStore.remove(Record);
		delete this.selectedIdMap[Record.data[Store.idProperty]];
		this.applyFilter();
	},
	
	getSelectedIds: function() {
		var ids = [];
		Ext.iterate(this.selectedIdMap,function(k,v){
			if(v) { ids.push(k); }
		},this);
		return ids;
	},
	
	onSelectionChange: function(sm) {
		this.leftSelectionCheck.call(this);
		this.rightSelectionCheck.call(this);
	},
	
	leftSelectionCheck: function() {
		var sm = this.localGrid.getSelectionModel();
		this.removeButton.setDisabled(!sm.hasSelection());
	},
	
	rightSelectionCheck: function() {
		var sm = this.grid.getSelectionModel();
		this.addButton.setDisabled(!sm.hasSelection());
	},
	
	tryClosePage: function() {
		if (! this.ownerCt) { return; }
		if (this.ownerCt.closable) { return this.ownerCt.close(); }
		if (! this.ownerCt.ownerCt) { return; }
		if (this.ownerCt.ownerCt.closable) { return this.ownerCt.ownerCt.close(); }
	},
	
	getSelectedCount: function() {
		var count = 0;
		Ext.iterate(this.selectedIdMap,function() { count++; });
		return count;
	},
	
	updateTitleCounts: function() {
		if(! this.showCountsInTitles) { return; }
		
		var total = this.grid.getStore().getTotalCount();
		var selected = this.getSelectedCount();
		var adjusted = total - selected;
		
		this.getComponent('left-panel').setTitle(this.leftTitle + ' (' + selected + ')');
		
		var right_panel = this.getComponent('right-panel');
		if(selected > total) {
			right_panel.setTitle(this.rightTitle);
		}
		else {
			right_panel.setTitle(this.rightTitle + ' (' + adjusted + ')');
		}
	}
	
});
Ext.reg('appgridselector',Ext.ux.RapidApp.AppGridSelector);

Ext.ux.RapidApp.PagingToolbar = Ext.extend(Ext.PagingToolbar,{

	allowChangePageSize: true,
	maxPageSize: 500,
  enableOverflow: true,


	initComponent: function() {
    this.layout = 'ra_toolbar';

		if(this.allowChangePageSize) {

			var paging = this;
			
			var suffix_str = '/<span style="font-size:.9em;vertical-align:top;">' +
				'page' +
			'</span>';

			this.pageSizeField = new Ext.form.NumberField({
				itemCls: 'rapp-margin-bottom-0',
				fieldLabel: 'Items per page',
				width: 35,
				maxValue: this.maxPageSize,
				minValue: 1,
				regex: /^\d+$/, // <-- only allow integers
				enableKeyEvents:true,
				listeners:{
					keyup:{
						buffer: 150,
						fn: function(field, e) {
							if (Ext.EventObject.ENTER == e.getKey()){
								if(field.validate()) {
									var size = field.getValue();
									if (size != paging.pageSize) {
										paging.pageSize = size;
                    paging.pageSizeButton.setText(size + suffix_str);
										paging.doLoad();
                    var ovrMenu = field.ownerCt.parentMenu;
                    // Handle special overflow case: hide the menu
                    if(ovrMenu) {
                      ovrMenu.hide();
                    }
									}
									field.ownerCt.hide();
								}
								else {
									field.markInvalid();
								}
							}
						}
					}
				}
			});

			var orig_text = this.beforePageText;
			if(paging.pageSize) { orig_text = paging.pageSize + suffix_str; }
			
			this.pageSizeButton = new Ext.Button({
				text: orig_text,
				style: 'font-size:.9em;',
				menu: {
					layout: 'form',
					showSeparator: false,
					labelAlign: 'right',
					labelWidth: 90,
					items: this.pageSizeField,
					listeners: {
						beforeshow: function(menu) {
							//Disable the menu keyNav to allow arrow keys to work in fields within the menu:
							if(menu.keyNav){ menu.keyNav.disable(); }
							paging.pageSizeField.setValue(paging.pageSize);
						},
						show: function() {
							paging.pageSizeField.focus('',200);
						}
					}
				}
			});
		}
		
		
		this.beforePageText = '';
		this.displayMsg = '{0} - {1} of <span style="font-size:1.1em;color:#083772;">{2}</span>';
		
		// place the query time label immediately after 'refresh'
		this.prependButtons = false;
		this.items = this.items || [];
		paging.queryTimeLabel = new Ext.Toolbar.TextItem({
			text: '',
      cls: 'ra-grid-tb-query-time'
		});
		this.items.unshift(paging.queryTimeLabel);
		
		Ext.ux.RapidApp.PagingToolbar.superclass.initComponent.call(this);
		
    this.insert(this.items.getCount() - 1,this.pageSizeButton,' ');
		
		this.store.on('load',function(store) {
			if(store.reader && store.reader.jsonData) {
				//'query_time' is returned from the server, see DbicLink2
				var query_time = store.reader.jsonData.query_time;
				if(query_time) {
					paging.queryTimeLabel.setText('query&nbsp;time ' + query_time);
				}
				else {
					paging.queryTimeLabel.setText('');
				}
			}
      this.autoSizeInputItem();
		},this);
		
		this.store.on('exception',function(store) {
			paging.queryTimeLabel.setText('--');
		},this);

    // --- NEW: update paging counts in-place (Github Issue #18)
    this.store.on('add',function(store,records,index) {
      this.store.totalLength = this.store.totalLength + records.length;
      this.updateInfo();
    },this);

    this.store.on('remove',function(store,record,index) {
      this.store.totalLength--;
      this.updateInfo();
    },this);
    // ---

    this.inputItem.on('afterrender',this.autoSizeInputItem,this);
    this.inputItem.on('keydown',this.autoSizeInputItem,this,{buffer:20});
    this.inputItem.on('blur',this.autoSizeInputItem,this);
    this.on('change',this.onPageDataChange,this);
	},

  doRefresh: function() {
    // Added for Github Issue #13
    // Special handling for DataStorePlus cached total counts. Clear
    // it whenever the user manually clicks 'Refresh' in the toolbar
    if(this.store.cached_total_count) {
      delete this.store.cached_total_count;
    }
    return Ext.ux.RapidApp.PagingToolbar.superclass.doRefresh.apply(this,arguments);
  },

  // NEW: override private method 'updateInfo()' to commify values 
  // (Added for Github Issue #15)
  updateInfo : function(){
    if(this.displayItem){
      var count = this.store.getCount();
      var msg = count == 0 ?
        this.emptyMsg :
        String.format(
          this.displayMsg,
          Ext.util.Format.number(this.cursor+1,'0,000'), 
          Ext.util.Format.number(this.cursor+count,'0,000'), 
          Ext.util.Format.number(this.store.getTotalCount(),'0,000')
        );
      this.displayItem.setText(msg);
    }
  },

  // Sets the width of the input (current page) dynamically
  autoSizeInputItem: function() {
    var val = this.inputItem.getValue();
    // 14px wide, plus 6px for each character:
    var size = 14 + (6 * [val].join('').length);
    if (size < 20) { size = 20; }
    // Max width 60px (enough for 8 digits)
    if (size > 60) { size = 60; }
    this.inputItem.setWidth(size);
    this.syncSize();
  },

  onPageDataChange: function(tb,d) {
    // Set the "afterPageText" again, but this time commified:
    this.afterTextItem.setText(String.format(
      this.afterPageText,
      Ext.util.Format.number(d.pages,'0,000')
    ));

    // Update the max value of the input item:
    this.inputItem.setMaxValue(d.pages);
    
    this.syncSize();
  }

});
Ext.reg('rapidapp-paging',Ext.ux.RapidApp.PagingToolbar);


Ext.ux.RapidApp.IconClsRenderFn = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	//return '<div style="width:16px;height:16px;" class="' + val + '"></div>';
	return '<div class="with-icon ' + val + '">' + val + '</div>';
}


/********************************************************************/
/***********  -- vvv -- Ext.ux.grid.PropertyGrid -- vvv -- **********/

/* http://www.extjs.com/forum/showthread.php?t=41390 */
Ext.namespace('Ext.ux.grid');
Ext.ux.grid.PropertyRecord = Ext.data.Record.create([
    {name:'name',type:'string'}, 'value', 'header', 'field'
]);

Ext.ux.grid.PropertyStore = function(grid, source){
    this.grid = grid;
    this.store = new Ext.data.Store({
        recordType : Ext.grid.PropertyRecord
    });

        this.store.loadRecords = function(o, options, success){
        if(!o || success === false){
            if(success !== false){
                this.fireEvent("load", this, [], options);
            }
            if(options.callback){
                options.callback.call(options.scope || this, [], options, false);
            }
            return;
        }

        var r = o.records, t = o.totalRecords || r.length;

        if(!options || options.add !== true){
            if(this.pruneModifiedRecords){
                this.modified = [];
            }

            for(var i = 0, len = r.length; i < len; i++){
                r[i].join(this);
            }

            if(this.snapshot){
                this.data = this.snapshot;
                delete this.snapshot;
            }

            this.data.clear();
            this.data.addAll(r);
            this.totalLength = t;
            //this.applySort();
            this.fireEvent("datachanged", this);

        }else{
            this.totalLength = Math.max(t, this.data.length+r.length);
            this.add(r);
        }

        this.fireEvent("load", this, r, options);

        if(options.callback){
            options.callback.call(options.scope || this, r, options, true);
        }
    };

    this.store.on('update', this.onUpdate,  this);
    if(source){
        this.setSource(source);
    }

    Ext.ux.grid.PropertyStore.superclass.constructor.call(this);
};

Ext.extend(Ext.ux.grid.PropertyStore, Ext.util.Observable, {
    setSource : function(o,fields){
        this.source = o;
        // -- removed by HV -- 
        // this doesn't seem to be needed and causes the page to jump around:
        //this.store.removeAll();
        var data = [];

        if (fields) {
            for (var k in fields) {
                k=fields[k];
                if (typeof(k) == 'object'){
                //if (k.id && this.isEditableValue(o[k.dataIndex])) {
                    data.push(new Ext.grid.PropertyRecord({
                        name: k.dataIndex,
                        value: o[k.dataIndex],
                        header: k.header,
                        field: k
                    }, k.id));
                }
            }
        } else {
            for (var k in o) {
                if (this.isEditableValue(o[k])) {
                    data.push(new Ext.grid.PropertyRecord({
                        name: k,
                        value: o[k],
                        header: k
                    }, k));
                }
            }
        }
        this.store.loadRecords({records: data}, {}, true);
    },

    onUpdate : function(ds, record, type){
        if(type == Ext.data.Record.EDIT){
            var v = record.data['value'];
            var oldValue = record.modified['value'];
            if(this.grid.fireEvent('beforepropertychange', this.source, record.id, v, oldValue) !== false){
                this.source[record.id] = v;
                record.commit();
                this.grid.fireEvent('propertychange', this.source, record.id, v, oldValue);
            }else{
                record.reject();
            }
        }
    },

    getProperty : function(row){
       return this.store.getAt(row);
    },

    isEditableValue: function(val){
        if(Ext.isDate(val)){
            return true;
        }else if(typeof val == 'object' || typeof val == 'function'){
            return false;
        }
        return true;
    },

    setValue : function(prop, value){
        this.source[prop] = value;
        this.store.getById(prop).set('value', value);
    },

    getSource : function(){
        return this.source;
    }
});

Ext.ux.grid.PropertyColumnModel = function(grid, store){
    this.grid = grid;
    var g = Ext.grid;
    var f = Ext.form;
    this.store = store;
    
    Ext.ux.grid.PropertyColumnModel.superclass.constructor.call(this, [
        {header: this.nameText, width:grid.nameWidth, fixed:true, sortable: true, dataIndex:'header', id: 'name', menuDisabled:true},
        {header: this.valueText, width:grid.valueWidth, resizable:false, dataIndex: 'value', id: 'value', menuDisabled:true}
    ]);

    this.booleanEditor = new Ext.form.ComboBox({
            triggerAction : 'all',
            mode : 'local',
            valueField : 'boolValue',
            displayField : 'name',
            editable:false,
            selectOnFocus: true,
            forceSelection: true,
            store : {
                xtype : 'arraystore',
                idIndex : 0,
                fields : ['boolValue','name'],
                data : [[false,'false'],[true,'true']]
                }
    });

    this.editors = {
        'date' : new g.GridEditor(new f.DateField({selectOnFocus:true})),
        'string' : new g.GridEditor(new f.TextField({selectOnFocus:true})),
        'number' : new g.GridEditor(new f.NumberField({selectOnFocus:true, style:'text-align:left;'})),
        'boolean' : new g.GridEditor(this.booleanEditor)
    };

    this.renderCellDelegate = this.renderCell.createDelegate(this);
    this.renderPropDelegate = this.renderProp.createDelegate(this);
};

Ext.extend(Ext.ux.grid.PropertyColumnModel, Ext.grid.ColumnModel, {
    nameText : 'Name',
    valueText : 'Value',
    dateFormat : 'j/m/Y',

    renderDate : function(dateVal){
        return dateVal.dateFormat(this.dateFormat);
    },

    renderBool : function(bVal){
        return bVal ? 'true' : 'false';
    },

    isCellEditable : function(colIndex, rowIndex){
            var p = this.store.getProperty(rowIndex);
            if (p.data.field && p.data.field.editable == false) {
                    return false;
                }
        return colIndex == 1;
    },

    getRenderer : function(col){
        return col == 1 ? this.renderCellDelegate : this.renderPropDelegate;
    },

    renderProp : function(v){
        return this.getPropertyName(v);
    },

    renderCell : function(val, metadata, record, rowIndex, colIndex, store){
        if (record.data.field && typeof(record.data.field.renderer) == 'function'){
            return record.data.field.renderer.call(this, val, metadata, record, rowIndex, colIndex, store);
        }

        var rv = val;
        if(Ext.isDate(val)){
            rv = this.renderDate(val);
        }else if(typeof val == 'boolean'){
            rv = this.renderBool(val);
        }
        return Ext.util.Format.htmlEncode(rv);
    },

    getPropertyName : function(name){
        var pn = this.grid.propertyNames;
        return pn && pn[name] ? pn[name] : name;
    },

    getCellEditor : function(colIndex, rowIndex){
        var p = this.store.getProperty(rowIndex);
        var n = p.data['name'], val = p.data['value'];
        if(p.data.field && typeof(p.data.field.editor) == 'object'){
            return p.data.field.editor;
        }

        if(typeof(this.grid.customEditors) == 'function'){
            return this.grid.customEditors(n);
        }

        if(Ext.isDate(val)){
            return this.editors['date'];
        }else if(typeof val == 'number'){
            return this.editors['number'];
        }else if(typeof val == 'boolean'){
            return this.editors['boolean'];
        }else{
            return this.editors['string'];
        }
    },

    destroy : function(){
        Ext.ux.grid.PropertyColumnModel.superclass.destroy.call(this);
        for(var ed in this.editors){
            Ext.destroy(this.editors[ed]);
        }
    }
});

Ext.ux.grid.PropertyGrid = Ext.extend(Ext.grid.EditorGridPanel, {
    enableColumnMove:false,
    stripeRows:false,
    trackMouseOver: false,
    clicksToEdit:1,
    enableHdMenu : false,
    editable: true,
    nameWidth: 120,
    valueWidth: 50,
    source: {},
    autoExpandColumn: 'value',

    initComponent : function(){
        this.customEditors = this.customEditors || {};
        this.lastEditRow = null;
        var store = new Ext.ux.grid.PropertyStore(this);
        this.propStore = store;
        var cm = new Ext.ux.grid.PropertyColumnModel(this, store);
        store.store.sort('name', 'ASC');
        this.addEvents(
            'beforepropertychange',
            'propertychange'
        );
        this.cm = cm;
        this.ds = store.store;
        Ext.ux.grid.PropertyGrid.superclass.initComponent.call(this);

        this.selModel.on('beforecellselect', function(sm, rowIndex, colIndex){
            if(colIndex === 0){
                this.startEditing.defer(200, this, [rowIndex, 1]);
                return false;
            }
        }, this);
                if (!this.editable){
                    this.on('beforeedit', function(){return false})
                }
    },

    onRender : function(){
        Ext.ux.grid.PropertyGrid.superclass.onRender.apply(this, arguments);
        this.getGridEl().addClass('x-props-grid');
    },

    afterRender: function(){
        Ext.ux.grid.PropertyGrid.superclass.afterRender.apply(this, arguments);
        if(this.source){
            this.setSource(this.source);
        }
    },

    setSource : function(source){
        this.propStore.setSource(source,this.fields);
    },

    load : function(source){
        this.setSource(source);
    },

    loadRecord : function(record) {
        record.data && this.setSource(record.data);
    },

    getSource : function(){
        return this.propStore.getSource();
    },

    setEditable: function(rowIndex, editable) {
      var p = this.store.getProperty(rowIndex);
      if(p.data.field) p.data.field.editable = editable;
    }
});
Ext.reg("propertygrid2", Ext.ux.grid.PropertyGrid);

/***********  -- ^^^ -- Ext.ux.grid.PropertyGrid -- ^^^ -- **********/
/********************************************************************/


/* GLOBAL OVERRIDE!!! 
We always want to hide the contents of the grid cell while we're editing it...
*/
Ext.override(Ext.grid.GridEditor,{
	hideEl: true
});


Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.AppPropertyGrid = Ext.extend(Ext.ux.grid.PropertyGrid,{
	
	editable_fields: {},
		
	storeReloadButton: true,
	
	viewConfig: { emptyText: '<span style="color:darkgrey;">(Empty)</span>' },
	
	markDirty: true,
	
	use_edit_form: true,
  
  getLoadMaskEl: function() {
    return this.getEl();
  },
	
	initComponent: function() {
		
		this.on('beforepropertychange',function(source,rec,n,o) {
			
			// FIXME!!!!!
			
			if(n == null && o == '0') { return false; }
			if(o == null && n == '0') { return false; }
			if(n == true && o == '1') { return false; }
			if(o == true && n == '1') { return false; }
			
			
			
		},this);
		
    // This is a workaround for a spurious race-condition bug that is not fully
    // understood... The root of the issue is that we are tying into the store 
    // earlier than normal, and it appears that very sporadically the 'store' 
    // property is undefined at this point. That is why we fall back to other
    // locations where the 'store' can be found. This is probably a bug someplace
    // else, like in AutoPanel or DataStore, but this seems to be the only place 
    // where we have the problem (again, because no other places do we try to hook 
    // into the store within 'initComponent' but this should work). TODO/FIXME
    this.bindStore = this.store || this.initialConfig.store;
    if(!this.bindStore && this.ownerCt) {
      this.bindStore = this.ownerCt.store || this.ownerCt.initialConfig.store;
    }
		delete this.store;
		
		if(this.storeReloadButton) {
			var store = this.bindStore;
			this.tools = [{
				id: 'refresh',
				qtip: 'Refresh',
				handler: function() {
					store.reload();
				},
				scope: this
			}];
			if(store.api.update){
				this.tools.unshift({
					id: 'gear',
					qtip: 'Edit',
					handler: function() {
						store.editRecordForm();
					},
					scope: this
				},{
					id: 'save',
					qtip: 'Save',
					handler: function() {
						store.saveAll();
					},
					scope: this
				});
			}
		}
		
		if(this.columns && ! this.fields) {
			this.fields = this.columns;
			delete this.columns;
		}
		
		var propgrid = this;
		
		var columns = [];
		if(this.bindStore.baseParams.columns) {
			// append to existing column list if set:
			columns = Ext.decode(this.bindStore.baseParams.columns);
		}
		
		// prune/modify fields according to 'no_column'/'allow_edit'/'allow_view' :
		var new_fields = [];
		Ext.each(this.fields,function(field) {
			field.id = field.dataIndex;
			columns.push(field.dataIndex);
			
			// Give the field editor a refernce back to us/the propgrid:
			if(field.editor) { field.editor.propgrid = propgrid; }
			
			// prune out 'no_column' fields without either 'allow_edit' or 'allow_view':
			if(field.no_column && !field.allow_edit && !field.allow_view) { return; }
			
			// prune out fields with 'allow_view' specificially set to false:
			if(typeof field.allow_view !== "undefined" && !field.allow_view) { return; }
			
			field.allow_view = true;
			
			if(typeof field.allow_edit !== "undefined" && !field.allow_edit) { 
				// prune out fields with 'allow_edit' by itself (without aithout allow_view)
				// specificially set to false:
				if(!field.allow_view) { return; }
				
				// Otherwise, remove the editor (if needed):
				if(field.editor) { delete field.editor; }
			}
			
			new_fields.push(field);
		},this);
		this.fields = new_fields;
		
		
		Ext.each(this.fields,function(field) {
			
			var wrapcss;
			// Extra logic to handle editors as simple xtypes and not already 
			// GridEditor objects. This is handled by EditorGridPanel, but not
			// by the PropertyGrid:
			if (field.editor) {
				if (!field.editor.getXType) { 
					field.editor = Ext.ComponentMgr.create(field.editor,'textfield'); 
				}
				if (!field.editor.startEdit){
					field.editor = new Ext.grid.GridEditor({ 
						//autoSize: true, 
						//hideEl: true, 
						field: field.editor
					});
				}
				
				xtype = field.editor.field.xtype;
				wrapcss = ' with-background-right-image ra-icon-gray-pencil';
				if (xtype == 'combo' || xtype == 'appcombo2') {
					wrapcss = ' with-background-right-image ra-icon-gray-down';
				}

				this.editable_fields[field.name] = 1;
			}
			
			var orig_renderer = field.renderer;
			field.renderer = function(value,metaData,record,rowIndex,colIndex) {
				
				// Turn on word-wrap (set to off in a normal grid)
				metaData.attr = 'style="white-space:normal;"';
				
				// Mark dirty like in normal grid:
				var bindRec = propgrid.bindRecord
				if(bindRec && bindRec.dirty && typeof bindRec.modified[record.id] != 'undefined') {
					metaData.css += ' x-grid3-dirty-cell';
				}
				
				// Make text of the value column selectable (copy/paste):
				metaData.css += ' yes-text-select';
				
				// Translate the renderer to work like in a normal grid:
				if(orig_renderer) {
					if(!bindRec) { 
						value = orig_renderer.apply(field,arguments); 
					}
					else {
						value = orig_renderer.call(field,value,metaData,bindRec,0,0,propgrid.bindStore);
					}
				}
				
				if(wrapcss) { value = '<div class="' + wrapcss + '">' + value + '</div>'; }
				return value;
			}
			
			
			
		},this);
		
		if(! this.fields.length > 0) { this.collapsed = true; }
		
		var params = { columns: Ext.encode(columns) };
		
		if(this.baseParams) {
			Ext.apply(params,this.baseParams);
		}
		
		Ext.apply(this.bindStore.baseParams,params);
		
		Ext.ux.RapidApp.AppPropertyGrid.superclass.initComponent.call(this);
		
		this.on('afterrender',this.loadFirstRecord,this);
		this.bindStore.on('load',this.loadFirstRecord,this);
		this.bindStore.on('update',this.loadFirstRecord,this);
		this.on('beforeedit',this.onBeforeEdit,this);
		this.on('propertychange',this.onPropertyChange,this);
		
		
		
		
		
		
		
		
		var cmp = this;
		/* COPIED FROM datastore-plus FIXME*/
		/* 
			Property Grids (from DbicAppPropertyPage) aren't normal RapidApp/DataStore2
			modules and so they don't get the datastore-plus plugin. This needs to be
			fixed/refactored. In the mean time, this code is copied verbatim from the
			datastore-plus plugin so that grid editors, specifically the new 'cycle-field'
			and 'menu-field', behave the same as in normal AppGrid2 grids
		*/
		/**********************/
		/** For Editor Grids **/
		if(Ext.isFunction(cmp.startEditing)){
			
			cmp.startEditing_orig = cmp.startEditing;
      
      // Now calls to the common function:
      cmp.startEditing = function(row,col) {
        return Ext.ux.RapidApp.Plugin.CmpDataStorePlusX.startEditingWrapper.call(
          this,
          row,col,
          cmp
        );
      };
		}
		/**********************/
		/**********************/
		
	},
	
	onBeforeEdit: function(e) {
		var field_name = e.record.data.field.name;
		if (this.editable_fields && ! this.editable_fields[field_name]) {
			e.cancel = true;
		}
	},
	
	onPropertyChange: function(source,recordId,value,oldValue) {
		this.bindRecord.beginEdit();
		this.bindRecord.set(recordId,value);
		this.bindRecord.endEdit();
		this.bindRecord.store.saveIfPersist();
	},
	
	getBindStore: function() {
		return this.bindStore;
	},
	
	loadFirstRecord: function() {
		this.bindRecord = this.getBindStore().getAt(0);
		if(!this.bindRecord) { return; }
		this.loadRecord(this.bindRecord.copy());
	}

});
Ext.reg('apppropertygrid', Ext.ux.RapidApp.AppPropertyGrid);


Ext.ux.RapidApp.newXTemplate = function(arg) {
  var tpl = arg;
  var parms = {};
  if(Ext.isArray(arg)) {
    tpl = arg[0];
    parms = arg[1];
  }
  return new Ext.XTemplate(tpl,parms);
}


Ext.ux.RapidApp.renderRed = function(val) {
	return '<span style="color:red;">' + val + '</span>'; 
}

Ext.ux.RapidApp.boolCheckMark = function(val) {
  if (val == null || val === "" || val <= 0) { 
    return [
      '<img src="',Ext.BLANK_IMAGE_URL,
      '" class="ra-icon-12x12 ra-icon-cross-light-12x12">'
    ].join('');
  }
  return [
    '<img src="',Ext.BLANK_IMAGE_URL,
    '" class="ra-icon-12x12 ra-icon-checkmark-12x12">'
  ].join('');
}

// Returns a date formatter function based on the supplied format:
Ext.ux.RapidApp.getDateFormatter = function(format,allow_zero) {
  if (!format) { format = "Y-m-d H:i:s"; }
  return function(date) {
    if(!allow_zero && date && Ext.isString(date)) {
      // New: handle the common case of an empty/zero date
      //  better than 'Nov 30, 00-1 12:00 AM' which is what the typical format returns
      if(date == '0000-00-00' || date == '0000-00-00 00:00:00') {
        return ['<span class="ra-null-val">',date,'</span>'].join('');
      }
    }
    var dt = Date.parseDate(date,"Y-m-d H:i:s");
    if (! dt) { return date; }
    return dt.format(format);
  }
}


Ext.ux.RapidApp.renderPencil = function(val) {
  return [
    '<span>',val,'</span>',
    '<img src="',Ext.BLANK_IMAGE_URL,'" class="ra-icon-14x14 ra-icon-gray-pencil">'
  ].join('');
}


/* -----
 This inline link handler code sets listeners in pure JavaScript on
 generated <a> tags. This is below the Ext level, but returns 'false'
 and sets cancelBubble to override and prevent any other click handlers
 (such as handlers to start editing in an EditorGrid, etc) from firing
 This allows running isolated code. Currently this is just setup for
 custom navigation/content loading but will handle a lot more scenarios
 in the future
*/
Ext.ux.RapidApp.inlineLink = function(href,text,css,style,title) {
	var link = 
		'<a href="' + href + '"' +
		(css ? ' class="' + css + '"' : '') +
		(style ? ' style="' + style + '"' : '') +
		(title ? " title='" + title + "'" : '') +
		' onclick="return Ext.ux.RapidApp.InlineLinkHandler.apply(this,arguments);"' +
		' ondblclick="return Ext.ux.RapidApp.InlineLinkHandler.apply(this,arguments);"' +
		'>' + text + '</a>';
	return link;
}
Ext.ux.RapidApp.InlineLinkHandler = function(e) {
	if (!e) var e = window.event;
	e.cancelBubble = true;
	if (e.stopPropagation) e.stopPropagation();
	if(e.type == 'click' && this.hash) {
	
		// --- New: handle simple hashpath URL
		// The reason this is still being done in this function at all is
		// for the code that stops the event from propagating above
		if(this.host == window.location.host && this.hash.search('#!/') == 0) {
			return window.location.href = this.href;
		}
		// ---
		
		var parts = this.hash.split('#loadcfg:data=');
		if(parts.length == 2) {
			var str = parts[1];
			
			// FireFox has automatically already decoded from URI, but Chrome hasn't,
			// making this required:
			str = decodeURIComponent(str);

			var loadCfg = Ext.decode(str);
			var loadTarget = Ext.getCmp("main-load-target");
      if(loadTarget) {
        loadTarget.loadContent(loadCfg);
      }
		}
	}
	return false;
}

Ext.ux.RapidApp.callFnLink = function(fn_name,text,args,attrs) {
	
	var arg_str = args;
	if(Ext.isArray(args)) {
		arg_str = "'" + args.join("','") + "'";
	}
	
	var func_str = "return " + fn_name + ".call(this," + arg_str + ");";
	
	attrs = attrs || {};
	attrs = Ext.apply({
		href: '#',
		onclick: func_str,
		ondblclick: func_str
	},attrs);
	
	var link = '<a';
	Ext.iterate(attrs,function(k,v) { link += ' ' + k + '="' + v + '"'; });
	link += '>' + text + '</a>';
	
	return link;
}
/* ----- */

/* http://stackoverflow.com/questions/130404/javascript-data-formatting-pretty-printer */
/* Modified by HV */
Ext.ux.RapidApp.DumpObjectIndented = function (obj, indent) {
	var result = "";
	if (indent == null) indent = "";

	for (var property in obj) {
		var value = obj[property];
		if (typeof value == 'string') { 
			value = "'" + value + "'"; 
		}
		else if (typeof value == 'object'){
			if (value instanceof Array) {
				// Just let JS convert the Array to a string!
				value = "[ " + value + " ]";
			}
			else {
				// Recursive dump
				// (replace "  " by "\t" or something else if you prefer)
				var od = Ext.ux.RapidApp.DumpObjectIndented(value, indent + "  ");
				// If you like { on the same line as the key
				//value = "{\n" + od + "\n" + indent + "}";
				// If you prefer { and } to be aligned
				//value = "\n" + indent + "{\n" + od + "\n" + indent + "}";
				value = "{\n" + od + "\n" + indent + "}";
			}
		}
		//result += indent + "'" + property + "' : " + value + ",\n";
		result += indent + property + ": " + value + ",\n";
	}
	return result.replace(/,\n$/, "");
}



/****************************************************************
 * jsDump
 * Copyright (c) 2008 Ariel Flesler - aflesler(at)gmail(dot)com | http://flesler.blogspot.com
 * Licensed under BSD (http://www.opensource.org/licenses/bsd-license.php)
 * Date: 5/15/2008
 * @projectDescription Advanced and extensible data dumping for Javascript.
 * @version 1.0.0
 * @author Ariel Flesler
 */
var jsDump;

(function(){
	function quote( str ){
		return '"' + str.toString().replace(/"/g, '\\"') + '"';
	};
	function literal( o ){
		return o + '';	
	};
	function join( pre, arr, post ){
		var s = jsDump.separator(),
			base = jsDump.indent();
			inner = jsDump.indent(1);
		if( arr.join )
			arr = arr.join( ',' + s + inner );
		if( !arr )
			return pre + post;
		return [ pre, inner + arr, base + post ].join(s);
	};
	function array( arr ){
		var i = arr.length,	ret = Array(i);					
		this.up();
		while( i-- )
			ret[i] = this.parse( arr[i] );				
		this.down();
		return join( '[', ret, ']' );
	};
	
	var reName = /^function (\w+)/;
	
	jsDump = {
		parse:function( obj, type ){//type is used mostly internally, you can fix a (custom)type in advance
			var	parser = this.parsers[ type || this.typeOf(obj) ];
			type = typeof parser;			
			
			return type == 'function' ? parser.call( this, obj ) :
				   type == 'string' ? parser :
				   this.parsers.error;
		},
		typeOf:function( obj ){
			var type = typeof obj,
				f = 'function';//we'll use it 3 times, save it
			return type != 'object' && type != f ? type :
				!obj ? 'null' :
				obj.exec ? 'regexp' :// some browsers (FF) consider regexps functions
				obj.getHours ? 'date' :
				obj.scrollBy ?  'window' :
				obj.nodeName == '#document' ? 'document' :
				obj.nodeName ? 'node' :
				obj.item ? 'nodelist' : // Safari reports nodelists as functions
				obj.callee ? 'arguments' :
				obj.call || obj.constructor != Array && //an array would also fall on this hack
					(obj+'').indexOf(f) != -1 ? f : //IE reports functions like alert, as objects
				'length' in obj ? 'array' :
				type;
		},
		separator:function(){
			return this.multiline ?	this.HTML ? '<br />' : '\n' : this.HTML ? '&nbsp;' : ' ';
		},
		indent:function( extra ){// extra can be a number, shortcut for increasing-calling-decreasing
			if( !this.multiline )
				return '';
			var chr = this.indentChar;
			if( this.HTML )
				chr = chr.replace(/\t/g,'   ').replace(/ /g,'&nbsp;');
			return Array( this._depth_ + (extra||0) ).join(chr);
		},
		up:function( a ){
			this._depth_ += a || 1;
		},
		down:function( a ){
			this._depth_ -= a || 1;
		},
		setParser:function( name, parser ){
			this.parsers[name] = parser;
		},
		// The next 3 are exposed so you can use them
		quote:quote, 
		literal:literal,
		join:join,
		//
		_depth_: 1,
		// This is the list of parsers, to modify them, use jsDump.setParser
		parsers:{
			window: '[Window]',
			document: '[Document]',
			error:'[ERROR]', //when no parser is found, shouldn't happen
			unknown: '[Unknown]',
			'null':'null',
			undefined:'undefined',
			'function':function( fn ){
				var ret = 'function',
					name = 'name' in fn ? fn.name : (reName.exec(fn)||[])[1];//functions never have name in IE
				if( name )
					ret += ' ' + name;
				ret += '(';
				
				ret = [ ret, this.parse( fn, 'functionArgs' ), '){'].join('');
				return join( ret, this.parse(fn,'functionCode'), '}' );
			},
			array: array,
			nodelist: array,
			arguments: array,
			object:function( map ){
				var ret = [ ];
				this.up();
				for( var key in map )
					ret.push( this.parse(key,'key') + ': ' + this.parse(map[key]) );
				this.down();
				return join( '{', ret, '}' );
			},
			node:function( node ){
				var open = this.HTML ? '&lt;' : '<',
					close = this.HTML ? '&gt;' : '>';
					
				var tag = node.nodeName.toLowerCase(),
					ret = open + tag;
					
				for( var a in this.DOMAttrs ){
					var val = node[this.DOMAttrs[a]];
					if( val )
						ret += ' ' + a + '=' + this.parse( val, 'attribute' );
				}
				return ret + close + open + '/' + tag + close;
			},
			functionArgs:function( fn ){//function calls it internally, it's the arguments part of the function
				var l = fn.length;
				if( !l ) return '';				
				
				var args = Array(l);
				while( l-- )
					args[l] = String.fromCharCode(97+l);//97 is 'a'
				return ' ' + args.join(', ') + ' ';
			},
			key:quote, //object calls it internally, the key part of an item in a map
			functionCode:'[code]', //function calls it internally, it's the content of the function
			attribute:quote, //onode calls it internally, it's an html attribute value
			string:quote,
			date:quote,
			regexp:literal, //regex
			number:literal,
			'boolean':literal
		},
		DOMAttrs:{//attributes to dump from nodes, name=>realName
			id:'id',
			name:'name',
			'class':'className'
		},
		HTML:false,//if true, entities are escaped ( <, >, \t, space and \n )
		indentChar:'   ',//indentation unit
		multiline:true //if true, items in a collection, are separated by a \n, else just a space.
	};

})();
/** End jsDump
****************************************************************/


Ext.ux.RapidApp.renderJSONjsDump = function(v) {
	try {
		var obj = Ext.decode(v);
		var dump = jsDump.parse( obj );
		return '<pre>' + dump + '</pre>';
	} catch(err) {
		//console.log('ERROR: ' + err);
		return Ext.ux.showNull(v); 
	}
}

Ext.ux.RapidApp.renderMonoText = function(v) {
  return '<pre class="ra-pre-wrap">' + v + '</pre>';
}

Ext.ux.RapidApp.getWithIconClsRenderer = function(icon_cls) {
	return function(value, metaData) {
		if(icon_cls) { metaData.css = 'grid-cell-with-icon ' + icon_cls; }
		return value;
	};
}

Ext.ux.RapidApp.getRendererStatic = function(str,meta) {
	meta = meta || {};
	return function(value,metaData) { 
		Ext.apply(metaData,meta);
		return str; 
	}
}



// Gets the named value in the data set of the field (calling scope),
// whether its a grid, a form, etc. Specific to RapidApp modules
// use like this:
// var value = Ext.ux.RapidApp.fieldContextDataGetValue.call(fieldObj,key);
Ext.ux.RapidApp.fieldContextDataGetValue = function(name) {
	
	var rec_data = {};
		
	// In AppGrid2:
	if(this.gridEditor && this.gridEditor.record) { 
		rec_data = this.gridEditor.record.data;
	}
	
	// In AppDV
	if(this.Record) { 
		rec_data = this.Record.data;
	}
	
	// In AppPropertyGrid
	if(this.propgrid && this.propgrid.bindRecord) { 
		rec_data = this.propgrid.bindRecord.data;
	}
	
	// In a form
	if(this.ownerCt && this.ownerCt.getForm) { 
		var form = this.ownerCt.getForm();
		var field = form.findField(name);
		if (!field) { return null; }
		if(name) { 
			rec_data[name] = field.getValue(); 
		}
		if(this.ownerCt.Record && this.ownerCt.Record.data[name]) {
			if(!rec_data[name] || rec_data[name] == '');
			rec_data = this.ownerCt.Record.data;
		}
	}
	
	return rec_data[name];
}


Ext.ux.RapidApp.winLoadUrlGET = function(cnf) {
	var url = Ext.urlEncode(cnf.params,cnf.url + '?');
	if(!cnf.params) { url = cnf.url; }
	window.open(url,'');
}



// Takes an image tag (html string) and makes it autosize via max-width:100%
Ext.ux.RapidApp.imgTagAutoSizeRender = function(v,maxheight) {
	//if(v.search('<img ') !== 0) { return v; }
	var div = document.createElement('div');
	div.innerHTML = v;
	var domEl = div.firstChild;
	if(domEl && domEl.tagName == 'IMG') { 
		var El = new Ext.Element(domEl);
		var styles = 'max-width:100%;height:auto;width:auto;';
		if(maxheight) { styles += 'max-height:' + maxheight + ';'; }
		El.applyStyles(styles);
		if(El.dom.getAttribute('width')) { El.dom.removeAttribute('width'); }
		if(El.dom.getAttribute('height')) { El.dom.removeAttribute('height'); }
		return div.innerHTML;
	}
	else {
		return v;
	}
}


Ext.ux.RapidApp.getImgTagRendererDefault = function(src,w,h,alt) {
	var def = '<img ';
	if(src){ def += 'src="' + src + '" '; }
	if(w && w != 'autosize'){ def += 'width="' + w + '" '; }
	if(h){ def += 'height="' + h + '" '; }
	if(alt){ def += 'alt="' + alt + '" '; }
	def += '>';
	
	return function(v) {
		if(!v) { return def; }
		if(w == 'autosize') {
			var maxheight = h;
			return Ext.ux.RapidApp.imgTagAutoSizeRender(v); 
		}
		return v;
	}
}






Ext.ux.RapidApp.getRendererPastDatetimeRed = function(format) {
	var renderer = Ext.ux.RapidApp.getDateFormatter(format);
	return function(date) {
		var dt = Date.parseDate(date,"Y-m-d H:i:s");
		if (! dt) { dt = Date.parseDate(date,"Y-m-d"); }
		
		if (! dt) { return Ext.ux.showNull(date); }
		
		var out = renderer(date);
		var nowDt = new Date();
		// in the past:
		if(nowDt > dt) { return '<span style="color:red;">' + out + '</span>'; }
		return out;
	}
}

Ext.ux.RapidApp.num2pct = function(num) {
	if (num != 0 && isFinite(num)) {
		num = Ext.util.Format.round(100*num,2) + '%';
	}
	if(num == 0) { num = '0%'; }
	return num;
}


Ext.ux.RapidApp.NO_DBIC_REL_LINKS = false;

Ext.ux.RapidApp.DbicRelRestRender = function(c) {
	var disp = c.disp || c.record.data[c.render_col] || c.value;
	var key_value = c.record.data[c.key_col];

  // multi-rel: no link for 0 records:
  if(c.multi_rel && c.value == '0') { return disp; }
	
	if(!c.value) { 
		if(!disp && !key_value) {
			// If everything is unset, including the key_col value itself,
			// we render like a normal empty value. It is only when the 
			// key_col is set but the value/disp is not (indicating a broken
			// or missing link/relationship) that we want to render the special 
			// "unavailable" string (see the following code block) -- SEE UPDATED
			// NOTE BELOW
			return Ext.ux.showNull(key_value);
		}
		c.value = key_value; 
	}
	
	if(!c.value)		{ return disp; }
	if(!disp) 			{ return c.value; }
	if(!c.open_url)	{ return disp; }
	
	var url = '#!' + c.open_url + '/';
	if(c.rest_key) { url += c.rest_key + '/'; }

  // Added for GitHub #119 -- don't show links for bad rels
  if(!key_value && key_value != '0' && key_value != '') { 
    return c.is_phy_colname ? disp : Ext.ux.showNull(key_value); 
  }

	if(c.rs) {
		// For multi-rel. value actually only contains the count of related
		// rows. key_value will contain the id of the row from which the rs originated
		url += key_value + '/rel/' + c.rs; 
	}
	else {
		// For single-rel
		url += c.value;
	}
	
	if(Ext.ux.RapidApp.NO_DBIC_REL_LINKS) {
		return disp;
	}
	
	return disp + "&nbsp;" + Ext.ux.RapidApp.inlineLink(
		url,
		"<span>open</span>",
		"ra-nav-link ra-icon-magnify-tiny",
		null,
		"Open/view: " + disp
	);
}


Ext.ux.RapidApp.DbicSingleRelationshipColumnRender = function(c) {
	var disp = c.record.data[c.render_col];
	var key_value = c.record.data[c.key_col];

	if(!c.value) { 
		if(!disp && !key_value) {
			// If everything is unset, including the key_col value itself,
			// we render like a normal empty value. It is only when the 
			// key_col is set but the value/disp is not (indicating a broken
			// or missing link/relationship) that we want to render the special 
			// "unavailable" string (see the following code block) -- SEE UPDATED
			// NOTE BELOW
			return Ext.ux.showNull(key_value);
		}
		c.value = key_value; 
	}
	
	if(c.value == null && disp == null) {
		// UPDATE: this code path will actually never occur now (after adding the
		// above call to 'showNull'). It will either display the normal null/empty
		// output or the value of the key, so this never happens!! But, after some
		// other improvements to relationship column handling, they now work correctly
		// (I think) with unset values/broken links, which they didn't before, and
		// this alternate display was actually added as a workaround for that problem
		// and is now not even needed/helpful. TODO: after verifying this is in fact true,
		// clean up the logic in this function and remove this and other not-needed
		// code and logic... Also see about applying a special style when the link
		// *is* broken and the key value is being displayed instead of the related
		// render value (I tried to do this already but it wasn't working immediately
		// and I had other, more important things to do at the time)...
		return '<span style="font-size:.90em;color:darkgrey;">' +
			'&times&nbsp;unavailable&nbsp;&times;' +
		'</span>';
	}
	
	if(!c.value)		{ return disp; }
	if(!disp) 			{ return c.value; }
	if(!c.open_url)	{ return disp; }
	
	var loadCfg = { 
		title: disp, 
		autoLoad: { 
			url: c.open_url, 
			params: { ___record_pk: "'" + c.value + "'" } 
		}
	};
		
	var url = "#loadcfg:" + Ext.urlEncode({data: Ext.encode(loadCfg)});

	return disp + "&nbsp;" + Ext.ux.RapidApp.inlineLink(
		url,
		"<span>open</span>",
		"ra-nav-link ra-icon-magnify-tiny",
		null,
		"Open/view: " + disp
	);
}

Ext.ux.RapidApp.prettyCsvRenderer = function(v) {
	if(!v) { return Ext.ux.showNull(v); }
	var sep = '<span style="color: navy;font-size:1.2em;font-weight:bold;">,</span> ';
	var list = v.split(',');
	Ext.each(list,function(item){
		// strip whitespace:
		item = item.replace(/^\s+|\s+$/g,"");
	},this);
	return list.join(sep);
}

/************** CUSTOM VTYPES **************/
Ext.apply(Ext.form.VTypes,{
	zipcode: function(v) { return /^\d{5}(-\d{4})?$/.test(v); },
	zipcodeMask: /[0-9\-]+/,
	zipcodeText: 'Zipcode must be 5-digits (e.g. 12345) or 5-digits + 4 (e.g. 12345-6789)'
});
/*******************************************/


Ext.ux.RapidApp.showIframeWindow = function(cnf){
	cnf = Ext.apply({
		src: 'about:blank',
		title: 'Message',
		width: 400,
		height: 225,
		show_loading: false
	},cnf || {});
		
	var win, iframe = document.createElement("iframe");
	iframe.height = '100%';
	iframe.width = '100%';
	iframe.setAttribute("frameborder", '0');
	iframe.setAttribute("allowtransparency", 'true');
	iframe.src = cnf.src;
		
	var winCfg = {
		title: cnf.title,
		modal: true,
		closable: true,
		width: cnf.width,
		height: cnf.height,
		buttonAlign: 'center',
		buttons:[{
			text: 'Ok',
			handler: function(){ win.hide(); win.close(); }
		}],
		contentEl: iframe
	};
	
	if(cnf.show_loading) { 
		winCfg.bodyCssClass = 'loading-background'; 
	}
	
	win = new Ext.Window(winCfg);
	win.show();

};

// Renders a positive, negative, or zero number as green/red/black dash
Ext.ux.RapidApp.increaseDecreaseRenderer = function(v) {
	if (v == null || v === "") { return Ext.ux.showNull(v); }
	if(v == 0) { return	'<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
	if(v < 0) { return 	'<span style="color:red;font-weight:bold;">' + v + '</span>'; }
	return 					'<span style="color:green;font-weight:bold;">+' + v + '</span>'; 
};

// Renders pct up tp 2 decimal points (i.e. .412343 = 41.23%) in green or red for +/-
Ext.ux.RapidApp.increaseDecreasePctRenderer = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	var v = Math.round(val*10000)/100;
	if(v == 0) { return	'<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
	if(v < 0) { return 	'<span style="color:red;font-weight:bold;">-' + Math.abs(v) + '%</span>'; }
	return 					'<span style="color:green;font-weight:bold;">+' + v + '%</span>'; 
};

// Renders money up tp 2 decimal points (i.e. 41.2343 = $41.23) in green or red for +/-
Ext.ux.RapidApp.increaseDecreaseMoneyRenderer = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	var v = Math.round(val*100)/100;
	if(v == 0) { return	'<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
	if(v < 0) { return 	'<span style="color:red;font-weight:bold;">' + Ext.util.Format.usMoney(v) + '</span>'; }
	return 					'<span style="color:green;font-weight:bold;">+' + Ext.util.Format.usMoney(v) + '</span>'; 
};


// Returns the infitity character instead of the value when it is
// a number greater than or equal to 'maxvalue'. Otherwise, the value
// is returned as-is.
Ext.ux.RapidApp.getInfinityNumRenderer = function(maxvalue,type) {
	if(!Ext.isNumber(maxvalue)) { 
		return function(v) { return Ext.ux.showNull(v); }; 
	}
	return function(v) {
		if(Number(v) >= Number(maxvalue)) {
			// also increase size because the default size of the charater is really small
			return '<span title="' + v + '" style="font-size:1.5em;">&infin;</span>';
		}
		
		if(type == 'duration') {
			return Ext.ux.RapidApp.renderDuration(v);
		}
		
		return Ext.ux.showNull(v);
	}
};




Ext.ux.RapidApp.renderDuration = function(seconds,suffixed) {
	if(typeof seconds != 'undefined' && seconds != null && moment) {
		return '<span title="' + seconds + ' seconds">' +
			moment.duration(Number(seconds),"seconds").humanize(suffixed) +
		'</span>'
	}
	else {
		return Ext.ux.showNull(seconds);
	}
}

Ext.ux.RapidApp.renderDurationSuf = function(seconds) {
	return Ext.ux.RapidApp.renderDuration(seconds,true);
}

Ext.ux.RapidApp.renderDurationPastSuf = function(v) {
  if(typeof v != 'undefined' && v != null && moment) {
    var seconds = Math.abs(Number(v));
    return Ext.ux.RapidApp.renderDurationSuf(-seconds);
  }
  else {
    return Ext.ux.showNull(v);
  }
}


// Renders a short, human-readable duration/elapsed string from seconds.
// The seconds are divided up into 5 units - years, days, hours, minutes and seconds -
// but only the first two are shown for readability, since if its '2y, 35d',
// you probably don't care about the exact hours minutes and seconds ( i.e.
// '2y, 35d, 2h, 4m, 8s' isn't all that useful and a lot longer)
Ext.ux.RapidApp.renderSecondsElapsed = function(s) {

  if(!s) {
    return Ext.ux.showNull(s);
  }

  var years = Math.floor    ( s / (365*24*60*60));
  var days  = Math.floor   (( s % (365*24*60*60)) / (24*60*60));
  var hours = Math.floor  ((( s % (365*24*60*60)) % (24*60*60)) / (60*60));
  var mins  = Math.floor (((( s % (365*24*60*60)) % (24*60*60)) % (60*60)  / 60));
  var secs  =             ((( s % (365*24*60*60)) % (24*60*60)) % (60*60)) % 60;
  
  var list = [];
  if(years) { list.push(years + 'y'); }
  if(days)  { list.push(days  + 'd'); }
  if(hours) { list.push(hours + 'h'); }
  if(mins)  { list.push(mins  + 'm'); }
  if(secs)  { list.push(secs  + 's'); }
  
  if (list.length == 0) {
    return Ext.ux.showNull(s);
  }
  else if (list.length == 1) {
    return list[0];
  }
  else {
    return list[0] + ', ' + list[1];
  }
}

// renders a json array of arrays into an HTML Table
Ext.ux.RapidApp.jsonArrArrToHtmlTable = function(v) {

	var table_markup;
	try {
		var arr = Ext.decode(v);
		var rows = [];
		Ext.each(arr,function(tr,r) {
			var cells = [];
			Ext.each(tr,function(td,c) {
				var style = '';
				if(r == 0) {
					style = 'font-size:1.1em;font-weight:bold;color:navy;min-width:50px;';
				}
				else if (c == 0) {
					style = 'font-weight:bold;color:#333333;padding-right:30px;';
				}
				else {
					style = 'font-family:monospace;padding-right:10px;';
				}
				cells.push({
					tag: 'td',
					html: td ? '<div style="' + style + '">' +
						td + '</div>' : Ext.ux.showNull(td)
				})
			});
			rows.push({
				tag: 'tr',
				children: cells
			});
		});
		
		table_markup = Ext.DomHelper.markup({
			tag: 'table',
			cls: 'r-simple-table',
			children: rows
		});
	}catch(err){};

	return table_markup ? table_markup : v;
}

Ext.ux.RapidApp.withFilenameIcon = function(val) {
  var parts = val.split('.');
  var ext = parts.pop().toLowerCase();

  var icon_cls = 'ra-icon-document';

  if(ext == 'pdf')  { icon_cls = 'ra-icon-page-white-acrobat'; }
  if(ext == 'zip')  { icon_cls = 'ra-icon-page-white-compressed'; }
  if(ext == 'xls')  { icon_cls = 'ra-icon-page-white-excel'; }
  if(ext == 'xlsx') { icon_cls = 'ra-icon-page-excel'; }
  if(ext == 'ppt')  { icon_cls = 'ra-icon-page-white-powerpoint'; }
  if(ext == 'txt')  { icon_cls = 'ra-icon-page-white-text'; }
  if(ext == 'doc')  { icon_cls = 'ra-icon-page-white-word'; }
  if(ext == 'docx') { icon_cls = 'ra-icon-page-word'; }
  if(ext == 'iso')  { icon_cls = 'ra-icon-page-white-cd'; }

  return [
    '<span class="with-icon ', icon_cls,'">',
      val,
    '</span>'
  ].join('');
}


Ext.ux.RapidApp.renderBase64 = function(str) {

  try {
    return Ext.util.Format.htmlEncode(
      base64.decode(
        // strip any newlines:
        str.replace(/(\r\n|\n|\r)/gm,"")
      )
    );
  } catch(err) { 
    return str; 
  }
}

// http://stackoverflow.com/a/15405953
String.prototype.hex2bin = function () {
  var i = 0, l = this.length - 1, bytes = [];
  for (i; i < l; i += 2) {
    bytes.push(parseInt(this.substr(i, 2), 16));
  }
  return String.fromCharCode.apply(String, bytes);
}

String.prototype.bin2hex = function () {
  var i = 0, l = this.length, chr, hex = '';
  for (i; i < l; ++i) {
    chr = this.charCodeAt(i).toString(16)
    hex += chr.length < 2 ? '0' + chr : chr;
  }
  return hex;
}

Ext.ux.RapidApp.formatHexStr = function(str) {
  
  // http://stackoverflow.com/a/4017825
  function splitStringAtInterval (string, interval) {
    var result = [];
    for (var i=0; i<string.length; i+=interval)
      result.push(string.substring (i, i+interval));
    return result;
  }
  
  str = ['0x',str.toUpperCase()].join('');
  return splitStringAtInterval(str,8).join(' ');
}

Ext.ux.RapidApp.renderHex = function(s) {
  if(s) {
    var orig_length = s.length;
    var hex_str = Ext.ux.RapidApp.formatHexStr(s.bin2hex());
    return [
      '<code ',
        'title="binary data (length ',orig_length,')" ',
        'class="ra-hex-string">',
        hex_str,
      '</code>'
    ].join('');
  }
  else {
    return Ext.ux.showNull(s);
  }
}

// Returns a renderer that will return an img tag with its data
// embedded as base64. This is useful for blob columns which
// contain raw/binary image data
Ext.ux.RapidApp.getEmbeddedImgRenderer = function(mime_type) {
  mime_type = mime_type || 'application/octet-stream';
  return function(data) {
    if(data) {
      return ['<img src="data:',mime_type,';base64,',base64.encode(data),'">'].join('');
    }
    else {
      return Ext.ux.showNull(data);
    }
  }
}


Ext.ux.RapidApp.renderCasLink = function(v){
  if(typeof v != 'undefined' && v != null) {
    var parts = v.split('/');

    if(parts.length <= 2) {
      var sha1 = parts[0], filename = parts[1] || parts[0];
      var cls = ['filelink'];
      var fnparts = filename.split('.');
      if (fnparts.length > 1) {
        cls.push(fnparts.pop().toLowerCase());
      }
      var url = ['simplecas/fetch_content/',sha1,'/',filename].join('');
      return [
        '<div class="',cls.join(' '),'">',
          '<span>',filename,'</span>',
          '<a ',
            'href="',url,'" ',
            'target="_self" ',
            'class="ra-icon-paperclip-tiny"',
          '>save</a>',
        '</div>'
      ].join('');
    }
    else {
      // unexpected currently...
      return v;
    }
  }
  else {
    return Ext.ux.showNull(v);
  }
}

Ext.ux.RapidApp.extractImgSrc = function(str) {
  var div = document.createElement('div');
  div.innerHTML = str;
  var domEl = div.firstChild;
  if(domEl && domEl.tagName == 'IMG') {
    return domEl.getAttribute('src');
  }
  return null;
}


Ext.ux.RapidApp.renderCasImg = function(v) {
  var url, pfx = Ext.ux.RapidApp.AJAX_URL_PREFIX || '';
  if(!v) {
    url = [pfx,'/assets/rapidapp/misc/static/images/img-placeholder.png'].join('');
  }
  else {
    // Handle legacy, full <img> tag values
    if(v.search('<img ') == 0) {
      var src = Ext.ux.RapidApp.extractImgSrc(v);
      if(!src) { return v; }
      var parts = src.split('simplecas/fetch_content/');
      if(parts.length == 2) {
        v = parts[1];
      }
      else {
        return v;
      }
    }
    var parts = v.split('/');
    if(parts.length <= 2) {
      // Just for reference, this is what we expect:
      //var sha1 = parts[0], filename = parts[1] || 'image.png';
      url = ['simplecas/fetch_content/',v].join('');
    }
    else {
      // unexpected currently...
      return v;
    }
  }

  return [
    '<img src="',url,'" ',
    'style="max-width:100%;max-height:100%;">'
  ].join('');
}



Ext.ux.RapidApp.nl2brWrap = function(v) {
  return v && v.length > 1 ? [
    '<span class="ra-wrap-on">',
      Ext.util.Format.nl2br(v),
    '</span>'
  ].join('') : v;
}

// Called from ext_viewport.tt to initialize the main app UI:
Ext.ux.RapidApp.MainViewportInit = function(opt) {
  
  // New: redirect to <path>/ if it doesn't already end with "/"
  // we need to do this to ensure consistency for relative paths.
  // We have to do it here, because the server side is not able to
  // see the difference, otherwise we'd redirect there. This will
  // only apply when the app is not mounted at the root
  var loc = window.location;
  if(loc.pathname.slice(-1) != '/') {
    loc.href = [loc.pathname,'/',loc.search,loc.hash].join('');
    return;
  }
  
  Ext.ux.RapidApp.HistoryInit();

  var panel_cfg = opt.panel_cfg || {
    xtype: 'autopanel',
    layout: 'fit',
    autoLoad: {
      url: opt.config_url,
      params: opt.config_params
    }
  };

  panel_cfg.id = panel_cfg.id || 'maincontainer';

  new Ext.Viewport({
    plugins: ['ra-link-click-catcher'],
    layout : 'fit',
    hideBorders : true,
    items : panel_cfg
  });
}
