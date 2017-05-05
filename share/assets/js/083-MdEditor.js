
Ext.ux.RapidApp.MdEditor = Ext.extend(Ext.form.TextArea,{
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
      this.simplemde.toTextArea();
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
Ext.reg('ra-md-editor',Ext.ux.RapidApp.MdEditor);
