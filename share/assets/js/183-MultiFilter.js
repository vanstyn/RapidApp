

Ext.ns('Ext.ux.MultiFilter');


Ext.ux.MultiFilter.Plugin = Ext.extend(Ext.util.Observable,{

	init: function(grid) {
		this.grid = grid;
		grid.multifilter = this;
		
		grid.allow_edit_frozen = grid.allow_edit_frozen || false;
		
		this.store = grid.getStore();
		
		if(grid.init_state && grid.init_state.multifilters) {
			this.store.filterdata = grid.init_state.multifilters;
		}
		
		this.store.on('beforeload',function(store,options) {
			if(store.baseParams) {
				delete store.baseParams.multifilter;
			}
			if(store.lastOptions && store.lastOptions.params) { 
				delete store.lastOptions.params.multifilter;
			}
			if(store.filterdata || store.filterdata_frozen) {
				var multifilter = this.getMultiFilterParam();
				var multifilter_frozen = this.getMultiFilterParam(true);
				
				// Forcefully set both baseParams and lastOptions so make sure
				// no param caching is happening in the Ext.data.Store
				store.baseParams.multifilter = multifilter;
				store.lastOptions.params.multifilter = multifilter;
				store.baseParams.multifilter_frozen = multifilter_frozen;
				store.lastOptions.params.multifilter_frozen = multifilter_frozen;
				
				// this is required for very first load to see changes 
				// (not sure why this is needed beyond the above lines)
				Ext.apply(options.params, {
					multifilter: multifilter,
					multifilter_frozen: multifilter_frozen
				});
			}
			return true;
		},this);
		
		if (grid.rendered) {
			this.onRender();
		} else {
			grid.on({
				scope: this,
				single: true,
				render: this.onRender
			 });
		}
	},
	
	getMultiFilterParam: function(frozen) {
		var data = frozen ? this.store.filterdata_frozen : this.store.filterdata;
		data = data || [];
		return Ext.encode(data);
	},
	
	onRender: function() {
	
		var grid = this.grid;

		this.filtersBtn = new Ext.Button({
			text: 'Filters',
			handler: function(btn) {
				var win = grid.multifilter.showFilterWindow();
			},
			hidden: grid.hide_multifilter_button ? true: false
		});
		
		this.updateFilterBtn();
		
		var add_to_cmp = this.grid.getBottomToolbar() || this.grid.getTopToolbar();
		if(add_to_cmp && !grid.hide_filtersBtn) { 
			if(!this.filtersBtn.hidden){
				add_to_cmp.add('-');
			}
			add_to_cmp.add(this.filtersBtn);
		};
	},
	
	setFields: function() {
		var fields = [];
		
		//var columns = this.grid.getColumnModel().config;
		var columns = this.grid.initialConfig.columns;
		
		if(! this.grid.no_multifilter_fields) { this.grid.no_multifilter_fields = {}; }
		Ext.each(columns,function(column) {
			
			if(Ext.isObject(column.editor)) { column.rel_combo_field_cnf = column.editor; }
			if(column.rel_combo_field_cnf && column.rel_combo_field_cnf.store) { 
				column.rel_combo_field_cnf.store.autoDestroy = false; 
			}
			
			if (! this.grid.no_multifilter_fields[column.dataIndex] && ! column.no_multifilter) {
				fields.push(column.dataIndex);
			}
		},this);
		
		this.Criteria = Ext.extend(Ext.ux.MultiFilter.Criteria,{
			gridColumns: columns,
			fieldList: fields
		});
	},
	
	updateFilterBtn: function() {
		var text = 'Filters';
		var iconCls = 'ra-icon-funnel'; //<-- no filters
		var count = this.filterCount();
		var fcount = this.filterCount(true);
		if(count) {
			text = 'Filters (' + count + ')';
			iconCls = 'ra-icon-funnel-edit'; //<-- only normal filters
			if(fcount) { iconCls = 'ra-icon-funnel-new-edit'; } //<-- both normal + frozen
		}
		else if(fcount) {
			iconCls = 'ra-icon-funnel-new'; //<-- only frozen filters
		}
		
		this.filtersBtn.setIconClass(iconCls);
		this.filtersBtn.setText(text);
	},
	
	filterCount: function(frozen,cust) {
		
		var filterdata = frozen ? this.store.filterdata_frozen : this.store.filterdata;
		filterdata = cust ? cust : filterdata;
		
		var recurseCount = function(item) {
			if(Ext.isObject(item)) {
				if (item['-and']) { return recurseCount(item['-and']); }
				if (item['-or']) { return recurseCount(item['-or']); }
				return 1;
			}
			if(Ext.isArray(item)) {
				var count = 0;
				Ext.each(item,function(i) {
					count = count + recurseCount(i);
				});
				return count;
			}
			return 0;
		}
	
		if (!filterdata) { return 0; }
		return recurseCount(filterdata);
	},
	
	showFilterWindow: function() {
		
		this.setFields();
		
		var plugin = this,frozen_header,freeze_btn,hlabel;
		
		var update_selections = function(set){
			var count = 0,fcount = 0;
			if(set) {
				set.filterdata_frozen = set.filterdata_frozen || [];
				fcount = plugin.filterCount(true,set.filterdata_frozen);
				count = set.items.length - 1;
			}
			
			hlabel.setText(get_header_html(fcount),false);
			frozen_header.setVisible(fcount);
			
			if(freeze_btn) { freeze_btn.setDisabled(!count); }
		};

		var get_header_html = function(size){
			return '<img src="/assets/rapidapp/misc/static/images/simple_new.png" style="padding-bottom:3px;">&nbsp;&nbsp;' +
				size + '&nbsp; Frozen (hidden) Filter Conditions Applied';
		};
		
		var hbuttons = [
			hlabel = new Ext.form.Label({
				itemId: 'heading',
				html: get_header_html(0),
				style: 'color:gray;font-size:1.2em;font-weight:bold;'
			})
		];
		
		var button_Align = 'right'; //<-- default
		var buttons = [];
		
		if(this.grid.allow_edit_frozen) {
			buttons.push( freeze_btn = new Ext.Button({
				text: 'Freeze Conditions',
				iconCls: 'ra-icon-arrow-up',
				handler: function(btn) {
					var win = btn.ownerCt.ownerCt,
						set = win.getComponent('filSet'),
						store = btn.ownerCt.ownerCt.multifilter.store;
					
					set.filterdata_frozen = set.filterdata_frozen || [];
					set.filterdata_frozen = set.filterdata_frozen.concat(set.getData());
					
					set.items.each(function(item){
						if(item.isFilterItem){ set.remove(item); }
					},this);
					
					update_selections(set);
					
				}
			}),'->');
			
			button_Align = 'left';

			hbuttons.push({
				xtype: 'button',
				style: 'padding-left:5px;',
				text: 'Un-Freeze Conditions',
				iconCls: 'ra-icon-arrow-down',
				handler: function(btn) {
					var win = btn.ownerCt.ownerCt.ownerCt,
						set = win.getComponent('filSet');
					
					var curdata = set.getData() || [];
					set.items.each(function(item){
						if(item.isFilterItem){ set.remove(item); }
					},this);
					
					set.loadData(set.filterdata_frozen.concat(curdata));
					set.filterdata_frozen = [];
					
					update_selections(set);
				}
			});
		}
		
		
		buttons.push({
			xtype: 'button',
			text: 'Save and Close',
			iconCls: 'ra-icon-save-ok',
			handler: function(btn) {
				var win = btn.ownerCt.ownerCt;
				var set = win.getComponent('filSet');
				var store = btn.ownerCt.ownerCt.multifilter.store;
				
				store.filterdata = set.getData();
				store.filterdata_frozen = set.filterdata_frozen;
				
				win.multifilter.updateFilterBtn();
				
				win.close();
        
        // Added for Github Issue #20 (and copied from Quick Search code)
        // clear start (necessary if we have paging) - resets to page 1
        if(store.lastOptions && store.lastOptions.params) {
          store.lastOptions.params[store.paramNames.start] = 0;
        }
        
				store.reload();
			}
		},
		
		{
			xtype: 'button',
			text: 'Cancel',
			//iconCls: 'ra-icon-close',
			handler: function(btn) {
				btn.ownerCt.ownerCt.close();
			}
		});
		
		frozen_header = new Ext.Panel({
			frame: true,
			anchor: '-0',
			style: 'padding:2px;',
			buttonAlign: 'center',
			buttons: hbuttons
		});
		
    // -- NEW: Set the window size taking the active 
    // browser size into account
    var winWidth = 750;
    var winHeight = 500;
    //#This code is a bit funky, so instead we're now simply relying on the just added
    //#global Ext.Window override which prevents any window from being larger than the 
    //#available browser area:
    //var browserSize = Ext.getBody().getViewSize();
    //if (browserSize.width < winWidth) {
    //  winWidth = browserSize.width - 20;
    //}
    //if (browserSize.height < winHeight) {
    //  winHeight = browserSize.hight - 20;
    //}
    //if(winWidth < 300) { winWidth = 300 }
    //if(winHeight < 150) { winHeight = 150 }
    // --
    
		var win = new Ext.Window({
		
			//id: 'mywin',
			multifilter: this,
			title: 'MultiFilter',
			layout: 'anchor',
			width: winWidth,
			height: winHeight,
			closable: true,
			modal: true,
			
			autoScroll: true,
			items: [
				frozen_header,
				new Ext.ux.MultiFilter.FilterSetPanel({
					FilterParams: {
						criteriaClass: this.Criteria
					},
					cls: 'x-toolbar x-small-editor',
					anchor: '-0', 
					frame: true,
					itemId: 'filSet'
				})
			],
			buttons: buttons,
			buttonAlign: button_Align
		});
		
		win.show();
		
		var set = win.getComponent('filSet');
		set.loadData(this.store.filterdata || []);
		set.filterdata_frozen = this.store.filterdata_frozen || [];
		set.on('remove',update_selections.createDelegate(this,[set]),this);
		set.on('add',update_selections.createDelegate(this,[set]),this,{ buffer: 20 });

		update_selections(set);
		
		return win;
	}
});


