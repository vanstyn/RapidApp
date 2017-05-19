
/**
 * We override Connection so that **Every** AJAX request gets our processing added to it.
 * We first set up a closure that can re-issue the current request, and then check headers
 *   to see if we want to interrupt the current one.
 */
Ext.override(Ext.data.Connection,{
  //request_orig: Ext.data.Connection.prototype.request,
  //request: function(opts) {
  //  return this.request_orig(opts);
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



Ext.ux.AutoPanel = Ext.extend(Ext.Panel, {

  // Set the timeout to match the Ajax default:
  timeout: Ext.Ajax.timeout,

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
  
  errorDataForResponse: function(response) {
    var opt = { 
      tabTitle: '<span style="color:gray;">(load failed)</span>',
      tabIconCls: 'ra-icon-warning' 
    };
    
    var retry_text = [
     'Please try again later.&nbsp;&nbsp;',
     '<div style=height:20px;"></div>',
     '<span style="font-size:.7em;">',
     '<i style="white-space:normal;">If you continue to receive this message, please contact your ',
     'System Administrator.</i></span>',
     '<div class="retry-foot">',
      '<center>',
        '<span',
          'class="with-icon ra-icon-refresh-24x24 ra-autopanel-reloader"',
          'style="font-size:1.5em;display:inline;vertical-align:baseline;padding-left:40px;"',
        '>Try Again</span>',
      '</center>',
     '</div>'
    ].join(' ');
    
    opt.title = 'Load Request Failed:';
    opt.msg = '<div style="padding:10px;font-size:1.3em;color:navy;">&nbsp;&nbsp;' +
     response.statusText + 
     '&nbsp;</div>' +
     '<br>' + retry_text;
    
    
    // All-purpose timeout message:
    if(response.isTimeout) {
      opt.tabTitle = '<span style="color:gray;">(timed out)</span>';
      opt.title = 'Load Request Timeout';
      opt.msg = 'The page/content load request timed out.<br><br>Possible causes:<br>' +
       '<ol style="list-style:circle inside;padding:20px;font-size:.8em;color:navy;">' +
       '<li>Connection problem. (check to make sure you can access other sites)</li>' +
       '<li>The server may be responding slowly due to an unusually high load.</li>' +
       '<li>The system may be temporarily down for maintentence.</li>' +
       '</ol>' + retry_text;
    }
    
    return opt;
  
  },
  
  onAutoLoadFailure: function(el,response) {
    // --- RapidApp Exceptions are handled in global Ajax handlers:
    if(
      response && Ext.isFunction(response.getResponseHeader) &&
      response.getResponseHeader('X-RapidApp-Exception')
    ) { return; }
    // ---
    
    var opt = this.errorDataForResponse(response);

    return this.setErrorBody(opt.title,opt.msg,opt);
  },

  // Save the ID of the AutoPanel in the Updater object for referencing if
  // an exception (X-RapidApp-Exception) occurs during content load:
  doAutoLoad: function() {
    var u = this.body.getUpdater();
    
    // -- Set the 'Updater' timeout: (note conversion from millisecs to secs)
    u.timeout = (this.timeout)/1000;
    
    //New: allow custom timeout to be set via autoLoad param:
    if(Ext.isObject(this.autoLoad) && this.autoLoad.timeout) {
      u.timeout = (this.autoLoad.timeout)/1000;
    }
    // --
    
    // -----  AutoPanel failure handler  -----
    u.on('failure',this.onAutoLoadFailure,this);
    // -----   ***   -----
    
    u.AutoPanelId = this.getId();
    Ext.ux.AutoPanel.superclass.doAutoLoad.call(this);
  },

  initComponent: function() {
    
    // -- Make sure no highlighting can happen during load (this prevents highlight
    //    bugs that can happen if we double-clicked something to spawn this panel)
    var thisEl;
    this.on('render',function(){
      thisEl = this.getEl();
      thisEl.addClass('ra-ap-body');
      thisEl.addClass('no-text-select');
      
      this.on('resize',this.setSafesizeClasses,this);
      this.setSafesizeClasses();
      
      // Listen for clicks on custom 'ra-autopanel-reloader' elements
      // to fire reload of the panel. This provides inline access to
      // this function within the html/content of the panel. 
      // (Added for Github Issue #24)
      thisEl.on('click',function(e,t,o) {
        var target = e.getTarget(null,null,true);
        if(target && target.hasClass('ra-autopanel-reloader')) {
        // in the case of nested AutoPanels, don't allow this event to
        // bubble up higher:
        e.stopEvent(); 
        this.reload();
        }
      }, this);
      
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
          
          var conf, content_type = response.getResponseHeader('Content-Type');
          var cont_parts = content_type.split(';');
          
          // Expected content-type returned by a RapidApp module:
          if(cont_parts[0] == 'text/javascript') {
            try {
              conf = Ext.decode(response.responseText);
            }
            catch(err) {
              throw [
                'RapidApp Ext.ux.AutoPanel render exception - ',
                'Error encountered decoding response JSON/JavaScript (size: '+response.responseText.length+'):',
                '  "'+err+'"',"STACK:",err.stack
              ].join("\n");
            };
          }
          else {
            var html, title, icon = 'ra-icon-document', 
              style = "font-weight:lighter;font-family:arial;";
            if (cont_parts[0] == 'text/html') {
              icon = 'ra-icon-page-white-world';
              html = response.responseText;
              
              // --- Support special syntax to parse tab title/icon/style
              var div = document.createElement('div');
              var El = new Ext.Element(div);
              El.createChild({
                tag: 'div',
                html: '<div style="padding:5px;">' + html + '</div>'
              });
              var titleEl = El.child('title');
              if(titleEl) {
                title = titleEl.dom.innerHTML || '';
                title.replace('^\\s+',''); // strip leading whitespace
                title.replace('\\s+$',''); // strip trailing whitespace
                icon = titleEl.getAttribute('class') || icon;
                style = titleEl.getAttribute('style') || style;
              }
             
              // ---
            }
            else if (cont_parts[0] == 'text/plain') {
              icon = 'ra-icon-page-white-text';
              html = Ext.util.Format.nl2br(Ext.util.Format.htmlEncode(response.responseText));
            }
            else {
              icon: 'ra-icon-page-white';
              html = '<b>Warning, Unknown Content-Type: ' + content_type + 
                '</b><br><br><pre>' + response.responseText + '</pre>';
            }
            
            if(!title || title == '') {
              title = cont_parts[0];
              var size = response.getResponseHeader('Content-Length');
              if(size) { title = title + ' [' + Ext.util.Format.fileSize(size) + ']'; }
            }
            
            conf = {
              xtype: 'panel',
              autoScroll: true,
              tabTitle: '<span style="' + style + '">' + title + '</span>',
              tabIconCls: icon,
              html: '<div style="padding:5px;">' + html + '</div>'
            };
          }
          
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
          
          // ------------------------------------
          // TODO/FIXME: new feature - deduplicate/refactor/merge with above -
          //  Allow regular JSON configs to also tap into the tab title/icon/style
          //  via parsing html content with special param 'autopanel_parse_title'
          // UPDATE: this new option now takes precidence over 'tabTitle', which is
          // now different than above
          if(conf.autopanel_parse_title && conf.html) {
            var div = document.createElement('div');
            var El = new Ext.Element(div);
            El.createChild({
              tag: 'div',
              html: conf.html
            });
            var titleEl = El.child('title');
            if(titleEl) {
              var style = titleEl.getAttribute('style');
              var title = titleEl.dom.innerHTML || '';
              title.replace('^\\s+',''); // strip leading whitespace
              title.replace('\\s+$',''); // strip trailing whitespace
              title = title || conf.tabTitle;
              title = style ? '<span style="' + style + '">' + title + '</span>' : title;
              conf.tabTitle = title || conf.tabTitle;
              conf.tabIconCls = titleEl.getAttribute('class') || conf.tabIconCls || 'ra-icon-page-white-world';
            }
          }
          // ------------------------------------
          
          // NEW: optional override option to disable any tab title/icon 
          // configured in returned page
          if(container.autopanel_ignore_tabtitle) {
            if(conf.tabTitle) { delete conf.tabTitle; }
            if(conf.tabIconCls) { delete conf.tabIconCls; }
            if(conf.tabTitleCls) { delete conf.tabTitleCls; }
          }
          
          // New: If this is html content (i.e. not an Ext container/panel)
          // set the default body class to 'ra-scoped-reset' to escape from the
          // global ExtJS CSS which does not have useful defaults for this case
          if(conf.html && !conf.bodyCssClass) {
            conf.bodyCssClass = 'ra-scoped-reset';
          }
          
          // just for good measure, stop any existing auto refresh:
          updater.stopAutoRefresh();
          
          container.setBodyConf.call(container,conf,el,true);
          
          // autopanel_refresh_interval can be set from either the inner
          // dynamic panel, or hard-coded on the autopanel container itself:
          var refresh_interval = 
            container.autopanel_refresh_interval ||
            conf.autopanel_refresh_interval;
          
          if(refresh_interval) {
            updater.startAutoRefresh(
              refresh_interval,
              container.autoLoad
            );
          }
          
          // This is legacy and should probably be removed:
          if (conf.rendered_eval) { eval(conf.rendered_eval); }
        }
      }
    };

    Ext.ux.AutoPanel.superclass.initComponent.call(this);
  },

  setBodyConf: function(conf,thisEl,clear) {
    // Always attempt to find and remove loading-indicator
    this.purgeLoadingIndicator();
  
    thisEl = thisEl || this.getEl();
    if(this.items.getCount() > 0) { this.removeAll(true); }
    
    // Clear the existing innerHTML (deletes the loading-indicator)
    // Previously, the loading-indicator was just hidden off the bottom
    // of the panel, but certain situations could make it show back up,
    // such as when the browser tries to scroll a label into view (as
    // described in Github Issue #46 which this change was added for).
    if(clear) { thisEl.dom.innerHTML = ''; }
    
    var cmp = this.insert(0,conf);
    this.doLayout();
    if(cmp && Ext.isFunction(cmp.relayEvents)) {
      cmp.relayEvents(this,['show','activate']);
    }
  },
  
  htmlForError: function(title,msg) {
    return [
        '<div class="ra-autopanel-error">',
          '<div class="ra-exception-heading">',
            title,
            '<span style="padding-left:20px;">',
              '<a class="with-icon ra-icon-refresh ra-autopanel-reloader">',
                '<span class="ra-autopanel-reloader">',
                  'Reload',
                '</span>',
              '</a>',
            '</span>',
          '</div>',
          '<div class="msg">',msg,'</div>',
        '</div>'
      ].join('');
  },

  setErrorBody: function(title,msg,opt) {
    opt = opt || {};
    opt = Ext.apply({
      tabTitle: 'Load Failed',
      tabIconCls: 'ra-icon-cancel',
      html: this.htmlForError(title,msg)
    },opt);
    
    opt.bodyConf = opt.bodyConf || {
      layout: 'fit',
      autoScroll: true,
      frame: true,
      xtype: 'panel',
      html: opt.html
    };
    
    if(!this.autopanel_ignore_tabtitle) {
      this.setTitle(opt.tabTitle);
      this.setIconClass(opt.tabIconCls);
    }
    this.setBodyConf(opt.bodyConf,this.getEl());
  },
  
  purgeLoadingIndicator: function() {
    var loadEl = this.getEl().child('div.loading-indicator');
    if(loadEl) { loadEl.remove(); }
  },
  
  reload: function() {
    // Call removeAll now so that any listeners associated with remove/destroy can
    // be called early (removeAll also gets called during the load process later).
    // This is being done mainly to accomidate unsaved change detection in 
    // DataStorePlus-driven components, but is the right/clean thing to do 
    // regardless. Note that this is still not totally ideal, because it is already
    // too late for the user to stop the reload (as with a simple close) but at
    // least they have one last chance to save the outstanding changes which is
    // better than nothing. 
    // UPDATE -- don't do this after all because it can lead to a deadlock situation
    //           just purge the listeners b/c it is too late for the user to save 
    //           their changes if they clicked reload on the tab. Just like there
    //           is nothing we can do if they refreshed the browser.
    //this.removeAll();
    // TODO: hook into the guts of this process to support
    // actually cancelling the reload. This would need to be done by calling and
    // testing the result of 'beforeremove'
    
    // NEW/Updated:
    // Clear *only* 'beforeremove' events -- we can't call purgeListeners()
    // because it breaks things like resize events. We only really need to
    // escape 'beforeremove' because, again, its too late at this point to abort
    // the remove, which is what beforeremove is for (as discussed above)
    var befRem = this.events.beforeremove;
    if(befRem && typeof befRem == 'object') {
      befRem.clearListeners();
    }
    
    // Purge any child listeners for good measure (probably not needed)
    this.items.each(function(itm) { itm.purgeListeners(); });

    // Now call load using the same/original autoLoad config:
    this.load(this.autoLoad);
  },
  
  
  // This method sets 5 informational CSS classes on the body element
  // pertaining to the current size of the element within the browser.
  // There is no active RapidApp code that takes any action based on
  // the presence of these classes, however, it is available to
  // user-defined CSS/HTML. Each class is 1 of a predefined set of possible
  // values defining the "safesize" that inner content can be set to in order
  // to be visible without scrolling. These are for width alone, height
  // alone, and heightXwidth(ws), each of which might be useful in different
  // ways for CSS rules. For example, 'ra-safesize-w640' means that content
  // up to at least 640 pixels wide will be viewable without scrolling.
  // On the other hand, 'ra-safesize-800x600' means that at least that size
  // **sqaure** (i.e. 2-dimensions instead of 1) will be visible. CSS rules
  // can then take action to adjust inner content accordingly, such as
  // making sure a video in an iFrame will always display w/o scrolling
  //
  // There is also a 5th more general class set to one of:
  //   * ra-safesize-small
  //   * ra-safesize-medium
  //   * ra-safesize-large
  //
  // These are provided to limit the number of rules required to cover the
  // entire spectrum of sizes w/o gaps. They can be used alone, or in combination with 
  // the more-specific resolution values to zero in on the size at one end
  // of the size spectrum and not the other (for example, custom CSS could
  // be set for several different small styles and single rules for medium/large)
  setSafesizeClasses: function() {
    var El = this.getEl();
    var width = El.getWidth() + 4;
    var height = El.getHeight() + 4;
    
    // 4x3
    var xWidth = parseInt(height/0.75);
    if(xWidth > width) { xWidth = width; }
    
    //16x9
    var xwWidth = parseInt(height/0.5625);
    if(xwWidth > width) { xwWidth = width; }
    
    var wClass, hClass, xClass, xwClass, smlClass;
    
    wClass = 'ra-safesize-w0';
    if(width > 100)  { wClass = 'ra-safesize-w100'; }
    if(width > 320)  { wClass = 'ra-safesize-w320'; }
    if(width > 480)  { wClass = 'ra-safesize-w480'; }
    if(width > 640)  { wClass = 'ra-safesize-w640'; }
    if(width > 800)  { wClass = 'ra-safesize-w800'; }
    if(width > 1024) { wClass = 'ra-safesize-w1024'; }
    if(width > 1400) { wClass = 'ra-safesize-w1400'; }
    
    hClass = 'ra-safesize-h0';
    if(height > 50)  { hClass = 'ra-safesize-h50'; }
    if(height > 120) { hClass = 'ra-safesize-h120'; }
    if(height > 240) { hClass = 'ra-safesize-h240'; }
    if(height > 360) { hClass = 'ra-safesize-h360'; }
    if(height > 480) { hClass = 'ra-safesize-h480'; }
    if(height > 600) { hClass = 'ra-safesize-h600'; }
    if(height > 768) { hClass = 'ra-safesize-h768'; }
    if(height > 1050) { hClass = 'ra-safesize-h768'; }
    
    xClass = 'ra-safesize-0x0';
    if(xWidth > 200)  { xClass = 'ra-safesize-200x150'; }
    if(xWidth > 320)  { xClass = 'ra-safesize-320x240'; }
    if(xWidth > 480)  { xClass = 'ra-safesize-480x360'; }
    if(xWidth > 640)  { xClass = 'ra-safesize-640x480'; }
    if(xWidth > 800)  { xClass = 'ra-safesize-800x600'; }
    if(xWidth > 1024) { xClass = 'ra-safesize-1024x768'; }
    if(xWidth > 1400) { xClass = 'ra-safesize-1400x1050'; }
    
    xwClass = 'ra-safesize-0x0ws';
    if(xwWidth > 320)  { xwClass = 'ra-safesize-320x200ws'; }
    if(xwWidth > 480)  { xwClass = 'ra-safesize-480x270ws'; }
    if(xwWidth > 640)  { xwClass = 'ra-safesize-640x360ws'; }
    if(xwWidth > 800)  { xwClass = 'ra-safesize-800x450ws'; }
    if(xwWidth > 1024) { xwClass = 'ra-safesize-1024x576ws'; }
    if(xwWidth > 1280) { xwClass = 'ra-safesize-1280x720ws'; }
    if(xwWidth > 1920) { xwClass = 'ra-safesize-1920x1080ws'; }
    
    // Alternate broader small/medium/large
    smlClass = 'ra-safesize-small';
    if(xWidth > 480)  { smlClass = 'ra-safesize-medium'; }
    if(xWidth > 800)  { smlClass = 'ra-safesize-large'; }
    
    if(this.current_safesize_Classes) {
      El.removeClass(this.current_safesize_Classes);
    }
    
    this.current_safesize_Classes = [wClass,hClass,xClass,xwClass,smlClass];
    El.addClass(this.current_safesize_Classes);
  }
  
});
Ext.reg('autopanel',Ext.ux.AutoPanel);

Ext.ns('Ext.ux.RapidApp');


Ext.ux.RapidApp.showAjaxError = function(title,msg,options,data) {
  data = data || {};

  // -----------------------------------------------------------------------------
  // Check to see if this exception is associated with an AutoPanel load, and
  // if it is, display the exception message in the AutoPanel body instead of in
  // a new window
  if(options && options.scope && options.scope.AutoPanelId) {
    var AutoPanel = Ext.getCmp(options.scope.AutoPanelId);
    if(AutoPanel) {
      return AutoPanel.setErrorBody.call(AutoPanel,title,msg);
    }
  }
  // -----------------------------------------------------------------------------
  else {
    if (data.winform) {
      return Ext.ux.RapidApp.WinFormPost(data.winform);
    }
    else {
      return Ext.ux.RapidApp.errMsgHandler(title,msg,data.as_text,data.extra_opts);
    }
  
  }

}

Ext.ux.RapidApp.ajaxCheckException = function(conn,response,options) {
  if (!response || !response.getResponseHeader || response.ajaxExceptionChecked){
    return;
  }
  
  response.ajaxExceptionChecked = true;

  try {
    var exception = response.getResponseHeader('X-RapidApp-Exception');
    if (exception) {
      var data = response.result || Ext.decode(response.responseText, true) || {};
      var title = data.title || 'Error';
      var msg = data.msg || 'unknown error - Ext.ux.RapidApp.ajaxCheckException';
      
      Ext.ux.RapidApp.showAjaxError(title,msg,options,data);
    }
    
    var warning = response.getResponseHeader('X-RapidApp-Warning');
    if (warning) {
      var data;
        try        { data = Ext.decode(warning); }
        catch(err) { data = { title: 'Warning', msg: warning }; }
        
      var title = data.title || 'Warning';
      var msg = data.msg || 'Unknown (X-RapidApp-Warning)';
      Ext.ux.RapidApp.errMsgHandler(title,msg,data.as_text,{
        win_title: 'Warning',
        warn_icon: true,
        win_width: 500,
        win_height: 300
      });
    }
    
    var eval_code = response.getResponseHeader('X-RapidApp-EVAL');
    if (eval) { eval(eval_code); }
  }
  catch(err) {}
}

Ext.ux.RapidApp.ajaxRequestContentType = function(conn,options) {
  if (!options.headers) { options.headers= {}; }
  
  if(options.url && !options.pfx_applied) {
    var pfx = Ext.ux.RapidApp.AJAX_URL_PREFIX || '';
    options.url = [pfx,options.url].join('');
    options.pfx_applied = true;
  }
  
  options.headers['X-RapidApp-RequestContentType']= 'JSON';
  options.headers['X-RapidApp-VERSION'] = Ext.ux.RapidApp.VERSION;
};


Ext.ux.RapidApp.ajaxException = function(conn,response,options) {

  var opts = options, Cmp = opts && opts.request && opts.request.scope // ref to the store object
    && opts.request.scope.datastore_plus_plugin // if the store has the DataStorePlus plugin loaded
    ? opts.request.scope.datastore_plus_plugin.cmp : null;

  if(response && response.isTimeout){
    var timeout = opts.timeout ? (opts.timeout/1000) : null;
    timeout = timeout ? timeout : conn.timeout ? (conn.timeout/1000) : null;
    var msg = timeout ? 'Ajax Request Timed Out (' + timeout + ' seconds).' : 'Ajax Request Timed Out.';

    var title = 'Timeout';
    Ext.ux.RapidApp.errMsgHandler(title,msg,null,{
      win_title: response.statusText || 'Ajax Timeout',
      warn_icon: true,
      win_width: 350,
      win_height: 200,
      smartRenderTo: Cmp
    });
  }
  else if (response && response.getResponseHeader) {
    if(response.getResponseHeader('X-RapidApp-Exception')) {
      // If this is an exception with the X-RapidApp-Exception header,
      // pass it off to the normal check exception logic
      return Ext.ux.RapidApp.ajaxCheckException.apply(this,arguments);
    }
    else {
      // If we're here, it means a raw exception was encountered (5xx) 
      // without an X-RapidApp-Exception header, so just throw the raw
      // response body as text. This should not happen - it probably means 
      // the server-side failed to catch the exception. The message will
      // probably be ugly, but it is the best/safest thing we can do at 
      // this point:
      return Ext.ux.RapidApp.showAjaxError(
        'Ajax Exception - ' + response.statusText + ' (' + response.status + ')',
        '<pre>' + Ext.util.Format.htmlEncode(response.responseText) + '</pre>',
        null, { extra_opts: { smartRenderTo: Cmp } }
      );
    }
  }
  else {
    // If we're here it means the request failed altogether, and didn't even
    // send back a response with headers (server is down, network down, etc).
    
    // If this is an AutoPanel load request, take no action, since AutoPanel
    // handles its own errors by showing them as its content: 
    // (TODO - consolidate this handling)
    if(options && options.scope && options.scope.AutoPanelId) {
      return;
    }
    
    // For all other types of Ajax requests (such as CRUD actions), display
    // the error to the user in a standard window:
    var msg = (response && response.statusText) ? 
      response.statusText : 'unknown error';
    return Ext.ux.RapidApp.showAjaxError(
      'Ajax Request Failed',
      '<div style="padding:10px;font-size:1.5em;color:navy;">&nbsp;&nbsp;' +
        '<b>' + msg + '</b>' +
      '&nbsp;</div>',
      null, { extra_opts: { smartRenderTo: Cmp } }
    );
  }
}

Ext.Ajax.on('requestexception',Ext.ux.RapidApp.ajaxException);
Ext.Ajax.on('requestcomplete',Ext.ux.RapidApp.ajaxCheckException);
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


/*  ra-async-box

NEW - general-purpose Ajax content loader, triggered by special CSS class 'ra-async-box'

This is essentially a lighter, stand-alone version of 'AutoPanel' but it is designed
to load on-the-fly in any tag with the 'ra-async-box' class and a 'src' attibute 
defined. This is meant to follow the same pattern as iframe, but our use of 'src' is
a bastardization. The content is designed to load either within another ExtJS component
or not, and hooks the appropriate resize events in either case. If we're within another
component, while we do hook its resize event, we do _NOT_ properly participate in its
layout. We are essentially stand-alone, bound to the original element.

The reason for this is to support more flexibility to load async content without needing
to setup a full-blown container structure with child items, etc, as is the case with 
AutoPanel. We may take some of these ideas back to AutoPanel as well

   -- STILL EXPERIMENTAL --   */
Ext.ux.RapidApp.loadAsyncBoxes = function(Target) {
  
  var Element, Container;
  if(Target && Target instanceof Ext.BoxComponent) {
    Container = Target;
    Element = Container.getEl();
  }
  else {
    Element = Target || Ext.getBody();
  }
  
  if(!Element || ! (Element instanceof Ext.Element)) { return; }
  
  var nodes = Element.query('.ra-async-box');
  
  Ext.each(nodes,function(dom,index){
    var El = new Ext.Element(dom);
    if(El.hasClass('loaded')) { return; }
    
    var src = El.getAttribute('src');
    if(!src) { return; }
    
    // Clear any existing content
    El.dom.innerHTML = '';
    
    // Add the 'loaded' class early to ensure we're only processed once
    El.addClass('loaded');
    
    var loadMask = new Ext.LoadMask(El);
    loadMask.show();
    
    var reloadFn = function() {
      loadMask.hide();
      El.removeClass('loaded');
      El.dom.innerHTML = '';
      return Ext.ux.RapidApp.loadAsyncBoxes(Target);
    };
    
    // Hook to reload on 'ra-autopanel-reloader' clicks, just like AutoPanel
    if(!El.reloadClickListener) {
      El.reloadClickListener = function(e,t,o) {
        var target = e.getTarget(null,null,true);
        if(target && target.hasClass('ra-autopanel-reloader')) {
          e.stopEvent(); 
          reloadFn.call(El);
        }
      };
      El.on('click',El.reloadClickListener,El);
    }

    var failure = function(response,options) {
    
      // re-use markup code from AutoPanel:
      var opt  = Ext.ux.AutoPanel.prototype.errorDataForResponse(response);
      var html = Ext.ux.AutoPanel.prototype.htmlForError(opt.title,opt.msg);
      
      var size = El.getSize();
      
      var div = document.createElement('div');
      var errEl = new Ext.Element(div);
      
      var height = size.height - 18;
      var width  = size.width  - 18;
      if(width  < 80) { width  = 80; }
      if(height < 30) { height = 30; }
      
      errEl.setSize(width,height);

      errEl.setStyle({ 
        'position'    : 'relative', 
        'overflow'    : 'auto',
        'white-space' : 'nowrap'
      });
      
      errEl.dom.innerHTML = html;
      
      El.dom.innerHTML = '';
      El.appendChild(errEl); // must already be appened before we call boxWrap()
      errEl.boxWrap(); // apply same styles as panel 'frame' option
      
      loadMask.hide();

    };
    
    var success = function(response,options) {
      var ct = response.getResponseHeader('Content-Type');
      if(ct) { ct = ct.split(';')[0]; }
      
      // The 'text/javascript' content type means this is a ExtJS config
      if(ct && ct == 'text/javascript') {

        var cnf = Ext.decode(response.responseText);
        
        // Our height and width is bound to the existing size of the element (if it has them)
        var size = El.getSize();
        if(size.height) { cnf.height = size.height; }
        if(size.width)  { cnf.width  = size.width;  }
        
        loadMask.hide();
        var Cmp = Ext.create(cnf);
        
        Cmp.reload = reloadFn;
        
        // --
        // resizeFn: Calls itself recursively up to 20 times until the height is greater than 0.
        // This gives the dom extra time to finish updating itself for when the ra-async-box has
        // its size determined by its content (which we're setting). Once the size has updated
        // and there is a positive height, it will continue to call itself until both the height
        // and width are unchanged for three iterations (80 ms apart). This is a general-purpose
        // handler for dynamic sizing, with a reletively small footprint. There is no native way
        // to handle element resize detection w/o setting up some kind of polling/timer, so this
        // is actually less hackish than it might appear on first glance...
        var resizeFn = function(){
          var _reSize, lastSize;
          _reSize = function(ttl) {
            ttl = typeof ttl == "undefined" ? 20 : ttl;
            if(ttl < 0) {  return;  }
            else        {  ttl--;   }

            var size = El.getSize();

            if(size.height == 0 && ttl >= 0) {
              var delay = 15 + ((20-ttl)*3);
              _reSize.defer(delay,this,[ttl]);
            }
            else {
              Cmp.setSize.call(Cmp,size.width,size.height);
              // Re-apply the element height to prevent recursive scenario where dynamic heights
              // cause a infinite loop progressing stepping the height, if the component setSize
              // changed the element height -- TODO: there may be more cases yet to handle...
              El.setHeight(size.height);
              if(lastSize) {
                // Reset if the size has changed:
                if(lastSize.height != size.height || lastSize.width != size.width) {
                  lastSize = null;
                }
              }
              // call ourselves again until the size stays the same, thrice more in a row
              if(!lastSize) {
                lastSize = size;
                ttl = 2;
              }
              _reSize.defer(80,this,[ttl]);
            }
          }
          _reSize();
        };
        
        // Save a reference to the resizeFn within the DOM object so it can be found again
        // later by the asyncBoxesOnResize listener, below - but NOT found if the element
        // is removed or no longer contained within the DOM (.
        dom._onAsyncBoxResize = resizeFn;
        // --
        
        if(Container) {
          // If we're within another component/container, we'll hook into its
          // 'resize' event to trigger recalculation of our size. This only
          // matters when the element's size changes, if it can, such as with
          // absolute positioning or when a width percent value is supplied, etc
          // --
          // NEW: hook using a global function only ONCE - this prevents duplicate listeners
          // from being attached to the same componenet mutliple times, which can 
          // happen when AppDV templates, or other dynamic content include ra-async-box
          // that is updated or replaced via refresh of other mechanism. This listener
          // is applied exactly 1 time per unique Container object, and uses the DOM
          // to scan and find the ra-async-box elements again, and call their resize
          // listeners (dom._onAsyncBoxResize, as set above). This is yet another example
          // of a bastardized replacement for real layout manager
          if(! Container._asyncBoxResizeListener) {
            Container._asyncBoxResizeListener = Ext.ux.RapidApp.asyncBoxesOnResize;
            Container.on('resize',Container._asyncBoxResizeListener,Container);
          }
          
          // Set our ownerCt, even though we're not proper participants in the layout
          Cmp.ownerCt = Container;
        }
        else {
          // If we're not within a container, hook the raw browser resize
          // TODO: should we also setup this case to hook only once?
          Ext.EventManager.onWindowResize(resizeFn, Cmp,{delay:300});
        }

        // Trigger resize after render so any dynamic sizes can
        // update after the new content is present:
        Cmp.on('afterrender',resizeFn,Cmp);//,{delay:50});

        Cmp.render(El);
        if(Ext.isFunction(Cmp.doLayout)) {
          Cmp.doLayout();
        }
      }
      else {
        // If we're here it means the returned content is not module config.
        // For now, we simply inline the raw text
        loadMask.hide();
        El.dom.innerHTML = response.responseText;
      }
    };

    Ext.Ajax.request({
      url     : src,
      success : success,
      failure : failure
    });
  },this);
};
// This is the global async resize listener function which we attach to 
Ext.ux.RapidApp.asyncBoxesOnResize = function(Target) {
  var args = arguments;
  var Element, Container;
  if(Target && Target instanceof Ext.BoxComponent) {
    Container = Target;
    Element = Container.getEl();
  }
  else {
    Element = Target || Ext.getBody();
  }
  
  if(!Element || ! (Element instanceof Ext.Element)) { return; }
  
  var nodes = Element.query('.ra-async-box');
  
  Ext.each(nodes,function(dom,index){
    if (dom._onAsyncBoxResize) {
      dom._onAsyncBoxResize.apply(Target,args);
    }
  },this);
};
