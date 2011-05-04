Ext.ns('Ext.ux.RapidApp');


Ext.ux.RapidApp.AppSuperBox = Ext.extend(Ext.ux.form.SuperBoxSelect, {
	
	createItemClass: 'create-item',
	
	onViewClick: function() {
		var event = arguments[arguments.length - 1]; // <-- last passed argument, the event object;
		var target = event.getTarget(null,null,true);
		
		// Handle create item instead of normal handler:
		if (target.hasClass(this.createItemClass)) {
			return this.createItemHandler.apply(this,arguments);
		}

		// Original handler:
		Ext.ux.RapidApp.AppSuperBox.superclass.onViewClick.apply(this,arguments);
	},
	
	createItemHandler: function() {
		
		console.dir('createItemHandler()');
		
	}

});
Ext.reg('appsuperbox', Ext.ux.RapidApp.AppSuperBox);
