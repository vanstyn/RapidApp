
// this is the original non-iframe version, currently disabled
Ext.ux.RapidApp.MdEditor_orig = Ext.extend(Ext.form.TextArea,{
  initComponent: function() {
    this.on('render',this.initMDE,this);
    this.on('beforedestroy',this.destroyMDE,this);
    
    Ext.ux.RapidApp.MdEditor.superclass.initComponent.call(this);
  },
  
  initMDE: function() {
    this.simplemde = new SimpleMDE({ 
      element: this.el.dom,
      forceSync: true,
      initialValue: this.value,
      spellChecker: false,
      status: false
      
    });
  
  },
  
  destroyMDE: function() {
    if(this.simplemde) {
      try{ this.simplemde.toTextArea() }catch(err){};
      this.simplemde = null;
    }
  },
  
  //getValue: function() {
  //  return this.simplemde.value();
  //},
  //
  setValue: function(v) {
    Ext.ux.RapidApp.MdEditor.superclass.setValue.apply(this,arguments);
    try{ this.simplemde.value(v); } catch(err) {};
  }
  
});


Ext.ux.RapidApp.iframeTextField = Ext.extend(Ext.form.Field,{

  iframeHtmlHead: '<head></head>',
  syncOnKeyUp: true,
  
  initComponent: function() {
  
    this.iframeHtml = this.iframeHtml || [
      '<iframe frameborder="0" ',
      'srcdoc="',
      '<html>', 
      this.iframeHtmlHead,
      '<body style=\'margin:0px;\'>',
        '<textarea style=\'',
            'position:absolute; top:0; bottom:0; ;width:100%;',
            'border:0;',
         '\'></textarea>',
      '</body></html>',
      '"></iframe>'
    ].join('');
    
    this.autoCreate = {
      tag: 'div',
      html: this.iframeHtml
    };

    Ext.ux.RapidApp.iframeTextField.superclass.initComponent.call(this);
  },
  
  getIframeEl: function() {
    return this.el.first('iframe');
  },
  
  getTextAreaEl: function() {
    if(!this.textAreaEl) {
      var iframe = this.getIframeEl();
      var doc = iframe.dom.contentDocument;
      var bodyDom = doc.body;
      if(!bodyDom) { return null; }
      var el = new Ext.Element( bodyDom ).first('textarea');
      if(el && this.syncOnKeyUp) {
        el.on('keyup',this.onTextAreaKeyup,this);
        this.textAreaEl = el;
      }
    }
    return this.textAreaEl;
  },
  
  onTextAreaKeyup: function(e,dom) {
    this.syncValue(dom);
  },
  
  syncValue: function(dom) {
    if(!dom) {
      var el = this.getTextAreaEl();
      if(el) { dom = el.dom; }
    }
    if(dom) {
      this.value = dom.value;
    }
  },
  
  getRawValue: function() {
    this.syncValue();
    return this.value;
  },
  
  getValue : function(){
    return this.getRawValue();
  },
  
  setRawValue : function(v){
    return this.rendered ? (this.setTextAreaText(null,(Ext.isEmpty(v) ? '' : v))) : '';
  },

  setValue : function(v){
    this.value = v;
    if(this.rendered){
        this.setTextAreaText('set',Ext.isEmpty(v) ? '' : v);
    }
    return this;
  },

  setTextAreaText: function(opt,v,count) {
    count = count || 1;
    var el = this.getTextAreaEl();
    
    if(el) {
      el.dom.value = v;
      if(opt == 'set') {
        this.value = v;
        this.validate();
      }
    }
    else {
      this.setTextAreaText.defer(10,this,[opt,v,count+1]);
    }
  }
  
});


Ext.ux.RapidApp.MdEditor = Ext.extend(Ext.ux.RapidApp.iframeTextField,{

  iframeHtmlHead: [
    '<head>',
      '<link rel=\'stylesheet\' href=\'https://maxcdn.bootstrapcdn.com/font-awesome/latest/css/font-awesome.min.css\'>',
      '<link rel=\'stylesheet\' href=\'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css\'>',
      '<script src=\'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js\'></script>',
    '</head>'
  ].join(''),
  
  syncOnKeyup: false,

  initComponent: function() {
    this.on('render',this.initMDE,this);
    this.on('beforedestroy',this.destroyMDE,this);
    
    Ext.ux.RapidApp.MdEditor.superclass.initComponent.call(this);
  },
  
  initMDE: function() {
    var el = this.getTextAreaEl();
    if(el) { 
      this.simplemde = new SimpleMDE({
        element: el.dom,
        forceSync: true,
        initialValue: this.value,
        spellChecker: false,
        status: false
      });
      var thisF = this;
      this.simplemde.codemirror.on("change", function(){
        thisF.syncValue.call(thisF);
      });
    }
    else {
      this.initMDE.defer(10,this);
    }
  },
  
  destroyMDE: function() {
    if(this.simplemde) {
      try{ this.simplemde.toTextArea() }catch(err){};
      this.simplemde = null;
    }
  },
  
  setValue: function(v) {
    Ext.ux.RapidApp.MdEditor.superclass.setValue.apply(this,arguments);
    try{ this.simplemde.value(v); } catch(err) {};
  }
  
});
Ext.reg('ra-md-editor',Ext.ux.RapidApp.MdEditor);
