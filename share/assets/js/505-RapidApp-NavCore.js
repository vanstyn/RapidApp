Ext.ns('Ext.ux.RapidApp.NavCore');

// This is currently used only by RapidApp::NavCore plugin!

Ext.ux.RapidApp.NavCore.SaveSearchHandler = function(cmp,cnf) {
	
	var save_url = cnf.save_url;
	var search_id = cnf.search_id;
	var pub_allowed = cnf.pub_allowed;
	var is_pub = cnf.is_pub;

	var grid = cmp.findParentByType('appgrid2') || cmp.findParentByType('appgrid2ed');
	if (!grid) { throw("Failed to find parent with XType appgrid2"); }
	
	var target_url = cnf.target_url;
	var target_params = cnf.target_params;
	var target_iconcls = grid.ownerCt.iconCls;
	
	var search_field = {
		xtype			: 'textfield',
		name			: 'search_name',
		itemId		: 'search_name_field',
		labelStyle	: 'text-align:right;',
		fieldLabel	: 'New Search Name'
	};
	
	var pub_checkbox = {
		xtype			: 'checkbox',
		name			: 'public_search',
		itemId		: 'public_search_field',
		fieldLabel	: 'Public Search',
		labelStyle	: 'text-align:right;'
	};
	
	var hide_items = [ search_field ];
	if (pub_allowed) { hide_items.push(pub_checkbox); }
	
	var hide_fieldset = {
		xtype			: 'fieldset',
		itemId		: 'hide_set',
		style			: 'border: none',
		hideBorders	: true,
		labelWidth	: 110,
		border		: false,
		hidden		: true,
		items			: hide_items
	};
	
	
	var checkbox = {
		xtype			: 'checkbox',
		name			: 'create_search',
		fieldLabel	: 'Save-As New Search',
		labelStyle	: 'text-align:right;',
		listeners: {
			check : function(cb,checked) {
				var fset = cb.ownerCt.getComponent("hide_set");
				if (checked) {
					fset.show();
				} else {
					fset.hide();
				}
			}
		}
	};
	
	var items = [ checkbox, hide_fieldset ];
	if (!search_id) {
		hide_fieldset.hidden = false;
		items = [ {xtype:'spacer', height:15 }, hide_fieldset ];
	}
	if(is_pub && ! pub_allowed) {
		checkbox.disabled = true;
		checkbox.checked = true;
		hide_fieldset.hidden = false;
		items = [ checkbox, hide_fieldset ];
	}
	
	var fieldset = {
		xtype			: 'fieldset',
		style			: 'border: none',
		hideBorders	: true,
		labelWidth	: 120,
		border		: false,
		items			: items
	};
	
	var state_data = Ext.encode(grid.getCurSearchData());
	
	return Ext.ux.RapidApp.WinFormPost({
		title: "Save Search",
		height: 195,
		width: 330,
		url: save_url,
		params: {
			cur_search_id: search_id,
			target_url: target_url,
			target_params: target_params,
			target_iconcls: target_iconcls,
			state_data: state_data
		},
		//eval_response: true,
		fieldset: fieldset,
		success: function(response) {
			var loadTarget = grid.findParentByType("apptabpanel");
			// Reload/refresh the tree:
      Ext.ux.RapidApp.NavCore.reloadMainNavTrees();
			
			if (response && response.responseText) {
				var res = Ext.decode(response.responseText);
				// If there is a loadCnf in the JSON packet it means a new search was
				// created and now we need to load it in a new tab:
				if (res && res.loadCnf) {
					loadTarget.loadContent(res.loadCnf);
				}
			}
		}
	});
};


// New handler function for deleting a search - works with AppGrid2
Ext.ux.RapidApp.NavCore.DeleteSearchHandler = function(cmp,url,search_id) {

	var grid = cmp.findParentByType('appgrid2') || cmp.findParentByType('appgrid2ed');
	if (!grid) { throw("Failed to find parent with XType appgrid2"); }
	
	var fn = function() {
		Ext.Ajax.request({
			url: url,
			params: {
				search_id: search_id
			},
			success: function() {
				var loadTarget = grid.findParentByType("apptabpanel");
				loadTarget.closeActive();
				
				// Reload/refresh the tree:
				Ext.ux.RapidApp.NavCore.reloadMainNavTrees();
			
			}
		
		});
	}
	
	return Ext.ux.RapidApp.confirmDialogCall("Delete Search", "Really Delete This Search?", fn);
};


/*
// TODO: put this in rapidapp and handle properly:
Ext.ux.RapidApp.NavCore.reloadMainNavTree = function() {
	//var loadTarget = Ext.getCmp("main-load-target");
	//var tree = loadTarget.getNavsource();
	//if(!tree) { tree = Ext.getCmp('main-nav-tree'); }
	
	Ext.ux.RapidApp.NavCore.reloadMainNavTreeOnly();
	
	// Now reload the manage NavTree, if its loaded, too:
	var tree = Ext.getCmp('manage-nav-tree');
	if(tree) {
		var rootnode = tree.getRootNode();
		tree.getLoader().load(rootnode);
	}
}
*/


Ext.ux.RapidApp.NavCore.reloadMainNavTrees = function() {
	var container = Ext.getCmp('main-navtrees-container');
  container.items.each(function(tree) {
    if(Ext.isFunction(tree.getRootNode)) {
      var rootnode = tree.getRootNode();
      tree.getLoader().load(rootnode);
    }
  });
}


