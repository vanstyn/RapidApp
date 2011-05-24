
/*
 Refactored based on example here (2011-05-10 by HV):
 http://www.sencha.com/forum/showthread.php?128164-Set-value-on-a-searching-combo-box-SOLVED&highlight=combo+query+type
*/
Ext.ns('Ext.ux.RapidApp.AppCombo2');
Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{

	nativeSetValue: function(v) {
		if (this.valueCssField) {
			var record = this.findRecord(this.valueField, v);
			if (record) {
				var addclass = record.data[this.valueCssField];
				if (addclass) { this.el.addClass(addclass); }
			}
		}
		return Ext.form.ComboBox.prototype.setValue.apply(this,arguments);
	},
	
	setValue: function(v){
		
		this.getStore().baseParams['valueqry'] = v;
		this.apply_field_css();
		
		var combo = this;
		if(this.valueField){
			var r = this.findRecord(this.valueField, v);
			if (!r) {
				var data = {}
				data[this.valueField] = v
				this.store.load({
					params:data,
					callback:function(){
						delete combo.getStore().baseParams['valueqry'];
						combo.nativeSetValue(v)
					}
				})   
			} else return combo.nativeSetValue(v);
		} else combo.nativeSetValue(v);
	},
	
	apply_field_css: function() {
		if (this.focusClass) {
			this.el.addClass(this.focusClass);
		}
		if (this.value_addClass) {
			this.el.addClass(this.value_addClass);
		}
	},

});
Ext.reg('appcombo2', Ext.ux.RapidApp.AppCombo2.ComboBox);
