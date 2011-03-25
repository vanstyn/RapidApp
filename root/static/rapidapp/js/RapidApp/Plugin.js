Ext.ns('Ext.ux.RapidApp.Plugin');

/* disabled and replaced by "listener_callbacks"

// Generic plugin that loads a list of event handlers. These 
// should be passed as an array of arrays, where the first
// element of each inner array is the event name, and the rest
// of the items are the handlers (functions) to register

Ext.ux.RapidApp.Plugin.EventHandlers = Ext.extend(Ext.util.Observable,{

	init: function(cmp) {
		if (! Ext.isArray(cmp.event_handlers)) { return true; }
		
		Ext.each(cmp.event_handlers,function(item) {
			if (! Ext.isArray(item)) { throw "invalid element found in event_handlers (should be array of arrays)"; }
			
			var event = item.shift();
			Ext.each(item,function(handler) {
				//Add handler:
				cmp.on(event,handler);
			});
		});
	}
});
Ext.preg('rappeventhandlers',Ext.ux.RapidApp.Plugin.EventHandlers);
*/


/* 2011-03-25 by HV:
 This is my solution to the problem described here:
 http://www.sencha.com/forum/showthread.php?92215-Toolbar-resizing-problem
*/
Ext.ux.RapidApp.Plugin.AutoWidthToolbars = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		if(! cmp.getTopToolbar) { return; }
		cmp.on('afterrender',function(c) {
			var tbar = c.getTopToolbar();
			if(tbar) {
				this.setAutoSize(tbar);
			}
			var bbar = c.getBottomToolbar();
			if(bbar) {
				this.setAutoSize(bbar);
			}
		},this);
	},
	setAutoSize: function(toolbar) {
		var El = toolbar.getEl();
		El.setSize('auto');
		El.parent().setSize('auto');
	}
});
Ext.preg('autowidthtoolbars',Ext.ux.RapidApp.Plugin.AutoWidthToolbars);