
/*
 Refactored based on example here (2011-05-10 by HV):
 http://www.sencha.com/forum/showthread.php?128164-Set-value-on-a-searching-combo-box-SOLVED&highlight=combo+query+type
*/
Ext.ns('Ext.ux.RapidApp.AppCombo2');
Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{
	
	initComponent: function() {
    Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.initComponent.call(this);
    if (this.baseParams) {
      Ext.apply(this.getStore().baseParams,this.baseParams);
    }
	
	},
	
	lastValueClass: '',
	
	nativeSetValue: function(v) {
		if (this.valueCssField) {
			var record = this.findRecord(this.valueField, v);
			if (record) {
				var addclass = record.data[this.valueCssField];
				if (addclass) { 
					this.el.replaceClass(this.lastValueClass,addclass);
					this.lastValueClass = addclass;
				}
			}
		}
		return Ext.form.ComboBox.prototype.setValue.apply(this,arguments);
	},
	
	setValue: function(v){
	
    this.apply_field_css();
	
    if (!v || v == '') { return this.nativeSetValue(v); }
		
		this.getStore().baseParams['valueqry'] = v;
		var combo = this;
		if(this.valueField){
			var r = this.findRecord(this.valueField, v);
			if (!r) {
				var data = {}
				data[this.valueField] = v
				this.store.load({
					params:data,
					callback:function(){
						delete combo.getStore().baseParams['valueqry'];
						combo.nativeSetValue(v)
					}
				})   
			} else return combo.nativeSetValue(v);
		} else combo.nativeSetValue(v);
	},
	
	apply_field_css: function() {
		if (this.focusClass) {
			this.el.addClass(this.focusClass);
		}
		if (this.value_addClass) {
			this.el.addClass(this.value_addClass);
		}
	}

});
Ext.reg('appcombo2', Ext.ux.RapidApp.AppCombo2.ComboBox);



// TODO: Make this the parent class of and merge with AppCombo2 above:
Ext.ux.RapidApp.AppCombo2.CssCombo = Ext.extend(Ext.form.ComboBox,{
	
	lastValueClass: '',
	
	clearCss: false,
	
	setValue: function(v) {

		if (this.valueCssField) {
			var record = this.findRecord(this.valueField, v);
			if (record) {
				var addclass = record.data[this.valueCssField];
				if (addclass && this.el) { 
					this.el.replaceClass(this.lastValueClass,addclass);
					this.lastValueClass = addclass;
				}
			}
			else {
				if(this.clearCss) {
					this.el.removeClass(this.lastValueClass);
				}
			}
		}
		return Ext.form.ComboBox.prototype.setValue.apply(this,arguments);
	}
});



Ext.ux.RapidApp.AppCombo2.IconCombo = Ext.extend(Ext.ux.RapidApp.AppCombo2.CssCombo,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	value_list: false,
	valueField: 'valueField',
	displayField: 'displayField',
	valueCssField: 'valueCssField',
	cls: 'with-icon',
	clearCss: true,
	initComponent: function() {
		if (this.value_list) {
			var data = [];
			Ext.each(this.value_list,function(item,index){
				if(Ext.isArray(item)) {
					data.push([item[0],item[1],item[2]]);
				}
				else {
					data.push([item,item,item]);
				}
			});
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField,
					this.valueCssField
				],
				data: data
			});
		}
		
		this.tpl = 
			'<tpl for=".">' +
				'<div class="x-combo-list-item">' +
					'<div class="with-icon {' + this.valueCssField + '}">' +
						'{' + this.displayField + '}' +
					'</div>' +
				'</div>' +
			'</tpl>';
		
		Ext.ux.RapidApp.AppCombo2.IconCombo.superclass.initComponent.apply(this,arguments);
	}
});
Ext.reg('icon-combo',Ext.ux.RapidApp.AppCombo2.IconCombo);