Ext.ux.MultiFilter.StaticCombo = Ext.extend(Ext.form.ComboBox,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	value_list: false,
	valueField: 'valueField',
	displayField: 'displayField',
	initComponent: function() {
		if (this.value_list) {
			var data = [];
			Ext.each(this.value_list,function(item,index){
				data.push([index,item]);
			});
			//for (i in this.value_list) {
			//	data.push([i,this.value_list[i]]);
			//}
			//data.pop();
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField
				],
				data: data
			});
		}
		Ext.ux.MultiFilter.StaticCombo.superclass.initComponent.apply(this,arguments);
	}
});
Ext.reg('multifilter-sc', Ext.ux.MultiFilter.StaticCombo);


/*
Ext.ux.MultiFilter.defaultConditionMap = {

	'is'							: '=',
	'is equal to'				: '=',
	'equal to'					: '=',
	'is not equal to'			: '!=',
	'before'						: '<',
	'after'						: '>',
	'less than'				: '<',
	'greater than'			: '>',
	
	'contains'					: 'contains',
	'starts with'				: 'starts_with',
	'ends with'					: 'ends_with',
	"doesn't contain"			: 'not_contain',
	
	'null/empty status'  : 'null_empty',
	
	
	//'is null' : 'is_null',
	//'is empty' : 'is_empty',
	//'is null or empty': 'null_or_empty'

};
*/

