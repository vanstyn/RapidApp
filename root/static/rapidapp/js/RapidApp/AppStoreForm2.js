Ext.ns('Ext.ux.RapidApp.AppStoreForm2');

Ext.ux.RapidApp.AppStoreForm2.FormPanel = Ext.extend(Ext.form.FormPanel,{

	// Defaults:
	closetab_on_create: true,
	bodyCssClass: 'panel-borders',
	monitorValid: true,
	trackResetOnLoad: true, // <-- for some reason this default doesn't work and has to be set in the constructor
	frame: true,
	autoScroll: true,

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
	
	store.rejectChanges();
	store.removeAll();
	
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

	var tbar = FormPanel.getTopToolbar();
	if (! tbar) { return; }
	if (valid && FormPanel.getForm().isDirty()) {
		var save_btn = tbar.getComponent("save-btn");
		if(save_btn) save_btn.enable();
		var add_btn = tbar.getComponent("add-btn");
		if(add_btn) add_btn.enable();
	} else {
		var save_btn = tbar.getComponent("save-btn");
		if (save_btn && !save_btn.disabled) save_btn.disable();
		var add_btn = tbar.getComponent("add-btn");
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


Ext.ux.RapidApp.AppStoreForm2.store_create_handler = function(store,action,result,res,rs) {
	if(action != "create"){ return; }

	var panel = store.formpanel;
	if(!res.raw.loadCfg && !panel.closetab_on_create) { return; }

	// get the current tab:
	var tp, tab;
	if(panel.closetab_on_create) {
		tp = panel.findParentByType("apptabpanel");
		tab = tp.getActiveTab();
	}

	// Automatically load "loadCfg" if it exists in the response:
	if(res.raw.loadCfg) {
		var loadTarget = Ext.ux.RapidApp.AppTab.findParent_loadTarget(panel);
		loadTarget.loadContent(res.raw.loadCfg);
	}

	// close the tab:
	if(panel.closetab_on_create) {
		tp.remove(tab);
	}
}


Ext.ux.RapidApp.AppStoreForm2.save_and_close = function(fp) {
	var store = fp.store;
	var tbar = fp.getTopToolbar();

	var tp = fp.findParentByType("apptabpanel");
	var tab = tp.getActiveTab();

	var add_btn = tbar.getComponent("add-btn");

	// if both add_btn and closetab_on_create are true, then we don't have to
	// add a listener to the store because it should already have one that will
	// close the active tab:
	if (! add_btn || ! fp.closetab_on_create) {
		store.on('write',function() { tp.remove(tab); });
	}

	// find either add-btn or save-btn (they shouldn't both exist):
	var btn = add_btn;
	if (! btn) {
		btn = tbar.getComponent("save-btn");
	}

	// call the button's handler directly:
	return btn.handler(btn);
}