// TODO: remove Ext.ux.MultiFilter.StaticCombo and reconfigure MultiFilter
// to use this here as a general purpose component
Ext.ux.RapidApp.StaticCombo = Ext.extend(Ext.ux.RapidApp.AppCombo2.CssCombo,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	forceSelection: true,
	value_list: false, //<-- set value_list to an array of the static values for the combo dropdown
	valueField: 'valueField',
	displayField: 'displayField',
	valueCssField: 'valueCssField',
	itemStyleField: 'itemStyleField',
	useMenuList: false,
	initComponent: function() {
		if (this.value_list || this.storedata) {
			if(!this.storedata) {
				this.storedata = [];
				Ext.each(this.value_list,function(item,index){
					if(Ext.isArray(item)) {
						this.storedata.push([item[0],item[1],item[2],item[3]]);
					}
					else {
						// x-null-class because it has to be something for replaceClass to work
						this.storedata.push([item,item,'x-null-class','']);
					}
				},this);
			}
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField,
					this.valueCssField,
					this.itemStyleField
				],
				data: this.storedata
			});
			
			this.tpl = 
				'<tpl for=".">' +
					'<div class="x-combo-list-item {' + this.valueCssField + '}" ' +
						'style="{' + this.itemStyleField + '}">' +
						'{' + this.displayField + '}' +
					'</div>' +
				'</tpl>';
		}
		Ext.ux.RapidApp.StaticCombo.superclass.initComponent.apply(this,arguments);
		
		// New custom funtionality replaces the normal dropdown with a menu.
		// TODO: make this a general plugin. The reason this hasn't been done yet
		// is because there is no functionality to handle store event/changes, so
		// this only works with static value (i.e. StaticCombo)
		if(this.useMenuList) {
			var combo = this;
			var orig_initList = this.initList;
			this.initList = function() {
				if(!combo.list) {
					orig_initList.call(combo);
					combo.initMenuList.call(combo);
				}
			};
			// pre-init menu for performance:
			this.getMenuList();
		}
	},
	
	initMenuList: function () {
		
		this.expand = function() {
			var menu = this.getMenuList();
			
			// Have to track expand status manually so clicking the combo shows
			// and then hides the menu (vs show it over and over since menus auto
			// hide themselves)
			if(this.expandFlag) {
				this.expandFlag = false;
				return;
			}
			
			this.list.alignTo.apply(this.list, [this.el].concat(this.listAlign));
			menu.showAt(this.list.getXY());
			this.expandFlag = true;
		};
		
		// Reset the expand flag when the field blurs:
		this.on('blur',function(){ this.expandFlag = false; },this);
		
	},
	
	getMenuList: function() {
		if(!this.menuList) {
			
			var items = [];
			this.store.each(function(record,i){
				items.push({
					text: record.data[this.displayField],
					value: record.data[this.displayField],
					scope: this,
					handler: this.onSelect.createDelegate(this,[record,i])
				});
			},this);
			
			var menuCfg = {
				items: items,
				maxHeight: this.maxHeight,
				plugins: ['menu-filter'],
				autoFocusFilter: true
			};
			
			// Skip the filter if there are fewer than 5 items:
			if(items.length < 5) { delete menuCfg.plugins; }
			
			this.menuList = new Ext.menu.Menu(menuCfg);
			
			this.menuList.on('show',function(menu){
				menu.setPosition(this.list.getXY());
				this.updateItemsStyles();
			},this);
			
		}
		return this.menuList;
	},
	
	updateItemsStyles: function(){
		var Menu = this.menuList;
		var cur_val = this.getValue();
		Menu.items.each(function(mitem) {
			if(typeof mitem.value == "undefined") { return; }
			var el = mitem.getEl();
			if(mitem.value == cur_val) {
				el.setStyle('font-weight','bold');
				mitem.setIconClass('icon-checkbox-yes');
			}
			else {
				el.setStyle('font-weight','normal');
				mitem.setIconClass('');
			}
		},this);
	}
	
});
Ext.reg('static-combo',Ext.ux.RapidApp.StaticCombo);


