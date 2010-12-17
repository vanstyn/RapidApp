Ext.ns('Ext.ux.RapidApp.AppCombo2');

Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{

	initComponent: function() {
		Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.initComponent.apply(this,arguments);
		
		this.on('afterrender',function(combo) {
			combo.getStore().on('load',function(store,records,options) {
				if (combo.value) {
					combo.setValue(combo.value);
				}
			});
			combo.getStore().load();
		});
	},

	setValue: function() {
		this.apply_field_css();
		Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.setValue.apply(this,arguments);
	},
	
	apply_field_css: function() {
		if (this.focusClass) {
			this.el.addClass(this.focusClass);
		}
		if (this.value_addClass) {
			this.el.addClass(this.value_addClass);
		}
	}

});
Ext.reg('appcombo2', Ext.ux.RapidApp.AppCombo2.ComboBox);