// Moved condition remapping to the back end:
Ext.ux.MultiFilter.defaultConditionMap = {};

// This now needs to be simplified:
Ext.ux.MultiFilter.defaultTypeToConditionMap = {

	'default': {
		'is equal to'			: '=',
		'is not equal to'		: '!=',
		'contains'				: 'contains',
		"doesn't contain"		: 'not_contain',
		'starts with'			: 'starts_with',
		'ends with'				: 'ends_with',
		"doesn't start with"	: 'not_starts_with',
		"doesn't end with"	: 'not_ends_with',
		'less than'				: '<',
		'greater than'			: '>'
	},
	
  date: {
    'before'  : '<',
    'after'   : '>',
    'exactly' : '='
  },
	
  datetime: {
    'before'  : '<',
    'after'   : '>',
    'exactly' : '='
  },
	
	number: {
		'less than'				: '<',
		'greater than'			: '>',
		'equal to'				: '=',
		'not equal to'			: '!='
	},
	
	// bool is empty, leaving only 'is' in the dropdown, which
	// defaults to the editor, which in the case of bool should
	// allow the selection of the only possible values (0/1). No
	// other conditions make sense (>, <, etc)
	bool: {}

};


Ext.ux.MultiFilter.Criteria = Ext.extend(Ext.Container,{

	layout: 'hbox',
	
	autoEl: {},
	
	// Dummy default list of fields:
	fieldList: [ 'field1','field2','field3','field4' ],
	
	gridColumns: null,
	
	columnMap: {},
	
	fieldNameMap: {},
	reverseFieldNameMap: {},
	
	conditionMap: Ext.ux.MultiFilter.defaultConditionMap,
	
	typeCondMap: Ext.ux.MultiFilter.defaultTypeToConditionMap,
	
	// This is crap that I think shouldn't be required. 
	// Create an entire hidden version of the field_combo and add it
	// to the container just to get its Elelment so that Elelment
	// can be used to create an instance of TextMetrics just so that
	// we can accurately use it to measure text width:
	TM: function() {
		//var scope = this.constructor.prototype;
		var scope = this;
		if (!scope.TMinstance) {
			var cnf = {
				hidden: true,
				itemId: 'hidden_field_combo',
				name: 'hidden_field_combo'
			};
			Ext.applyIf(cnf,this.field_combo_cnf);
			
			scope.hiddenCombo = new Ext.ux.MultiFilter.StaticCombo(cnf);
			scope.add(scope.hiddenCombo);
			scope.doLayout();
			scope.TMinstance = Ext.util.TextMetrics.createInstance(scope.hiddenCombo.getEl());
		}
		return scope.TMinstance;
	},
	
	createFieldCombo: function() {
		var val_list = [];
		Ext.each(this.fieldList,function(item,index) {
			var val = item;
			if(this.reverseFieldNameMap[val]) {
				val = this.reverseFieldNameMap[val];
			}
			val_list.push(val);
		},this);
		Ext.apply(this.field_combo_cnf,{
			//value_list: this.fieldList
			value_list: val_list
		});
		
		this.field_combo_cnf.useMenuList = true;
		return Ext.ComponentMgr.create(this.field_combo_cnf,'static-combo');
		//return Ext.ComponentMgr.create(this.field_combo_cnf,'menu-field');
	},
	
	condType: 'default',
	
	createCondCombo: function() {
	
		var colCondCnf = this.typeCondMap[this.condType];
		if (!colCondCnf) { colCondCnf = this.typeCondMap['default']; }
		
		var value_list = [];
		// Ext.iterate instead of for(key in colCondCnf){...
		Ext.iterate(colCondCnf,function(key,value){
			value_list.push(key);
		});
		
		value_list.push('null/empty status');
		
		// Extra condition for use with rel_combo_field_cnf:
		value_list.push('is');
		
		Ext.apply(this.cond_combo_cnf,{
			value_list: value_list
		});
		//return new Ext.ux.MultiFilter.StaticCombo(this.cond_combo_cnf);
		return Ext.ComponentMgr.create(this.cond_combo_cnf,'static-combo');
	},
	
	createDataField: function () {
		
		var cnf = Ext.apply({},this.datafield_cnf);
		
		return Ext.ComponentMgr.create(cnf,'textfield');
	},
	
	getNullEmptyDfield: function () {
		
		var init_value = 'is null';// <-- default
		var value_list = [
			'is null', 
			'is empty', 
			'is null or empty',
			'is not null', 
			'is not empty', 
			'is not null or empty'
		];
		
		// Set to the current value ONLY if its one of the vals in the value_list
		var cur_value = this.datafield_cnf.value;
		Ext.each(value_list,function(val){
			if(cur_value == val) { init_value = cur_value; }
		},this);
		
		return {
			xtype: 'static-combo',
			value: init_value, 
			value_list: value_list
		};
	},
		
	initComponent: function() {
	
		this.reverseConditionMap = {};
		//for (i in this.conditionMap) {
		//	this.reverseConditionMap[this.conditionMap[i]] = i;
		//}
		Ext.iterate(this.conditionMap,function(key,val) {
			this.reverseConditionMap[val] = key;
		},this);
		
		this.initColumns();
		
		/* These are declared here instead of in the base class above because we 
		 * modify them later on, and we need to make sure they are attributes
		 * of the instance and not the class itself
		**/
		Ext.applyIf(this,{
			field_combo_cnf: {
				name: 'field_combo',
				itemId: 'field_combo',
				minListWidth: 200,
				width: 100,
				listeners: {
					// On select, set the value and call configSelector() to recreate the criteria container:
					select: function(combo) {
						var criteria = combo.ownerCt;
						var val = combo.getRawValue();
						Ext.apply(criteria.field_combo_cnf,{
							value: val
						});
						criteria.configSelector();
					}
				}
			},
			cond_combo_cnf: {
				name: 'cond_combo',
				itemId: 'cond_combo',
				width: 110,
				value_list: [],
				listeners: {
					select: function(combo) {
						var criteria = combo.ownerCt;
						var val = combo.getRawValue();
						
						if(val == criteria.last_cond_value) { return; }
						
						// clear the data field if we're switching from null/empty:
						if(criteria.last_cond_value == 'null/empty status') {
							delete criteria.datafield_cnf.value;
						}
						
						//if(val != 'is' && criteria.last_cond_value != 'is') { return; }
						
						Ext.apply(criteria.cond_combo_cnf,{
							value: val
						});
						
						// Set criteria.last_cond_value (used above and also in configSelector login below)
						Ext.apply(criteria,{
							last_cond_value: val
						});

						criteria.configSelector();
					}
				}
			},
			datafield_cnf: {
				xtype	: 'textfield',
				name	: 'datafield',
				itemId: 'datafield',
				flex	: 1
			}
		});
	
		this.items = this.createFieldCombo();

		Ext.ux.MultiFilter.Criteria.superclass.initComponent.call(this);
	},
	
	initColumns: function() {
		if (! this.gridColumns) { return; }
		
		this.columnMap = {};
		//for (var i = 0; i < this.gridColumns.length; i++) {
		//	var column = this.gridColumns[i];
		//	this.columnMap[column.name] = column;
		//}
		Ext.each(this.gridColumns,function(item,index) {
			var column = item;
			this.columnMap[column.name] = column;
			if (column.header) {
				this.fieldNameMap[column.header] = column.name;
			}
		},this);
		
		this.reverseFieldNameMap = {};
		Ext.iterate(this.fieldNameMap,function(key,val) {
			this.reverseFieldNameMap[val] = key;
		},this);
		
		return this.columnMap;
	},
	
	configSelector: function() {
		
		// reset condType to default:
		this.condType = 'default';
		
		var cust_dfield_cnf = null;
		
		if (this.field_combo_cnf.value) {
			var TM = this.TM();
			var width = 30 + TM.getWidth(this.field_combo_cnf.value);
			Ext.apply(this.field_combo_cnf,{
				width: width
			});
			
			var fval = this.field_combo_cnf.value;
			if(this.fieldNameMap[fval]) {
				fval = this.fieldNameMap[fval];
			}
			var column = this.columnMap[fval];
			// Get the type from the filter.type property of the column model:
			if (column && column.filter && column.filter.type) {
				this.condType = column.filter.type;
			}
			
			// new: column.filter.type above is no longer set since TableSpec stuff:
			if (column && column.multifilter_type) {
				this.condType = column.multifilter_type;
			}

			if (column && column.rel_combo_field_cnf && this.last_cond_value == 'is') {
				cust_dfield_cnf = {};
				Ext.apply(cust_dfield_cnf,column.rel_combo_field_cnf);
				delete cust_dfield_cnf.id;
				delete cust_dfield_cnf.width;
			}
			
			if(this.last_cond_value == 'null/empty status') {
				cust_dfield_cnf = this.getNullEmptyDfield();
			}
			
		}
				
		if(this.datafield_cnf.width) { delete this.datafield_cnf.width; }

		if(cust_dfield_cnf) {
			// Make sure we preserve the existing value of 'value'
			// (this is an issue with 'menu-field' setup by RapidApp::Column)
			if(typeof this.datafield_cnf.value != 'undefined') {
				cust_dfield_cnf.value = this.datafield_cnf.value;
			}
			
			Ext.apply(this.datafield_cnf,cust_dfield_cnf);
			
			// Make sure itemId is 'datafield'
			// TODO: find a new way to do the lookup. If the cust_dfield/editor had
			// an itemId it might have needed it for something that could be broken by this
			this.datafield_cnf.itemId = 'datafield';
		}
		else if (this.condType == 'date') {
			Ext.apply(this.datafield_cnf,{
				xtype	: 'datefield',
				plugins: ['form-relative-datetime'],
				noReplaceDurations: true, //<-- option of the form-relative-datetime plugin
				format: 'Y-m-d'
			});
		}
		else if (this.condType == 'datetime') {
			Ext.apply(this.datafield_cnf,{
				xtype	: 'datefield',
				plugins: ['form-relative-datetime'],
				noReplaceDurations: true, //<-- option of the form-relative-datetime plugin
				format: 'Y-m-d H:i'
			});
		}
		else if(this.condType == 'number') {
			Ext.apply(this.datafield_cnf,{
				xtype	: 'numberfield',
				style: 'text-align:left;',
				flex: 1
			});
		}
		else {
			Ext.apply(this.datafield_cnf,{
				xtype	: 'textfield',
				itemId: 'datafield',
				flex	: 1
			});
		}

		// Remove all the fields and add all back in from scratch to
		// get hbox to set the correct sizes:
		this.removeAll(true);
		this.add(
			this.createFieldCombo(),
			this.createCondCombo(),
			this.createDataField()
		);
		this.doLayout();
	},
	
	getData: function() {
		var field_combo = this.getComponent('field_combo'),
			cond_combo = this.getComponent('cond_combo'),
			datafield = this.getComponent('datafield');
		
		var field = field_combo ? field_combo.getRawValue() : null,
			cond = cond_combo ? cond_combo.getRawValue() : null,
			val = null;
		
		if(datafield) {
			val = datafield.xtype == 'datefield' ? 
				// Special case for datefield ONLY: use getRawValue to optionally preserve
				// the relative date string which has special handling to convert on the 
				// server side
				datafield.getRawValue() : 
				
				// ALL other kinds of fields should use the normal getValue function:
				datafield.getValue();
		}
		
		
		if(!field || !cond) { return null; }
		
		//field combo
		if(field && this.fieldNameMap[field]) {
			field = this.fieldNameMap[field];
		}
		
		/* Moved into the back end:
		// --- translate relationship column to its id *or* render col ---
		var column = this.columnMap[field];
		if(column) {
			
			if (cond == 'is') {
				if(column.query_id_use_column) { field = column.query_id_use_column; }
			}
			else {
				if(column.query_search_use_column) { field = column.query_search_use_column; }
			}
		}
		// --- ---
		
		*/

		
		if(cond && this.conditionMap[cond]) {
			cond = this.conditionMap[cond];
		}
		
		var data = {};
		data[field] = {};
		data[field][cond] = val;
			
		return data;
	},
	
	loadData: function(data) {

		Ext.iterate(data,function(k,v) {
			
			//field combo
			if(this.reverseFieldNameMap[k]) {
				k = this.reverseFieldNameMap[k];
			}
			
			this.field_combo_cnf.value = k;
			Ext.iterate(v,function(k2,v2) {
				var cond = k2;
				if(this.reverseConditionMap[cond]) {
					cond = this.reverseConditionMap[cond];
				}
				this.cond_combo_cnf.value = cond;
				this.datafield_cnf.value = v2;

				this.last_cond_value = cond;
			},this);
		},this);
		
		this.configSelector();
	}
});