Ext.ux.RapidApp.ClickActionField = Ext.extend(Ext.form.DisplayField,{
	
	actionOnShow: false,
	
	actionFn: Ext.emptyFn,
	
	nativeGetValue: Ext.form.DisplayField.prototype.getValue,
	nativeSetValue: Ext.form.DisplayField.prototype.setValue,
	
	initComponent: function() {
		Ext.ux.RapidApp.ClickActionField.superclass.initComponent.call(this);
		this.addEvents( 'select' );
		this.on('select',this.onSelectMe,this);
		this.on('render',this.onShowMe,this);
		this.on('show',this.onShowMe,this);
	},
	
	onSelectMe: function() {
		this.actionRunning = false;
	},
	
	onShowMe: function() {
		this.applyElOpts();
		
		if(this.actionOnShow && (this.nativeGetValue() || !this.isInForm())) {
			// If there is no value yet *and* we're in a form, don't call the action
			// We need this because in the case of a form we don't want the action to
			// be called on show, we want it called on click. In the case of an edit 
			// grid and AppDV, we want to run the action on show because on show in
			// that context happens after we've clicked to start editing
			this.callActionFn.defer(10,this);
		}
	},
	
	isInForm: function() {
		if(this.ownerCt) {
			
			// Special, if in MultiFilter (TODO: clean this up and find a more generaalized
			// way to detect this stuff without having to create custom tests for each different
			// scenario/context!
			if(Ext.isObject(this.ownerCt.datafield_cnf)) { return true; }
			
			var xtype = this.ownerCt.getXType();
			if(xtype == 'container' && this.ownerCt.initialConfig.ownerCt) {
				// special case for compositfield, shows wrong xtype
				xtype = this.ownerCt.initialConfig.ownerCt.getXType();
			}
			if(!xtype) { return false; }
			// any xtype that contains the string 'form' or 'field':
			if(xtype.search('form') != -1 || xtype.search('field') != -1) {
				return true;
			}
		}
		return false;
	},
	
	callActionFn: function() {
		if(this.actionRunning || this.disabled) { return; }
		this.actionRunning = true;
		this.actionFn.apply(this,arguments);
	},
	
	applyElOpts: function() {
		var el = this.getEl();
		if(!el.ElOptsApplied) {
			el.applyStyles('cursor:pointer');
			// Click on the Element:
			el.on('click',this.onClickMe,this);
			el.ElOptsApplied = true;
		}
	},
	
	onClickMe: function(e) {
		this.callActionFn.defer(10,this,arguments);
	},
	
	// Make us look like a combo with an 'expand' function:
	expand: function(){
		this.callActionFn.defer(10,this);
	}
});
Ext.reg('click-action-field',Ext.ux.RapidApp.ClickActionField);

