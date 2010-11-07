Ext.ns('Ext.ux.RapidApp.AppTab');


Ext.ux.RapidApp.AppTab.TabPanel = Ext.extend(Ext.TabPanel, {

	itemId: 'load-target',

	layoutOnTabChange: true,
	enableTabScroll: true,
	
	loadContent: function() {
		this.loadTab.apply(this,arguments);
	},

	loadTab: function(cnf) {
		
		Ext.applyIf(cnf,{
			xtype: 'autopanel',
			title: 'Unnamed Tab',
			iconCls: 'icon-default',
			itemId: 'tab-' + Math.floor(Math.random()*100000),
			layout: 'fit',
			closable: true,
			autoLoad: {}
		});
		
		Ext.applyIf(cnf.autoLoad, {
			text: 'Loading...',
			nocache: true
		});
		
		// Check if this Tab is already loaded, and set active and return if it is:
		var existTab = this.getComponent(cnf.itemId);
		if (existTab) {
			return this.activate(existTab);
		}
		
		// --- Backwards compat with AppTreeExplorer/AppGrid:
		if (!cnf.autoLoad.url) {
			if (cnf.url) { cnf.autoLoad.url = cnf.url; }
		}
		if (!cnf.autoLoad.params) {
			if (cnf.params) { cnf.autoLoad.params = cnf.params; }
		}
		// ---
		
		var new_tab = this.add(cnf);
		return this.activate(new_tab);
	}
	
});
Ext.reg('apptabpanel', Ext.ux.RapidApp.AppTab.TabPanel);

// This is designed to be a function that can be supplied to a treepanel 
// click handler. This assumes the node has a compatible 'loadContentCnf'
// attribute and that the tree has a reference to a compatable 'loadTargetObj'
// (defined as a property). 
Ext.ux.RapidApp.AppTab.treenav_click = function(node,event) {
	var tree = node.getOwnerTree();
	var loadTarget = tree.loadTargetObj;
	
	return loadTarget.loadContent(node.attributes.loadContentCnf);
}

Ext.ux.RapidApp.AppTab.treenav_beforerender = function(tree) {
	var loadTarget;
	var parent = tree.findParentBy(function(cmp) {
		loadTarget = cmp.getComponent('load-target');
		if(loadTarget) { return true; }
		return false;
	});
	tree.loadTargetObj = loadTarget;
	//tree.loadTargetObj = tree.ownerCt.ownerCt.getComponent('load-target');
}
