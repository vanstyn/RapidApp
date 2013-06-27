Ext.ux.RapidApp.Plugin.TemplateControllerPanel = Ext.extend(Ext.util.Observable,{
	
	init: function(panel) {
    this.panel = panel;
		panel.on('afterrender',this.onAfterRender,this);
	},
 
	onAfterRender: function() {
    this.panel.getEl().on('click',function(event,node) {
      var El = new Ext.Element(node);
      if (El.hasClass('edit')) {
      
        console.dir(El);
      
      }
    },this);
	}
	
});
Ext.preg('template-controller-panel',Ext.ux.RapidApp.Plugin.TemplateControllerPanel);

