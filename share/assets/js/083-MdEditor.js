
Ext.ux.RapidApp.MdEditor = Ext.extend(Ext.form.Field,{

// ---------------------------------------------------------------------------------------
iframeHtml: 
`<html>
<head>
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/normalize.css' />
  <link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Open+Sans:400,700' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/stylesheet.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/github-light.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/font-awesome.min.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/simplemde.min.css' />
  <script src='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/simplemde.min.js'></script>
  <script src='_ra-rel-mnt_/assets/rapidapp/misc/current/simplemde/init.js'></script>
</head>
<body style='margin:0px;'>
  <textarea 
    id='ta-target' 
    style='position:absolute; top:0; bottom:0; ;width:100%;border:0;'
  ></textarea>
  <script>
    window.document.simplemde = new SimpleMDE({
      element: document.getElementById("ta-target"),
      forceSync: true,
      spellChecker: false,
      status: false,
      toolbar: SimpleMDE_Toolbar
    });
  </script>
</body>
</html>
`
// ---------------------------------------------------------------------------------------
,

  autoCreate:  { tag: 'div' },
  
  initComponent: function() {
    this.on('afterrender',this.injectIframe,this);
    Ext.ux.RapidApp.iframeTextField.superclass.initComponent.call(this);
  },
  
  injectIframe: function() {
    if(!this.iframeDom) { 
    
      var elHeight = this.el.getHeight(true);
      
      // 50px is the toolbar height which gets added back within simplemde/codemirror logic
      var initHeight = elHeight - 50; 
      
      console.log('initHeight: ' + initHeight);
    
      var iframe = document.createElement('iframe');
      iframe.width = '100%'; 
      //iframe.height = '100%';
      iframe.height = initHeight;
      iframe.frameborder = '0';
      iframe.style = 'border: 0px;'; //position:absolute;top:0;right:0;bottom:0:left:0;';
      iframe.src = 'about:blank';
      
      this.el.dom.appendChild(iframe);
      
      iframe.contentWindow.document.open('text/html', 'replace');
      iframe.contentWindow.document.write(this.iframeHtml);
      iframe.contentWindow.document.close();
      
      this.iframeDom = iframe;
    }
  },
  
  getSimpleMDE: function() {
    if(!this.simplemde) {
      if(!this.iframeDom) { return null; }
      var simplemde = this.iframeDom.contentWindow.document.simplemde;
      if(!simplemde) { return null; }
      
      // this is needed to get the starting size to cooporate (FIXME)
      simplemde.codemirror.setSize(null,'100%');
      
      var iframe = this.iframeDom;
      var Field = this;
      
      simplemde.codemirror.on('viewportChange',function() {
        var iframe = Field.iframeDom;
       
        var sH = iframe.contentWindow.document.body.scrollHeight;
        
        // If we're taller than the scroll height, shrink us:
        if(simplemde.codemirror.doc.height > sH) {
          var nH = sH - 50; // extra 50px to make room for toolbar
          simplemde.codemirror.setSize(null,nH);
        }
        
        // Now update the iframe to match the scrollheight:
        iframe.height = sH;
      });
      
      this.simplemde = simplemde;
    }
    return this.simplemde;
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
    if(count> 100) { return; }
    
    var simplemde = this.getSimpleMDE();
    if(simplemde) {
      simplemde.value(v);
      if(opt == 'set') {
        this.value = v;
        this.validate();
      }
    }
    else {
      this.setTextAreaText.defer(10,this,[opt,v,count+1]);
    }
  },
  
  syncValue: function() {
    var simplemde = this.getSimpleMDE();
    if(simplemde) {
      this.value = simplemde.value();
    }
  },
  
  getRawValue: function() {
    this.syncValue();
    return this.value;
  },
  
  getValue : function(){
    return this.getRawValue();
  }
  
});
Ext.reg('ra-md-editor',Ext.ux.RapidApp.MdEditor);


// This was started in order to be the parent class for MdEditor, but after a redesign it no longer 
// is. However, since its a working implementation of an iframe-based plaintext editor, it is being
// left in the code for future reference
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


