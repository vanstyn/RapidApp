

Ext.ns('Ext.ux.MultiFilter');


Ext.ux.MultiFilter.Plugin = Ext.extend(Ext.util.Observable,{

	init: function(grid) {
		this.grid = grid;
		grid.multifilter = this;

		this.store = grid.getStore();
		this.store.on('beforeload',function(store,options) {
			if(store.filterdata) {
				var encoded = Ext.encode(store.filterdata);
				Ext.apply(options.params, {
					'multifilter': encoded 
				});
			}
			return true;
		});
	
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
	
	onRender: function() {
	
		this.filtersBtn = new Ext.Button({
			text: 'Filters',
			handler: function(btn) {
				var win = btn.ownerCt.ownerCt.multifilter.showFilterWindow();
			}
		});
		
		var grid = this.grid;
		var tbar = this.grid.getTopToolbar();
		tbar.add(this.filtersBtn);
	},
	
	setFields: function() {
		var fields = [];
		
		this.store.fields.each(function(item,index,length) {
			fields.push(item.name);
		});
		
		this.Criteria = Ext.extend(Ext.ux.MultiFilter.Criteria,{
			gridColumns: this.grid.getColumnModel().config,
			fieldList: fields
		});
	},
	
	showFilterWindow: function() {
		
		this.setFields();
	
		var win = new Ext.Window({
			//id: 'mywin',
			multifilter: this,
			title: 'MultiFilter',
			layout: 'anchor',
			width: 750,
			height: 600,
			closable: true,
			modal: true,
			
			autoScroll: true,
			items: [
				new Ext.ux.MultiFilter.FilterSetPanel({
					FilterParams: {
						criteriaClass: this.Criteria
					},
					anchor: '-26', 
					frame: true,
					itemId: 'filSet'
				})
			],
			buttons: [
				{
					xtype: 'button',
					text: 'Save and Close',
					iconCls: 'icon-save',
					handler: function(btn) {
						var win = btn.ownerCt.ownerCt;
						var set = win.getComponent('filSet');
						var store = btn.ownerCt.ownerCt.multifilter.store;
						store.filterdata = set.getData();
						
						//TODO: set the text to bold and count of the active filters
						win.multifilter.filtersBtn.setText('FILTERS');
						
						win.close();
						store.reload();
					}
				},
				{
					xtype: 'button',
					text: 'Cancel',
					//iconCls: 'icon-close',
					handler: function(btn) {
						btn.ownerCt.ownerCt.close();
					}
				},
			]
			
		});
		
		win.show();
		
		if (this.store.filterdata) {
			var set = win.getComponent('filSet');
			set.loadData(this.store.filterdata);
		}
		
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
			for (i in this.value_list) {
				data.push([i,this.value_list[i]]);
			}
			data.pop();
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



Ext.ux.MultiFilter.defaultConditionMap = {

	'is equal to'				: '=',
	'is not equal to'			: '!=',
	'before'						: '<',
	'after'						: '>'

};


Ext.ux.MultiFilter.defaultTypeToConditionMap = {

	'default': {
		'is equal to'			: '=',
		'is not equal to'		: '!='
	},
	
	date: {
		'before'					: '<',
		'after'					: '>'
	},
	
	number: {
		'less than'				: '<',
		'greater than'			: '>',
		'equal to'				: '=',
		'not equal to'			: '!='
	}

};


Ext.ux.MultiFilter.Criteria = Ext.extend(Ext.Container,{

	layout: 'hbox',
	
	fieldList: [
		'field1',
		'field2',
		'field3',
		'field4'
	],
	
	gridColumns: null,
	
	columnMap: {},
	
	conditionMap: Ext.ux.MultiFilter.defaultConditionMap,
	
	typeCondMap: Ext.ux.MultiFilter.defaultTypeToConditionMap,

	initComponent: function() {
	
		this.reverseConditionMap = {};
		for (i in this.conditionMap) {
			this.reverseConditionMap[this.conditionMap[i]] = i;
		}
		
		this.initColumns();
		
		this.field_combo_cnf = {
			name: 'field_combo',
			itemId: 'field_combo',
			grow: true,
			minListWidth: 200,
			width: 100,
			value_list: this.fieldList,
			UpdateWidth: function() {
				var TM = Ext.util.TextMetrics.createInstance(this.el);
				var value = this.getRawValue();
				var new_width = 30 + TM.getWidth(value);
				this.setWidth(new_width);
				
				// This is the only way to get the hbox to properly recalculate.
				// We update the config object and then recreate all the fields
				// from scratch on the select event:
				Ext.apply(this.ownerCt.field_combo_cnf,{
					width: new_width,
					value: value
				});

				//this.ownerCt.bubble(function(){ this.syncSize(); this.doLayout(); });
			},
			listeners: {
				select: function(combo) {
					combo.UpdateWidth();
					var criteria = combo.ownerCt;
					var column = criteria.columnMap[combo.getRawValue()];
					if (column) {
						criteria.configSelector(column);
					}
				}
			}
		};
		
		this.items = new Ext.ux.MultiFilter.StaticCombo(this.field_combo_cnf);

		Ext.ux.MultiFilter.Criteria.superclass.initComponent.call(this);
	},
	
	initColumns: function() {
		if (! this.gridColumns) { return; }
		
		this.columnMap = {};
		
		for (var i = 0; i < this.gridColumns.length; i++) {
			var column = this.gridColumns[i];
			this.columnMap[column.name] = column;
		}
		return this.columnMap;
	},
	
	configSelector: function(column) {
		var cond = this.getComponent('cond_combo');
		if (cond) {
			cond.ownerCt.remove(cond,true);
		}
		var val = this.getComponent('datafield');
		if (val) {
			val.ownerCt.remove(val,true);
		}
		
		var type = column.filter.type;
		
		var colCondCnf = this.typeCondMap[type];
		if (!colCondCnf) { colCondCnf = this.typeCondMap['default']; }
		
		var value_list = [];
		for (i in colCondCnf) {
			value_list.push(i);
		}
		
		cond = new Ext.ux.MultiFilter.StaticCombo({
			name: 'cond_combo',
			itemId: 'cond_combo',
			width: 100,
			value_list: value_list
		});
		
		if (type == 'date') {
			val = {
				xtype	: 'datefield',
				name	: 'datafield',
				itemId: 'datafield',
				format: 'Y-m-d H:i:s',
				width: 130
			};
		}
		else if (type == 'number') {
			val = {
				xtype	: 'numberfield',
				name	: 'datafield',
				itemId: 'datafield',
				flex	: 1
			};
		}
		else {
		
			val = {
				xtype	: 'textfield',
				name	: 'datafield',
				itemId: 'datafield',
				flex	: 1
			};
		}
		
		// Remove all the fields and add all back in from scratch to
		// get hbox to set the correct sizes
		this.removeAll(true);
		this.add(
			new Ext.ux.MultiFilter.StaticCombo(this.field_combo_cnf),
			cond,
			val
		);
		this.doLayout();
	},
	
	getData: function() {
		var field = this.getComponent('field_combo').getRawValue();
		var cond = this.getComponent('cond_combo').getRawValue();
		var val = this.getComponent('datafield').getRawValue();
		
		if(this.conditionMap[cond]) {
			cond = this.conditionMap[cond];
		}
		
		var data = {};
		data[field] = {};
		data[field][cond] = val;
	
		return data;
	},
	
	loadData: function(data) {

		for (i in data) {
			var field_combo = this.getComponent('field_combo');
			field_combo.setRawValue(i);
			for (j in data[i]) {
				var cond = j;
				if(this.reverseConditionMap[cond]) {
					cond = this.reverseConditionMap[cond];
				}
				this.getComponent('cond_combo').setRawValue(cond);
				this.getComponent('datafield').setRawValue(data[i][j]);
			}
		}
	}
});



Ext.ux.MultiFilter.Filter = Ext.extend(Ext.Container,{

	layout: 'hbox',
	cls: 'x-toolbar x-small-editor', // < --- this makes the container look like a toolbar
	style: {
		margin: '5px 5px 5px 5px',
		'border-width': '1px 1px 1px 1px'
	},
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
	
			this.filterSelection,
			
			{
				xtype: 'button',
				flex: 0,
				iconCls: 'icon-arrow-down',
				itemId: 'down-button',
				handler: function(btn) {
					var filter = btn.ownerCt;
					var set = btn.ownerCt.ownerCt;
					return Ext.ux.MultiFilter.movefilter(set,filter,1);
				}
			},
			
			{
				xtype: 'button',
				flex: 0,
				iconCls: 'icon-arrow-up',
				itemId: 'up-button',
				handler: function(btn) {
					var filter = btn.ownerCt;
					var set = btn.ownerCt.ownerCt;
					return Ext.ux.MultiFilter.movefilter(set,filter,-1);
				}
			},
			
			{
				xtype: 'button',
				flex: 0,
				iconCls: 'icon-delete',
				handler: function(btn) {
					var filter = btn.ownerCt;
					var set = btn.ownerCt.ownerCt;
					set.remove(filter,true);
					set.bubble(function(){ this.doLayout(); });
				}
			},
			
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
		//console.dir(data);
		return this.filterSelection.loadData(data);
	}
});
Ext.reg('filteritem',Ext.ux.MultiFilter.Filter);



Ext.ux.MultiFilter.FilterSetPanel = Ext.extend(Ext.Panel,{

	forceLayout: true,
	autoHeight: true,
	
	FilterParams: {},

	initComponent: function() {
		
		var add_filter = {
			xtype: 'button',
			text: 'Add',
			iconCls: 'icon-add',
			handler: function(btn) {
				btn.ownerCt.ownerCt.addFilter();
			}
		};
		
		var add_set = {
			xtype: 'button',
			text: 'Add Set',
			iconCls: 'icon-add',
			handler: function(btn) {
				btn.ownerCt.ownerCt.addFilterSet();
			}
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
			});
		};
		
		this.on('add',checkPositions);
		this.on('remove',checkPositions);
	
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
		
		if(Ext.ux.MultiFilter.RealTypeOf(new_item) == 'object') {
			filter = this.addFilter();
		}
		else if(Ext.ux.MultiFilter.RealTypeOf(new_item) == 'array') {
			filter = this.addFilterSet();
			if(new_item.length == 1) {
				var only_item = new_item[0];
				if(Ext.ux.MultiFilter.RealTypeOf(only_item) == 'array') {
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
			
			var itemdata = item.getData();
			
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
			
		});
		
		return data;
	},
	
	loadData: function(data,setOr) {
		for (var i = 0; i < data.length; i++) {
			var item = data[i];
			this.addFilterWithData(item);
		}
		return;
	}
});
Ext.reg('filtersetpanel',Ext.ux.MultiFilter.FilterSetPanel);


Ext.ux.MultiFilter.RealTypeOf = function(v) {
	if (typeof(v) == "object") {
		if (v === null) return "null";
		if (v.constructor == (new Array).constructor) return "array";
		if (v.constructor == (new Date).constructor) return "date";
		if (v.constructor == (new RegExp).constructor) return "regex";
		return "object";
	}
	return typeof(v);
}


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
