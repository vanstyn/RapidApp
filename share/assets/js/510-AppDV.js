Ext.ns('Ext.ux.RapidApp.AppDV');


Ext.ux.RapidApp.AppDV.DataView = Ext.extend(Ext.DataView, {
	
  // New option to enable all links (<a> tags)to be processed. This is not the default
  // because this can result is navigating away from the interface which is
  // usually not desired. Links with explicit target attributes (i.e. target="_blank")
  // are already handled, and relative links are also already handled. The main
  // reason for this setting and the fact that it is false by default is due both
  // to back-compat, and also the fact that the native Ext.DataView code does not allow
  // links through by default when singleSelect or multiSelect is on
  allow_all_links: false,
  
	// TODO: make cascade recursive like in Ext.Container
	cascade: function(fn,scope,args) {
		fn.apply(scope || this, args || [this]);
		return this;
	},
	
  // collectData() is called whenever rendering/refreshing the template:
  collectData: function() {
    // New: Save the latest response data within the XTemplate object via the
    // reference keys which are now made available via DataStorePlus. This
    // enables the template environment to get this data via '[{this.resData}]'
    try{
      var hashval = window.location.hash;
      if(hashval && hashval.search('#') == 0) { 
        hashval = hashval.substring(1); 
      }
      this.tpl.hashval = hashval;
      this.tpl.resData = this.store.lastJsonData
        // The lastJsonData might not be populated on the first load, for this 
        // case,   // reach into the lastResponse, which is also now tracked, and decode it
        || Ext.decode(this.store.proxy.lastResponse.responseText);
    }catch(err){};
    return Ext.ux.RapidApp.AppDV.DataView.superclass.collectData.apply(this,arguments);
  },
  
  getLoadMaskEl: function() {
    var El = this.getEl();
    return El ? El.parent().parent() : Ext.getBody();
  },
  
	initComponent: function(){
		Ext.each(this.items,function(item) {
			item.ownerCt = this;
		},this);
		Ext.ux.RapidApp.AppDV.DataView.superclass.initComponent.call(this);
		this.components = [];
    
    this.on('beforeclick',this.onBeforeclick,this);
		this.on('click',this.click_controller,this);
		
    this.on('containerclick',function(dv,event){
      // Block the containerclick, which clears selections, for the special 
      // AppDV-specific clickable command (i.e. store buttons, etc)
      if(this.find_clickableEl(event)){ return false; };
    },this);
    
    this.tpl.store = this.store;
    
		//if(!this.store) { this.store = this.ownerCt.store; }
		
		this.store.on('beforesave',this.onBeforesave,this);
		this.store.on('beforeremove',this.onBeforeremove,this);
		
		// Special AppDV override: addNotAllowed based on
		// current edit record:
		var cmp = this;
		cmp.on('afterrender',function(){
      this.el.on('click',this.el_click_controller,this);
 
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
    
    if(this.refresh_on_save) {
      this.store.on('write',function(){
        this.refresh.apply(this,arguments);
      },this);
    }
    
    if(this.init_record_editable) {
      this.on('firstload',function(cmp,ds){
        var node = this.getNode(0,0);
        if(node) {
          var El = new Ext.Element(node);
          var Toggle = El.child('div.edit-record-toggle');
          if(Toggle) {
            Toggle.dom.click();
          }
        }
      },this);
    }
    
    if(this.refresh_on_hash_change) {
      Ext.History.on('change',this.refresh,this);
      this.on('beforedestroy',function(){
        Ext.History.un('change',this.refresh,this);
      },this);
    }
    
    // init
    this.FieldCmp = {};
    
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

    //Ext.ux.RapidApp.AppDV.DataView.superclass.refresh.call(this);
    // --- Orig refresh(), with modified 'emptyText' behavior (GitHub Issue #157)---
    this.clearSelections(false, true);
    var el = this.getTemplateTarget(),
        records = this.store.getRange();
        
    el.update('');
    // We do not apply the 'emptyText' if it is empty (new for GH #157):
    if(records.length < 1 && this.emptyText && this.emptyText != ''){
        if(!this.deferEmptyText || this.hasSkippedEmptyText){
            el.update(this.emptyText);
        }
        this.all.clear();
    }else{
        this.tpl.overwrite(el, this.collectData(records, 0));
        this.all.fill(Ext.query(this.itemSelector, el.dom));
        this.updateIndexes(0);
    }
    this.hasSkippedEmptyText = true;
    // ---

    // renderItems relates to the special case of sub-componenets, not 
    // rendering the normal, local records/columns and their editors
    this.renderItems(0, this.store.getCount() - 1);
    
    this.toggleDirtyCssRecord(records,false);
    this.injectDynamicStylesheet();
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
    
    var dsPlug = this.datastore_plus_plugin;
    if(!dsPlug.use_add_form && !this.persist_immediately.create) {
    
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
    }
		
    // If scrollNodeClass, this should work:
    if(this.scrollNodeClass) {
      this.scrollRecordIntoView.defer(10,this,[records[records.length - 1]]);
    }
    else {
      this.scrollRecord.defer(10,this,[records[records.length - 1]]);
    }
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
  
  scrollRecord: function(record) {
    var dvEl = this.el;
    this.forEachRecordNode(function(el){
      el.scrollIntoView(dvEl);
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
			//if(rec.dirtyEl) { rec.dirtyEl.remove(); }
			if(tog && el && rec.dirty) {
        
        // New: sets the dirty flag on the appropriate, individual fields:
        var fieldDoms = el.query('div.field-name'); 
        Ext.each(fieldDoms,function(fDom) {
          var fname = fDom.innerHTML;
          if(rec.fields.get(fname)) {
            var fEl = new Ext.Element(fDom);
            var dWrap = fEl.parent('div.editable-value');
            if(dWrap) {
              if(dWrap.hasClass('x-grid3-dirty-cell')) {
                dWrap.removeClass('x-grid3-dirty-cell');
              }
              if(typeof rec.modified[fname] !== "undefined") {
                dWrap.addClass('x-grid3-dirty-cell');
              }
            }
          }
        },this);
        
				// This logic sets a dirty flag on the entire record... disabled 
        // after adding the above, field-specific dirty flagging
				//var domCfg = {
				//	tag: 'div',
				//	style: 'position:absolute;',
				//	children:[{
				//		tag: 'div',
				//		cls: 'x-grid3-dirty-cell',
				//		style: 'position:relative;top:0;left:0;z-index:15000;height:10px;width:10px;'
				//	}]
				//};
				//
				//if(el.dom.tagName.toUpperCase() == 'TR') {
				//	domCfg = {
				//		tag: 'tr',
				//		children:[{
				//			tag: 'td',
				//			children:[domCfg]
				//		}]
				//	};
				//}
				//
				//rec.dirtyEl = el.insertSibling(domCfg,'before');
			}
      
      if(rec.phantom) {
        if(el.hasClass('non-phantom')) { el.removeClass('non-phantom'); }
        if(!el.hasClass('is-phantom')) { el.addClass('is-phantom'); }
      }
      else {
        if(el.hasClass('is-phantom')) { el.removeClass('is-phantom'); }
        if(!el.hasClass('non-phantom')) { el.addClass('non-phantom'); }
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
      // we have to do this ourselves because we cancel the default remove event,
      // normally this would be done for us by the DataStorePlus plugin
      if(this.datastore_plus_plugin.persist_immediately.destroy) { 
        ds.saveIfPersist();
      }
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
    
    // re-scan for ra-async-box elements -- codepath is specific to AppDV
    Ext.ux.RapidApp.loadAsyncBoxes(this);
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
    
    if(!this.fieldRecordCanEdit(fieldname,Record)) { return; }

		
		editEl.addClass('editing');

		var cnf = {};
		Ext.apply(cnf,Ext.decode(this.FieldCmp_cnf[fieldname]));
		Ext.apply(cnf,{
			ownerCt: this,
			Record: Record,
			renderTo: fieldEl
			//contentEl: dataEl
		});
    
    if(Record && Record.data && typeof Record.data[fieldname] !== "undefined") {
      // This will not get called in add record context, and we don't want it to:
      cnf.value = Record.data[fieldname];
    }
    
		
		if(!cnf.width) {	cnf.width = dataEl.getWidth() + 10; }
		if(!cnf.height) { cnf.height = dataEl.getHeight() + 6; }
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
    
    cnf.AppDv_context = {
      appdv: this,
      Record: Record,
      editEl:editEl,
      index: index
    };
    cnf.plugins = cnf.plugins || [];
    cnf.plugins.push('appdv-field-plugin');
    
    // New: handle the special appdv-fill-absolute case - remove all
    // dynamic sizing options and apply the target rule to set 'absolute'
    // from and according to the CSS
    if(editEl.findParent('div.appdv-fill-absolute')) {
      if(cnf.grow) { cnf.grow = false; }
      cnf.cls = 'appdv-fill-absolute-target-rule';
      //cnf.width = '100%';
      cnf.height = 'auto';
    }
    
		
		var Field = Ext.create(cnf,'field');
    
    Field.reportDirtyDisplayVal = function(disp) {
      Record._dirty_display_data = Record._dirty_display_data || {};
      Record._dirty_display_data[Field.name] = disp;
    }
		
		if(!Ext.isObject(this.FieldCmp)) { this.FieldCmp = {} }
		if(!Ext.isObject(this.FieldCmp[index])) { this.FieldCmp[index] = {} }
		this.FieldCmp[index][fieldname] = Field;
		
		
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
			
			var endEdit = function() {
				this.cancel_field_editable(editEl,fieldname,index,Record);
			};
			
			var saveEndEdit = function() {
				//console.log('saveEndEdit');
				this.save_field_data(editEl,fieldname,index,Record);
				Store.saveIfPersist();
				endEdit.call(this);
			};
			
			this.currentEditingFieldScope = s;
			
			// Setup keymaps for Enter and Esc:
			Field.on('specialkey',function(field,e) {
				if(e.getKey() == e.ENTER) {
          // triggerBlur is on trigger/combos, and needs to be called to call any needed
          // logic to apply the raw field value 
          if(Ext.isFunction(field.triggerBlur)) {
            field.triggerBlur();
          }
					if(! field.isValid()) { return; }
					saveEndEdit.call(this);
				}
				else if(e.getKey() == e.ESC) {
					endEdit.call(this);
				}
			},this);
			
			// If its a combo then set/save on select
			Field.on('select',function(field) {
				//console.log('AppDV select');
				
				if(field && ! field.isValid()) { return; }
				saveEndEdit.call(this);
			},this);
			
			if(Ext.isFunction(Field.selectText)) {
				// Focus the field and put the cursor at the end
				Field.on('show',function(field){
					field.focus();
					field.setCursorPosition(1000000);
				},this);
			}
			
      // Fire the trigger if present (i.e. expand dropdown)
      if(Ext.isFunction(Field.onTriggerClick)) {
        Field.on('show',function(field){
          field.onTriggerClick();
        },this);
      }

		}
		/*****************************************************/
		
		// This logic moved into Ext.ux.RapidApp.HtmlEditor
		//if(Field.resizable) {
		//	var resizer = new Ext.Resizable(Field.wrap, {
		//		pinned: true,
		//		handles: 's',
		//		//handles: 's,e,se',
		//		dynamic: true,
		//		listeners : {
		//			'resize' : function(resizable, height, width) {
		//				Field.setSize(height,width);
		//			}
		//		}
		//	});
		//}
		
		Field.show();
		
	},
	
	save_field_data: function(editEl,fieldname,index,Record) {
		if(!editEl.hasClass('editing')) { return false; }
		var Field = this.FieldCmp[index][fieldname];
			
		if(!Field.validate()) { return false; }
    if(Field.isDirty()) {
      var val = Field.getValue();
      Record.set(fieldname,val);
    }
		
		return true;
	},
	
	cancel_field_editable: function(editEl,fieldname,index,Record) {
	
		var dataWrap = editEl.child('div.data-wrapper');
		var dataEl = editEl.child('div.data-holder');
		var fieldEl = editEl.child('div.field-holder');
		
    
    if(this.FieldCmp[index] && this.FieldCmp[index][fieldname] && dataWrap && dataEl && fieldEl) {
			var Fld = this.FieldCmp[index][fieldname];
			if(Fld.contentEl) {
				Fld.contentEl.appendTo(dataWrap);
			}
      // remove the field valid state from consideration (will clear if the field was invalid)
      this.fireEvent('valid',Fld); 
			Fld.destroy();
			dataEl.setVisible(true);
			
			editEl.removeClass('editing');
		}
		delete this.currentEditingFieldScope;
	},
  
  find_clickableEl: function(event,domNode) {
    var target = event.getTarget(null,null,true);
    
    // --- Override nav links
    var href = target.getAttribute('href');
    if(href && target.is('a')) {
      // New: ignore links with target attribute (i.e. target="_self", etc)
      if(target.getAttribute('target')) {
        return null;
      }
      // HashNav links (a tags with href starting with '#!/'):
      else if(href.search('#!/') === 0) {
        window.location.hash = href;
        return null;
      }
    }
    // ---
      
    // Limit processing to click nodes within this dataview (i.e. not in our submodules)
    var topmostEl = target.findParent('div.appdv-tt-generated.' + this.id,null,true);
    if(!topmostEl) { 
      // Temporary: map to old function:
      //return Ext.ux.RapidApp.AppDV.click_handler.apply(this,arguments);
      return null; 
    }
    var clickableEl = topmostEl.child('div.clickable');
  
    return clickableEl;
  },

  // The el_click_controller handles raw clicks on the whole content area, not just
  // a specific record, like the click_controller
  el_click_controller: function(event,domNode,o) {
    var clickableEl = this.find_clickableEl(event,domNode);
    
    // We only handle class="clickable command" (click_controller handles class="clickable")
    if(clickableEl && clickableEl.hasClass('command')) {
      
      var cmdEl = clickableEl.child('div.store-button');
      if(cmdEl) {
        //this.store.addRecordForm();
          
        var Btn, dsPlug = this.datastore_plus_plugin;
        Ext.each(dsPlug.store_buttons,function(itm){
          if(cmdEl.hasClass(itm)) {
            Btn = dsPlug.getStoreButton(itm);
            return false; //<-- stop iteration
          }
        },this);
        
        if(Btn && !Btn.disabled && Btn.handler) {
          Btn.handler.call(this,Btn);
        
        }
        
        //console.dir(Btn);
      
        return;
      }
      
      // handle other commands ...
    
    }
  },
  
    
  onBeforeclick: function(dv, index, domNode, event) {
  
    // Important: when multiSelect or singleSelect is enabled, if we don't return 
    // *false* from this event to stop it, the native Ext.DataView code will block
    // the ordinary browser event (by calling e.preventDefault()). This will stop
    // ordinary links from working. So, if we want links to work, we have to handle
    // here, manually:
  
    // testTarget()
    // Returns true if the supplied target should be handled by AppDV, false if
    // it should be handled natively by the browser
    var testTarget;
    testTarget = function(target) {
      // We're still not going to allow *ALL* links through... We are letting
      // through links with the special 'filelink' class, and also letting 
      // through links which have defined a target (i.e. target="_blank", etc),
      // otherwise we will continue with the existing native behavior which is
      // to make the link do nothing in the browser, but be handled in AppDV. 
      // Also, note that we are now enabling the
      // 'ra-link-click-catcher' in AppDV per default (see AppDV.pm) so it may
      // still pickup and handle relative URL links in the standard manner.
      if(
        target.hasClass('filelink') ||
        target.getAttribute('target') || 
        // New: if this is a form submit button/input, assume the user means it
        // to submit as usual and allow it through:
        (target.getAttribute('type') && target.getAttribute('type')  == 'submit')
      ) {
        // If we're here it means the target matches one of our exclusions, so we'll
        // return false to allow the browser to handle it **unless** it is within a
        // declared, appdv clickable element. We always want to handle these ourselves
        var click_parent = target.parent('div.clickable');
        if(click_parent && click_parent.parent('div.appdv-tt-generated')){
          return true;
        }
        else {
          return false; 
        }
      }
      
      if(target.is('a')) {
        if(this.allow_all_links) {
          return false;
        }
      }
      else {
        // If we're not an <a> tag, check to see if we are within an <a> tag, and
        // for that case consider the parent <a> tag:
        var parent = target.parent('a');
        if(parent) {
          return testTarget(parent);
        }
      }
      
      return true;
    };
    
    return testTarget( event.getTarget(null,null,true) );
  },
  
	click_controller: function(dv, index, domNode, event) {
    var clickableEl = this.find_clickableEl.call(dv,event,domNode);
    
    if(!clickableEl) { return; }
    
    var target = event.getTarget(null,null,true);
    var domEl = new Ext.Element(domNode);

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
		if(!this.fieldRecordCanEdit(fieldname,Record)) { return; }
		
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
  
  // Returns true/false if the field can edit, properly considering edit vs add
  fieldRecordCanEdit: function(fieldname,Record) {
    if(!fieldname || !Record) { return false; }
    var column = Record.store.getColumnConfig(fieldname);
    if(!column) { return false; }
    if(Record.phantom) {
      if(!column.allow_add) { return false; }
      if(!Record.store.api.create) { return false; }
    }
    else {
      if(!column.allow_edit) { return false; }
      if(!Record.store.api.update) { return false; }
    }
    
    return true;
  },
  
	
	handle_edit_record: function (target,editEl,Record,index,domEl) {
		
		var Store = this.getStore();
		
		// New: use the datastore-plus edit record function:
		if(this.use_edit_form && !Record.phantom){
			return Store.editRecordForm(Record);
		}

		var editDoms = domEl.query('div.editable-value');
		var editEls = [];
		Ext.each(editDoms,function(dom) {
			editEls.push(new Ext.Element(dom));
		});
		
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
				if(!this.fieldRecordCanEdit(fieldname,Record)) { return; }
				
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
			if(domEl.parent()) {
        domEl.parent().removeClass('record-update');
      }
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
      if(domEl.parent()) {
        if(domEl.parent().hasClass('record-update')) { return; }
        domEl.parent().addClass('record-update');
      }
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
    if(this.ownerCt && Ext.isFunction(this.ownerCt.getBottomToolbar)) {
      var bbar = this.ownerCt.getBottomToolbar();
      if(bbar) { Ext.fly(bbar.getEl()).scrollIntoView(node); }
    }
	},
	
	scrollRecordIntoView: function(Record) {
		if(!this.getStore()) { return; }
		
		//if(Record == Record.store.getLastRecord()) {
		//	return this.scrollBottomToolbarIntoView();
		//}
    
    var recNode = this.getNode(Record);
		
		//var node = this.getParentScrollNode(this.getEl().dom);
    var node = this.getParentScrollNode(recNode);
		if(!node) { return; }
		Ext.fly(recNode).scrollIntoView(node);

	},
  
  scrollNodeClass: null,

  getParentScrollNode: function(node) {
    if(!node) { return null; }
    if(this.scrollNodeClass) {
      var nodeEl = new Ext.Element(node);
      if(nodeEl.hasClass(this.scrollNodeClass)) {
        return node;
      }
    }
    if(node.style && (
      node.style.overflow == 'auto' || 
      node.style.overflow == 'scroll'
    )){ return node; }
      
    if(node.parentNode) {
      return this.getParentScrollNode(node.parentNode); 
    }
    return null;
  },

  // proof-of-concept: preliminary styles moved out of 045-AppDV.css to be generated
  // on-the-fly for each AppDB component. This is being done so that the override
  // style will match ONLY the correct AppDV, and not any nested AppDV modules
  dynStylesheetTpl: new Ext.XTemplate("<style type=\"text/css\">            \
    #{id}.ra-dsapi-deny-destroy .appdv-tt-generated.{id} .delete-record {   \
      display: none !important;                                             \
    }                                                                       \
  </style>").compile(),
  
  injectDynamicStylesheet: function() {
    this.dynStylesheetTpl.append(this.el,{ id: this.id });
  }

});
Ext.reg('appdv', Ext.ux.RapidApp.AppDV.DataView);

Ext.ux.RapidApp.AppDV.FieldPlugin = Ext.extend(Ext.util.Observable,{

  constructor: function(config){
    this.addEvents('valid','invalid');
    this.on('valid',this.onFieldValid,this);
    this.on('invalid',this.onFieldInvalid,this);
  },
    
  init: function(Field) {
    var Ctx = Field.AppDv_context;
    if(!Ctx) { return; }
    
    this.Field = Field; 
    this.Ctx = Ctx;
    
    var recNode = Ctx.appdv.getNode(Ctx.index);
    if(recNode) { 
      Ctx.recEl = new Ext.Element(recNode); 
    }

    this.relayEvents(Field,['valid','invalid']);
  },
    
  onFieldValid: function() {
    var El = this.Ctx.editEl;
    if(!El) { return; }
    
    if(El.hasClass('appdv-field-invalid')) {
      El.removeClass('appdv-field-invalid');
    }
    this.checkRecEl.defer(100,this);
  },
  onFieldInvalid: function(Field,msg) {
    var El = this.Ctx.editEl, recEl = this.Ctx.recEl;
    if(!El) { return; }

    if(!El.hasClass('appdv-field-invalid')) {
      El.addClass('appdv-field-invalid');
    }
    
    if(recEl && !recEl.hasClass('appdv-rec-invalids')) {
      recEl.addClass('appdv-rec-invalids');
    }
  },
  checkRecEl: function() {
    var recEl = this.Ctx.recEl;

    if(! recEl || ! recEl.hasClass('appdv-rec-invalids')) {
      return;
    }
    
    // If the record is marked invalid, but there are no longer
    // any field invalids, clear it
    if(! recEl.child('div.appdv-field-invalid')){
      if(recEl.hasClass('appdv-rec-invalids')) {
        recEl.removeClass('appdv-rec-invalids');
      }
    }
  }
   

});
Ext.preg('appdv-field-plugin',Ext.ux.RapidApp.AppDV.FieldPlugin);
