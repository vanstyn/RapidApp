Ext.ns('Ext.ux.RapidApp.Plugin');

/*
 Ext.ux.RapidApp.Plugin.CmpDataStorePlus
 2011-11-02 by HV

 Plugin for components with stores (such as AppGrid2, AppDV).
 This plugin contains generalized extra functionality applicable
 to any components with stores (note that Ext.data.Store itself
 cannot use plugins because its not a component)
*/
Ext.ux.RapidApp.Plugin.CmpDataStorePlus = Ext.extend(Ext.util.Observable,{
	init: function(cmp) {
		this.cmp = cmp;
		cmp.datastore_plus_plugin = this;

		delete cmp.store.tiedChildStores;
		
		// bubbles up the parent components and records us as a tied child store:
		cmp.bubbleTieStoreParents = function() {
			this.bubble(function() {
				if(this.bubbleTieStoreParents) {
					if(!this.store.tiedChildStores) {
						this.store.tiedChildStores = {};
						this.store.tiedChildStores[this.store.storeId] = this.store;
					}
					this.store.tiedChildStores[cmp.store.storeId] = cmp.store;
				}
			});
		};
		this.cmp.on('render',cmp.bubbleTieStoreParents,cmp);
		
		
		this.cmp.origInitEvents = this.cmp.initEvents;
		this.cmp.initEvents = function() {
			cmp.origInitEvents.call(cmp);
			if(cmp.loadMask){
				cmp.loadMask = new Ext.LoadMask(cmp.bwrap,
						  Ext.apply({store:cmp.store}, cmp.loadMask));
			}
		}
		
		
		// -- instead of standard store 'autoLoad' param, 'store_autoLoad' happens
		// on 'render' in order to be delayed, in the case of the component being
		// within a collapsed panel, etc. This is partnered with the setting set
		// within DataStore2
		if(typeof cmp.store_autoLoad == 'undefined'){
			// Optionally override value from the cmp, if it exists:
			cmp.store_autoLoad = cmp.store.store_autoLoad;
		}
		if(cmp.store_autoLoad) {
			var onFirstShow;
			onFirstShow = function(){
				// only load if its the first load and not collapsed:
				if(!cmp.store.lastOptions && !cmp.collapsed){
					var params = Ext.isObject(cmp.store_autoLoad) ? cmp.store_autoLoad : {};
					cmp.store.load(params);
				}
			}
			cmp.on('render',onFirstShow,this);
			cmp.on('expand',onFirstShow,this);
		}
		// --
		
		
		if(!cmp.persist_immediately) { cmp.persist_immediately = {}; }
		if(cmp.persist_all_immediately) {
			cmp.persist_immediately = {
				create: true,
				update: true,
				destroy: true
			};
		}
		var miss = false;
		if(cmp.store.api.create && !cmp.persist_immediately.create) { miss = true; }
		if(cmp.store.api.update && !cmp.persist_immediately.update) { miss = true; }
		if(cmp.store.api.destroy && !cmp.persist_immediately.destroy) { miss = true; }
		cmp.persist_all_immediately = true;
		if(miss) { cmp.persist_all_immediately = false; }
		
		Ext.copyTo(this,cmp,[
			'store_buttons',
			'show_store_button_text',
			'store_button_cnf',
			'store_exclude_buttons',
			'close_unsaved_confirm',
			'persist_all_immediately',
			'persist_immediately',
			'store_add_initData',
			'use_edit_form',
			'use_add_form',
			'add_form_url_params',
			'add_form_window_cnf',
			'autoload_added_record',
			'add_records_first',
			'store_exclude_api',
			'store_write_mask',
			'confirm_on_destroy'
		]);
		
		this.exclude_btn_map = {};
		Ext.each(this.store_exclude_buttons,function(item) { this.exclude_btn_map[item] = true; },this);
		if(!this.use_edit_form) { this.exclude_btn_map.edit = true; }
		
		this.initAdditionalStoreMethods.call(this,this.cmp.store,this);
		
		this.cmp.loadedStoreButtons = {};
			
		
		// --vv-- Displays the number of records in the title (superscript)	
		var titleCmp = cmp;
		if(!cmp.title && cmp.ownerCt && (cmp.ownerCt.titleCountLocal || cmp.ownerCt.titleCount )){
			titleCmp = cmp.ownerCt;
		}
		if(titleCmp.title && ( titleCmp.titleCountLocal || titleCmp.titleCount )) {
			cmp.store.on('buttontoggle',function() {
				var count = titleCmp.titleCountLocal ? cmp.store.getCount() : cmp.store.getTotalCount();
				if(count == 0) { count = ''; }
				titleCmp.setTitle(
					titleCmp.initialConfig.title + 
						'&nbsp;<span class="superscript-navy">' + count + '</span>'
				);
			},cmp);
		}
		// --^^--
		
		var plugin = this;
		this.cmp.getStoreButton = function(name,showtext) {
			return plugin.getStoreButton.call(plugin,name,showtext);
		};
		
		if(this.cmp.setup_bbar_store_buttons) {
			this.cmp.on('render',this.insertStoreButtonsBbar,this);
		}
		
		if(this.cmp.setup_tbar_store_buttons) {
			this.cmp.on('render',this.insertStoreButtonsTbar,this);
		}
		
		// Only applies to editor grids; no effect/impact on other components
		// without the beforeedit/afteredit events
		this.cmp.on('beforeedit',this.beforeCellEdit,this);
		this.cmp.on('afteredit',this.cmp.store.saveIfPersist,this);
		
		/**********************/
		/** For Editor Grids **/
		if(Ext.isFunction(cmp.startEditing)){

			cmp.startEditing_orig = cmp.startEditing;
			
			cmp.startEditing = function(row,col) {
				var ed = this.colModel.getCellEditor(col, row);
				if(ed) {
					var field = ed.field;
					if(field && !field.DataStorePlusApplied) {
						
						var stopEditFn = cmp.stopEditing.createDelegate(cmp);
						
						// --- Handle Ctrl+S/Ctrl+Z ('save'/'undo' keyboard shortcuts) for in-progress edit:
						field.on('afterrender', function(){
							if(!field.el) { return; }
							var savebtn = cmp.loadedStoreButtons ? cmp.loadedStoreButtons.save : null;
							new Ext.KeyMap(field.el,{
								ctrl: true,
								key: 's',
								fn: function(k,e){
									e.stopEvent();

									// Complete the edit:
									stopEditFn();

									// If we have a Store save button, also call its handler:
									if(savebtn) { return savebtn.handler.call(this,savebtn); }
								},
								scope: this
							});
							// This is better than the default Ctrl+Z behavior for text fields:
							var xtype = field.getXType();
							if(xtype == 'field' || xtype == 'textfield' || xtype == 'numberfield') {
								new Ext.KeyMap(field.el,{
									ctrl: true,
									key: 'z',
									fn: ed.cancelEdit,
									scope: ed
								});
							}
						},this);
						// ---

						// For combos and other fields with a select listener, automatically
						// finish the edit on select
						field.on('select',stopEditFn);
						
						// For cycle-field/menu-field:
						field.cycleOnShow = false;
						field.manuOnShow = false;
						
						//Call 'expand' for combos and other fields with an expand method (cycle-field)
						if(Ext.isFunction(field.expand)) {
							ed.on('startedit',function(){
								this.expand();
								// If it is specifically a combo, call expand again to make sure
								// it really expands
								if(Ext.isFunction(this.doQuery)) {
									this.expand.defer(50,this);
								}
							},field);
						}
						
						field.DataStorePlusApplied = true;
					}
				}
				return cmp.startEditing_orig.apply(cmp,arguments);
			}
		}
		/**********************/
		/**********************/
		
		
		
		if(Ext.isFunction(this.cmp.getSelectionModel)) {
			// Give Grids getSelectedRecords() so they work like DataViews:
			if(!Ext.isFunction(this.cmp.getSelectedRecords)) {
				this.cmp.getSelectedRecords = function() {
					
					var sm = this.getSelectionModel();
					return sm.getSelections.apply(sm,arguments);
				}
			}
			
			// Give grids the selectionchange event so they work like dataviews:
			var sm = this.cmp.getSelectionModel();
			this.cmp.relayEvents(sm,['selectionchange']);
		}
		
		if(this.close_unsaved_confirm) {
			this.cmp.bubble(function(){
				//this.on('beforedestroy',plugin.beforeDestroy,plugin);
				this.on('beforeremove',plugin.beforeRemoveConfirm,plugin);
			});
		}
		
		// Override 'renderRows' of GridViews to get freshly added rows
		// to show up as dirty. Fields associated with a modified value of
		// undefined don't show up as dirty in the original code. This fixes
		// that:
		this.cmp.on('viewready',function(){
			var view = this.cmp.getView();
			if(!view.renderRowsOrig) { view.renderRowsOrig = view.renderRows; }
			view.renderRows = function(startRow,endRow){
				var grid = view.grid,
				store    = grid.store,
				rowCount = store.getCount(),
				records;
		  
				if (rowCount < 1) { return ''; }
		  
				startRow = startRow || 0;
				endRow   = Ext.isDefined(endRow) ? endRow : rowCount - 1;
				records  = store.getRange(startRow, endRow);
				
				Ext.each(records,function(record) {
					Ext.iterate(record.modified,function(k,v) {
						if(typeof v == 'undefined') { record.modified[k] = null; }
					},this);
				},this);
				return view.renderRowsOrig(startRow,endRow);
			};
		},this);
		
		// Automatically tries to load newly created (from backend) records
		// into loadTarget. This is roughly the same as a double-click on a
		// grid row:
		if(this.autoload_added_record) {
			cmp.store.on('write',function(store,action,result,res,Record){
				if(action == "create" && Ext.isObject(Record) && !Record.phantom && Record.data.loadContentCnf){
					//var loadTarget = Ext.getCmp("main-load-target");
					//return Ext.ux.RapidApp.AppTab.tryLoadTargetRecord(loadTarget,Record,cmp);
          // NEW: consolidated open via improved gridrow_nav (Github Issue #34)
          return Ext.ux.RapidApp.AppTab.gridrow_nav(cmp,Record);
				}
      // New: added tiny delay to prevent race condition (Github Issue #34)
      // Now that we're calling gridrow_nav which now does a REST nav (hashpath)
      // we need to add a delay to prevent a race condition when the add form
      // is in a tab, because it closes after successful create (exactly the same
      // event as this listener) which triggers a hashnav event (by AppTab).
      // Without the delay, the AppTab change of window.location.hash beats the
      // gridrow_nav one, which makes it appear as though it never happened at all
      // (the browser doesn't even see the hash 'change' event). 
      // TODO: I *think* that adding any delay here solves the problem, even if systems
      // are slow/bogged down, but I am not 100% sure...
			},cmp.store,{ delay: 10 });
		}
		
		// -- Display a page-wide mask during save
		if(this.store_write_mask) {
			var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Saving Changes..."});
			var show_mask = function() { myMask.show(); }
			var hide_mask = function() { myMask.hide(); }
			
			cmp.store.on('beforewrite',show_mask,this);
			cmp.store.on('write',hide_mask,this);
			cmp.store.on('exception',hide_mask,this);
		}
		// --
		
		
		// --- Cache the last total count, and supply it back to the server. If the
		// server module supports cache_total_count it will return the cached total back
		// instead of calculating it, increasing performance. When changing pages, sorts, 
		// or other options that don't change the number of rows in the set, there is no
		// reason to calculate the total count over and over
		if(cmp.cache_total_count) {
			// Changes in any request params between requests will clear the cached total 
			// count except for these params:
			var excl_params = [
				'cached_total_count',
				'columns',
				'start',
				'limit',
				'sort',
				'dir',
				'column_summaries'
			];
		
			var get_params_str = function(params) {
				var params = params || {};
				var p = Ext.apply({},params);
				for (i in excl_params) { delete p[excl_params[i]]; }
				
				// Going through this just to make sure we don't get thrown off by the same
				// values but in different orders:
				var keys = [],flat = [];
				for (k in p) { keys.push(k); }
				keys.sort();
				var len = keys.length;
				for (i = 0; i < len; i++) { flat.push(keys[i],p[keys[i]]); }
				return flat.join(',');
			};
			
			// Task to clear the cache:
			cmp.store.clearCachedTotalTask = new Ext.util.DelayedTask(function(){
				if(this.cached_total_count) {
					delete this.cached_total_count;
				}
			},cmp.store);
			
			cmp.store.on('load',function(store) {
				delete store.cached_total_count;
				if(store.reader && store.reader.jsonData) {
					store.cached_total_count = store.reader.jsonData.results;
					store.cached_total_count_params = {};
					Ext.apply(store.cached_total_count_params,store.baseParams);
					Ext.apply(store.cached_total_count_params,store.lastOptions.params);
				}
				// Start a timer to clear the cache after 1 minute of inactivity (loads):
				store.clearCachedTotalTask.delay(60000);
			},this);
			
			
			// Wraping in an afterrender to try to make sure this is the last 'beforeload'
			// handler so we can see any changes made by other components that also hook
			// beforeload, such as MultiFilters. Note: Still seem to have to set all 3 of
			// options.params, store.baseParams, and store.lastOptions.params to be safe...
			cmp.on('afterrender',function(){

				cmp.store.on('beforeload',function(store,options) {
					var next_opts = {};
					Ext.apply(next_opts,store.baseParams || {});
					Ext.apply(next_opts,store.lastOptions.params || {});
					Ext.apply(next_opts,options.params);
					var cur = get_params_str(next_opts);

					if(store.baseParams) {
						delete store.baseParams.cached_total_count;
					}
					
					if(store.lastOptions && store.lastOptions.params) {
						delete store.lastOptions.params.cached_total_count;
					}
					
					if(options && options.params) {
						delete options.params.cached_total_count;
					}
					
					if(store.cached_total_count) {
						store.cached_total_count_params = store.cached_total_count_params || {};
						var prev = get_params_str(store.cached_total_count_params);
						store.cached_total_count_params = next_opts;

						if(prev == cur) {
							options.params.cached_total_count = store.cached_total_count;
							
							if(store.lastOptions && store.lastOptions.params) {
								store.lastOptions.params.cached_total_count = store.cached_total_count;
							}
							
							if(store.baseParams) {
								store.baseParams.cached_total_count = store.cached_total_count;
							}
						}
					}
					return true;
				},this);
			},this);
		}
		// ---
		
	},
	
	store_add_initData: {},
	close_unsaved_confirm: true,
	show_store_button_text: false,
	store_buttons: [ 'add', 'edit', 'delete', 'reload', 'save', 'undo' ],
	store_button_cnf: {},
	store_exclude_buttons: [],
	exclude_btn_map: {},
	use_edit_form: false,
	use_add_form: false,
	add_form_url_params: {},
	add_form_window_cnf: {},
	autoload_added_record: false,
	add_records_first: false,
	store_exclude_api: [],
	store_write_mask: true,
	confirm_on_destroy: true,
		
	initAdditionalStoreMethods: function(store,plugin) {
		
		Ext.each(plugin.store_exclude_api,function(item){
			if(store.api[item]) { delete store.api[item]; }
		});
		
		store.on('beforewrite',function(ds,action,records,options,arg) {
			if(action == 'create'){
				var colnames = [];
				store.fields.each(function(field){ colnames.push(field.name); });
				options.params.create_columns = Ext.encode(colnames);
			}
			
			
			// -- Invalidate the total cache on write operations:
			delete store.cached_total_count;
			if(store.baseParams) {
				delete store.baseParams.cached_total_count;
			}
			if(store.lastOptions && store.lastOptions.params) {
				delete store.lastOptions.params.cached_total_count;
			}
			// --
			
		});
		
		store.addEvents('beforeremove');
		store.removeOrig = store.remove;
		store.remove = function(record) {
			if(store.fireEvent('beforeremove',store,record) !== false) {
				return store.removeOrig.apply(store,arguments);
			}
			return -1;
		};
		
		store.getColumnConfig = function(name) {
			if(!store.columns_map){
				var map = {};
				Ext.each(store.columns,function(cnf){ map[cnf.name] = cnf; },this);
				store.columns_map = map;
			}
			return store.columns_map[name];
		};
    
    store.isEditableColumn = function(name) {
      return store.editable_columns_map && store.editable_columns_map[name] ? true : false;
    };
		
		// ----
		// New: track 'loaded_columns' from the server (see metaData in DataStore2)
		store.on('metachange',function(ds,meta){

			if(meta.loaded_columns){
        // New: track individual editable columns:
        store.editable_columns_map = {};
				var loaded_map = {}, edit_count = 0;
				Ext.each(meta.loaded_columns,function(f){
					loaded_map[f] = true; 
					if(store.api.update) {
						var column = store.getColumnConfig(f);
						if(!column){ return; }
						var editable = (column.editor && !column.no_column);
						if(typeof column.allow_edit != 'undefined' && !column.allow_edit) {
							editable = false;
						}
						if(editable || column.allow_edit || column.allow_batchedit) { 
              edit_count++;
              store.editable_columns_map[f] = true;
            }
					}
				},this);
				store.loaded_columns_map = loaded_map;
				// We're tracking the count of loaded and editable fields, which can change from
				// request to request, so we can disable the edit button when that number is 0
				store.editable_fields_count = edit_count;
			}
		},this);
		
		store.hasLoadedColumn = function(name) {
			var map = store.loaded_columns_map || {};
			return map[name];
		};
		store.editableFieldsCount = function() {
			return (store.editable_fields_count || 0);
		};
		// ----
		
		store.getPhantomRecords = function() {
			var records = [];
			store.each(function(Record){
				if(Record.phantom) { records.push(Record); } 
			});
			return records;
		};
		
		store.hasPhantomRecords = function() {
			if(store.getPhantomRecords().length > 0) { return true; }
			return false;
		};
		
		store.addNotAllowed = function() {
			return store.hasPhantomRecords();
		},
		
		store.getNonPhantomModifiedRecords = function() {
			var records = [];
			Ext.each(store.getModifiedRecords(),function(Record){
				if(!Record.phantom) { records.push(Record); } 
			});
			return records;
		};
		
		store.hasPendingChanges = function() {
			if(store.getModifiedRecords().length > 0 || store.removed.length > 0) { 
				return true; 
			}
			return false;
		};
		
		store.getParentStore = function() {
			var parent = plugin.cmp.findParentBy(function(p) {
				if(p.store && p.store.getParentStore) { return true; }
				return false;
			});
			if(parent) { return parent.store; }
			return null;
		};
		
		store.eachTiedChild = function(fn) {
			Ext.iterate(store.tiedChildStores,function(id,str) {
				fn(str);
			});
		};
		
		store.hasAnyPendingChanges = function() {
			var pend = false;
			// If the store has no update or destroy api, it can't have any pending changes
			if(!store.api.update && !store.api.destroy) { return false; }
			store.eachTiedChild(function(s) {
				if(s.hasPendingChanges()) { pend = true; }
			});
			return pend;
		};
		
		store.saveAll = function() {
			store.eachTiedChild(function(s) {
				if(s.hasPendingChanges()) { s.save.call(s); }
			});
		};
		
		store.reloadAll = function() {
			store.eachTiedChild(function(s) { s.reload.call(s); });
		};
		
		store.undoChangesAll = function() {
			store.eachTiedChild(function(s) { 
				if(s.hasPendingChanges()) { s.undoChanges.call(s); }
			});
		};
		
		store.undoChanges = function() {
			var store = this;
			Ext.each(store.getPhantomRecords(),function(Rec){ store.remove(Rec); });
			store.rejectChanges();
			store.fireEvent('buttontoggle',store);
		};
		store.on('beforeload',store.undoChanges,store);
		
		store.getLastRecord = function() {
			var count = store.getCount();
			if(!count) { return null; }
			var index = count - 1;
			return store.getAt(index);
		};
		
		
		
		
		// -- Add Functions -- //
		store.prepareNewRecord = function(initData) {
			return new store.recordType(
				Ext.apply({},initData || plugin.store_add_initData)
			);
		};
		
		store.addRecord = function(initData) {
			var newRec = store.prepareNewRecord(initData);
			var ret;
			if(plugin.add_records_first) {
				ret = store.insert(0,newRec);
			}
			else {
				ret = store.add(newRec);
			}
			if(plugin.persist_immediately.create) { store.saveIfPersist(); }
			return ret;
		};
		
		store.addRecordForm = function(initData) {
			if(plugin.use_add_form == 'tab') {
				return store.addRecordFormTab(initData);
			}
			else {
				return store.addRecordFormWindow(initData);
			}
		};
		
		store.addRecordFormWindow = function(initData) {
			var newRec = store.prepareNewRecord(initData);
			
			var win;
			var close_handler = function(btn) { win.close(); };
			
			plugin.getAddFormPanel(newRec,close_handler,function(formpanel){
			
				var title;
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
					title = plugin.store_button_cnf.add.text;
				}
				else {
					title = 'Add Record'
				}
				if(formpanel.title) { title = formpanel.title; }
				var height = formpanel.height || 500;
				var width = formpanel.width || 700;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				
				var win_cfg = Ext.apply({
					title: title,
					layout: 'fit',
					width: width,
					height: height,
					closable: true,
					modal: true,
					items: formpanel
				},plugin.add_form_window_cnf);
				
				if(Ext.isFunction(plugin.cmp.add_form_onPrepare)) {
					plugin.cmp.add_form_onPrepare(win_cfg);
				}
				
				win = new Ext.Window(win_cfg);
				return win.show();
			});
		};
		
		store.addRecordFormTab = function(initData) {
			var loadTarget = Ext.getCmp('main-load-target');
			
			// Fall back to Window if the load target can't be found for a Tab:
			if(!loadTarget) { return store.addRecordFormWindow(initData); }
			
			var newRec = store.prepareNewRecord(initData);
			
			var tab;
			var close_handler = function(btn) { loadTarget.remove(tab); };
			
			plugin.getAddFormPanel(newRec,close_handler,function(formpanel){

				var title, iconCls;
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.text) {
					title = plugin.store_button_cnf.add.text;
				}
				else {
					title = 'Add Record'
				}
				
				if(plugin.store_button_cnf.add && plugin.store_button_cnf.add.iconCls) {
					iconCls = plugin.store_button_cnf.add.iconCls;
				}
				
				title = formpanel.title || title;
				iconCls = formpanel.iconCls || iconCls;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				delete formpanel.iconCls;
				
				var tab_cfg = {
					title: title,
					iconCls: iconCls,
					layout: 'fit',
					closable: true,
					items: formpanel
				};
				
				if(Ext.isFunction(plugin.cmp.add_form_onPrepare)) {
					plugin.cmp.add_form_onPrepare(tab_cfg);
				}
				
				tab = loadTarget.add(tab_cfg);
				loadTarget.activate(tab);
			});
		};
		// -- -- //
		
		
		
		// -- Edit Functions -- //
		// edit is only allowed if 1 record is selected, or there is only 1 record
		store.editNotAllowed = function() {
			//if(!store.use_edit_form) { return true; }
			var count;
			if(plugin.cmp.getSelectionModel) {
				var sm = plugin.cmp.getSelectionModel();
				count = sm.getCount();
			}
			else {
				count = store.getCount();
			}
			if(!store.editableFieldsCount()){ return true; }
			return (count != 1);
		},
		
		// Gets the record that should be the target of an edit operation. If the
		// component has getSelectedRecords (like a grid or dataview) it is used, 
		// otherwise, the first record of the store is returned
		store.getRecordForEdit = function() {
			if(store.editNotAllowed()) { return null; }
			if(plugin.cmp.getSelectedRecords) {
				var records = plugin.cmp.getSelectedRecords() || [];
				return records[0];
			}
			if(store.getCount() == 1){
				return store.getAt(0);
			}
			return null;
		};
		
		
		store.editRecordForm = function(Rec) {
			Rec = Rec || store.getRecordForEdit();
			if(!Rec) { return; }
			if(plugin.use_edit_form == 'tab') {
				return store.editRecordFormTab(Rec);
			}
			else {
				return store.editRecordFormWindow(Rec);
			}
		};
		
		store.editRecordFormWindow = function(Rec) {
			
			var win;
			var close_handler = function(btn) { win.close(); };
			
			plugin.getEditFormPanel(Rec,close_handler,function(formpanel){
			
				var title;
				if(plugin.store_button_cnf.edit && plugin.store_button_cnf.edit.text) {
					title = plugin.store_button_cnf.edit.text;
				}
				else {
					title = 'Edit Record';
				}
				if(formpanel.title) { title = formpanel.title; }
				var height = formpanel.height || 500;
				var width = formpanel.width || 700;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				
				var win_cfg = Ext.apply({
					title: title,
					layout: 'fit',
					width: width,
					height: height,
					closable: true,
					modal: true,
					items: formpanel
				},plugin.add_form_window_cnf); //<-- use same custom config from add
				
				if(Ext.isFunction(plugin.cmp.edit_form_onPrepare)) {
					plugin.cmp.edit_form_onPrepare(win_cfg);
				}
				
				win = new Ext.Window(win_cfg);
				return win.show();
			});
		};
		
		store.editRecordFormTab = function(Rec) {
			var loadTarget = Ext.getCmp('main-load-target');
			
			// Fall back to Window if the load target can't be found for a Tab:
			if(!loadTarget) { return store.editRecordFormWindow(Rec); }
			
			var tab;
			var close_handler = function(btn) { loadTarget.remove(tab); };
			
			plugin.getEditFormPanel(Rec,close_handler,function(formpanel){

				var title, iconCls;
				if(plugin.store_button_cnf.edit && plugin.store_button_cnf.edit.text) {
					title = plugin.store_button_cnf.edit.text;
				}
				else {
					title = 'Edit Record'
				}
				
				if(plugin.store_button_cnf.edit && plugin.store_button_cnf.edit.iconCls) {
					iconCls = plugin.store_button_cnf.edit.iconCls;
				}
				
				title = formpanel.title || title;
				iconCls = formpanel.iconCls || iconCls;
				
				delete formpanel.height;
				delete formpanel.width;
				delete formpanel.title;
				delete formpanel.iconCls;
				
				var tab_cfg = {
					title: title,
					iconCls: iconCls,
					layout: 'fit',
					closable: true,
					items: formpanel
				};
				
				if(Ext.isFunction(plugin.cmp.edit_form_onPrepare)) {
					plugin.cmp.edit_form_onPrepare(tab_cfg);
				}
				
				tab = loadTarget.add(tab_cfg);
				loadTarget.activate(tab);
			});
		};
		// -- -- //
		
		
		
		
		store.removeRecord = function(Record) {
			var ret = store.removeOrig(Record);
			if(plugin.persist_immediately.destroy) { store.saveIfPersist(); }
			return ret;
		};
		
		store.doTransactionIfPersist = function(action) {
			if(!plugin.persist_immediately[action]) { return; }
			return store.doTransactionOrig.apply(store,arguments);
		};
		
		store.saveIfPersist = function() {
			if(!store.doTransactionOrig) {
				store.doTransactionOrig = store.doTransaction;
			}
			store.doTransaction = store.doTransactionIfPersist;
			var ret = store.save.apply(store,arguments);
			store.doTransaction = store.doTransactionOrig;
			return ret;
		};
		
		store.addEvents('buttontoggle');
		store.fireButtonToggleEvent = function(){
			store.fireEvent('buttontoggle',store);
		}
		store.on('load',store.fireButtonToggleEvent,store);
		store.on('read',store.fireButtonToggleEvent,store);
		store.on('write',store.fireButtonToggleEvent,store);
		store.on('datachanged',store.fireButtonToggleEvent,store);
		store.on('clear',store.fireButtonToggleEvent,store);
		store.on('update',store.fireButtonToggleEvent,store);
		store.on('remove',store.fireButtonToggleEvent,store);
		store.on('add',store.fireButtonToggleEvent,store);
		
		// ------
		// NEW: Manually update record.id after an update if the idProperty (typically '___record_pk'
		// in RapidApp) has changed. This is needed to be able to edit the primary column, save it,
		// and then edit the record again. If the record's id isn't updated, the subsequent update
		// will fail because the lookup (DbicLink2) will use the old value, which it won't find anymore
		// This code not only updates the record, but updates its entry in the store (MixedCollection)
		// with the new id/key so that 'getById' and other functions will still operate correctly.
		store.on('write',function(ds,action,result,res,rs){
			if(action != 'update') { return; }
			Ext.each(res.raw.rows,function(row){
				// See update_records in DbicLink2 for where the new key is stored. So this code only
				// fires when working with DbicLink2 on the backend and the pk has changed, otherwise
				// this has no effect
				var idPropertyNew = ds.idProperty + '_new';
				var new_pk = row[idPropertyNew];
				if(!new_pk) { return; }
				
				var ndx = ds.data.indexOfKey(row[ds.idProperty]);
				var record = ds.data.itemAt(ndx);
				if(!record) { return; }
				record.data[ds.idProperty] = new_pk;
				record.id = new_pk;
				
				ds.data.removeAt(ndx);
				ds.data.insert(ndx,record.id,record);
				
			},this);
		},store);
		// ------
		
		
		store.addTrackedToggleFunc = function(func) {
			store.on('buttontoggle',func,store);
		};
		//store.on('buttontoggle',function(){ console.log('buttontoggle'); });
		
		store.buttonConstructor = function(cnf,showtext) {
			if(cnf.text && !cnf.tooltip) {
				cnf.tooltip = cnf.text;
				delete cnf.text;
			}
			
			if (showtext && !cnf.text) {
				cnf.text = cnf.tooltip;
				cnf.tooltip = null;
			}
			
			if (!showtext && cnf.text) {
				delete cnf.text;
			}
      
      // Added for Github Issue #21 - set the overflow text to
      // match the tooltip when showtext (for the button) is false
      if(!showtext && cnf.tooltip) {
        cnf.overflowText = cnf.tooltip;
      }
			
			return new Ext.Button(cnf);
		};
		
		store.allSaveCompleted = function() {
			var completed = true;
			store.eachTiedChild(function(s) {
				if(s.save_inprogress) { completed = false; }
			});
			return completed;
		};
		
		store.fireIfSaveAll = function() {
			if(store.allSaveCompleted()) { 
				store.fireEvent('saveall');
				var pstore = store.getParentStore();
				if(pstore) {
					pstore.fireIfSaveAll();
				}
			}
		};
		
		
		// -- This function purges out a list of param names from lastOptions 
		// and baseParams. This is still a major problem with the way stores
		// and various plugins operate:
		store.purgeParams = function(names) {
			Ext.each(names,function(name){
				if(store.baseParams[name]) { 
					delete store.baseParams[name]; 
				}
				if(store.lastOptions && store.lastOptions.params) {
					if(store.lastOptions.params[name]) { 
						delete store.lastOptions.params[name]; 
					}
				}
			},this);
		};
		// --
		
		store.addEvents('saveall');
		store.on('beforesave',function(ds,data) {
			store.save_inprogress = true; 
			
			// ------------------------------------
			// vv ----- CONFIRM ON DESTROY ----- vv
			if(data && data.destroy && data.destroy.length > 0 && plugin.cmp.confirm_on_destroy) {
				if(store.destroy_confirmed) {
					store.destroy_confirmed = false;
				}
				else {
					Ext.Msg.show({
						title: 'Confirm Delete?',
						msg: '<b>Are you sure you want to delete <span style="color:red;">' + 
							data.destroy.length + '</span> items?</b>',
						icon: Ext.Msg.WARNING,
						buttons: { yes: 'Yes', no: 'No' }, 
						fn: function(sel) {
							if (sel == 'yes') {
								this.destroy_confirmed = true;
								return this.saveAll();
							}
							else {
								this.destroy_confirmed = false; //<-- redundant, added for extra safety
								return this.undoChangesAll();
							}
						},
						scope: store
					});
					
					store.save_inprogress = false;
					return false;
				}
			}
			store.destroy_confirmed = false; //<-- clear one more time for good measure
			// ^^ ------------------------------ ^^
			// ------------------------------------
			
		});
		this.cmp.on('afterrender',function(){
			store.eachTiedChild(function(s) {
				s.on('save',function() {
					s.save_inprogress = false;
					store.fireIfSaveAll();
				});
			});
		});
		
    // Removed this exception hook because it is redundant and can cause
    // problems when rolling back certain changes. The store already fully
    // handles reverting itself when a save/persist operation fails.
    // Fixes Github Issue #11
    //store.on('exception',store.undoChanges,store);
    store.on('exception',function(ds,res,action){
      // NEW/UPDATE from #11 change above:
      // it turns out the undoChanges call wasn't so redundant after all, and
      // removing it caused the regression described in GitHub Issue #32.
      // The store *does* automatically roll itself back for update/delete,
      // but not for 'create' so now we call it specifically for that case.
      // This fixes #32, and keeps #11 fixed.
      if(action == 'create') {
        store.undoChanges.call(store);
      }
    },store);
	},
	
	// Only applies to Editor Grids implementing the 'beforeedit' event
	beforeCellEdit: function(e) {
		var column = e.grid.getColumnModel().getColumnById(e.column);
		if(!column) { return; }
		
		// Adding a new record (phantom):
		if(e.record.phantom) {
			// Prevent editing if allow_add is set to false:
			if(typeof column.allow_add !== "undefined" && !column.allow_add) {
				e.cancel = true; //<-- redundant with return false but set for good measure
				return false;
			}
		}
		// Editing an existing record:
		else {
			// Prevent editing if allow_edit is set to false:
			if(typeof column.allow_edit !== "undefined" && !column.allow_edit) {
				e.cancel = true; //<-- redundant with return false but set for good measure
				return false;
			}
		}
		
	},
	
	getStoreButton: function(name,showtext) {
		
		if(this.exclude_btn_map[name]) { return; }
		
		if(!this.cmp.loadedStoreButtons[name]) {
			var constructor = this.getStoreButtonConstructors.call(this)[name];
			if(! constructor) { return; }
			
			var cnf = this.store_button_cnf[name] || {};
				
			if(cnf.text && !cnf.tooltip) { cnf.tooltip = cnf.text; }
			if(typeof cnf.showtext != "undefined") { showtext = cnf.showtext; }
			
			var btn = constructor(cnf,this.cmp,showtext);
			if(!btn) { return; }
			
			this.cmp.loadedStoreButtons[name] = btn;
			
			// --------------------------------------------------
			// --- Keyboard shortcut handling:
			var keyMapConfigs = {
				'save': {
					ctrl: true,
					key: 's'
				},
				'undo': {
					ctrl: true,
					key: 'z'
				},
				'delete': {
					key: Ext.EventObject.DELETE
				}
			};
			
			this.storeBtnKeyMaps = this.storeBtnKeyMaps || {};
			
			if(keyMapConfigs[name]) {
				this.storeBtnKeyMaps[name] = new Ext.KeyMap(Ext.getBody(),Ext.apply({
					fn: function(k,e){
					
						// -- New: skip DELETE (46) if the event target is within a form field:
						if(k == 46 && e.target && typeof e.target.form != 'undefined') {
							return;
						}
						// --
					
						var El = this.cmp.getEl();
						var pos = El.getXY();
						
						// Method to know if our component element is *really* visible
						// and only handle the key event if it is
						var element = document.elementFromPoint(pos[0],pos[1]);
						
						if(El.isVisible() && El.contains(element)){
							e.stopEvent();
							btn.handler.call(this,btn);
						}
					},
					scope: this
				},keyMapConfigs[name]));
				
				this.cmp.on('beforedestroy',function(){
					this.storeBtnKeyMaps[name].disable.call(this.storeBtnKeyMaps[name]);
					delete this.storeBtnKeyMaps[name];
				},this);
			}
			// ---
			// --------------------------------------------------
			
		}

		return this.cmp.loadedStoreButtons[name];
	},
	
	getStoreButtonConstructors: function() {
		var plugin = this;
		return {
			add: function(cnf,cmp,showtext) {
				
				if(!cmp.store.api.create) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Add',
					iconCls: 'ra-icon-add',
					handler: function(btn) {
						var store = cmp.store;
						if(store.proxy.getConnection().isLoading()) { return; }
						if(cmp.use_add_form) {
							store.addRecordForm();
						}
						else {
							store.addRecord();
						}
					}
				},cnf || {}),showtext);
					
				cmp.store.addTrackedToggleFunc(function(store) {
					if (store.addNotAllowed()) {
						btn.setDisabled(true);
					}
					else {
						btn.setDisabled(false);
					}
				});
					
				return btn;
			},
			
			edit: function(cnf,cmp,showtext) {
				
				if(!cmp.store.api.update) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Edit',
					iconCls: 'ra-icon-application-form-edit',
					handler: function(btn) {
						var store = cmp.store;
						if(store.proxy.getConnection().isLoading()) { return; }
						store.editRecordForm();
					}
				},cnf || {}),showtext);
					
				cmp.store.addTrackedToggleFunc(function(store) {
					btn.setDisabled(store.editNotAllowed());
				});
				
				cmp.on('afterrender',function() {
					var store = this.store;
					var toggleBtn = function() {
						btn.setDisabled(store.editNotAllowed());
					};
					this.on('selectionchange',toggleBtn,this);
				},cmp);
					
				return btn;
			},
			
			'delete': function(cnf,cmp,showtext) {
				
				if(!cmp.store.api.destroy) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Delete',
					iconCls: 'ra-icon-delete',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						if(store.proxy.getConnection().isLoading()) { return; }
						//store.remove(cmp.getSelectionModel().getSelections());
						store.removeRecord(cmp.getSelectedRecords());
						//store.saveIfPersist();
						//if(cmp.persist_immediately) { store.save(); }
					}
				},cnf || {}),showtext);
				
				cmp.on('afterrender',function() {
				
					var toggleBtn = function() {
						if (this.getSelectedRecords.call(this).length > 0) {
							btn.setDisabled(false);
						}
						else {
							btn.setDisabled(true);
						}
					};
					
					this.on('selectionchange',toggleBtn,this);
				},cmp);
					
				return btn;
			},
			
      // Note: this is *not* the refresh button in the grid toolbar/pager because
      // it already provides its own
			reload: function(cnf,cmp,showtext) {
				
				return cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Reload',
					iconCls: 'x-tbar-loading',
					handler: function(btn) {
						var store = cmp.store;
						store.reloadAll();
					}
				},cnf || {}),showtext);
			},
			
			save: function(cnf,cmp,showtext) {

				if(cmp.persist_all_immediately) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Save',
					iconCls: 'ra-icon-save-ok',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						//store.save();
						store.saveAll();
					}
				},cnf || {}),showtext);
					
				var title_parent = cmp.findParentBy(function(c){
					return (c.title && c.setTitle)  ? true : false;
				},this);

				var modified_suffix = '&nbsp;<span class="ra-tab-dirty-flag">*</span>';

				cmp.cascade(function(){
					if(!this.store || !this.store.addTrackedToggleFunc){ return; }
					this.store.addTrackedToggleFunc(function(store) {
						var has_changes = cmp.store.hasAnyPendingChanges();
						btn.setDisabled(!has_changes);
						
						// ---- Add/remove '*' suffix from the title based on the saved/unsaved status:
						if(!title_parent) { return; }
						if(has_changes) {
							if(!title_parent.notUnsavedTitle) {
								title_parent.notUnsavedTitle = title_parent.title;
								title_parent.setTitle(title_parent.notUnsavedTitle + modified_suffix);
							}
						}
						else {
							if(title_parent.notUnsavedTitle) {
								title_parent.setTitle(title_parent.notUnsavedTitle);
								delete title_parent.notUnsavedTitle;
							}
						}
						// ----
					});
				});
				
				return btn;
			},
			
			undo: function(cnf,cmp,showtext) {

				if(cmp.persist_all_immediately) { return false; }
				
				var btn = cmp.store.buttonConstructor(Ext.apply({
					tooltip: 'Undo',
					iconCls: 'ra-icon-arrow-undo',
					disabled: true,
					handler: function(btn) {
						var store = cmp.store;
						//store.undoChanges.call(store);
						store.undoChangesAll.call(store);
					}
				},cnf || {}),showtext);
				
					
				cmp.cascade(function(){
					if(!this.store || !this.store.addTrackedToggleFunc){ return; }
					this.store.addTrackedToggleFunc(function(store) {
						if (cmp.store.hasAnyPendingChanges()) {
							btn.setDisabled(false);
						}
						else {
							btn.setDisabled(true);
						}
					});
				});
					
				/*
				cmp.store.addTrackedToggleFunc(function(store) {
					if (store.hasPendingChanges()) {
						btn.setDisabled(false);
					}
					else {
						btn.setDisabled(true);
					}
				});
				*/
					
				return btn;
			}
		};
	},
	
	insertStoreButtonsBbar: function() {
		var index = 0;
		var skip_reload = false;
		var bbar;

		if(Ext.isFunction(this.cmp.getBottomToolbar)) { 
			bbar = this.cmp.getBottomToolbar();
		}
		else if (Ext.isFunction(this.cmp.ownerCt.getBottomToolbar)) {
			bbar = this.cmp.ownerCt.getBottomToolbar();
		}
		
		if(!bbar) { return; }
		
		bbar.items.each(function(cmp,indx) {
			if(cmp.tooltip == 'Refresh') { 
				index = indx + 1; 
				skip_reload = true;
			};
		});
		
		//console.dir(bbar);
		
		var showtext = false;
		if(this.show_store_button_text) { showtext = true; }
		
		var bbar_items = [];
		Ext.each(this.store_buttons,function(btn_name) {
			// Skip redundant reload if we have a paging toolbar
			if(btn_name == 'reload' && skip_reload) { return; }
			
			var btn = this.getStoreButton(btn_name,showtext);
			if(!btn) { return; }
			bbar_items.unshift(btn);
		},this);
		Ext.each(bbar_items,function(btn) { bbar.insert(index,btn); },this);
		
	},
	
	insertStoreButtonsTbar: function() {
		var tbar;

		if(Ext.isFunction(this.cmp.getTopToolbar)) { 
			tbar = this.cmp.getTopToolbar();
		}
		else if (Ext.isFunction(this.cmp.ownerCt.getTopToolbar)) {
			tbar = this.cmp.ownerCt.getTopToolbar();
		}
		
		if(!tbar) { return; }
		
		var showtext = false;
		if(this.show_store_button_text) { showtext = true; }
		
		var tbar_items = [ '->' ]; //<-- right-align buttons
		Ext.each(this.store_buttons,function(btn_name) {
			var btn = this.getStoreButton(btn_name,showtext);
			if(!btn) { return; }
			tbar_items.unshift(btn);
		},this);
		Ext.each(tbar_items,function(btn) { tbar.insert(0,btn); },this);
		
	},
	
	beforeRemoveConfirm: function(c,component) {
		if(component != this.cmp) {
			var parent = this.cmp.findParentBy(function(p) {
				if(p.confirmRemoveInProg) { return false; }
				
				if(p == component) { return true; }
				// if we're here, it's a sibling removal:
				return false;
			},this);
			// This is a sibling removal, or our tied parent already handled the remove, which we need to ignore:
			if(component != parent) { return true; }
		}
		
		component.confirmRemoveInProg = true;
		
		var store = this.cmp.store;
		if(!store || !store.hasAnyPendingChanges()) { 
			c.un('beforeremove',this.beforeRemoveConfirm,this);
			return true; 
		}
		
		Ext.Msg.show({
			title: 'Save Changes?',
			msg: (
				store.removed.length > 0 ?
					'<b>There are unsaved changes on this page, including <span style="color:red;">' + 
						store.removed.length + '</span> items to be deleted.</b>' :
					'<b>There are unsaved changes on this page.</b>'
				) +
				'<br><br>Save before closing?<br>',
			icon: Ext.Msg.WARNING,
			buttons: { yes: 'Save', no: 'Discard Changes', cancel: 'Cancel' }, 
			fn: function(sel) {
				if (sel == 'cancel') {
					delete component.confirmRemoveInProg;
					return;
				}
				else if (sel == 'yes') {
					var onsave;
					onsave = function() {
						store.un('saveall',onsave);
						c.un('beforeremove',this.beforeRemoveConfirm,this);
						// Complete the original remove:
						c.remove(component);
					};
					store.on('saveall',onsave);
					// Prevent the confirm delete dialog from also being displayed:
					store.destroy_confirmed = true;
					store.saveAll();
				}
				else {
					store.undoChangesAll();
					c.un('beforeremove',this.beforeRemoveConfirm,this);
					// Complete the original remove:
					c.remove(component);
				};
			},
			scope: this
		});
		
		return false;
	},
	
	getAddFormPanel: function(newRec,close_handler,callback) {
		
		var plugin = this;
		var store = this.cmp.store;
		
		close_handler = close_handler || Ext.emptyFn;
		
		var cancel_handler = function(btn) {
			close_handler(btn);
		};
		
		var save_handler = function(btn) {
			var fp = btn.ownerCt.ownerCt, form = fp.getForm();
			
			// Disable the form panel to prevent user interaction during the save.
			// Tthere is also a global load mask set on updates, but it is possible 
			// that the form could be above it if this is a chained sequences of
			// created records, so this is an extra safety measure in that case:
			fp.setDisabled(true);
			
			// Re-enable the form panel if an exception occurs so the user can
			// try again. We don't need to do this on success because we close
			// the form/window:
			var fp_enable_handler = function(){ try{ fp.setDisabled(false); }catch(err){} }
			store.on('exception',fp_enable_handler,this);
			
			// Use a copy of the new record in case the save fails and we need to try again:
			var newRecord = newRec.copy();
			newRecord.phantom = true; //<-- the copy doesn't have this set like the original... why?
			
			form.updateRecord(newRecord);
			
			store.add(newRecord);
			
			if(plugin.persist_immediately.create) {
				
				var after_write_fn = Ext.emptyFn;
				var remove_handler = Ext.emptyFn;
				
				remove_handler = function() { 
					store.un('write',after_write_fn);
					// Remove ourselves as we are also a single-use handler:
					store.un('exception',remove_handler);
					// remove the enable handler:
					store.un('exception',fp_enable_handler);
				}
				
				after_write_fn = function(store,action) {
					if(action == 'create') {
						// Remove ourselves as we are a single-use handler:
						remove_handler();
						
						// close the add form only after successful create on the server:
						close_handler(btn);
					}
				}
				
				store.on('write',after_write_fn,store);
				
				// Also remove this single-use handler on exception:
				store.on('exception',remove_handler,store);
				
				store.saveIfPersist(); 
			}
			else {
				close_handler(btn);
			}
		};
		
		//var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Loading Form..."});
		var myMask = new Ext.LoadMask(plugin.cmp.getEl(), {msg:"Loading Add Form..."});
		var show_mask = function() { myMask.show(); }
		var hide_mask = function() { myMask.hide(); }
		
		var params = {};
		if(store.lastOptions.params) { Ext.apply(params,store.lastOptions.params); }
		if(store.baseParams) { Ext.apply(params,store.baseParams); }
		if(plugin.cmp.baseParams) { Ext.apply(params,plugin.cmp.baseParams); }
		Ext.apply(params,plugin.add_form_url_params);
		
		show_mask();
		Ext.Ajax.request({
			url: plugin.cmp.add_form_url,
			params: params,
			failure: hide_mask,
			success: function(response,options) {
				
				var formpanel = Ext.decode(response.responseText);
				
				Ext.each(formpanel.items,function(field) {
					// Important: autoDestroy must be false on the store or else store-driven
					// components (i.e. combos) will be broken as soon as the form is closed 
					// the first time
					if(field.store) { field.store.autoDestroy = false; }
          // Make sure that hidden fields that can't be changed don't 
          // block validation of the form if they are empty and erroneously
          // set with allowBlank: false (common-sense failsafe):
          if(field.hidden) { field.allowBlank = true; } 
				},this);
				
				Ext.each(formpanel.buttons,function(button) {
					if(button.name == 'save') {
						button.handler = save_handler;
					}
					else if(button.name == 'cancel') {
						button.handler = cancel_handler;
					}
				},this);
				
				formpanel.Record = newRec;
				
				hide_mask();
				callback(formpanel);
			},
			scope: this
		});
	},
	
	
	getEditFormPanel: function(Rec,close_handler,callback) {
		
		var plugin = this;
		var store = this.cmp.store;
		
		close_handler = close_handler || Ext.emptyFn;
		
		var cancel_handler = function(btn) {
			close_handler(btn);
		};
		
		var save_handler = function(btn) {
			var fp = btn.ownerCt.ownerCt, form = fp.getForm();
			
			// Disable the form panel to prevent user interaction during the save.
			// Tthere is also a global load mask set on updates, but it is possible 
			// that the form could be above it if this is a chained sequences of
			// created records, so this is an extra safety measure in that case:
			fp.setDisabled(true);
			
			// Re-enable the form panel if an exception occurs so the user can
			// try again. We don't need to do this on success because we close
			// the form/window:
			var fp_enable_handler = function(){ try{ fp.setDisabled(false); }catch(err){} }
			store.on('exception',fp_enable_handler,this);
			
			form.updateRecord(Rec);
			
			if(plugin.persist_immediately.update) {
				
				var after_write_fn = Ext.emptyFn;
				var remove_handler = Ext.emptyFn;
				
				remove_handler = function() { 
					store.un('write',after_write_fn);
					// Remove ourselves as we are also a single-use handler:
					store.un('exception',remove_handler);
					// remove the enable handler:
					store.un('exception',fp_enable_handler);
				}
				
				after_write_fn = function(store,action) {
					if(action == 'update') {
						// Remove ourselves as we are a single-use handler:
						remove_handler();
						
						// close the add form only after successful create on the server:
						close_handler(btn);
					}
				}
				
				store.on('write',after_write_fn,store);
				
				// Also remove this single-use handler on exception:
				store.on('exception',remove_handler,store);
				
				if(store.hasAnyPendingChanges()) {
					store.saveIfPersist();
				}
				else {
					// Cleanup if there are no changes, thus no write action will be
					// called. 
					remove_handler();
					close_handler(btn);
				}
			}
			else {
				close_handler(btn);
			}
		};
		
		//var myMask = new Ext.LoadMask(Ext.getBody(), {msg:"Loading Form..."});
		var myMask = new Ext.LoadMask(plugin.cmp.getEl(), {msg:"Loading Edit Form..."});
		var show_mask = function() { myMask.show(); }
		var hide_mask = function() { myMask.hide(); }
		
		var params = {};
		if(store.lastOptions.params) { Ext.apply(params,store.lastOptions.params); }
		if(store.baseParams) { Ext.apply(params,store.baseParams); }
		if(plugin.cmp.baseParams) { Ext.apply(params,plugin.cmp.baseParams); }
		Ext.apply(params,plugin.add_form_url_params);
		
		show_mask();
		Ext.Ajax.request({
			url: plugin.cmp.edit_form_url,
			params: params,
			failure: hide_mask,
			success: function(response,options) {

				var formpanel = Ext.decode(response.responseText);
				
				var new_items = [];
				Ext.each(formpanel.items,function(field) {
					// Don't try to edit fields that aren't loaded, exclude them from the form:
					if(!store.hasLoadedColumn(field.name)){ return; }
					// Important: autoDestroy must be false on the store or else store-driven
					// components (i.e. combos) will be broken as soon as the form is closed 
					// the first time
					if(field.store) { field.store.autoDestroy = false; }
          // Make sure that hidden fields that can't be changed don't 
          // block validation of the form if they are empty and erroneously
          // set with allowBlank: false (common-sense failsafe):
          if(field.hidden) { field.allowBlank = true; } 
					field.value = Rec.data[field.name];
					new_items.push(field);
				},this);
				formpanel.items = new_items;
				
				Ext.each(formpanel.buttons,function(button) {
					if(button.name == 'save') {
						button.handler = save_handler;
					}
					else if(button.name == 'cancel') {
						button.handler = cancel_handler;
					}
				},this);
				
				formpanel.Record = Rec;
				
				hide_mask();
				callback(formpanel);
			},
			scope: this
		});
	}
	// --- ^^ ---

});
Ext.preg('datastore-plus',Ext.ux.RapidApp.Plugin.CmpDataStorePlus);

