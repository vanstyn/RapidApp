Ext.Updater.defaults.disableCaching = true;
Ext.Ajax.timeout = 120000; // 2 minute timeout (default is 30 seconds)

Ext.ns('Ext.log');
Ext.log = function() {};

Ext.ns('Ext.ux.RapidApp');
	
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
        var maxHeight = this.maxHeight || Ext.getBody().getHeight() - xy[1];
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
    },
	 
	// Added 2012-04-02 by HV: further turn off the default tiny menu scroller functions:
	enableScrolling: false
	 
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


Ext.ux.RapidApp.errMsgHandler = function(title,msg,as_text) {
	var win;
	
	var body = as_text ? '<pre>' + Ext.util.Format.nl2br(msg) + '</pre>' : msg;
	
	win = new Ext.Window({
		title: 'Exception',
		width: 600,
		height: 400,
		modal: true,
		closable: true,
		layout: 'fit',
		items: {
			xtype: 'panel',
			frame: true,
			headerCfg: {
				tag: 'div',
				cls: 'ra-exception-heading',
				html: title
			},
			autoScroll: true,
			html: body,
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
				var loadTarget = Ext.getCmp("explorer-id").getComponent("load-target");
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



Ext.ux.RapidApp.ajaxCheckException = function(conn,response,options) {
	if (!response || !response.getResponseHeader) return;
	try {
		var exception = response.getResponseHeader('X-RapidApp-Exception');
		if (exception) {
			
			var data = response.result || Ext.decode(response.responseText, true) || {};
			var title = data.title || 'Error';
			var msg = data.msg || 'unknown error - Ext.ux.RapidApp.ajaxCheckException';
			
			// -----------------------------------------------------------------------------
			// Check to see if this exception is associated with an AutoPanel load, and
			// if it is, display the exception message in the AutoPanel body instead of in
			// a new window
			if(options.scope && options.scope.AutoPanelId) {
				var AutoPanel = Ext.getCmp(options.scope.AutoPanelId);
				if(AutoPanel) {
					return AutoPanel.setErrorBody.call(AutoPanel,title,msg);
				}
			}
			// -----------------------------------------------------------------------------
			
			if (data.winform) {
				Ext.ux.RapidApp.WinFormPost(data.winform);
			}
			else {
				Ext.ux.RapidApp.errMsgHandler(title,msg,data.as_text);
			}
		}
		
		var warning = response.getResponseHeader('X-RapidApp-Warning');
		if (warning) {
			var data = Ext.decode(warning);
			var title = data.title || 'Warning';
			var msg = data.msg || 'Unknown (X-RapidApp-Warning)';
			Ext.ux.RapidApp.errMsgHandler(title,msg,data.as_text);
		}
		
		var eval_code = response.getResponseHeader('X-RapidApp-EVAL');
		if (eval) { eval(eval_code); }
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



Ext.ux.RapidApp.ajaxShowGlobalMask = function(conn,options) {
	if(options.loadMaskMsg) {
	
		conn.LoadMask = new Ext.LoadMask(Ext.getBody(),{
			msg: options.loadMaskMsg
			//removeMask: true
		});
		conn.LoadMask.show();
	}
}
Ext.ux.RapidApp.ajaxHideGlobalMask = function(conn,options) {
	if(conn.LoadMask) {
		conn.LoadMask.hide();
	}
}
Ext.Ajax.on('beforerequest',Ext.ux.RapidApp.ajaxShowGlobalMask,this);
Ext.Ajax.on('requestcomplete',Ext.ux.RapidApp.ajaxHideGlobalMask,this);
Ext.Ajax.on('requestexception',Ext.ux.RapidApp.ajaxHideGlobalMask,this);

Ext.ux.RapidApp.checkLocalTimezone = function(conn,options) {
	if (!options.headers) { options.headers= {}; }
	var dt= new Date();
	Ext.ux.RapidApp.userPrefs.timezoneOffset= -dt.getTimezoneOffset();
	options.headers['X-RapidApp-TimezoneOffset']= Ext.ux.RapidApp.userPrefs.timezoneOffset;
};
Ext.Ajax.on('beforerequest',Ext.ux.RapidApp.checkLocalTimezone);


Ext.Ajax.on('requestexception',function(conn,response,options){
	
	if(response && response.isTimeout){
		
		var timeout = options.timeout ? (options.timeout/1000) : null;
		timeout = timeout ? timeout : conn.timeout ? (conn.timeout/1000) : null;
		var msg = timeout ? 'Request Timed Out (' + timeout + ' secs).' : 'Request Timed Out.';
		
		Ext.Msg.show({
			title:'Timeout',
			msg: msg,
			icon: Ext.Msg.WARNING,
			buttons: Ext.Msg.OK
		});
	}
});


/* -------------------------------------------------------------------------------------
/* ------------------------------------------------------------------------------------- 
 This should be used instead of 'new Ext.data.Connection()' whenever creating a
 custom Conn object. The reason one might want to create a custom Conn object
 instead of using the Ext.Ajax singleton is to be able to set custom event listeners
 that apply to just that one connection. But we want these to also fire the global
 RapidApp event listeners, too:                                                         */
Ext.ux.RapidApp.newConn = function(config) {
	
	config = config || {};
	
	// Copy default properties from Ext.Ajax
	var props = Ext.copyTo({},Ext.Ajax,[
		'autoAbort',
		'disableCaching',
		'disableCachingParam',
		'timeout'
	]);
	Ext.apply(props,config);
	
	var Conn = new Ext.data.Connection(props);
	
	// Relay all the events of Ext.Ajax:
	Ext.Ajax.relayEvents(Conn,[
		'beforerequest',
		'requestexception',
		'requestcomplete'
	]);
	
	return Conn;
};
/* -------------------------------------------------------------------------------------
/* -------------------------------------------------------------------------------------
/* ------------------------------------------------------------------------------------- */

/**
 * We override Connection so that **Every** AJAX request gets our processing added to it.
 * We first set up a closure that can re-issue the current request, and then check headers
 *   to see if we want to interrupt the current one.
 */
Ext.override(Ext.data.Connection,{
	//request_orig: Ext.data.Connection.prototype.request,
	//request: function(opts) {
	//	return this.request_orig(opts);
	//},
	
	handleResponse_orig: Ext.data.Connection.prototype.handleResponse,
	handleResponse : function(response){
		this.fireEvent('requestcomplete',this,response,response.argument.options);
		
		var options = response.argument.options;
		
		var thisConn = this;
		var success_callback_repeat = function(newopts) {
			// Optional changes/additions to the original request options:
			if(Ext.isObject(newopts)) {
				Ext.iterate(newopts,function(key,value){
					Ext.apply(options[key],value);
				});
			}
			thisConn.request(options);
		};
		
		var orig_args= arguments;
		var current_callback_continue= function() { thisConn.handleResponse_orig.apply(thisConn,orig_args); };
		
		Ext.ux.RapidApp.handleCustomServerDirectives(response, current_callback_continue, success_callback_repeat);
	},
	
	doFormUpload_orig: Ext.data.Connection.prototype.doFormUpload,
	doFormUpload : function(o, ps, url){
		var thisConn= this;
		var success_callback_repeat = function(newopts) {
			// Optional changes/additions to the original request options:
			if(Ext.isObject(newopts)) {
				Ext.iterate(newopts,function(key,value){
					Ext.apply(o[key],value);
				});
			}
			thisConn.doFormUpload(o, ps, url);
		};
		
		// had to copy/paste from Ext.data.Connection, since there were no smaller routines to subclass...
		var id = Ext.id(),
			doc = document,
			frame = doc.createElement('iframe'),
			form = Ext.getDom(o.form),
			hiddens = [],
			hd,
			encoding = 'multipart/form-data',
			buf = {
				target: form.target,
				method: form.method,
				encoding: form.encoding,
				enctype: form.enctype,
				action: form.action
			};
		
		Ext.fly(frame).set({
			id: id,
			name: id,
			cls: 'x-hidden',
			src: Ext.SSL_SECURE_URL
		}); 
		
		doc.body.appendChild(frame);
		
		if(Ext.isIE){
			document.frames[id].name = id;
		}
		
		Ext.fly(form).set({
			target: id,
			method: 'POST',
			enctype: encoding,
			encoding: encoding,
			action: url || buf.action
		});
		
		var addParam= function(k, v){
			hd = doc.createElement('input');
			Ext.fly(hd).set({
				type: 'hidden',
				value: v,
				name: k
			});
			form.appendChild(hd);
			hiddens.push(hd);
		};
		
		addParam('RequestContentType', 'text/x-rapidapp-form-response');
		Ext.iterate(Ext.urlDecode(ps, false), addParam);
		if (o.params)
			Ext.iterate(o.params, addParam);
		if (o.headers)
			Ext.iterate(o.headers, addParam);
		
		function cb(){
			var me = this,
				r = {responseText : '',
					responseXML : null,
					responseHeaders : {},
					getResponseHeader: function(key) { return this.responseHeaders[key]; },
					argument : o.argument},
				doc,
				firstChild;
			
			try{
				doc = frame.contentWindow.document || frame.contentDocument || WINDOW.frames[id].document;
				if(doc){
					// Here, we modify the ExtJS stuff to also include out-of-band data that would normally be
					//   in the headers.  We store it in a second textarea
					var header_json_textarea= doc.getElementById('header_json');
					var json_textarea= doc.getElementById('json');
					
					if (header_json_textarea) {
						r.responseHeaderJson= header_json_textarea.value;
						r.responseHeaders= Ext.decode(r.responseHeaderJson) || {};
					}
					
					if (json_textarea) {
						r.responseText= json_textarea.value;
					}
					else if (doc.body) {
						if(/textarea/i.test((firstChild = doc.body.firstChild || {}).tagName)){ 
							r.responseText = firstChild.value;
						}else{
							r.responseText = doc.body.innerHTML;
						}
					}
					
					r.responseXML = doc.XMLDocument || doc;
				}
			}
			catch(e) {}
			
			Ext.EventManager.removeListener(frame, 'load', cb, me);
			
			me.fireEvent('requestcomplete', me, r, o);
			
			function current_callback_continue(fn, scope, args){
				if(Ext.isFunction(o.success)) o.success.apply(o.scope, [r, o]);
				if(Ext.isFunction(o.callback)) o.callback.apply(o.scope, [o, true, r]);
			}
			
			Ext.ux.RapidApp.handleCustomServerDirectives(r, current_callback_continue, success_callback_repeat);
			
			if(!me.debugUploads){
				setTimeout(function(){Ext.removeNode(frame);}, 100);
			}
		}
		
		Ext.EventManager.on(frame, 'load', cb, this);
		form.submit();
		
		Ext.fly(form).set(buf);
		Ext.each(hiddens, function(h) {
			Ext.removeNode(h);
		});
	}
});

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

// Window Group for Custom Prompts to make them higher than other windows and load masks
Ext.ux.RapidApp.CustomPromptWindowGroup = new Ext.WindowGroup();
Ext.ux.RapidApp.CustomPromptWindowGroup.zseed = 20050;

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
		var myInput = iframe.doc.createElement("input") ;
		myInput.setAttribute("name", k) ;
		myInput.setAttribute("value", p[k]);
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
			iconCls: 'icon-cross',
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
	if (val == null) { return '<span style="color:darkgrey;">(not&nbsp;set)</span>'; }
	if (val === "") { return '<span style="color:darkgrey;">(empty&nbsp;string)</span>'; }
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
	if(! cfg.cancelHandler)			{ cfg.cancelHandler = Ext.emptyFn;	}
	if(! typeof(cfg.closable))		{ cfg.closable = true;	}
	
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

	var failure_fn = function(response,options) {
		if (cfg.failure) { cfg.failure.apply(scope,arguments); }
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
						if(cfg.disableBtn) {
							btn.setDisabled(true);
							btn.setText('Wait...');
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
				},
				{
					text		: 'Cancel',
					handler	: cancel_fn
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



Ext.ux.AutoPanel = Ext.extend(Ext.Panel, {

	setTitle: function() {
		Ext.ux.AutoPanel.superclass.setTitle.apply(this,arguments);
		
		// If our owner is the RapidApp 'main-load-target' TabPanel, this will
		// update the browser title
		if(this.ownerCt && Ext.isFunction(this.ownerCt.applyTabTitle)) {
			this.ownerCt.applyTabTitle();
		}
	},
	
	// Override Ext.Component.getId() auto id generation
	getId : function(){
		return this.id || (this.id = 'ap-' + (++Ext.Component.AUTO_ID));
	},
	
	cmpListeners: null,
	cmpConfig: {},
	update_cmpConfig: null,
	
	// Save the ID of the AutoPanel in the Updater object for referencing if
	// an exception (X-RapidApp-Exception) occurs during content load:
	doAutoLoad: function() {
		var u = this.body.getUpdater();
		u.AutoPanelId = this.getId();
		Ext.ux.AutoPanel.superclass.doAutoLoad.call(this);
	},
	
	initComponent: function() {
		
		// -- Make sure no highlighting can happen during load (this prevents highlight
		//    bugs that can happen if we double-clicked something to spawn this panel)
		var thisEl;
		this.on('render',function(){
			thisEl = this.getEl();
			thisEl.addClass('no-text-select');
		},this);
		// Allowing highlighting within the panel once loading is complete:
		this.on('afterlayout',function(){
			thisEl = this.getEl();
			thisEl.removeClass('no-text-select');
		},this);
		// --

		var container = this;
		this.renderer = {
			disableCaching: true,
			render: function(el, response, updater, callback) {
				if (!updater.isUpdating() && el.dom) {
					var conf = Ext.decode(response.responseText);
					Ext.apply(conf,container.cmpConfig);
					
					// new: 'update_cmpConfig' - same thing as cmpConfig except it is a
					// function-based api which allows updating the config based on 
					// the existing config instead of blindly like cmpConfig does
					if(Ext.isFunction(container.update_cmpConfig)) {
						container.update_cmpConfig(conf);
					}
					
					if(container.cmpListeners) {
						conf.initComponent = function() {
							this.on(container.cmpListeners);
							this.constructor.prototype.initComponent.call(this);
						};
					}

					container.setBodyConf.call(container,conf,el);
					
					// This is legacy and should probably be removed:
					if (conf.rendered_eval) { eval(conf.rendered_eval); }
				}
			}
		};

		Ext.ux.AutoPanel.superclass.initComponent.call(this);
	},
	
	setBodyConf: function(conf,thisEl) {
		thisEl = thisEl || this.getEl();
		if(this.items.getCount() > 0) { this.removeAll(true); }
		this.insert(0,conf);
		this.doLayout();
	},
	
	setErrorBody: function(title,msg) {
		this.setTitle('Load Failed');
		this.setIconClass('icon-cancel');
		
		this.setBodyConf({
			layout: 'fit',
			autoScroll: true,
			frame: true,
			xtype: 'panel',
			html: '<div class="ra-autopanel-error">' +
				'<div class="ra-exception-heading">' + title + '</div>' +
				'<div class="msg">' + msg + '</div>' +
			'</div>'
		},this.getEl());
	}
});
Ext.reg('autopanel',Ext.ux.AutoPanel);



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


/* 2011-01-28 by HV:
 Extended Saki's Ext.ux.form.DateTime to updateValue on 'select' and then 
 fire the new event 'updated'
*/
Ext.ns('Ext.ux.RapidApp.form');
Ext.ux.RapidApp.form.DateTime2 = Ext.extend(Ext.ux.form.DateTime ,{
	initComponent: function() {
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
	}
});
Ext.reg('xdatetime2', Ext.ux.RapidApp.form.DateTime2);


/*
 Creates a "tool" button just like the tools from "tools" in Ext.Panel
 Inspired by: http://www.sencha.com/forum/showthread.php?119956-use-x-tool-close-icon-in-toolbar&highlight=tool+button
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
		
		this.cls = 'x-tool x-tool-' + this.toolType;
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
	defaultAutoCreate : { tag: 'div', cls: 'x-logical-checkbox icon-checkbox-clear' },
	
	onRender: function(ct, position) {
		if(this.value == "0") { this.value = false; }
		if(typeof this.value !== 'undefined') { this.checked = this.value ? true : false; }
		Ext.ux.RapidApp.LogicalCheckbox.superclass.onRender.apply(this,arguments);
	},
	
	setValue: function(v) {
		Ext.ux.RapidApp.LogicalCheckbox.superclass.setValue.apply(this,arguments);
		if (v) {
			this.el.replaceClass('icon-checkbox-clear','icon-checkbox');
		}
		else {
			this.el.replaceClass('icon-checkbox','icon-checkbox-clear');
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
	loadingIconCls: 'icon-loading', // <-- set this to null to disable the loading icon feature
	
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
		}
		Ext.ux.RapidApp.menu.ToggleSubmenuItem.superclass.initComponent.call(this);
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
	leftIconCls: 'icon-checkbox-yes',
	rightTitle: 'Not Selected',
	rightIconCls: 'icon-checkbox-no',
	
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
			iconCls: 'icon-arrow-left',
			iconAlign: 'left',
			handler: function() {
				cmp.addRowsSelected.call(cmp);
			},
			disabled: true
		});
		
		this.removeButton = new Ext.Button({
			text: 'Remove',
			iconCls: 'icon-arrow-right',
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

	initComponent: function() {

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
										var btn = field.ownerCt.ownerCt;
										btn.setText(size + suffix_str);
										paging.doLoad();
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
			
			//this.beforePageText = {
			var page_btn = {
				xtype: 'button',
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
			};
		}
		
		
		this.beforePageText = '';
		this.displayMsg = '{0} - {1} of <span style="font-size:1.1em;color:#083772;">{2}</span>';
		
		// place the query time label immediately after 'refresh'
		this.prependButtons = false;
		this.items = this.items || [];
		paging.queryTimeLabel = new Ext.form.Label({
			html: '',
			style: 'color:#b3b3b3;font-size:0.85em;padding-left:10px;' // light gray
		});
		this.items.unshift(paging.queryTimeLabel);
		
		Ext.ux.RapidApp.PagingToolbar.superclass.initComponent.call(this);
		
		this.insert(this.items.getCount() - 1,page_btn,' ');
		
		this.store.on('load',function(store) {
			if(store.reader && store.reader.jsonData) {
				//'query_time' is returned from the server, see DbicLink2
				var query_time = store.reader.jsonData.query_time;
				if(query_time) {
					paging.queryTimeLabel.setText('query time ' + query_time);
				}
				else {
					paging.queryTimeLabel.setText('');
				}
			}
		},this);
		
		this.store.on('exception',function(store) {
			paging.queryTimeLabel.setText('--');
		},this);

	}
});
Ext.reg('rapidapp-paging',Ext.ux.RapidApp.PagingToolbar);


Ext.ux.RapidApp.IconClsRenderFn = function(val) {
	if (val == null || val === "") { return Ext.ux.showNull(val); }
	//return '<div style="width:16px;height:16px;" class="' + val + '"></div>';
	return '<div class="with-icon ' + val + '">' + val + '</div>';
}


/*
  BgTaskRenderPanel
  
  Renders the interface to the BgTask supervisor process.
  
  At the moment, this doesn't include any buttons or an input blank, but those will likely
  be future options on this class.  (or, perhaps create a BgTaskInterface which contains a BgTaskRenderPanel)
*/

Ext.ux.RapidApp.BgTaskRenderPanel= Ext.extend(Ext.Panel, {
	controllerUrl: null,  // URL to a controller implementing BgTaskRenderHandler
	callbackParams: null, // Extra parameters supplied to Get or Post when coming back to the controller
	
	running: false,
	updateInProgress: false,
	
	updateInterval: 2000,
	scrollbackLines: 500,
	errorCount: 0,
	
	lines: [],
	
	lineOffsets: [],
	
	/* The box structure we use is a border layout, with a scrollable panel inside, with a simple div in it
	   that we write all our HTML into */
	constructor: function(config) {
		var self= this;
		config= Ext.apply({
				layout: 'border',
				items: [
					{ xtype: 'panel', itemId: 'scroller', region: 'center', autoScroll: true,
						items: [
							{ xtype: 'box', itemId: 'textBlock', cls: 'bgtask-terminal', html: '<div>connecting...</div>' },
							{ xtype: 'spacer', itemId: 'bottom', width:1, height:1 }
						]
					}
				]
			},
			config
		);
		Ext.ux.RapidApp.BgTaskRenderPanel.superclass.constructor.call(this, config);
		this.controllerUrl= config.controllerUrl;
		this.callbackParams= config.callbackParams? Ext.apply( {}, config.callbackParams ) : {};
		if (config.initStart) {
			this.start();
		}
	},
	
	/* Refresh the HTML content of the window with the data stored in this.lines.
	   This also accounts for proper scrolling. */
	refresh: function() {
		var scroller= this.getComponent('scroller');
		var textBlock= scroller.getComponent('textBlock');
		var scroller= textBlock.getEl().dom.parentNode;
		var isAtBottom= (scroller.scrollTop + scroller.clientHeight > scroller.scrollHeight - 15);
		textBlock.getEl().first().replaceWith({
			tag: 'div',
			html: this.lines.join('<br />')
		});
		if (isAtBottom) {
			scroller.scrollTop= scroller.scrollHeight;
		}
	},
	
	/* Update this.lines and this.lineOffsets with the new data from the parameters.
	   The values of this.lineOffsets and newLineOffsets are used to determine which lines get overwritten. */
	applyNewLines: function(newLines, newLineOffsets) {
		if (newLines.length != newLineOffsets.length)
			return Ext.Msg.alert('Error', 'Problem communicating with server.  Please refresh page');
		if (newLines.length < 1)
			return;
		
		while (this.lines.length > 0 && this.lineOffsets[this.lineOffsets.length - 1] >= newLineOffsets[0]) {
			this.lines.pop();
			this.lineOffsets.pop();
		}
		
		this.lines= this.lines.concat(newLines);
		this.lineOffsets= this.lineOffsets.concat(newLineOffsets);
		if (this.lines.length > this.scrollbackLines) {
			this.lines= this.lines.slice(-this.scrollbackLines);
			this.lineOffsets= this.lineOffsets.slice(-this.scrollbackLines);
		}
	},
	
	/* Begin polling for updates */
	start: function() {
		this.running= true;
		this.initiatePoll();
	},
	
	/* Stop polling for updates */
	stop: function() {
		this.running= false;
	},
	
	/* Internal method which begins one update, and schedules itself to recur, based on various flags.
	   No update is performed if the window is not visible.
	   No update is performed if another update is in progress (safeguard against overlapping updates)
	   Updates are stopped completely if the last few attempts errored out.
	   Updates are stopped completely if the window has been destroyed.
	   Method is rescheduled if updates are enabled and the method isn't already scheduled.
	   
	   Update requests are handled in this.processLinesAndStatus
	*/
	initiatePoll: function() {
		var self= this;
		if (!this.updateInProgress && this.checkVisibility()) {
			this.updateInProgress= true;
			Ext.Ajax.request({
				url: this.controllerUrl + '/readOutput',
				params: Ext.apply(
					{ lastLineOfs: this.lineOffsets.length > 0? this.lineOffsets[ this.lineOffsets.length - 1 ] : 0 },
					this.callbackParams
				),
				disableCaching: true,
				callback: function(options, success, res) {
					self.updateInProgress= false;
					if (success) {
						self.errorCount= 0;
						try {
							var ret= Ext.util.JSON.decode(res.responseText);
							if (ret.success) {
								self.processLinesAndStatus(ret);
							}
							else { self.errorCount++; }
						}
						catch (err) { self.errorCount++; }
					}
					else { self.errorCount++; }
				}
			});
		}
		
		if (!self.ownerCt || self.errorCount > 5) self.stop();
		
		if (this.running && !self.timerActive) {
			self.timerActive= true;
			window.setTimeout(function() { self.timerActive= false; self.initiatePoll(); }, this.updateInterval);
		}
	},
	
	/* Handle the update response from the server.
	   Appends any new lines received.
	   Displays special markup if the job terminated.
	   Calls this.refresh to update the screen.
	*/
	processLinesAndStatus: function(params) {
		if (params.reset) {
			this.lines= [''];
			this.lineOffsets= [0];
		}
		// check for errors, or end of program
		var eof= params.streamInfo.eof;
		var err= params.streamInfo.error;
		var errMsg= params.streamInfo.errMsg;
		var exited= 'exit' in params.exitStatus;
		var exitCode= params.exitStatus.exit;
		var sig= params.exitStatus.signal;
		
		if (eof || err || exited) {
			this.stop();
			var appendix= '<hr />';
			if (err) {
				appendix= appendix+'<span style="color:red">Error reading stream'+(errMsg? ': '+errMsg : '')+'</span>';
			} else if (eof) {
				appendix= appendix+'<span style="color:green">[ eof ]</span>';
			}
			
			if (sig) {
				appendix = appendix
					+ '<br /><span style="color:red">Task exited on signal '+sig+'</span>';
			} else if (exited) {
				appendix = appendix
					+ '<br /><span style="color:'+(exitCode? 'red':'green')
					+'">Task exited with code '+exitCode+'</span>';
			}
			
			if (!params.lines.length) {
				params.lines.push('');
				params.lineOffsets.push(0);
			}
			params.lines.push(params.lines.pop() + appendix);
		}
		this.applyNewLines(params.lines, params.lineOffsets);
		this.refresh();
	},
	
	/* Determine whether this window and all the parents up to the viewport are visible. */
	checkVisibility: function() {
		var cmp= this;
		while (cmp) {
			if (cmp.hidden) return false;
			if (cmp.xtype && cmp.xtype == 'dyncontainer') return true;
			cmp= cmp.ownerCt;
		}
		return false;
	}
});

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
	
	initComponent: function() {
		
		this.on('beforepropertychange',function(source,rec,n,o) {
			
			// FIXME!!!!!
			
			if(n == null && o == '0') { return false; }
			if(o == null && n == '0') { return false; }
			if(n == true && o == '1') { return false; }
			if(o == true && n == '1') { return false; }
			
			
			
		},this);
		
		this.bindStore = this.store;
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
				wrapcss = ' with-background-right-image icon-gray-pencil';
				if (xtype == 'combo' || xtype == 'appcombo2') {
					wrapcss = ' with-background-right-image icon-gray-down';
				}

				this.editable_fields[field.name] = 1;
			}
			
			var orig_renderer = field.renderer;
			field.renderer = function(value,metaData,record,rowIndex,colIndex) {
				
				// Turn on word-wrap (set to off in a normal grid)
				metaData.attr = 'style="white-space:normal;"';
				
				// Mark dirty like in normal grid:
				var bindRec = propgrid.bindRecord
				if(bindRec && bindRec.dirty && bindRec.modified[record.id]) {
					metaData.css += ' x-grid3-dirty-cell';
				}
				
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
		
		/* -- vv -- Make text of the value column selectable (copy/paste) :*/
		// TODO: expand/refine this
		var val_col = this.getColumnModel().getColumnById('value');
		val_col.css = '-moz-user-select: text;-khtml-user-select: text;';
		/* -- ^^ -- */
		
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
		return '<img src="/static/ext/resources/images/default/s.gif" class="icon-12x12 icon-cross-light-12x12">';
	}
	return '<img src="/static/ext/resources/images/default/s.gif" class="icon-12x12 icon-checkmark-12x12">';
}

// Returns a date formatter function based on the supplied format:
Ext.ux.RapidApp.getDateFormatter = function(format) {
	if (!format) { format = "Y-m-d H:i:s"; }
	return function(date) {
		var dt = Date.parseDate(date,"Y-m-d H:i:s");
		if (! dt) { return date; }
		return dt.format(format);
	}
}


Ext.ux.RapidApp.renderPencil = function(val) {
	return '<span>' + val + '</span>' + 
		'<img src="/static/ext/resources/images/default/s.gif" class="icon-14x14 icon-gray-pencil">';
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
			var loadTarget = Ext.getCmp("explorer-id").getComponent("load-target");
			loadTarget.loadContent(loadCfg);
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


/* http://www.sencha.com/forum/showthread.php?95486-Cursor-Position-in-TextField&p=609639&viewfull=1#post609639 */
Ext.override(Ext.form.Field, {

    setCursorPosition: function(pos) {
       var el = this.getEl().dom;
		 if(!el) { return; } // <-- rare cases this is undef and throws error
       if (el.createTextRange) {
          var range = el.createTextRange();
          range.move("character", pos);
          range.select();
       } else if(typeof el.selectionStart == "number" ) { 
          el.focus(); 
          el.setSelectionRange(pos, pos); 
       } else {
         //alert('Method not supported');
         return;
       }
    },

    getCursorPosition: function() {
       var el = this.getEl().dom;
       var rng, ii=-1;
       if (typeof el.selectionStart=="number") {
          ii=el.selectionStart;
       } else if (document.selection && el.createTextRange){
          rng=document.selection.createRange();
          rng.collapse(true);
          rng.moveStart("character", -el.value.length);
          ii=rng.text.length;
       }
       return ii;
    }
   
});

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
	var disp = c.disp || c.record.data[c.render_col];
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
	
	if(!c.value)		{ return disp; }
	if(!disp) 			{ return c.value; }
	if(!c.open_url)	{ return disp; }
	
	var url = '#!' + c.open_url + '/';
	if(c.rest_key) { url += c.rest_key + '/'; }
	
	
	if(c.rs) {
		// multi-rel: no link for 0 records:
		if(c.value == '0') { return disp; }
		// For multi-rel. value actually only contains the count of related
		// rows. key_value will contain the id of the row from which the rs originated
		url += key_value + '/rs/' + c.rs; 
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
		"magnify-link-tiny",
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
		"magnify-link-tiny",
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