Ext.ux.RapidApp.ClickCycleField = Ext.extend(Ext.ux.RapidApp.ClickActionField,{
	
	value_list: [],
	
	// cycleOnShow: if true, the the value is cycled when the field is shown
	cycleOnShow: false,
	
	fieldClass: 'x-form-field x-grid3-hd-inner no-text-select',
	
	initComponent: function() {
		Ext.ux.RapidApp.ClickCycleField.superclass.initComponent.call(this);
		
		this.actionOnShow = this.cycleOnShow;
		
		var map = {};
		var indexmap = {};
		var itemlist = [];
		Ext.each(this.value_list,function(item,index) {
			
			var value, text, cls; 
			if(Ext.isArray(item)) {
				value = item[0];
				text = item[1] || name;
				cls = item[2];
			}
			else {
				value = item;
				text = item;
			}
			
			map[value] = {
				value: value,
				text: text,
				cls: cls,
				index: index
			};
			indexmap[index] = map[value];
			itemlist.push(map[value]);
			
		},this);
		
		this.valueMap = map;
		this.indexMap = indexmap;
		this.valueList = itemlist;
	},
	
	setValue: function(v) {
		
		this.dataValue = v;
		var renderVal = v;
		if(this.valueMap[v]) { 
			var itm = this.valueMap[v];
			renderVal = itm.text;
			if(itm.cls) {
				renderVal = '<div class="with-icon ' + itm.cls + '">' + itm.text + '</div>';
			}
		}
		return this.nativeSetValue(renderVal);
	},
	
	getValue: function() {
		if(typeof this.dataValue !== "undefined") {
			return this.dataValue;
		}
		return this.nativeGetValue();
	},

	getCurrentIndex: function(){
		var v = this.getValue();
		var cur = this.valueMap[v];
		if(!cur) { return null; }
		return cur.index;
	},
	
	getNextIndex: function() {
		var cur = this.getCurrentIndex();
		if(cur == null) { return 0; }
		var next = cur + 1;
		if(this.indexMap[next]) { return next; }
		return 0;
	},
	
	actionFn: function() {
		
		var nextIndex = this.getNextIndex();
		var next = this.indexMap[nextIndex];
		if(typeof next == "undefined") { return; }
		
		return this.selectValue(next.value);
	},
	
	selectValue: function(v) {
		var itm = this.valueMap[v];
		if(typeof itm == "undefined" || !this.el.dom) { return; }

		var ret = this.setValue(itm.value);

		if(ret) { this.fireEvent('select',this,itm.value,itm.index); }
		return ret;
	}
	
});
Ext.reg('cycle-field',Ext.ux.RapidApp.ClickCycleField);

Ext.ux.RapidApp.ClickMenuField = Ext.extend(Ext.ux.RapidApp.ClickCycleField,{
	
	header: null,
	
	// cycleOnShow: if true, the the value is cycled when the field is shown
	menuOnShow: false,
	
	initComponent: function() {
		Ext.ux.RapidApp.ClickMenuField.superclass.initComponent.call(this);
		
		this.actionOnShow = this.menuOnShow;
	},
	
	updateItemsStyles: function(){
		var Menu = this.getMenu();
		var cur_val = this.getValue();
		Menu.items.each(function(mitem) {
			if(typeof mitem.value == "undefined") { return; }
			var el = mitem.getEl();
			if(mitem.value == cur_val) {
				el.addClass('menu-field-current-value');
			}
			else {
				el.removeClass('menu-field-current-value');	
			}
			
			//console.log(mitem.text);
		},this);
		
	},
	
	getMenu: function() {
		if(!this.clickMenu) {
			
			var cnf = {
				items: []
			};
			
			if(this.header) {
				cnf.items = [
					{
						canActivate: false,
						iconCls : 'icon-bullet-arrow-down',
						style: 'font-weight:bold;color:#333333;cursor:auto;padding-right:5px;',
						text: this.header + ':',
						hideOnClick: true
					},
					{ xtype: 'menuseparator' }
				];
				
			}
			
			Ext.each(this.valueList,function(itm) {
				var menu_item = {
					text: itm.text,
					value: itm.value,
					handler: function(){
						//we just set the value. Hide is automatically called which will
						//call selectValue, which will get the new value we're setting here
						this.setValue(itm.value);
					},
					scope:this
				}
				
				if(itm.cls) { menu_item.iconCls = 'with-icon ' + itm.cls; }
				
				cnf.items.push(menu_item);
			},this);
			
			this.clickMenu = new Ext.menu.Menu(cnf);
			
			/*************************************************/
			/* TODO: fixme (see below)  */
			this.clickMenu.on('beforehide',function(){ 
				if (!this.hideAllow) {
					this.hideAllow = true;
					var func = function() {
						// The hide only proceeds if hideAllow is still true.
						// If show got called, it will be set back to false and
						// the hide will not happen. This is to solve a race 
						// condition where hide gets called before show. That isn't
						// the *real* hide. Not sure why this happens
						if(this.hideAllow) { this.clickMenu.hide(); }
					}
					func.defer(50,this);
					return false; 
				}
			},this);
			
			this.clickMenu.on('show',function(){
				this.hideAllow = false;
			},this);
			
			this.clickMenu.on('hide',function(){
				if(this.hidden){ return; }
				//if(!this.isVisible()){ return; }
				this.selectValue(this.getValue());
			},this);
			/*************************************************/
			
			this.clickMenu.on('show',this.updateItemsStyles,this);
			
		}
		return this.clickMenu;
	},
	
	actionFn: function(e) {
		var el = this.getEl();
		var pos = [0,0];
		if(el){ 
			pos = el.getXY();
		}
		else if(e && e.getXY) { pos = e.getXY(); }
		
		// TODO: sometimes it just fails to get the position! why?!
		if(pos[0] <= 0) {
			pos = this.getPosition(true);
			//console.dir(this);
		}
		
		var Menu = this.getMenu();
		
		Menu.showAt(pos);
		this.ignoreHide = false;
	}
	
});
Ext.reg('menu-field',Ext.ux.RapidApp.ClickMenuField);




