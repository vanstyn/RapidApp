Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.AppTree = Ext.extend(Ext.tree.TreePanel,{
	
	add_node_text: 'Add',
	add_node_iconCls: 'ra-icon-add',
	add_node_url: null,
	
	delete_node_text: 'Delete',
	delete_node_iconCls: 'ra-icon-delete',
	delete_node_url: null,
	
	rename_node_text: 'Rename',
	rename_node_iconCls: 'ra-icon-textfield-rename',
	rename_node_url: null,
	
	reload_node_text: 'Reload',
	reload_node_iconCls: 'ra-icon-refresh',
	
	copy_node_text: 'Copy',
	copy_node_iconCls: 'ra-icon-element-copy',
	copy_node_url: null,
	
	node_action_reload: true,
	node_action_expandall: true,
	node_action_collapseall: true,
	
	use_contextmenu: false,
	no_dragdrop_menu: false,
	setup_tbar: false,
	no_recursive_delete: false,
	no_recursive_copy: false,
	
	// Controls if nodes can drag/drop between nodes as well as into (append) nodes
	ddAppendOnly: true,
	
	// Set this to true to display extra options to dump the node and tree to
	// the firebug console in the node right-click context menu
	debug_menu_options: false,
	
	initComponent: function() {
		
		this.initDragAndDrop();
		
		if(!this.node_actions) {
			this.node_actions = [];
			
			if(this.node_action_reload) {
				this.node_actions.push({
					text: this.reload_node_text,
					iconCls: this.reload_node_iconCls,
					handler: this.nodeReload,
					rootValid: true,
					leafValid: false,
					noTbar: false,
					tbarIconOnly: true
				});
			}
			
			if(this.node_action_expandall) {
				this.node_actions.push({
					text: 'Expand All',
					iconCls: 'ra-icon-tree-expand',
					handler: this.nodeExpandAll,
					rootValid: true,
					leafValid: false,
					noTbar: false,
					tbarIconOnly: true
				});
			}
			
			if(this.node_action_collapseall) {
				this.node_actions.push({
					text: 'Collapse All',
					iconCls: 'ra-icon-tree-collapse',
					handler: this.nodeCollapseAll,
					rootValid: true,
					leafValid: false,
					noTbar: false,
					tbarIconOnly: true
				});
			}
			
			
			if(this.node_actions.length > 0) {
				this.node_actions.push('-');
			}
			
			if(this.rename_node_url) {
				this.node_actions.push({
					text: this.rename_node_text,
					iconCls: this.rename_node_iconCls,
					handler: this.nodeRename,
					rootValid: false,
					leafValid: true,
					noTbar: false,
					tbarIconOnly: true
				});
			}
			
			if(this.delete_node_url) {
				this.node_actions.push({
					text: this.delete_node_text,
					iconCls: this.delete_node_iconCls,
					handler: this.nodeDelete,
					rootValid: false,
					leafValid: true,
					noTbar: false,
					tbarIconOnly: true
				});
			}
			
			if(this.add_node_url) {
				this.node_actions.push({
					text: this.add_node_text,
					iconCls: this.add_node_iconCls,
					handler: this.nodeAdd,
					rootValid: true,
					leafValid: false,
					noTbar: false,
					tbarIconOnly: false
				});
			}
			
			if(this.copy_node_url) {
				this.node_actions.push({
					text: this.copy_node_text,
					iconCls: this.copy_node_iconCls,
					handler: this.nodeCopyInPlace,
					rootValid: false,
					leafValid: true,
					noTbar: false,
					tbarIconOnly: false
				});
			}
			
			if(this.expand_node_url) {
				this.on('expandnode',function(node){
					this.persistNodeExpandState(node,1);
				},this);
				this.on('collapsenode',function(node){
					this.persistNodeExpandState(node,0);
				},this);
			}
			
				
			if(Ext.isArray(this.extra_node_actions)) {
				Ext.each(this.extra_node_actions,function(action) {
					this.node_actions.push(action);
				},this);
			}
			
			// Remove the divider if it is the last item:
			if(this.node_actions.length > 0 && this.node_actions[this.node_actions.length - 1] == '-') {
				this.node_actions.pop();
			}
		}
		
		if(this.setup_tbar) {
		
			var init_tbar_items = [];
			if(Ext.isArray(this.tbar)) { init_tbar_items = this.tbar; }
			if(!Ext.isObject(this.tbar)) {
				this.tbar = {
					xtype: 'toolbar',
					enableOverflow: true,
					items: init_tbar_items
				};
			}
			
			var tbar_items = this.getTbarActionsButtons();
			if(tbar_items.length > 0) {
				this.tbar.items.push('->');
				Ext.each(tbar_items,function(item) {
					this.tbar.items.push(item);
				},this);
			}
		}
		
		if(this.use_contextmenu) { 
			this.on('contextmenu',this.onContextmenu,this);
		}
		
		this.on('afterrender',function() {
			// Init button states with the root node first:
			this.notifyActionButtons(this.root);
			
			this.getSelectionModel().on('selectionchange',function(selMod,node) {
				this.notifyActionButtons(node);
			},this);
		},this);
		
		
		
		Ext.ux.RapidApp.AppTree.superclass.initComponent.call(this);
	},
	
	persistNodeExpandState: function(node,state) {
		if(node == this.root) { return false; } // <-- ignore the root node
		this.queuePersistExpandUpdates(node.id,state);
	},
	
	queuePersistExpandUpdates: function(id,state) {
		this.initPersistExpandQueue();
		this.persistExpandQueue.nodes.push(id);
		this.persistExpandQueue.states.push(state);
		
		if(!this.processPersistExpandPending) {
			this.processPersistExpandPending = true;
			this.processPersistExpandQueue.defer(1000,this);
		}
	},
	
	initPersistExpandQueue: function(delete_current) {
		if(delete_current && this.persistExpandQueue) { 
			delete this.persistExpandQueue;
		}
		if(! this.persistExpandQueue) {
			this.persistExpandQueue = { nodes: [], states: [] };
		}
	},
	
	processPersistExpandQueue: function() {
		this.processPersistExpandPending = false;
		
		// do nothing if the queue is empty:
		if(this.persistExpandQueue.nodes.length == 0) { return true; }
		
		var queue = this.persistExpandQueue;
		this.initPersistExpandQueue(true);
		
		Ext.Ajax.request({
			url: this.expand_node_url,
			params: { node: queue.nodes, expanded: queue.states },
			scope: this,
			success: Ext.emptyFn //<-- assume it worked, don't do anything if it didn't
		});
	},
	
	initDragAndDrop: function() {
		if(this.copy_node_url || this.move_node_url) {
			this.enableDD = true;
			//this.ddAppendOnly = true; //<-- this disables setting "order"
			this.on('nodedragover',this.onNodeDragOver,this);
			this.on('beforenodedrop',this.beforeNodeDropHandler,this);
		}
	},
	
	onNodeDragOver: function(dragOverEvent) {
		var t = dragOverEvent.target;
		var leafOnly = false;
		
		// Nodes with allowLeafDropOnly will only allow leaf nodes dropped on them:
		if(t.attributes.allowLeafDropOnly) { leafOnly = true; }
		
		// parents can also restrict their children with allowChildrenLeafDropOnly:
		if(t.parentNode && t.parentNode.attributes.allowChildrenLeafDropOnly) { leafOnly = true; }
		
		if(leafOnly && !dragOverEvent.data.node.isLeaf()) {
			dragOverEvent.cancel = true;
		}
	},
	
	beforeNodeDropHandler: function(dropEvent) {
		// nothing but 'append' should get this far if ddAppendOnly is true
		if(this.ddAppendOnly && dropEvent.point !== 'append') { return; }
		
		var node = dropEvent.data.node;
		var target = dropEvent.target;
		var e = dropEvent.rawEvent;
		var point = dropEvent.point;
		var point_node;
		
		// point of 'before' or 'after' for order/positioning:
		if(point !== 'append') {
			point_node = target;
			target = target.parentNode;
		}
		
		if(this.nodeDropMenu(node,target,e,point,point_node)) {
			// If we're here it means that the menu has been displayed.
			// We are setting these attributes to prevent the "repair" ui
			// since we have to run an async round-trip to the server
			dropEvent.cancel = true;
			dropEvent.dropStatus = true;
		}
	},
	
	nodeDropMenu: function(node,target,e,point,point_node) {

		var menuItems = [];
		
		/* New: Disable drop/copy option if 'no_dragdrop_menu' is true.
		   the original logic/intent was that this setting would allow
		   either *copy* or *move* to happen automatically, but after
		   thinking about it more, automatic drag/drop copy doesn't make
		   a lot of sense, and now a "Copy In-place" option is being added
		   as a right-click "action" and will use 'copy_node_url' too, so
		   I am just disabling this auto copy or auto move feature for now,
		   leaving only 'auto move' when no_dragdrop_menu is turned on
		*/
		if(this.copy_node_url && !this.no_dragdrop_menu) {
			menuItems.push({
				text: 'Copy here',
				iconCls: 'ra-icon-element-copy',
				handler: function(no_reloads) { 
					this.nodeCopyMove(node,target,this.copy_node_url,false,point,point_node,no_reloads); 
				},
				scope: this
			});
		}
		
		if(this.move_node_url) {
			menuItems.push({
				text: 'Move here',
				iconCls: 'ra-icon-element-into',
				handler: function(no_reloads) { 
					this.nodeCopyMove(node,target,this.move_node_url,true,point,point_node,no_reloads); 
				},
				scope: this
			});
		}
		
		if(!menuItems.length) { return false; }
		
		// -- If no drop menu is set, and there is exactly 1 option (copy or move, but not both), 
		// run that one option automatically:
		// Update:
		//  see above 'copy' comment. menuItems.length should now always be 1 if no_dragdrop_menu
		//  is on, but I am leaving the redundant check in place in case this auto copy or auto
		//  move feature wants to be turned back on...
		if(this.no_dragdrop_menu && menuItems.length == 1) {
			var item = menuItems[0];
			var no_reloads = true;
			item.handler.defer(10,item.scope,[no_reloads]);
			//return true;
			
			// return false to *prevent* cancelling the GUI drag/drop:
			return false;
		}
		// --
		
		
		menuItems.push('-',{
			text: 'Cancel',
			iconCls: 'x-tool x-tool-close',
			handler: Ext.emptyFn
		});
		
		var menu = new Ext.menu.Menu({ items: menuItems });
		var pos = e.getXY();
		pos[0] = pos[0] + 10;
		pos[1] = pos[1] + 5;
		menu.showAt(pos);
		return true;
	},
	
	nodeCopyMove: function(node,target,url,remSrc,point,point_node,no_reloads) {
		
		var params = { 
			node: node.id,
			target: target.id,
			point: point
		};
		
		if(point_node) { params.point_node = point_node.id; }
		
		Ext.Ajax.request({
			url: url,
			params: params,
			scope: this,
			success: function() {
				
				// no_reloads will be on when there is only one copy/move action
				// setup and thus no need for a menu, and thus no need to cancel
				// the GUI move, and thus no need to do node reloading because
				// the GUI move operation is properly tracking what happened by itself:
				if(!no_reloads) {
					
					// no_reloads also overrides/disables remSrc setting... so far this
					// logic was tested and needed with "move" as the only DD operation
					// and no menu display... again, since we don't cancel the GUI move,
					// ExtJS is automatically handling this... TODO: what happens if copy
					// were the only operation with no menu? Would that even make sense? 
					// probably not...
					if(remSrc) {
						node.parentNode.removeChild(node,true);
					}

					this.nodeReload(target);
				}
			},
			failure: function() {
				// If the operation failed on the server side, reload the whole tree to
				// be safe and avoid any possible interface/database inconsistency
				this.nodeReload(this.root);
			}
		});
	},
	
	actionValidForNode: function(action,node) {
		if(!node) { return false; }
		
		/* Broad validation by node type and action rules: */
		if(!action.rootValid && (node == this.root || node.attributes.rootValidActions)) { 
			return false; 
		}
		
		if(!action.leafValid && node.isLeaf()) { 
			return false; 
		}
		
		
		/* Per-action name validations: */
		if(action.text == this.add_node_text) {
			// The add action can be turned off for any given node by setting "allowDelete" to false:
			if(typeof node.attributes.allowAdd !== "undefined" && !node.attributes.allowAdd) {
				return false;
			}
		}
		
		else if(action.text == this.rename_node_text) {
			// The rename action can be turned off for any given node by setting "allowRename" to false:
			if(typeof node.attributes.allowRename !== "undefined" && !node.attributes.allowRename) {
				return false;
			}
		}
		
		else if(action.text == this.reload_node_text) {
			// Nodes with static array of children can't be reloaded from the server:
			// Update: this is now handled in the nodeReload function
			//if(typeof node.attributes.children !== "undefined") {
			//	return false;
			//}
			
			// The reload action can be turned off for any given node by setting "allowReload" to false:
			if(typeof node.attributes.allowReload !== "undefined" && !node.attributes.allowReload) {
				return false;
			}
		}
		
		else if(action.text == this.delete_node_text) {
			if(this.no_recursive_delete && node.isLoaded && node.isLoaded() && node.hasChildNodes()) { 
				return false; 
			}
			// The delete action can be turned off for any given node by setting "allowDelete" to false:
			if(typeof node.attributes.allowDelete !== "undefined" && !node.attributes.allowDelete) {
				return false;
			}
		}
		
		
		else if(action.text == this.copy_node_text) {
			if(this.no_recursive_copy && node.isLoaded && node.isLoaded() && node.hasChildNodes()) { 
				return false; 
			}
			// The copy action can be turned off for any given node by setting "allowCopy" to false:
			if(typeof node.attributes.allowCopy !== "undefined" && !node.attributes.allowCopy) {
				return false;
			}
		}
		
		// If we made it to the end without being invalidated, then the action is valid for this node:
		return true;
	},
	
	notifyActionButtons: function(node) {
		Ext.each(this.tbarActionsButtons,function(btn) {
			if(btn.notifyCurrentNode) {
				btn.notifyCurrentNode.call(btn,node);
			}
		},this);
	},
	
	getTbarActionsButtons: function() {
		var items = [];
		Ext.each(this.node_actions,function(action) {
			if(Ext.isString(action)) {
				items.push(action);
				return;
			}
			var cnf = {
				tree: this,
				nodeAction: action,
				xtype: 'button',
				text: action.text,
				iconCls: action.iconCls,
				handler: function() {
					var node = this.getSelectionModel().getSelectedNode();
					action.handler.call(this,node);
				},
				scope: this
			};
			if (action.tbarIconOnly) {
				cnf.tooltip = cnf.text;
				cnf.overflowText = cnf.text;
				delete cnf.text;
			}
			
			cnf.notifyCurrentNode = function(node) {
				var valid = this.tree.actionValidForNode(this.nodeAction,node);
				this.setDisabled(!valid);
			}
			
			var button = new Ext.Button(cnf);
			items.push(button);
		},this);
		this.tbarActionsButtons = items;
		return this.tbarActionsButtons;
	},
	
	onContextmenu: function(node,e) {

		var menuItems = [];
		Ext.each(this.node_actions,function(action) {
			if(Ext.isString(action)) {
				// Prevent adding a divider as the first item:
				if(action == '-' && menuItems.length == 0) { return; }
				menuItems.push(action);
				return;
			}
			if(!this.actionValidForNode(action,node)) { return; }
			menuItems.push({
				text: action.text,
				iconCls: action.iconCls,
				handler: function() { action.handler.call(this,node); },
				scope: this
			});
			
		},this);
		
		
		
		//-- for debugging:
		if(this.debug_menu_options) {
			menuItems.push(
				'-',
				{
					text: 'console.dir(node)',
					handler: function() { console.dir(node); }
				},
				{
					text: 'console.dir(tree)',
					handler: function() { console.dir(node.getOwnerTree()); }
				}
			);
		}
		//--
		
		// remove a divider if it ends up as the last item:
		if(menuItems.length && menuItems[menuItems.length-1] == '-') {
			menuItems.pop();
		}
		
		
		if(menuItems.length == 0){ return false; }
		
		var menu = new Ext.menu.Menu({ items: menuItems });
		node.select();
		var pos = e.getXY();
		pos[0] = pos[0] + 10;
		pos[1] = pos[1] + 5;
		menu.showAt(pos);
	},
	
	nodeReload: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }
		return this.nodeReloadRecursive(node);
	},
	
	// Recursively calls itself on parent nodes until it reaches a 
	// node that can be reloaded:
	nodeReloadRecursive: function(node) {
		node = node || this.root; //<-- default to the root node
		if(node !== this.root) {
			// Leaf nodes can't be reloaded from the server, but neither can
			// non-leaf nodes if they have a static defined list of children:
			if(node.isLeaf() || node.attributes.children) {
				return this.nodeReloadRecursive(node.parentNode);
			}
		}
		this.getLoader().load(node,function(tp){
			node.expand();
		});
	},
	
	nodeExpandAll: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }
		if(node.isLeaf() && node.parentNode) { node = node.parentNode; }
		node.expand(true);
	},
	
	nodeCollapseAll: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }
		if(node.isLeaf() && node.parentNode) { node = node.parentNode; }
		node.collapse(true);
	},
	
	nodeRename: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }
		if(node == this.root) { return; }
		return this.nodeApplyDialog(node,{
			title: this.rename_node_text,
			url: this.rename_node_url,
			value: node.attributes.text
		});
	},
	
	nodeAdd: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }
		
		return this.nodeApplyDialog(node,{
			title: this.add_node_text,
			url: this.add_node_url
		});
	},
	
	nodeDelete: function(node) {
		if (! node) { 
			Ext.Msg.alert('Nothing selected to Delete','You must select an item to delete.');
			return;
		}
		// Ignore attempts to delete the root node:
		if(node == this.root) { return; }
		var tree = this;
		var params = { node: node.id };

		var ajaxFunc = function() {
			Ext.Ajax.request({
				url: tree.delete_node_url,
				params: params,
				success: function() {
					node.parentNode.removeChild(node,true);
					//var pnode = node.parentNode;
					//tree.getLoader().load(pnode,function(tp){
					//	pnode.expand();
					//});
				}
			});
		};

		var Func = ajaxFunc;

		if (node.hasChildNodes()) {
			
			if(this.no_recursive_delete) {
				Ext.Msg.alert(
					'Cannot Delete',
					'"' + node.attributes.text + '" cannot be deleted because it contains child items.'
				);
				return;
			}
			
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
	},
	
	// This works like an action (right-click) instead of a drag-drop
	// like nodeCopyMove. So it is really more like nodeAdd
	nodeCopyInPlace: function(node) {
		if(!node) { node = this.activeNonLeafNode(); }

		return this.nodeApplyDialog(node,{
			title: this.copy_node_text,
			url: this.copy_node_url,
			params : {
				node: node.id,
				target: node.parentNode.id,
				point: 'below',
				point_node: node.id
			},
			value: node.attributes.text + ' (Copy)'
		});
	},
	
	// General purpose functon for several operations, like add, rename
	nodeApplyDialog: function(node,opt) {
		var tree = this;
		var cnf = Ext.apply({
			url: null, // <-- url is required
			title: 'Apply Node',
			name: 'name',
			fieldLabel: 'Name',
			labelWidth: 40,
			height: 130,
			width: 350,
			params: { node: node.id },
			value: null
		},opt);
		
		if(!cnf.url) { throw "url is a required parameter"; }
		
		var Field = Ext.create({
			xtype: 'textfield',
			name: cnf.name,
			fieldLabel: cnf.fieldLabel,
			value: cnf.value,
			anchor: '100%'
		},'field');
		
		Field.on('afterrender',function(field){ field.show.defer(300,field); });
		
		//Focus the field and put the cursor at the end
		Field.on('show',function(field){
			field.focus();
			field.setCursorPosition(1000000);
		},this);

		var fieldset = {
			xtype: 'fieldset',
			style: 'border: none',
			hideBorders: true,
			labelWidth: cnf.labelWidth,
			border: false,
			//items: items
			items: Field
		};

		var winform_cfg = {
			title: cnf.title,
			height: cnf.height,
			width: cnf.width,
			url: cnf.url,
			useSubmit: true,
			params: cnf.params,
			fieldset: fieldset,
			
			success: function(response,options) {
				var res = options.result;
				
				// if 'new_text' is supplied in the response then update the text of current node
				if (res.new_text) {
					node.setText(res.new_text);
				}
				
				// if 'child' is supplied in the response then we add it as a child to the current node
				if (res.child) {
					var newChild = tree.getLoader().createNode(res.child);
					
					if(res.child_after) { // <-- for 'copy in place'
						node.parentNode.insertBefore(newChild,node.nextSibling);
					}
					else {
						node.expand();
						node.appendChild(newChild);
					}
					//newChild.ensureVisible();
				}
				
				// If neither 'child' nor 'new_text' is in the reponse we reload the node
				if(!res.new_text && !res.child) {
					tree.nodeReload(node);
					
				}
				
				
			}
		};
		Ext.ux.RapidApp.WinFormPost(winform_cfg);
	},
	
	activeNonLeafNode: function() {
		var node = this.getSelectionModel().getSelectedNode();
		if(node) {
			// If this is a leaf node, it can't have childred, so use the parent node:
			if(node.isLeaf() && node.parentNode) { 
				node = node.parentNode;
			}
		}
		else {
			node = this.root;
		}
		return node;
	}
	
});
Ext.reg('apptree',Ext.ux.RapidApp.AppTree);



Ext.ux.RapidApp.AppTree_rename_node = function(node) {
	var tree = node.getOwnerTree();

	return tree.nodeApplyDialog(node,{
		title: "Rename",
		url: tree.rename_node_url,
		value: node.attributes.text
	});
	
	
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
				iconCls: 'ra-icon-textfield-rename',
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

