Ext.ns('Ext.ux.RapidApp.AppCombo2.combo');

Ext.ux.RapidApp.AppCombo2.combo.afterrender_listener = function(combo) {
	combo.getStore().on('load',function(store,records,options) {
		if (combo.value) {
			combo.setValue(combo.value);
		}
		if (combo.focusClass) {
			combo.el.addClass(combo.focusClass);
		}
	});
	combo.getStore().load();
}
