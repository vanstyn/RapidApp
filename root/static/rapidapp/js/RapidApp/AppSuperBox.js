Ext.ns('Ext.ux.RapidApp');


Ext.ux.RapidApp.AppSuperBox = Ext.extend(Ext.ux.form.SuperBoxSelect, {
	
	createItemClass: 'create-item',
	
	createItemHandler: null,
	
	onViewClick: function() {
		var event = arguments[arguments.length - 1]; // <-- last passed argument, the event object;
		var target = event.getTarget(null,null,true);
		
		// Handle create item instead of normal handler:
		if (this.createItemHandler && target.hasClass(this.createItemClass)) {
			this.collapse();
			return this.createItemHandler.call(this,this.createItemCallback);
		}

		// Original handler:
		Ext.ux.RapidApp.AppSuperBox.superclass.onViewClick.apply(this,arguments);
	},
	
	createItemCallback: function(data) {
		var Store = this.getStore();
		var recMaker = Ext.data.Record.create(Store.fields.items);
		var newRec = new recMaker(data);
		Store.insert(0,newRec);
		this.addRecord(newRec);
	}

});
Ext.reg('appsuperbox', Ext.ux.RapidApp.AppSuperBox);