Ext.ux.MultiFilter.Filter = Ext.extend(Ext.Container,{

	layout: 'hbox',
	
	isFilterItem: true,
	
	cls: 'x-toolbar x-small-editor', // < --- this makes the container look like a toolbar
	//cls: 'x-toolbar', // < --- this makes the container look like a toolbar
	style: {
		margin: '5px 5px 5px 5px',
		'border-width': '1px 1px 1px 1px'
	},
	
	//height: 40,
	
	defaults: {
		flex: 1
	},
	
	autoScroll: true,
	
	criteriaClass: Ext.ux.MultiFilter.Criteria,
	
	initComponent: function() {

		if (! this.filterSelection) {
			this.filterSelection = new this.criteriaClass({
				flex: 1
			});
		}

		this.items = [
		
			new Ext.ux.MultiFilter.StaticCombo({
				name: 'and_or',
				itemId: 'and_or',
				width: 30,
				hideTrigger: true,
				value: 'and',
				value_list: [
					'and',
					'or'
				]
			}),
		
			/* TODO: Get "not" button implemented and working 
			{
				xtype: 'button',
				text: '!',
				enableToggle: true,
				flex: 0,
				tooltip: 'Toggle invert ("not")',
				toggleHandler: function(btn,state) {
					if (state) {
						btn.btnEl.replaceClass('x-multifilter-not-off', 'x-multifilter-not-on');
					}
					else {
						btn.btnEl.replaceClass('x-multifilter-not-on', 'x-multifilter-not-off');
					}
				},
				listeners: {
					'render': function(btn) {
						btn.btnEl.addClass('x-multifilter-not');
					}
				}
			},
			*/
	
			this.filterSelection,
			
			{
				//xtype: 'button',
				//iconCls: 'ra-icon-arrow-down',
				xtype: 'boxtoolbtn',
				toolType: 'down',
				flex: 0,
				itemId: 'down-button',
				handler: function(btn) {
					//var filter = btn.ownerCt;
					//var set = btn.ownerCt.ownerCt;
					var filter = this;
					var set = this.ownerCt;
					return Ext.ux.MultiFilter.movefilter(set,filter,1);
				},
				scope: this
			},
			
			{
				//xtype: 'button',
				//iconCls: 'ra-icon-arrow-up',
				xtype: 'boxtoolbtn',
				toolType: 'up',
				flex: 0,
				itemId: 'up-button',
				handler: function(btn) {
					//var filter = btn.ownerCt;
					//var set = btn.ownerCt.ownerCt;
					var filter = this;
					var set = this.ownerCt;
					return Ext.ux.MultiFilter.movefilter(set,filter,-1);
				},
				scope: this
			},
			
			{
				//xtype: 'button',
				//iconCls: 'ra-icon-delete',
				xtype: 'boxtoolbtn',
				toolType: 'close',
				flex: 0,
				handler: function(btn) {
					//var filter = btn.ownerCt;
					//var set = btn.ownerCt.ownerCt;
					var filter = this;
					var set = this.ownerCt;
					set.remove(filter,true);
					set.bubble(function(){ this.doLayout(); });
				},
				scope: this
			},
			{ xtype: 'spacer', width: 2 }
		];

		Ext.ux.MultiFilter.Filter.superclass.initComponent.apply(this,arguments);
	},

	checkPosition: function() {
	
		var set = this.ownerCt;
		var index = set.items.indexOfKey(this.getId());
		var max = set.items.getCount() - 2;
		
		var upBtn = this.getComponent('up-button');
		var downBtn = this.getComponent('down-button');
		var and_or = this.getComponent('and_or');
		
		if(index == 0) {
			upBtn.setVisible(false);
			and_or.setValue('and');
			and_or.setVisible(false);
		}
		else {
			upBtn.setVisible(true);
			and_or.setVisible(true);
		}
		
		if(index >= max) {
			downBtn.setVisible(false);
		}
		else {
			downBtn.setVisible(true);
		}
	},
	
	isOr: function() {
		var and_or = this.getComponent('and_or');
		if (and_or.getRawValue() == 'or') {
			return true;
		}
		return false;
	},
	
	setOr: function(bool) {
		var and_or = this.getComponent('and_or');
		if(bool) {
			and_or.setRawValue('or');
		}
		else {
			and_or.setRawValue('and');
		}
	},
	
	getData: function() {
		var data = this.filterSelection.getData();
		return data;
	},
	
	loadData: function(data) {
		return this.filterSelection.loadData(data);
	}
});
Ext.reg('filteritem',Ext.ux.MultiFilter.Filter);



