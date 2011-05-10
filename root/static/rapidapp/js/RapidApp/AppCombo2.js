Ext.ns('Ext.ux.RapidApp.AppCombo2');

Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{

	setValue: function(val) {
		var Store = this.getStore();	
		this.apply_field_css();
			
		if(!this.findRecord(this.valueField,val)) {
			var fn;
			fn = function(store,records,options) {
				delete store.baseParams['valueqry'];
				store.un('load',fn);
				Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.setValue.call(this,val);
			};
			Store.baseParams['valueqry'] = val;
			Store.on('load',fn,this);
			Store.load();
		}
		else {
			Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.setValue.apply(this,arguments);
		}
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
