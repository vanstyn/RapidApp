Ext.ns('Ext.ux.RapidApp.AppDV');


Ext.ux.RapidApp.AppDV.DataView = Ext.extend(Ext.DataView, {
	
	initComponent: function(){
			Ext.each(this.items,function(item) {
				item.ownerCt = this;
			},this);
			Ext.ux.RapidApp.AppDV.DataView.superclass.initComponent.call(this);
			this.components = [];
			
			this.on('click',this.click_controller,this);
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
	},
	
	onAdd: function(ds, records, index){
		var count = this.all.getCount();
		Ext.ux.RapidApp.AppDV.DataView.superclass.onAdd.apply(this, arguments);
		if(count !== 0){
			this.renderItems(index, index + records.length - 1);
		}
		
		var Record = records[0];
		var domEl = this.getNode(Record);
		var editEl = new Ext.Element(domEl);
		
		this.handle_edit_record(editEl,editEl,Record,index,editEl);
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
	
	set_field_editable: function(editEl,fieldname,index,Record) {
		
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
		
		//console.dir(dataEl);
		
		if(!cnf.width) {	cnf.width = dataEl.getWidth(); }
		if(!cnf.height) { cnf.height = dataEl.getHeight(); }
		if(cnf.minWidth) { if(!cnf.width || cnf.width < cnf.minWidth) { cnf.width = cnf.minWidth; } }
		if(cnf.minHeight) { if(!cnf.height || cnf.height < cnf.minHeight) { cnf.height = cnf.minHeight; } }
		
		if(Ext.isIE) {
			dataEl.setVisibilityMode(Ext.Element.DISPLAY);
			dataEl.setVisible(false);
		}
		else {
			// Stupid IE can't do it with contentEl, but we want to do the contentEl
			// way because if we use the hide method the element jumps in an
			// ungly way in FF.
			cnf.contentEl = dataEl;
		}
		
		var Field = Ext.create(cnf,'field');

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
				window.open(this.printview_url,'print_view-' + this.id);
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
		
		Store.remove(Record);
		if (!Record.phantom) { Store.save(); }
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
				Store.save();
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
			this.set_field_editable(editEl,fieldname,index,Record);
		}
		
	},
	handle_edit_record: function (target,editEl,Record,index,domEl) {
		
		var editDoms = domEl.query('div.editable-value');
		var editEls = [];
		Ext.each(editDoms,function(dom) {
			editEls.push(new Ext.Element(dom));
		});
		
		var Store = this.getStore();
		//console.dir(editEls);
		
		if(domEl.hasClass('editing-record')) {
			
			var save = false;
			if(target.hasClass('save')) {
				save = true;
			}
			else {
				if(!target.hasClass('cancel')) { return; }
			}
			
			Record.beginEdit();
		
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
			Record.endEdit();
			
			if(Record.phantom && !save) {
				Store.remove(Record);
			}
			
			return Store.save();
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

		}
	}
});
Ext.reg('appdv', Ext.ux.RapidApp.AppDV.DataView);

/*
Ext.ux.RapidApp.AppDV.click_handler = function(dv, index, domEl, event) {
	var target = event.getTarget(null,null,true);

	// Limit processing to click nodes within this dataview (i.e. not in our submodules)
	if(!target.findParent('div.appdv-click.' + dv.id)) { return; }

	var clickEl = target;
	if(!clickEl.hasClass('appdv-click-el')) { clickEl = target.parent('div.appdv-click-el'); }
	if(!clickEl) { return; }
	
	var node = clickEl.dom;
	// Needed for IE:
	var classList = node.classList;
	if(! classList) {
		classList = node.className.split(' ');
	}
	
	var fieldname = null;
	Ext.each(classList,function(cls) {
		var arr = cls.split('edit:');
		if (arr.length > 1) {
			fieldname = arr[1];
		}
	});
	
	if (!fieldname) { return; }
	//console.log(fieldname);
	
	var topEl = new Ext.Element(domEl);
	
	//console.dir(topEl);
	
	var valueEl = topEl.child('div.appdv-field-value.' + fieldname);
	//if (!valueEl) { return; }
	
	var dataEl = valueEl.child('div.data');
	var fieldEl = valueEl.child('div.fieldholder');
	var Store = dv.getStore()
	var Record = Store.getAt(index);
	
	if (valueEl.hasClass('editing')) {
	
		var Field = dv.FieldCmp[index][fieldname];
		
		if(!target.hasClass('cancel')) {
			var val = Field.getValue();
			Record.set(fieldname,val);
			Store.save();
		}
	
		valueEl.removeClass('editing');
		
		//console.dir(dv.FieldCmp[index][fieldname].contentEl);
		dv.FieldCmp[index][fieldname].contentEl.appendTo(valueEl);
		dv.FieldCmp[index][fieldname].destroy();
		//dataEl.setVisible(true);
	}
	else {
		valueEl.addClass('editing');
		
		var cnf = {};
		Ext.apply(cnf,dv.FieldCmp_cnf[fieldname]);
		Ext.apply(cnf,{
			value: Record.data[fieldname],
			//renderTo: valueEl
			renderTo: fieldEl,
			contentEl: dataEl
		});
		
		//console.dir(dataEl);
		
		if(!cnf.width) {	cnf.width = dataEl.getWidth(); }
		if(!cnf.height) { cnf.height = dataEl.getHeight(); }
		if(cnf.minWidth) { if(!cnf.width || cnf.width < cnf.minWidth) { cnf.width = cnf.minWidth; } }
		if(cnf.minHeight) { if(!cnf.height || cnf.height < cnf.minHeight) { cnf.height = cnf.minHeight; } }
				
		var Field = Ext.ComponentMgr.create(cnf,'field');

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
		//dataEl.setVisibilityMode(Ext.Element.DISPLAY);
		//dataEl.setVisible(false);
		
		//Field.getEl().applyStyle(dataEl.getStyle());
		
		if(!Ext.isObject(dv.FieldCmp)) { dv.FieldCmp = {} }
		if(!Ext.isObject(dv.FieldCmp[index])) { dv.FieldCmp[index] = {} }
		dv.FieldCmp[index][fieldname] = Field;
	}
}

*/



