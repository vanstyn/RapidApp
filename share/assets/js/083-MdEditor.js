
Ext.ux.RapidApp.MdEditor = Ext.extend(Ext.form.Field,{

// ---------------------------------------------------------------------------------------
iframeHtml: 
`<html>
<head>
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/normalize.css' />
  <link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Open+Sans:400,700' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/stylesheet.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/github-light.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/fonts/font-awesome.min.css' />
  <link rel='stylesheet' href='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/simplemde.min.css' />
  <script src='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/simplemde.min.js'></script>
  <script src='_ra-rel-mnt_/assets/rapidapp/misc/static/simplemde/picoModal.js'></script>
</head>
<body style='margin:0px;'>
  <textarea 
    id='ta-target' 
    style='position:absolute; top:0; bottom:0; ;width:100%;border:0;'
  ></textarea>
  <script>
    window.document.simplemde = new SimpleMDE({
      picoModal: picoModal,
      customUploadActionFn: function(){ 
        throw " !! virtual method customUploadActionFn was not set to a real function!"; 
      },
      element: document.getElementById("ta-target"),
      forceSync: true,
      spellChecker: false,
      status: false,
      toolbar: [  
        "bold", "italic", "strikethrough", "heading", "|",
        "quote", "unordered-list", "ordered-list", "|",
        "table", "code", "preview", "side-by-side",
        "|", "link", "image",
        "|", {
          name: "upload",
          action: function customFunction(editor){
            return editor.options.customUploadActionFn(editor);
          },
          className: "fa fa-cloud-upload",
          title: "Insert Image/File",
        }
      ]

    });
  </script>
</body>
</html>
`
// ---------------------------------------------------------------------------------------
,

  autoCreate:  { tag: 'div' },
  autoHeight: true,
  autoWidth: true,
  
  initComponent: function() {
    this.on('afterrender',this.injectIframe,this);
    Ext.ux.RapidApp.iframeTextField.superclass.initComponent.call(this);
  },
  
  injectIframe: function() {
    if(!this.iframeDom) { 
    
      var iframe = document.createElement('iframe');
      iframe.frameborder = '0';
      iframe.src = 'about:blank';
      
      iframe.style['border']   = '0px';
      iframe.style['width']    = '100%';
      iframe.style['height']   = '100%';

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
      
      var scope = this;
      var iframe = this.iframeDom;
      
      simplemde.codemirror.setSize(null,iframe.clientHeight - 50);
      iframe.contentWindow.document.body.onresize = function() {
        simplemde.codemirror.setSize(null,iframe.clientHeight - 50);
      }
      
      simplemde.options.customUploadActionFn = function() {
        return scope.customUploadActionFn.apply(scope,arguments);
      }
      
      simplemde.codemirror.on('drop',function(cm,e) {
        // If this drop event is an file:
        //  (note: there is a bug in dumping this object in firebug, shows empty but isn't)
        var File = e.dataTransfer.files[0];
        if(!File) { return; }
        
        // prevent the browser/codemirror from any further processing:
        e.preventDefault();
        e.stopPropagation();
        
        scope.doXhrCasUpload(File);
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
  },
  
  doXhrCasUpload: function(File, addlCallback) {
    var scope = this;
    var editor = this.getSimpleMDE();
    var picoModal = editor.options.picoModal;
    var cm = editor.codemirror;
    var pos = cm.getCursor("start");
    var Xhr;

    var isImage = File.type.search('image/') == 0;
    
    var progressModal = picoModal({
      content: [
        "<h3>Uploading...</h3>"
        ,"<code><span class='pct'>0</span>% ",File.name, ' (',File.size,')</code>'
      ].join(''),
      overlayClose: false,
      closeHtml: "<span>Cancel</span>",
      closeStyles: {
          position: "absolute", bottom: "15px", right: "10px",
          background: "#eee", padding: "5px 10px", cursor: "pointer",
          borderRadius: "5px", border: "1px solid #ccc"
      },
      modalStyles: function (styles) { styles.top = '60px'; },
      focus: false,
      width: 550
    }).beforeClose(function(modal,event){
      if(Xhr && Xhr.readyState != 4) { // 4 means DONE
        Xhr.abort();
      }
    });
    
    progressModal.show();
    
    var PctEl = progressModal.modalElem().getElementsByClassName('pct')[0];
    
    var callback = function(E,event) {
      progressModal.close();
      var res = Ext.decode(E.currentTarget.responseText);
      if(res && res.filename && res.checksum) {
        var insertStr;
        if(isImage) {
          insertStr = [
            '![',res.filename,']',
            '(','_ra-rel-mnt_/simplecas/fetch_content/',res.checksum,'/',res.filename,')'
          ].join('');
        }
        else {
          insertStr = [
            '[',res.filename,']',
            '(','_ra-rel-mnt_/simplecas/fetch_content/',res.checksum,'/',res.filename,')'
          ].join('');
        }
        
        cm.replaceRange(insertStr,pos);
        pos.ch = pos.ch + insertStr.length;
      
        cm.focus();
        cm.doc.setCursor(pos);
      }
    
      if(addlCallback) { addlCallback.apply(scope,arguments); }
    }
    
    Xhr = new XMLHttpRequest();
    
    Xhr.upload.addEventListener('progress', function(E) {
      var pct = Math.floor((E.loaded/E.total)*100);
      PctEl.innerHTML = pct;
    }, false);
    
    Xhr.addEventListener('load',  function(E) { callback(E,'load')  }, false);
    Xhr.addEventListener('error', function(E) { callback(E,'error') }, false);
    Xhr.addEventListener('abort', function(E) { callback(E,'abort') }, false);
    
    var formData = new FormData();
    formData.append('Filedata', File);
    
    Xhr.open('POST', '_ra-rel-mnt_/simplecas/upload_file');
    Xhr.send(formData);
  
  },
  
  customUploadActionFn: function(editor) {

    var picoModal = editor.options.picoModal;
    var modal, insertStr;
    var cm = editor.codemirror;
    var pos = cm.getCursor("start");
    
    var scope = this;

    var onClose = function(){
    
      if(insertStr) {
        cm.replaceRange(insertStr,pos);
        pos.ch = pos.ch + insertStr.length;
      }
      
      cm.focus();
      cm.doc.setCursor(pos);
    }
    
    function onInputChange(e) {
      var File = e.target.files[0];
      if(File) {
        modal.close();
        scope.doXhrCasUpload(File);
      }
    }
    
    modal = picoModal({
        content: [
          "<h3>Upload and insert image/file</h3>",
          '<form>',
            '<div><input type="file" name="Filedata" /></div>',
          '</form>'
        ].join(''),
        modalStyles: function (styles) { styles.top = '60px'; },
        focus: false,
        width: 550
      })
      .afterCreate(function(m){
        var input = m.modalElem().getElementsByTagName('input')[0];
        if(input) {
          input.onchange = onInputChange;
        }
      })
      //.afterClose(onClose)
      .show();
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


