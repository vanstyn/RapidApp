Ext.ns('Ext.ux.RapidApp.AppStoreForm2');

Ext.ux.RapidApp.AppStoreForm2.FormPanel = Ext.extend(Ext.form.FormPanel,{

	// Defaults:
	closetab_on_create: true,
	bodyCssClass: 'panel-borders',
	monitorValid: true,
	trackResetOnLoad: true, // <-- for some reason this default doesn't work and has to be set in the constructor
	frame: true,
	autoScroll: true,
	addBtnId: null,
	saveBtnId: null,

	initComponent: function() {
		this.store.formpanel = this;
		Ext.ux.RapidApp.AppStoreForm2.FormPanel.superclass.initComponent.apply(this,arguments);
	},
	getAddBtn: function() {
		if (this.addBtnId) { return Ext.getCmp(this.addBtnId); }
		var tbar= this.getTopToolbar();
		if (tbar) { return tbar.getComponent("add-btn"); }
		return null;
	},
	getSaveBtn: function() {
		if (this.saveBtnId) { return Ext.getCmp(this.saveBtnId); }
		var tbar= this.getTopToolbar();
		if (tbar) { return tbar.getComponent("save-btn"); }
		return null;
	}
});
Ext.reg('appstoreform2', Ext.ux.RapidApp.AppStoreForm2.FormPanel);

Ext.ux.RapidApp.AppStoreForm2.reload_handler = function(cmp) {
	var fp= ('appstoreform_id' in cmp)? Ext.getCmp(cmp.appstoreform_id) : cmp.findParentByType('appstoreform2');
	//var fp = cmp.findParentByType('appstoreform2');
	fp.store.reload();
};


Ext.ux.RapidApp.AppStoreForm2.save_handler = function(cmp) {
	var fp= ('appstoreform_id' in cmp)? Ext.getCmp(cmp.appstoreform_id) : cmp.findParentByType('appstoreform2');
	var form = fp.getForm();
	var store = fp.store;
	var record = store.getAt(0);
	record.beginEdit();
	form.updateRecord(record);
	record.endEdit();
	return store.save();
};

Ext.ux.RapidApp.AppStoreForm2.add_handler = function(cmp) {
	var fp= ('appstoreform_id' in cmp)? Ext.getCmp(cmp.appstoreform_id) : cmp.findParentByType('appstoreform2');
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
	var save_btn = FormPanel.getSaveBtn();
	var add_btn = FormPanel.getAddBtn();
	
	if(this.forceInvalid) {
		if (save_btn && !save_btn.disabled) save_btn.disable();
		if (add_btn && !add_btn.disabled) add_btn.disable();
		return;
	}
	
	if (valid && FormPanel.getForm().isDirty()) {
		if(save_btn) save_btn.enable();
		if(add_btn) add_btn.enable();
	} else {
		if (save_btn && !save_btn.disabled) save_btn.disable();
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
		if (tp) { tab = tp.getActiveTab(); }
	}

	// Automatically load "loadCfg" if it exists in the response:
	if(res.raw.loadCfg) {
		var loadTarget = Ext.ux.RapidApp.AppTab.findParent_loadTarget(panel);
		if (loadTarget) { loadTarget.loadContent(res.raw.loadCfg); }
	}

	// close the tab:
	if(panel.closetab_on_create && tp && tab) {
		tp.remove(tab);
	}
}


Ext.ux.RapidApp.AppStoreForm2.save_and_close = function(fp) {
	var store = fp.store;

	var tp = fp.findParentByType("apptabpanel");
	var tab = tp.getActiveTab();

	var add_btn = fp.getAddBtn();

	// if both add_btn and closetab_on_create are true, then we don't have to
	// add a listener to the store because it should already have one that will
	// close the active tab:
	if (! add_btn || ! fp.closetab_on_create) {
		store.on('write',function() { tp.remove(tab); });
	}

	// find either add-btn or save-btn (they shouldn't both exist):
	var btn = add_btn? add_btn : fp.getSaveBtn();
	
	// call the button's handler directly:
	return btn.handler(btn);
}