Ext.ux.RapidApp.CasUploadField = Ext.extend(Ext.ux.RapidApp.ClickActionField,{
	
	// TODO
	
	
	initComponent: function() {
		Ext.ux.RapidApp.CasUploadField.superclass.initComponent.call(this);
		
	}
	
});
Ext.reg('cas-upload-field',Ext.ux.RapidApp.CasUploadField);


Ext.ux.RapidApp.CasImageField = Ext.extend(Ext.ux.RapidApp.CasUploadField,{
	
	// init/default value:
	value: '<div style="color:darkgray;">(select image)</div>',
	
	uploadUrl: '/simplecas/upload_image',
	
	maxImageWidth: null,
	maxImageHeight: null,
	
	resizeWarn: true,
	
	minHeight: 2,
	minWidth: 2,
	
	getUploadUrl: function() {
		url = this.uploadUrl;
		if(this.maxImageHeight && !this.maxImageWidth) {
			throw("Fatal: maxImageWidth must also be specified when using maxImageHeight.");
		}
		if(this.maxImageWidth) { 
			url += '/' + this.maxImageWidth; 
			if(this.maxImageHeight) { url += '/' + this.maxImageHeight; }
		}
		return url;
	},
	
	formUploadCallback: function(form,res) {
		var img = Ext.decode(res.response.responseText);
		
		if(this.resizeWarn && img.resized) {
			Ext.Msg.show({
				title:'Notice: Image Resized',
				msg: 
					'The image has been resized by the server.<br><br>' +
					'Original Size: <b>' + img.orig_width + 'x' + img.orig_height + '</b><br><br>' +
					'New Size: <b>' + img.width + 'x' + img.height + '</b>'
				,
				buttons: Ext.Msg.OK,
				icon: Ext.MessageBox.INFO
			});
		}
		
		img.link_url = '/simplecas/fetch_content/' + img.checksum + '/' + img.filename;
		
		if(!img.width || img.width < this.minWidth) { img.width = this.minWidth; }
		if(!img.height || img.height < this.minHeight) { img.height = this.minHeight; }
		var img_tag = 
			'<img alt="\<img: ' + img.filename + '\>" src="' + img.link_url + 
				'" width=' + img.width + ' height=' + img.height + 
				' style="background-color:yellow;"' +
			'>';
		this.setValue(img_tag);
		this.onActionComplete();
	},
	
	onActionComplete: function() {
		this.fireEvent.defer(50,this,['select']);
	},
	
	actionFn: function(){
		
		var upload_field = {
			xtype: 'fileuploadfield',
			emptyText: 'Select image',
			fieldLabel:'Select Image',
			name: 'Filedata',
			buttonText: 'Browse',
			width: 300
		};
		
		var fieldset = {
			style: 'border: none',
			hideBorders: true,
			xtype: 'fieldset',
			labelWidth: 80,
			border: false,
			items:[ upload_field ]
		};
		
		Ext.ux.RapidApp.WinFormPost.call(this,{
			title: 'Insert Image',
			width: 440,
			height:140,
			url: this.getUploadUrl(),
			useSubmit: true,
			fileUpload: true,
			fieldset: fieldset,
			success: this.formUploadCallback,
			cancelHandler: this.onActionComplete.createDelegate(this)
		});
	}
	
});
Ext.reg('cas-image-field',Ext.ux.RapidApp.CasImageField);


