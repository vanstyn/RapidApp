Ext.ns('Ext.ux.RapidApp.AppDV');

Ext.ux.RapidApp.AppDV.ClickBox = Ext.extend(Ext.ux.RapidApp.ClickBox, {
	setValue: function(val) {
		this.value = val;
	}
});
Ext.reg('appdv-clickbox', Ext.ux.RapidApp.AppDV.ClickBox);


Ext.ux.RapidApp.AppDV.edit_field_handler = function() {
	console.log(this.value);
	//console.log('Ext.ux.RapidApp.AppDV.edit_field_handler');
	//console.dir(arguments);
}