Ext.ux.MultiFilter.FilterSetPanel = Ext.extend(Ext.Panel,{

	autoHeight: true,
	
	FilterParams: {},

	initComponent: function() {
		
		var add_filter = {
			xtype: 'button',
			text: 'Add',
			iconCls: 'ra-icon-add',
			//handler: function(btn) {
			//	btn.ownerCt.ownerCt.addFilter();
			//},
			handler: this.addFilter,
			scope: this
		};
		
		var add_set = {
			xtype: 'button',
			text: 'Add Set',
			iconCls: 'ra-icon-add',
			//handler: function(btn) {
			//	btn.ownerCt.ownerCt.addFilterSet();
			//},
			handler: this.addFilterSet,
			scope: this
		};
		
		this.items = {
			xtype: 'container',
			layout: 'hbox',
			style: {
				margin: '2px 2px 2px 2px'
			},
			items: [
				add_filter,
				add_set		
			]
		};
	
		var checkPositions = function(set) {
			set.items.each(function(item,indx,length) {
				if(item.getXType() !== 'filteritem') { return; }
				item.checkPosition();
			},this);
		};
		
		this.on('add',checkPositions,this);
		this.on('remove',checkPositions,this);
	
		Ext.ux.MultiFilter.FilterSetPanel.superclass.initComponent.call(this);
	},
	
	addNewItem: function(item) {
		var count = this.items.getCount();
		this.insert(count - 1,item);
		this.bubble(function(){ this.doLayout(); });
		return item;
	},
	
	addFilter: function(data) {
		return this.addNewItem(new Ext.ux.MultiFilter.Filter(this.FilterParams));
	},
	
	addFilterSet: function(data) {
	
		var config = {
			filterSelection: new Ext.ux.MultiFilter.FilterSetPanel({ FilterParams: this.FilterParams })
		};
	
		return this.addNewItem(new Ext.ux.MultiFilter.Filter(config));
	},
	
	addFilterWithData: function(item) {

		var filter;
		var new_item = item;
		
		// prune filters out of sets with only 1 filter:
		if(Ext.isArray(item) && item.length == 1 && ! item[0]['-or']) {
			new_item = item[0];
		}
		if(Ext.isArray(new_item) && new_item.length == 1  && ! new_item[0]['-or']) {
			new_item = new_item[0];
		}
		
		if(item['-and']) {
			new_item = item['-and'];
		}
		if(item['-or']) {
			new_item = item['-or'];
			for (var j = 0; j < new_item.length; j++) {
				filter = this.addFilterWithData(new_item[j]);
				filter.setOr(true);
			}
			return;
		}
		
		if(Ext.isObject(new_item)) {
			filter = this.addFilter();
		}
		else if(Ext.isArray(new_item)) {
		
			// Skip empty filtersets:
			if(new_item.length == 0) {
				return;
			}
		
			filter = this.addFilterSet();
			if(new_item.length == 1) {
				var only_item = new_item[0];
				if(Ext.isArray(only_item)) {
					new_item = only_item;
				}
			}
		}

		filter.loadData(new_item);

		return filter;
	},

	getData: function() {
	
		var data = [];
		var curdata = data;
		var or_sequence = false;
		
		this.items.each(function(item,indx,length) {
			if(item.getXType() !== 'filteritem') { return; }
			
			var itemdata = item.getData.call(item);
			if(!itemdata) { return; }
			
			if (item.isOr()) {
				or_sequence = true;
				var list = data.slice();
				data = [];
				curdata = [];
				curdata.push(list);
				data.push({'-or': curdata});
			}
			else {
				if (or_sequence) {
					var list = [];
					var last = curdata.pop();
					list.push(last);
					curdata.push({'-and': list});
					curdata = list;
				}
				or_sequence = false;
			}
			
			curdata.push(itemdata);
			
		},this);
		
		return data;
	},
	
	loadData: function(data,setOr) {
		return Ext.each(data,function(item) {
			this.addFilterWithData(item);
		},this);
	}
});
Ext.reg('filtersetpanel',Ext.ux.MultiFilter.FilterSetPanel);



Ext.ux.MultiFilter.movefilter = function(set,filter,indexOffset) {

	var filter_id = filter.getId();
	var index = set.items.indexOfKey(filter_id);
	var newIndex = index + indexOffset;
	var max = set.items.getCount() - 1;
	
	if (newIndex < 0 || newIndex >= max || newIndex == index) return;
	
	set.remove(filter,false);
	var d = filter.getPositionEl().dom;
	d.parentNode.removeChild(d);
	set.insert(newIndex,filter);
	
	set.bubble(function(){ this.doLayout(); });
}
