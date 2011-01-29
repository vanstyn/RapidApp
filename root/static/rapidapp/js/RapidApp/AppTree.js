Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.AppTree_select_handler = function(tree) {

	var node = tree.getSelectionModel().getSelectedNode();

	return {
		value: node.id,
		display: node.attributes.text
	};

}


Ext.ux.RapidApp.AppTree_setValue_translator = function(val,tf,url) {
	if(val.indexOf('/') > 0) { tf.translated = false; }
	if(!tf.translated) {
		Ext.Ajax.request({
			url: url,
			params: { node: val },
			success: function(response) {
				var res = Ext.decode(response.responseText);
				tf.translated = true; // <-- prevent recursion
				tf.dataValue = res.id;
				tf.setValue(res.text);
			}
		});
	}
	else {
		return val;
	}
}


Ext.ns('Ext.ux.RapidApp.AppTree');
Ext.ux.RapidApp.AppTree.jump_to_node_id = function(tree,id) {

	var parents_arr = function(path,arr) {
		if (!arr) arr = [];
		if (path.indexOf('/') < 0) {
			return arr;
		}

		var path_arr = path.split('/');

		var item = path_arr.pop();
		var path_str = path_arr.join('/');
		arr.push(path_str);
		return parents_arr(path_str,arr);
	}

	var select_child = function(id,parents,lastpass) {

		var par = parents.pop();
		if(!par) return;

		var node = tree.getNodeById(par);
		if(!node) return;

		node.loaded = false;
		node.expand(false,false,function(){
			select_child(id,parents);
			node.select();
		});
	}

	var parents = parents_arr(id);
	parents.unshift(id);

	return select_child(id,parents);
};


Ext.ux.RapidApp.AppTree.get_selected_node = function(tree) {

	var node = tree.getSelectionModel().getSelectedNode();
	if(node) {
		// If this is a leaf node, it can't have childred, so use the parent node:
		if(node.isLeaf() && node.parentNode) { 
			var parent = node.parentNode;
			node = parent;
		}
		id = node.id;
	}
	else {
		node = tree.root;
	}

	return node;
}

Ext.ux.RapidApp.AppTree.add = function(tree,cfg) {

	var url;
	if (Ext.isObject(cfg)) {
	
	}
	else {
		url = cfg;
	}
	
	var items = [
		{
			xtype: 'textfield',
			name: 'name',
			fieldLabel: 'Name'
		}
	];

	var fieldset = {
		xtype: 'fieldset',
		style: 'border: none',
		hideBorders: true,
		labelWidth: 60,
		border: false,
		items: items
	};

	var node = Ext.ux.RapidApp.AppTree.get_selected_node(tree);
	var id = node.id;

/*
	var node = tree.getSelectionModel().getSelectedNode();
	var id = "root";
	if(node) {
		// If this is a leaf node, it can't have childred, so use the parent node:
		if(node.isLeaf() && node.parentNode) { 
			var parent = node.parentNode;
			node = parent;
		}
		id = node.id;
	}
*/
	
	var winform_cfg = {
		title: "Add",
		height: 130,
		width: 250,
		url: url,
		useSubmit: true,
		params: {
			node: id
		},
		fieldset: fieldset,
		success: function(response) {
			tree.getLoader().load(node,function(tp){
				node.expand();
			});
		}
	};
	
	Ext.apply(winform_cfg,cfg);
	Ext.ux.RapidApp.WinFormPost(winform_cfg);
}


Ext.ux.RapidApp.AppTree.del = function(tree,url) {

	var node = tree.getSelectionModel().getSelectedNode();
	var id = "root";
	if(node) id = node.id;

	var params = {
		node: id
	};

	var ajaxFunc = function() {
		Ext.Ajax.request({
			url: url,
			params: params,
			success: function() {
				var pnode = node.parentNode;
				tree.getLoader().load(pnode,function(tp){
					pnode.expand();
				});
			}
		});
	};

	var Func = ajaxFunc;

	if (node.hasChildNodes()) {
		params['recursive'] = true;
		Func = function() {
			Ext.ux.RapidApp.confirmDialogCall(
				'Confirm Recursive Delete',
				'"' + node.attributes.text + '" contains child items, they will all be deleted.<br><br>' +
				 'Are you sure you want to continue ?',
				ajaxFunc
			);
		}
	}

	Ext.ux.RapidApp.confirmDialogCall(
		'Confirm Delete',
		'Really delete "' + node.attributes.text + '" ?',
		Func
	);
}



