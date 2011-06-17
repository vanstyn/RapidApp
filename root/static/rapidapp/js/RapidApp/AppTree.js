Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.AppTree_rename_node = function(node) {
	var tree = node.getOwnerTree();

	var items = [
		{
			xtype: 'textfield',
			name: 'name',
			fieldLabel: 'Name',
			value: node.attributes.text,
			anchor: '100%',
			listeners: {
				'afterrender': function() { 
					// try to focus the field:
					this.focus('',10); 
					this.focus('',200);
					this.focus('',500);
				}
			}
		}
	];

	var fieldset = {
		xtype: 'fieldset',
		style: 'border: none',
		hideBorders: true,
		labelWidth: 40,
		border: false,
		items: items
	};

	var winform_cfg = {
		title: "Rename",
		height: 130,
		width: 350,
		url: tree.rename_node_url,
		useSubmit: true,
		params: {
			node: node.id
		},
		fieldset: fieldset,
		
		success: function(response,options) {
			var res = options.result;
			if(res.new_name) {
				node.setText(res.new_name);
			}
		}
	};
	
	Ext.ux.RapidApp.WinFormPost(winform_cfg);
}


Ext.ux.RapidApp.AppTree_contextmenu_handler = function(node,e) {

		var menu = new Ext.menu.Menu({
			items: [{
				iconCls: 'icon-textfield-rename',
				text: 'Rename',
				handler: function(item) {
					Ext.ux.RapidApp.AppTree_rename_node(node);
				}
			}]
		});
		node.select();
		menu.showAt(e.getXY());
		//menu.show(node.ui.getEl());
}

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
			if(parents.length > 0) {
				select_child(id,parents);
			}
			else {
				node.select();
			}
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
			fieldLabel: 'Name',
			listeners: {
				'afterrender': function() { 
					// try to focus the field:
					this.focus('',10); 
					this.focus('',200);
					this.focus('',500);
				}
			}
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







Ext.ux.RapidApp.AppTree.ensure_recursive_load = function(tree,callback,scope) {
	
	var func = function() {
		if(callback) {
			if(!scope) { scope = tree; }
			callback.call(scope);
		}
	};
	
	if(tree.recursive_load_complete) { return func(); }
	
	var pnode = tree.root;
	var expand_func;
	expand_func = function(node) {
		tree.recursive_load_complete = true;
		this.un('expand',expand_func);
		func();
	}
	pnode.on('expand',expand_func,pnode);
	pnode.collapse();
	pnode.loaded = false;
	
	var loader = tree.getLoader();
	
	var rfunc;
	rfunc = function(treeLoader,node) {
		this.baseParams.recursive = true;
		this.un("beforeload",rfunc);
	}
	loader.on("beforeload",rfunc,loader);
	
	pnode.expand(true,false);
}


Ext.ux.RapidApp.AppTree.reload1 = function(tree) {
	Ext.ux.RapidApp.AppTree.ensure_recursive_load(tree,function(){
		console.log('reloaded');
	});
}






Ext.ns('Ext.ux.RapidApp.AppTree');

