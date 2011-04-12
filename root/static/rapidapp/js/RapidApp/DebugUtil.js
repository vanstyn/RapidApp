Ext.ns('Ext.ux.RapidApp.Debug');

Ext.ux.RapidApp.Debug.show_components = function(xtype) {
	Ext.ComponentMgr.all.each(function(item){ 
		if(xtype) {
			if(xtype && item.getXType() == xtype) { 
				console.log(item.getXType() + ' ' + item.id); 
			}
		}
		else {
			console.log(item.getXType() + ' ' + item.id); 
		}
	});
}

Ext.ux.RapidApp.Debug.formpanel_show_invalid = function(fp) {
	fp.items.each(function(item) {
		console.log(item.getXType() + ' ' + item.id);
		if(item.validate) { console.log('  valid: ' + item.validate()); }
		
	});
	
}