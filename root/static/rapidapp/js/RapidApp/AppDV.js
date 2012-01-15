Ext.ns('Ext.ux.RapidApp.AppDV');


Ext.ux.RapidApp.AppDV.DataView = Ext.extend(Ext.DataView, {
	
	// TODO: make cascade recursive like in Ext.Container
	cascade: function(fn,scope,args) {
		fn.apply(scope || this, args || [this]);
		return this;
	},
	
	initComponent: function(){
		Ext.each(this.items,function(item) {
			item.ownerCt = this;
		},this);
		Ext.ux.RapidApp.AppDV.DataView.superclass.initComponent.call(this);
		this.components = [];
		
		this.on('click',this.click_controller,this);
		
		//if(!this.store) { this.store = this.ownerCt.store; }
		
		this.store.on('beforesave',this.onBeforesave,this);
		this.store.on('beforeremove',this.onBeforeremove,this);
		
		// Special AppDV override: addNotAllowed based on
		// current edit record:
		var cmp = this;
		cmp.on('afterrender',function(){
			cmp.store.addNotAllowed = function(){
				if(cmp.currentEditRecord && cmp.currentEditRecord.editing) {
					return true;
				}
				return false;
			}
			/* TODO:
			if(!cmp.store.hasPendingChangesOrig) {
				cmp.store.hasPendingChangesOrig = cmp.store.hasPendingChanges;
			}
			cmp.store.hasPendingChanges = function() {
				//console.log('has pending changes');
				if(cmp.store.addNotAllowed()) { return true; }
				return cmp.store.hasPendingChangesOrig.apply(this,arguments);
			};
			*/
		},this);
		
		this.on('beforeselect',this.onBeforeselect,this);
	},
	
	onBeforeselect: function() {
		// We don't want to allow clicks to toggle record select status when
		// we are editing:
		if(this.currentEditRecord && this.currentEditRecord.editing) {
			return false;
		}
	},
	
	onBeforesave: function() {
		this.isSaving = true;
		this.simulateSaveClick.call(this);
		this.isSaving = false;
	},
	
	refresh: function(){
		Ext.destroy(this.components);
		this.components = [];
		Ext.ux.RapidApp.AppDV.DataView.superclass.refresh.call(this);
		this.renderItems(0, this.store.getCount() - 1);
	},
	
	onUpdate: function(ds, record){
		var index = ds.indexOf(record);
		if(index > -1){
				this.destroyItems(index);
		}
		Ext.ux.RapidApp.AppDV.DataView.superclass.onUpdate.apply(this, arguments);
		if(index > -1){
				this.renderItems(index, index);
		}
		this.toggleDirtyCssRecord(record,true);
	},
	
	onAdd: function(ds, records, index){
		var count = this.all.getCount();
		Ext.ux.RapidApp.AppDV.DataView.superclass.onAdd.apply(this, arguments);
		if(count !== 0){
			this.renderItems(index, index + records.length - 1);
		}
		
		var Record;
		//Get first phantom record:
		Ext.each(records,function(rec) {
			if(Record || !rec.phantom) { return; }
			Record = rec;
		},this);
		
		if(Record) {
			this.currentEditRecord = Record;
			var domEl = this.getNode(Record);
			var editEl = new Ext.Element(domEl);
			this.currentEditEl = editEl;
			this.clearSelections();
			this.handle_edit_record(editEl,editEl,Record,index,editEl);
		}
		
		this.scrollRecordIntoView.defer(10,this,[records[records.length - 1]]);
		this.highlightRecord.defer(10,this,[records]);
		this.toggleDirtyCssRecord(records,true);

	},
	
	forEachRecordNode: function(fn,record) {
		
		if(Ext.isArray(record)){
			Ext.each(record, function(r){
				this.forEachRecordNode(fn,r);
			},this);
			return;
		}
	  
		if(!record || !record.store) { return; }

		var node = this.getNode(record);
		if(!node) { return; }
		var el = new Ext.Element(node);
		fn(el,record);
	},
	
	highlightRecord: function(record) {
		this.forEachRecordNode(function(el){
			el.highlight();
		},record);
	},
	
	puffRecord: function(record) {
		this.forEachRecordNode(function(el){
			el.fadeOut({
				easing: 'easeNone',
				duration: .5,
				remove: false,
				useDisplay: false,
				concurrent: true
			});
			el.highlight();
		},record);
	},
	
	toggleDirtyCssRecord: function(record,tog) {
		var dv = this;
		this.forEachRecordNode(function(el,rec){
			if(rec.dirtyEl) { rec.dirtyEl.remove(); }
			if(tog && el && rec.dirty) {
				
				var domCfg = {
					tag: 'div',
					style: 'position:absolute;',
					children:[{
						tag: 'div',
						cls: 'x-grid3-dirty-cell',
						style: 'position:relative;top:0;left:0;z-index:15000;height:10px;width:10px;'
					}]
				};
				
				if(el.dom.tagName.toUpperCase() == 'TR') {
					domCfg = {
						tag: 'tr',
						children:[{
							tag: 'td',
							children:[domCfg]
						}]
					};
				}
				
				rec.dirtyEl = el.insertSibling(domCfg,'before');
			}
		},record);
	},
	
	onBeforeremove: function(ds, record){
		
		if(this.removeInProgress) { return true; }
		this.toggleDirtyCssRecord(record,false);
		if(record == this.currentEditRecord) {
			var index = this.getStore().indexOf(record);
			this.simulateCancelClick(record,index,this.currentEditEl);
			return false;
		}
		
		this.puffRecord(record);
		
		this.removeInProgress = true;
		var doRemove = function(){
			ds.remove.apply(this,arguments);
			this.removeInProgress = false;
		};
		doRemove.defer(300,this,[record]);
		
		return false;
	},
	onRemove: function(ds, record, index){
		
		this.destroyItems(index);
		Ext.ux.RapidApp.AppDV.DataView.superclass.onRemove.apply(this, arguments);
	},
	
	onDestroy: function(){
		Ext.ux.RapidApp.AppDV.DataView.superclass.onDestroy.call(this);
		Ext.destroy(this.components);
		this.components = [];
	},
	
	renderItems: function(startIndex, endIndex){
		var ns = this.all.elements;
		var args = [startIndex, 0];
		
		//console.dir(args);
		
		for(var i = startIndex; i <= endIndex; i++){
			var r = args[args.length] = [];
			for(var items = this.items, j = 0, len = items.length, c; j < len; j++){
			
				// c = items[j].render ?
				//	c = items[j].cloneConfig() :
					
				// RapidApp specific:
				// Components are stored as serialized JSON to ensure they
				// come out exactly the same every time:
				var itemCnf = Ext.decode(items[j]);
				itemCnf.ownerCt = this;

				// renderDynTarget will look for a child div with class="encoded-params" containing
				// JSON encoded additional params that will be dynamically applied to the
				// config of the component being created. Essentially this allows part or all
				// of the component config to be stored directly within the HTML markup. Typically
				// the encoded-params div will have style="display:none;" to prevent the JSON
				// from showing up on the page.
				if(itemCnf.renderDynTarget) {
					var Node = Ext.DomQuery.selectNode(itemCnf.renderDynTarget, ns[i]);
					if(Node) {

						var cnf = {};
						Ext.apply(cnf,itemCnf);

						var encNode = Ext.DomQuery.selectNode('div.encoded-params', Node);
						if(encNode) {
							Ext.apply(cnf,Ext.decode(encNode.innerHTML));
						}
						
						c = Ext.create(cnf, this.defaultType);
						r[j] = c;
						c.render(Node);
					}
				}
				else {
					c = Ext.create(itemCnf, this.defaultType);
					r[j] = c;
					
					if(c.renderTarget){
						c.render(Ext.DomQuery.selectNode(c.renderTarget, ns[i]));
					}
					else if(c.applyTarget){
						c.applyToMarkup(Ext.DomQuery.selectNode(c.applyTarget, ns[i]));
					}
					else{
						c.render(ns[i]);
					}
				}	
				
				if(c && Ext.isFunction(c.setValue) && c.applyValue){
					c.setValue(this.store.getAt(i).get(c.applyValue));
					c.on(
						'blur', 
						function(f){
							this.store.getAt(this.index).data[this.dataIndex] = f.getValue();
						},
						{store: this.store, index: i, dataIndex: c.applyValue}
					);
				}

			}
		}
		this.components.splice.apply(this.components, args);
	},
	
	destroyItems: function(index){
		Ext.destroy(this.components[index]);
		this.components.splice(index, 1);
	},
	
	get_new_record: function(initData) {
		
		var Store = this.getStore();
		
		// abort if the Store doesn't have create in its API:
		if(!Store.api.create) { return false; } 
		
		var node = this.getNode(0);
		if(node) {
			var nodeEl = new Ext.Element(node);
			// abort if another record is already being updated:
			if(nodeEl.parent().hasClass('record-update')) { return; }
		}
		
		var recMaker = Ext.data.Record.create(Store.fields.items);
		var newRec;
		if(initData){
			newRec = new recMaker(initData);
		}
		else {
			newRec = new recMaker;
		}
		
		if(! Store.api.create) {
			Ext.Msg.alert('Cannot add','No create function has been defined');
			return false;
		}
		return newRec;
	},
	
	add_record: function(initData) {
		var newRec = this.get_new_record(initData);
		if (newRec) {
			return this.getStore().add(newRec);
		}
	},
	
	insert_record: function(initData) {
		var newRec = this.get_new_record(initData);
		if (newRec) {
			return this.getStore().insert(0,newRec);
		}
	},
	
	
	
	set_field_editable: function(editEl,fieldname,index,Record,domEl) {
		
		//abort if its already editing:
		if(editEl.hasClass('editing')) { return; }
		
		var dataWrap = editEl.child('div.data-wrapper');
		var dataEl = editEl.child('div.data-holder');
		var fieldEl = editEl.child('div.field-holder');
		
		
		editEl.addClass('editing');

		var cnf = {};
		Ext.apply(cnf,Ext.decode(this.FieldCmp_cnf[fieldname]));
		Ext.apply(cnf,{
			ownerCt: this,
			Record: Record,
			value: Record.data[fieldname],
			//renderTo: dataWrap
			renderTo: fieldEl
			//contentEl: dataEl
		});
		
		if(!cnf.width) {	cnf.width = dataEl.getWidth(); }
		if(!cnf.height) { cnf.height = dataEl.getHeight(); }
		if(cnf.minWidth) { if(!cnf.width || cnf.width < cnf.minWidth) { cnf.width = cnf.minWidth; } }
		if(cnf.minHeight) { if(!cnf.height || cnf.height < cnf.minHeight) { cnf.height = cnf.minHeight; } }
		
		// UPDATE: using visibility mode across the board now because the other method was
		// causing images to overlap in some cases (2011-10-10 by HV)
		//if(Ext.isIE) {
			dataEl.setVisibilityMode(Ext.Element.DISPLAY);
			dataEl.setVisible(false);
		//}
		//else {
			// Stupid IE can't do it with contentEl, but we want to do the contentEl
			// way because if we use the hide method the element jumps in an
			// ungly way in FF.
		//	cnf.contentEl = dataEl;
		//}
		
		var Store = this.getStore();
		
		var Field = Ext.create(cnf,'field');
		
		/*****************************************************/
		// don't do this if the entire record is in edit mode or another record is already being updated:
		if(domEl &&(!domEl.hasClass('editing-record') && !domEl.parent().hasClass('record-update'))) { 

			var s = this.currentEditingFieldScope;
			if(s) {
				// cancel editing of any other field already being edited
				this.cancel_field_editable(s.editEl,s.fieldname,s.index,s.Record);
			}
			
			s = {
				editEl: editEl,
				fieldname: fieldname,
				index: index,
				Record: Record
			};
			
			this.currentEditingFieldScope = s;
			
			// Setup keymaps for Enter and Esc:
			Field.on('specialkey',function(field,e) {
				if(e.getKey() == e.ENTER) {
					if(! field.isValid()) { return; }
					this.save_field_data(editEl,fieldname,index,Record);
					Store.saveIfPersist();
					this.cancel_field_editable(editEl,fieldname,index,Record);
				}
				else if(e.getKey() == e.ESC) {
					this.cancel_field_editable(editEl,fieldname,index,Record);
				}
			},this);
			
			// If its a combo then set/save on select
			Field.on('select',function(field) {
				if(! field.isValid()) { return; }
				this.save_field_data(editEl,fieldname,index,Record);
				Store.saveIfPersist();
				this.cancel_field_editable(editEl,fieldname,index,Record);
			},this);
			
			if(Ext.isFunction(Field.selectText)) {
				// Focus the field and put the cursor at the end
				Field.on('show',function(field){
					field.focus();
					field.setCursorPosition(1000000);
				},this);
			}
			
		}
		/*****************************************************/
		

		if(Field.resizable) {
			var resizer = new Ext.Resizable(Field.wrap, {
				pinned: true,
				handles: 's',
				//handles: 's,e,se',
				dynamic: true,
				listeners : {
					'resize' : function(resizable, height, width) {
						Field.setSize(height,width);
					}
				}
			});
		}
		
		Field.show();
		
		if(!Ext.isObject(this.FieldCmp)) { this.FieldCmp = {} }
		if(!Ext.isObject(this.FieldCmp[index])) { this.FieldCmp[index] = {} }
		this.FieldCmp[index][fieldname] = Field;
	},
	
	save_field_data: function(editEl,fieldname,index,Record) {
		if(!editEl.hasClass('editing')) { return false; }
		
		var Field = this.FieldCmp[index][fieldname];
			
		if(!Field.validate()) { return false; }
		var val = Field.getValue();
		Record.set(fieldname,val);
		
		return true;
	},
	
	cancel_field_editable: function(editEl,fieldname,index,Record) {
	
		var dataWrap = editEl.child('div.data-wrapper');
		var dataEl = editEl.child('div.data-holder');
		var fieldEl = editEl.child('div.field-holder');
		
		if(dataWrap && dataEl && fieldEl) {

			var Fld = this.FieldCmp[index][fieldname];
			if(Fld.contentEl) {
				Fld.contentEl.appendTo(dataWrap);
			}
			Fld.destroy();
			dataEl.setVisible(true);
			
			editEl.removeClass('editing');
		}
		delete this.currentEditingFieldScope;
	},
	
	click_controller: function(dv, index, domNode, event) {
		var target = event.getTarget(null,null,true);
		var domEl = new Ext.Element(domNode);

		// Limit processing to click nodes within this dataview (i.e. not in our submodules)
		var topmostEl = target.findParent('div.appdv-tt-generated.' + dv.id,null,true);
		if(!topmostEl) { 
			// Temporary: map to old function:
			//return Ext.ux.RapidApp.AppDV.click_handler.apply(this,arguments);
			return; 
		}
		var clickableEl = topmostEl.child('div.clickable');
		if(!clickableEl) { return; }

		var Store = this.getStore();
		var Record = Store.getAt(index);
		
		var editEl = clickableEl.child('div.editable-value');
		if(editEl) {
			// abort if the Store doesn't have update in its API:
			if(!Store.api.update) { return; } 
			return this.handle_edit_field(target,editEl,Record,index,domEl);
		}
		
		editEl = clickableEl.child('div.edit-record-toggle');
		if(editEl) {
			// abort if the Store doesn't have update in its API and we're not already
			// in edit mode from an Add operation:
			if(!Store.api.update && !domEl.hasClass('editing-record')) { return; } 
			return this.handle_edit_record(target,editEl,Record,index,domEl);
		}
		
		editEl = clickableEl.child('div.delete-record');
		if(editEl) {
			// abort if the Store doesn't have destroy in its API:
			if(!Store.api.destroy) { return; } 
			return this.handle_delete_record(target,editEl,Record,index,domEl);
		}
		editEl = clickableEl.child('div.print-view');
		if(editEl) {
			if(this.printview_url) {
				window.open(this.printview_url,'');
			}
		}
	},
	get_fieldname_by_editEl: function(editEl) {
		var fieldnameEl = editEl.child('div.field-name');
		if(!fieldnameEl) { return false; }
		
		return fieldnameEl.dom.innerHTML;
	},
	handle_delete_record: function (target,editEl,Record,index,domEl) {
		
		// abort if the entire record is in edit mode:
		if(domEl.hasClass('editing-record')) { return; }
		
		// abort if another record is already being updated:
		if(domEl.parent().hasClass('record-update')) { return; }
		
		var Store = this.getStore();
		
		Store.removeRecord(Record);
		//if (!Record.phantom) { Store.saveIfPersist(); }
	},
	handle_edit_field: function (target,editEl,Record,index,domEl) {
		
		// abort if the entire record is in edit mode:
		if(domEl.hasClass('editing-record')) { return; }
		
		// abort if another record is already being updated:
		if(domEl.parent().hasClass('record-update')) { return; }
		
		var Store = this.getStore();
		
		var fieldname = this.get_fieldname_by_editEl(editEl);
		if(!fieldname) { return; }
		
		var dataWrap = editEl.child('div.data-wrapper');
		var dataEl = editEl.child('div.data-holder');
		var fieldEl = editEl.child('div.field-holder');

		if (editEl.hasClass('editing')) {
		
			var Field = this.FieldCmp[index][fieldname];
			
			if(target.hasClass('save')) {
				if(!this.save_field_data(editEl,fieldname,index,Record)) { return; }
				//Store.save();
				Store.saveIfPersist();
			}
			else {
				if(!target.hasClass('cancel')) { return; }
			}
		
			this.cancel_field_editable(editEl,fieldname,index,Record);
		}
		else {
			// require-edit-click is set by "edit-bigfield" to disallow going into edit mode unless the
			// "edit" element itself was clicked:
			if(target.findParent('div.require-edit-click') && !target.hasClass('edit')) { return; }
			this.set_field_editable(editEl,fieldname,index,Record,domEl);
			
		}
		
	},
	beginEditRecord: function(Record) {
		if(Record.editing) { return; }
		Record.beginEdit();
		this.currentEditRecord = Record;
		var Store = this.getStore();
		Store.fireEvent('buttontoggle',Store);
		this.clearSelections();
	},
	endEditRecord: function(Record) {
		if(!Record.editing) { return; }
		Record.endEdit();
		this.currentEditRecord = null;
		var Store = this.getStore();
		Store.fireEvent('buttontoggle',Store);
	},
	simulateEditRecordClick: function(cls,Record,index,editEl) {
		
		if(!Record) { Record = this.currentEditRecord; }
		if(!Record) { return; }
		
		if(!editEl) {
			var domEl = this.getNode(Record);
			editEl = new Ext.Element(domEl);
		}

		var TargetEl = editEl.child(cls);		
		if(typeof index === 'undefined') { index = this.getStore().indexOf(Record); }

		return this.handle_edit_record(TargetEl,editEl,Record,index,editEl);
	},
	simulateSaveClick: function() {
		return this.simulateEditRecordClick('div.save');
	},
	simulateCancelClick: function(Record,index,editEl) {
		return this.simulateEditRecordClick('div.cancel',Record,index,editEl);
	},
	
	handle_edit_record: function (target,editEl,Record,index,domEl) {

		var editDoms = domEl.query('div.editable-value');
		var editEls = [];
		Ext.each(editDoms,function(dom) {
			editEls.push(new Ext.Element(dom));
		});
		
		var Store = this.getStore();
		
		if(domEl.hasClass('editing-record')) {
			
			var save = false;
			if(target.hasClass('save')) {
				save = true;
			}
			else {
				if(!target.hasClass('cancel')) { return; }
			}

			this.beginEditRecord(Record);
		
			var success = true;
			/***** SAVE RECORDS *****/
			Ext.each(editEls,function(editEl) {
				var fieldname = this.get_fieldname_by_editEl(editEl);
				if(!fieldname) { return; }
				
				if(save) {
					if(!this.save_field_data(editEl,fieldname,index,Record)) { 
						success = false;
						return;
					}
				}
			},this);
			
			if(!success) {
				return;
			}
			
			
			/***** REMOVE EDIT STATUS *****/
			Ext.each(editEls,function(editEl) {
				var fieldname = this.get_fieldname_by_editEl(editEl);
				this.cancel_field_editable(editEl,fieldname,index,Record);
			},this);
			
			domEl.removeClass('editing-record');	
			domEl.parent().removeClass('record-update');
			//Record.endEdit();
			this.endEditRecord(Record);
			
			if(Record.phantom && !save) {
				return Store.remove(Record);
			}
			
			//this.scrollBottomToolbarIntoView.defer(100,this);
			if (this.isSaving) { return; }
			
			// persist_on_add is AppDV specific, and causes a store save to happen *after* a
			// new record has been added via filling out fields. when persist_immediately.create
			// is set empty records are instantly created without giving the user the chance
			// set the initial values
			if(Record.phantom && this.persist_on_add) { return Store.save(); }
			
			return Store.saveIfPersist();
		}
		else {
			// abort if another record is already being updated:
			if(domEl.parent().hasClass('record-update')) { return; }

			domEl.parent().addClass('record-update');
			domEl.addClass('editing-record');
			
			Ext.each(editEls,function(editEl) {
				var fieldname = this.get_fieldname_by_editEl(editEl);
				this.set_field_editable(editEl,fieldname,index,Record);
			},this);

			this.beginEditRecord(Record);
		}
	},
	
	scrollBottomToolbarIntoView: function(){
		var node = this.getParentScrollNode(this.getEl().dom);
		if(!node) { return; }
		Ext.fly(this.ownerCt.getBottomToolbar().getEl()).scrollIntoView(node);
	},
	
	scrollRecordIntoView: function(Record) {
		if(!this.getStore()) { return; }
		
		if(Record == Record.store.getLastRecord()) {
			return this.scrollBottomToolbarIntoView();
		}
		
		var node = this.getParentScrollNode(this.getEl().dom);
		if(!node) { return; }
		Ext.fly(this.getNode(Record)).scrollIntoView(node);

	},
	
	getParentScrollNode: function(node) {
		if(!node || !node.style) { return null; }
		if(node.style.overflow == 'auto') { return node; }
		if(node.parentNode) { return this.getParentScrollNode(node.parentNode); }
		return null;
	}
});
Ext.reg('appdv', Ext.ux.RapidApp.AppDV.DataView);
