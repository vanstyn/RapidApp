
/*
 Refactored based on example here (2011-05-10 by HV):
 http://www.sencha.com/forum/showthread.php?128164-Set-value-on-a-searching-combo-box-SOLVED&highlight=combo+query+type
*/
Ext.ns('Ext.ux.RapidApp.AppCombo2');
Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{
	
	initComponent: function() {
    Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.initComponent.call(this);
    if (this.baseParams) {
      Ext.apply(this.getStore().baseParams,this.baseParams);
    }
	
	},
	
	lastValueClass: '',
	
	nativeSetValue: function(v) {
		if (this.valueCssField) {
			var record = this.findRecord(this.valueField, v);
			if (record) {
				var addclass = record.data[this.valueCssField];
				if (addclass) { 
					this.el.replaceClass(this.lastValueClass,addclass);
					this.lastValueClass = addclass;
				}
			}
		}
		return Ext.form.ComboBox.prototype.setValue.apply(this,arguments);
	},
	
	setValue: function(v){
	
    this.apply_field_css();
	
    if (!v || v == '') { return this.nativeSetValue(v); }
		
		this.getStore().baseParams['valueqry'] = v;
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
	}

});
Ext.reg('appcombo2', Ext.ux.RapidApp.AppCombo2.ComboBox);



// TODO: Make this the parent class of and merge with AppCombo2 above:
Ext.ux.RapidApp.AppCombo2.CssCombo = Ext.extend(Ext.form.ComboBox,{
	
	lastValueClass: '',
	
	clearCss: false,
	
	setValue: function(v) {

		if (this.valueCssField) {
			var record = this.findRecord(this.valueField, v);
			if (record) {
				var addclass = record.data[this.valueCssField];
				if (addclass) { 
					this.el.replaceClass(this.lastValueClass,addclass);
					this.lastValueClass = addclass;
				}
			}
			else {
				if(this.clearCss) {
					this.el.removeClass(this.lastValueClass);
				}
			}
		}
		return Ext.form.ComboBox.prototype.setValue.apply(this,arguments);
	}
});



Ext.ux.RapidApp.AppCombo2.IconCombo = Ext.extend(Ext.ux.RapidApp.AppCombo2.CssCombo,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	value_list: false,
	valueField: 'valueField',
	displayField: 'displayField',
	valueCssField: 'valueCssField',
	cls: 'with-icon',
	clearCss: true,
	initComponent: function() {
		if (this.value_list) {
			var data = [];
			Ext.each(this.value_list,function(item,index){
				if(Ext.isArray(item)) {
					data.push([item[0],item[1],item[2]]);
				}
				else {
					data.push([item,item,item]);
				}
			});
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField,
					this.valueCssField
				],
				data: data
			});
		}
		
		this.tpl = 
			'<tpl for=".">' +
				'<div class="x-combo-list-item">' +
					'<div class="with-icon {' + this.valueCssField + '}">' +
						'{' + this.displayField + '}' +
					'</div>' +
				'</div>' +
			'</tpl>';
		
		Ext.ux.RapidApp.AppCombo2.IconCombo.superclass.initComponent.apply(this,arguments);
	}
});
Ext.reg('icon-combo',Ext.ux.RapidApp.AppCombo2.IconCombo);

// TODO: remove Ext.ux.MultiFilter.StaticCombo and reconfigure MultiFilter
// to use this here as a general purpose component
Ext.ux.RapidApp.StaticCombo = Ext.extend(Ext.form.ComboBox,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	value_list: false, //<-- set value_list to an array of the static values for the combo dropdown
	valueField: 'valueField',
	displayField: 'displayField',
	initComponent: function() {
		if (this.value_list) {
			var data = [];
			Ext.each(this.value_list,function(item,index){
				//data.push([index,item]);
				data.push([item,item]); //<-- valueField and displayField are identical
			});
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField
				],
				data: data
			});
		}
		Ext.ux.RapidApp.StaticCombo.superclass.initComponent.apply(this,arguments);
	}
});
Ext.reg('static-combo',Ext.ux.RapidApp.StaticCombo);
