Ext.ns('Ext.ux.RapidApp.AppStoreForm2');

Ext.ux.RapidApp.AppStoreForm2.FormPanel = Ext.extend(Ext.form.FormPanel,{

	// Defaults:
	bodyCssClass: 'panel-borders',
	monitorValid: true,
	frame: true,
	autoScroll: true,
	trackResetOnLoad: true,
	
	initComponent: function() {
		this.store.formpanel = this;
		Ext.ux.RapidApp.AppStoreForm2.FormPanel.superclass.initComponent.apply(this,arguments);
	}

});
Ext.reg('appstoreform2', Ext.ux.RapidApp.AppStoreForm2.FormPanel);

Ext.ux.RapidApp.AppStoreForm2.reload_handler = function(cmp) {
	var fp = cmp.findParentByType('appstoreform2');
	fp.store.reload();
};


Ext.ux.RapidApp.AppStoreForm2.save_handler = function(cmp) {
	var fp = cmp.findParentByType('appstoreform2');
	var form = fp.getForm();
	var store = fp.store;
	var record = store.getAt(0);
	record.beginEdit();
	form.updateRecord(record);
	record.endEdit();
	return store.save();
};

Ext.ux.RapidApp.AppStoreForm2.add_handler = function(cmp) {
	var fp = cmp.findParentByType('appstoreform2');
	var form = fp.getForm();
	var store = fp.store;
	var form_data = form.getFieldValues();
	var store_fields = [];
	Ext.iterate(form_data,function(key,value){
		store_fields.push({name: key});
	});
	var record_obj = Ext.data.Record.create(store_fields);
	var record = new record_obj;
	if (record) Ext.log("record created...");
	record.beginEdit();
	if (form.updateRecord(record)) Ext.log("record updated with form...");
	record.endEdit();
	store.add(record);
	return store.save();
};

Ext.ux.RapidApp.AppStoreForm2.clientvalidation_handler = function(FormPanel, valid) {
	if (valid && FormPanel.getForm().isDirty()) { 
		var save_btn = FormPanel.getComponent("save-btn");
		if(save_btn) save_btn.enable();
		var add_btn = FormPanel.getComponent("add-btn");
		if(add_btn) add_btn.enable();
	} else {
		var save_btn = FormPanel.getComponent("save-btn");
		if (save_btn && !save_btn.disabled) save_btn.disable();
		var add_btn = FormPanel.getComponent("add-btn");
		if (add_btn && !add_btn.disabled) add_btn.disable();
	}
};

Ext.ux.RapidApp.AppStoreForm2.afterrender_handler = function(FormPanel) { 
	new Ext.LoadMask(FormPanel.getEl(),{
		msg: "StoreForm Loading...", 
		store: FormPanel.store 
	});
	FormPanel.store.load();
};

Ext.ux.RapidApp.AppStoreForm2.store_load_handler = function(store,records,options) { 

	var form = store.formpanel.getForm();
	var Record = records[0];
	if(!Record) return;
	form.loadRecord(Record);
	store.setBaseParam("orig_params",Ext.util.JSON.encode(Record.data));
}
			
			