Ext.ux.RapidApp.AppTree.FilterPlugin = Ext.extend(Ext.util.Observable,{
	
	fieldIndex: 0,
	
	init: function(tree) {
		this.tree = tree;
		var Filter = this;
		
		if(tree.filterConfig) { Ext.apply(this,tree.filterConfig); }

		var fieldConfig = {
			xtype:'trigger',
			emptyText: 'Type to Find',
			triggerClass:'x-form-clear-trigger',
			onTriggerClick:function() {
				this.setValue('');
				tree.filter.clear();
			},
			enableKeyEvents:true,
			listeners:{
				keyup:{
					buffer: 150, 
					fn: function(field, e) {
						if(Ext.EventObject.ESC == e.getKey()) {
							field.onTriggerClick();
						}
						//else {
						else if (Ext.EventObject.ENTER == e.getKey()){
							//Filter.treeLoadAll();
							var callback = function() {
								var val = field.getRawValue();
								Ext.ux.RapidApp.AppTree.set_next_treeload_params(tree,{search:val});
								var re = new RegExp('.*' + val + '.*', 'i');
								tree.filter.clear();
								tree.filter.filter(re, 'text');
							}
							
							Ext.ux.RapidApp.AppTree.ensure_recursive_load(tree,callback);
						}
					}
				}
			}
		};
			
		if(this.fieldConfig) {
			Ext.apply(fieldConfig,this.fieldConfig);
		}
		
		tree.filter = new Ext.ux.tree.TreeFilterX(tree);
		tree.filter.searchField = Ext.ComponentMgr.create(fieldConfig);
		var Tbar = tree.getTopToolbar();
		Tbar.insert(this.fieldIndex,tree.filter.searchField);
	}
});
Ext.preg('apptree-filter',Ext.ux.RapidApp.AppTree.FilterPlugin);



Ext.ux.RapidApp.AppTree.reload = function(tree,recursive) {
	if(Ext.isFunction(tree.onReload)) { tree.onReload.call(tree); }
	tree.root.collapse();
	tree.root.loaded = false;
	tree.root.expand();
}

Ext.ux.RapidApp.AppTree.ServerFilterPlugin = Ext.extend(Ext.util.Observable,{
	
	fieldIndex: 0,
	
	init: function(tree) {
		this.tree = tree;
		
		tree.onReload = function() {
			delete tree.next_load_params;
			tree.searchField.setValue('');
		};

		var loader = tree.getLoader();
		loader.on("beforeload",function(){
			this.baseParams = {};
			if(tree.next_load_params) {
				this.baseParams = tree.next_load_params;
				delete tree.next_load_params;
			}
		});
		
		if(tree.filterConfig) { Ext.apply(this,tree.filterConfig); }

		var fieldConfig = {
			emptyText: 'Type to Find',
			trigger1Class:'x-form-clear-trigger',
			trigger2Class: 'x-form-search-trigger',
			onTrigger1Click: function() {
				Ext.ux.RapidApp.AppTree.reload(tree);
			},
			onTrigger2Click:function() {
				this.runSearch.call(this);
			},
			runSearch: function() {
				var val = this.getRawValue();
				if(val == '') { return this.onTrigger1Click(); }
				tree.next_load_params = {
					search: val,
					recursive: true
				};
				tree.root.collapse();
				tree.root.loaded = false;
				tree.root.expand();
			},
			enableKeyEvents:true,
			listeners:{
				keyup:{
					buffer: 150, 
					fn: function(field, e) {
						if(Ext.EventObject.ESC == e.getKey()) {
							field.onTrigger1Click();
						}
						else if (Ext.EventObject.ENTER == e.getKey()){
							return field.runSearch();
						}
					}
				}
			}
		};
			
		if(this.fieldConfig) {
			Ext.apply(fieldConfig,this.fieldConfig);
		}
		
		tree.searchField = new Ext.form.TwinTriggerField(fieldConfig);
		var Tbar = tree.getTopToolbar();
		Tbar.insert(this.fieldIndex,tree.searchField);
	}
});
Ext.preg('apptree-serverfilter',Ext.ux.RapidApp.AppTree.ServerFilterPlugin);




