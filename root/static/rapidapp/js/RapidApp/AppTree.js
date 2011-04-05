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



Ext.ns('Ext.ux.RapidApp.AppTree');

Ext.ux.RapidApp.AppTree.FilterPlugin = Ext.extend(Ext.util.Observable,{
	
	fieldIndex: 0,
	
	init: function(tree) {
		if(tree.filterConfig) { Ext.apply(this,tree.filterConfig); }

		var fieldConfig = {
			xtype:'trigger',
			emptyText: 'Type to Find',
			triggerClass:'x-form-clear-trigger',
			onTriggerClick:function() {
				this.setValue('');
				tree.filter.clear();
			},
			//id:'filter',
			enableKeyEvents:true,
			listeners:{
				keyup:{buffer:150, fn:function(field, e) {
					if(Ext.EventObject.ESC == e.getKey()) {
						field.onTriggerClick();
					}
					else {
						var val = this.getRawValue();
						var re = new RegExp('.*' + val + '.*', 'i');
						tree.filter.clear();
						tree.filter.filter(re, 'text');
					}
				}}
			}
		};
			
		if(this.fieldConfig) {
			Ext.apply(fieldConfig,this.fieldConfig);
		}
		
		tree.filter = new Ext.ux.tree.TreeFilterX(tree);
		var Tbar = tree.getTopToolbar();
		Tbar.insert(this.fieldIndex, fieldConfig);
	}
});
Ext.preg('apptree-filter',Ext.ux.RapidApp.AppTree.FilterPlugin);








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