// increase from the default 9000 to prevent editor fields from showing through
// Keep under 15000 for menus...
Ext.WindowMgr.zseed = 12000;

Ext.ux.RapidApp.DataStoreAppField = Ext.extend(Ext.ux.RapidApp.ClickActionField,{
	
	actionOnShow: true,
	
	win_title: 'Select',
	win_width: 400,
	win_height: 350,
	
	value: '<div style="color:darkgray;">(select)</div>',
	
	onActionComplete: function() {
		this.fireEvent.defer(50,this,['select']);
	},
	
	actionFn: function() {
		this.displayWindow();
	},
	
	setValue: function() {
		delete this.dataValue;
		return this.nativeSetValue.apply(this,arguments);
	},
	
	getValue: function() {
		if(typeof this.dataValue !== "undefined") {
			return this.dataValue;
		}
		return this.nativeGetValue();
	},
	
	displayWindow: function() {
		var field = this;
		var win;
		
		var select_fn = function(Record) {
			if(!Record) {
				var app = win.getComponent('app').items.first();
				var records = app.getSelectedRecords();
				Record = records[0];
			}
			
			if(!Record) { return; }
			
			var value = Record.data[field.valueField];
			var disp = Record.data[field.displayField];
			if(typeof value != 'undefined') {
				field.setValue(value);
				if(typeof disp != 'undefined') {
					field.setValue(disp);
					field.dataValue = value;
				}
				win.close();
			}
		};
		
		var select_btn = new Ext.Button({
			text: 'Select', 
			handler: function(){ select_fn(null); },
			disabled: true
		});
		
		var add_btn = new Ext.Button({
			text: '<b>Add/Select New</b>',
			width: 175,
			iconCls: 'icon-add',
			handler: Ext.emptyFn,
			hidden: true
		});
		
		var buttons = [
			add_btn,
			'->',
			select_btn,
			{ text: 'Cancel', handler: function(){ win.close(); } }
		];
		
		win = new Ext.Window({
			buttonAlign: 'left',
			title: this.win_title,
			layout: 'fit',
			width: this.win_width,
			height: this.win_height,
			closable: true,
			modal: true,
			items: {
				xtype: 'autopanel',
				itemId: 'app',
				autoLoad: { url: this.load_url },
				layout: 'fit',
				cmpListeners: {
					afterrender: function(){
						var toggleBtn = function() {
							if (this.getSelectedRecords.call(this).length > 0) {
								select_btn.setDisabled(false);
							}
							else {
								select_btn.setDisabled(true);
							}
						};
						this.on('selectionchange',toggleBtn,this);
						
						this.store.on('write',function(ds,action,result,res,record){
							// Only auto-select new record if exactly 1 record was added and is not a phantom:
							if(action == "create" && record && typeof record.phantom != 'undefined' && !record.phantom) { 
								return select_fn(record); 
							}
						},this);
						
						// "Move" the store add button to the outer window button toolbar:
						if(this.loadedStoreButtons && this.loadedStoreButtons.add) {
							var store_add_btn = this.loadedStoreButtons.add;
							add_btn.setHandler(store_add_btn.handler);
							add_btn.setVisible(true);
							store_add_btn.setVisible(false);
						}
					},
					rowdblclick: function(){ select_fn(null); }
				},
				cmpConfig: {
					// Obviously this is for grids... not sure if this will cause problems
					// in the case of AppDVs
					sm: new Ext.grid.RowSelectionModel({singleSelect:true})
				}
			},
			buttons: buttons,
			listeners: {
				close: function(){ field.onActionComplete.call(field); }
			}
		});
		
		win.show();
	}
	
});
Ext.reg('datastore-app-field',Ext.ux.RapidApp.DataStoreAppField);
