Ext.ux.RapidApp.Plugin.TemplateControllerPanel = Ext.extend(Ext.util.Observable,{
	
	init: function(panel) {
    this.panel = panel;
		panel.on('afterrender',this.onAfterRender,this);
	},
 
	onAfterRender: function() {
    this.panel.getEl().on('click',function(event,node) {
      var target = event.getTarget(null,null,true);
      var El = new Ext.Element(target);
      if (El.hasClass('edit')) {
        var tplEl = El.parent('div.ra-template');
        if (tplEl) { return this.editTplEl(tplEl); }
      }
    },this);
	},
  
  editTplEl: function(tplEl) {
    var metaEl = tplEl.child('div.meta');
    var name = metaEl.child('div.template-name').dom.innerHTML;
    name = name.replace(/(\r\n|\n|\r)/gm,""); // <-- strip newlines
    var get_url = [
      this.panel.template_controller_url,
      'get', name
    ].join('/');
    
    var success_fn = function(response,options) {
      this.loadEditor(tplEl,name,response.responseText);
    };
    
    Ext.Ajax.request({
      url: get_url,
      method: 'GET',
      success: success_fn,
      //failure: failure_fn
      scope: this
    });
  },
  
  loadEditor: function(tplEl,name,content) {
  
  
    var fp, panel = this.panel;
		
		var saveFn = function(btn) {
			var form = fp.getForm();
			var content = form.findField('content').getRawValue();
			
      var set_url = [
        this.panel.template_controller_url,
        'set', name
      ].join('/');
      
      Ext.Ajax.request({
        url: set_url,
        method: 'POST',
        params: { content: content },
        success: function(response,options) {
          this.win.close();
          
          // Reload the tab
          var tab = panel.ownerCt, tp = tab.ownerCt;
          if(Ext.isFunction(tp.loadContent) && Ext.isObject(tab.loadContentCnf)) {
            var cnf = tab.loadContentCnf;
            tp.remove(tab);
            tp.loadContent(cnf);
          }
          
          // TODO: reload the template element if nested template
          
        },
        failure: function(response,options) {
          Ext.Msg.show({
            title: 'Template Error',
            msg: Ext.util.Format.nl2br(response.responseText),
            buttons: Ext.Msg.OK,
            icon: Ext.Msg.ERROR,
            minWidth: 275
          });
        },
        scope: this
      });
      
			
			
		};
		
		fp = new Ext.form.FormPanel({
			xtype: 'form',
			frame: true,
			labelAlign: 'right',
			
			//plugins: ['dynamic-label-width'],
			labelWidth: 160,
			labelPad: 15,
			bodyStyle: 'padding: 10px 10px 5px 5px;',
			defaults: { anchor: '-0' },
			autoScroll: true,
			monitorValid: true,
			buttonAlign: 'right',
			minButtonWidth: 100,
			
			items: [
				{
					name: 'content',
					itemId: 'content',
					xtype: 'textarea',
					style: 'font-family: monospace;',
					fieldLabel: 'Template',
					hideLabel: true,
					value: content,
					anchor: '-0 -0',
				}
			],
			
			buttons: [
				{
					name: 'save',
					text: 'Save',
					iconCls: 'icon-save-ok',
					width: 100,
					formBind: true,
					scope: this,
					handler: saveFn
				},
				{
					name: 'cancel',
					text: 'Cancel',
					handler: function(btn) {
						this.win.close();
					},
					scope: this
				}
			]
		});
  
  
  
    if(this.win) { 
      this.win.close(); 
    }
    
    this.win = new Ext.Window({
			title: ["Edit Template ('",name,"')"].join(''),
			layout: 'fit',
			width: 800,
			height: 600,
			minWidth: 400,
			minHeight: 250,
			closable: true,
			closeAction: 'close',
			modal: true,
			items: fp
		});
    
    this.win.show();
  
  
  }
	
});
Ext.preg('template-controller-panel',Ext.ux.RapidApp.Plugin.TemplateControllerPanel);