/**
 * @class   Ext.ux.tree.TreeFilterX
 * @extends Ext.tree.TreeFilter
 *
 * <p>
 * Shows also parents of matching nodes as opposed to default TreeFilter. In other words
 * this filter works "deep way".
 * </p>
 *
 * @author   Ing. Jozef Sakáloš
 * @version  1.0
 * @date     17. December 2008
 * @revision $Id: Ext.ux.tree.TreeFilterX.js 589 2009-02-21 23:30:18Z jozo $
 * @see      <a href="http://extjs.com/forum/showthread.php?p=252709">http://extjs.com/forum/showthread.php?p=252709</a>
 *
 * @license Ext.ux.tree.CheckTreePanel is licensed under the terms of
 * the Open Source LGPL 3.0 license.  Commercial use is permitted to the extent
 * that the code/component(s) do NOT become part of another Open Source or Commercially
 * licensed development library or toolkit without explicit permission.
 *
 * <p>License details: <a href="http://www.gnu.org/licenses/lgpl.html"
 * target="_blank">http://www.gnu.org/licenses/lgpl.html</a></p>
 *
 * @forum     55489
 * @demo      http://remotetree.extjs.eu
 *
 * @donate
 * <form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_blank">
 * <input type="hidden" name="cmd" value="_s-xclick">
 * <input type="hidden" name="hosted_button_id" value="3430419">
 * <input type="image" src="https://www.paypal.com/en_US/i/btn/x-click-butcc-donate.gif"
 * border="0" name="submit" alt="PayPal - The safer, easier way to pay online.">
 * <img alt="" border="0" src="https://www.paypal.com/en_US/i/scr/pixel.gif" width="1" height="1">
 * </form>
 */

Ext.ns('Ext.ux.tree');

/**
 * Creates new TreeFilterX
 * @constructor
 * @param {Ext.tree.TreePanel} tree The tree panel to attach this filter to
 * @param {Object} config A config object of this filter
 */
Ext.ux.tree.TreeFilterX = Ext.extend(Ext.tree.TreeFilter, {
	/**
	 * @cfg {Boolean} expandOnFilter Deeply expands startNode before filtering (defaults to true)
	 */
	 expandOnFilter:true

	// {{{
    /**
     * Filter the data by a specific attribute.
	 *
     * @param {String/RegExp} value Either string that the attribute value 
     * should start with or a RegExp to test against the attribute
     * @param {String} attr (optional) The attribute passed in your node's attributes collection. Defaults to "text".
     * @param {TreeNode} startNode (optional) The node to start the filter at.
     */
	,filter:function(value, attr, startNode) {

		// expand start node
		if(false !== this.expandOnFilter) {
			startNode = startNode || this.tree.root;
			var animate = this.tree.animate;
			this.tree.animate = false;
			startNode.expand(true, false, function() {

				// call parent after expand
				Ext.ux.tree.TreeFilterX.superclass.filter.call(this, value, attr, startNode);

			}.createDelegate(this));
			this.tree.animate = animate;
		}
		else {
			// call parent
			Ext.ux.tree.TreeFilterX.superclass.filter.apply(this, arguments);
		}

	} // eo function filter
	// }}}
	// {{{
    /**
     * Filter by a function. The passed function will be called with each 
     * node in the tree (or from the startNode). If the function returns true, the node is kept 
     * otherwise it is filtered. If a node is filtered, its children are also filtered.
	 * Shows parents of matching nodes.
	 *
     * @param {Function} fn The filter function
     * @param {Object} scope (optional) The scope of the function (defaults to the current node) 
     */
	,filterBy:function(fn, scope, startNode) {
		startNode = startNode || this.tree.root;
		if(this.autoClear) {
			this.clear();
		}
		var af = this.filtered, rv = this.reverse;

		var f = function(n) {
			if(n === startNode) {
				return true;
			}
			if(af[n.id]) {
				return false;
			}
			var m = fn.call(scope || n, n);
			if(!m || rv) {
				af[n.id] = n;
				n.ui.hide();
				return true;
			}
			else {
				n.ui.show();
				var p = n.parentNode;
				while(p && p !== this.root) {
					p.ui.show();
					p = p.parentNode;
				}
				return true;
			}
			return true;
		};
		startNode.cascade(f);

        if(this.remove){
           for(var id in af) {
               if(typeof id != "function") {
                   var n = af[id];
                   if(n && n.parentNode) {
                       n.parentNode.removeChild(n);
                   }
               }
           }
        }
	} // eo function filterBy
	// }}}

}); // eo extend

