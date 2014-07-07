
/*
 Refactored based on example here (2011-05-10 by HV):
 http://www.sencha.com/forum/showthread.php?128164-Set-value-on-a-searching-combo-box-SOLVED&highlight=combo+query+type
*/
Ext.ns('Ext.ux.RapidApp.AppCombo2');
Ext.ux.RapidApp.AppCombo2.ComboBox = Ext.extend(Ext.form.ComboBox,{
	
	allowSelectNone: false,
	selectNoneLabel: '(None)',
	selectNoneCls: 'ra-combo-select-none',
	selectNoneValue: null,
	
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
						var Store = combo.getStore();
						if(Store){
							delete Store.baseParams['valueqry'];
						}
						combo.nativeSetValue(v);
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
	},
	
	onLoad: function() {
		if(this.allowSelectNone && !this.hasNoneRecord()) {
			this.insertNoneRecord();
		}
		return Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.onLoad.apply(this,arguments);
	},
	
	hasNoneRecord: function() {
		var store = this.getStore();
		var Record = store.getAt(0);
		return (Record && Record.isNoneRecord);
	},
	
	getSelectNoneLabel: function() {
		return ! this.selectNoneCls
			? this.selectNoneLabel
				: '<span class="' + this.selectNoneCls + '">' + 
					this.selectNoneLabel + 
				'</span>';
	},
	
	insertNoneRecord: function(){
		var store = this.getStore();
		var data = {};
		data[this.valueField] = this.selectNoneValue;
		data[this.displayField] = this.getSelectNoneLabel();
		var noneRec = new store.recordType(data);
		noneRec.isNoneRecord = true;
		store.insert(0,noneRec);
	},
	
	// Record used as the target record for the select operation *after* '(None)' has
	// been selected from the dropdown list. This is needed because we don't want "(None)"
	// shown in the field (we want it to be empty). This record is never actually added 
	// to the store
	getEmptyValueRecord: function() {
		if(!this.emptyValueRecord) {
			var store = this.getStore();
			var data = {};
			data[this.valueField] = this.selectNoneValue;
			data[this.displayField] = this.selectNoneValue; //<-- this is where we differ from None Record
			this.emptyValueRecord = new store.recordType(data);
		}
		return this.emptyValueRecord;
	},
	
	onSelect: function(Record,index) {
		if(this.allowSelectNone && Record.isNoneRecord) {
			var emptyRec = this.getEmptyValueRecord();
			return Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.onSelect.call(this,emptyRec,index);
		}
		return Ext.ux.RapidApp.AppCombo2.ComboBox.superclass.onSelect.apply(this,arguments);
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
Ext.reg('ra-icon-combo',Ext.ux.RapidApp.AppCombo2.IconCombo);

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
				mitem.setIconClass('ra-icon-checkbox-yes');
			}
			else {
				el.setStyle('font-weight','normal');
				mitem.setIconClass('');
			}
		},this);
	}
	
});
Ext.reg('static-combo',Ext.ux.RapidApp.StaticCombo);


// Like Ext.form.DisplayField but doesn't disable validation stuff:
Ext.ux.RapidApp.UtilField = Ext.extend(Ext.form.TextField,{
	//validationEvent : false,
	//validateOnBlur : false,
	defaultAutoCreate : {tag: "div"},
	/**
	* @cfg {String} fieldClass The default CSS class for the field (defaults to <tt>"x-form-display-field"</tt>)
	*/
	fieldClass : "x-form-display-field",
	/**
	* @cfg {Boolean} htmlEncode <tt>false</tt> to skip HTML-encoding the text when rendering it (defaults to
	* <tt>false</tt>). This might be useful if you want to include tags in the field's innerHTML rather than
	* rendering them as string literals per the default logic.
	*/
	htmlEncode: false,

	// private
	//initEvents : Ext.emptyFn,

	//isValid : function(){
	//	return true;
	//},

	//validate : function(){
	//	return true;
	//},

	getRawValue : function(){
		var v = this.rendered ? this.el.dom.innerHTML : Ext.value(this.value, '');
		if(v === this.emptyText){
			v = '';
		}
		if(this.htmlEncode){
			v = Ext.util.Format.htmlDecode(v);
		}
		return v;
	},

	getValue : function(){
		return this.getRawValue();
	},

	getName: function() {
		return this.name;
	},

	setRawValue : function(v){
		if(this.htmlEncode){
			v = Ext.util.Format.htmlEncode(v);
		}
		return this.rendered ? (this.el.dom.innerHTML = (Ext.isEmpty(v) ? '' : v)) : (this.value = v);
	},

	setValue : function(v){
		this.setRawValue(v);
		return this;
	}
});

//Ext.ux.RapidApp.ClickActionField = Ext.extend(Ext.form.DisplayField,{
Ext.ux.RapidApp.ClickActionField = Ext.extend(Ext.ux.RapidApp.UtilField,{
	
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
		if(el && !el.ElOptsApplied) {
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
      var text = itm.text || v;
      // New: always render with an icon (related to Github Issue #30)
      var icon_cls = itm.cls || 'ra-icon-bullet-arrow-down';
      renderVal = '<div class="with-icon ' + icon_cls + '">' + text + '</div>';
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
						iconCls : 'ra-icon-bullet-arrow-down',
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
    else if (this.resizeWarn && img.shrunk) {
      Ext.Msg.show({
        title:'Notice: Oversized Image Shrunk',
        msg: 
          'The image is oversized and has been pre-shrunk for display <br>' +
          'purposes (however, you can click/drag it larger).<br><br>' +
          'Actual Size: <b>' + img.orig_width + 'x' + img.orig_height + '</b><br><br>' +
          'Displayed Size: <b>' + img.width + 'x' + img.height + '</b>'
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
	
	fieldClass: 'ra-datastore-app-field',
	invalidClass: 'ra-datastore-app-field-invalid',
	updatingClass: 'ra-datastore-app-field-updating',
	actionOnShow: true,
	win_title: 'Select',
	win_width: 500,
	win_height: 450,
	value: null,
	preloadAppWindow: true,
	queryResolveInterval: 50,
	
	initComponent: function() {
		Ext.ux.RapidApp.DataStoreAppField.superclass.initComponent.call(this);
    
    this.displayCache = {};
		
		if(!this.valueField || !this.displayField || this.valueField == this.displayField) {
			this.noDisplayLookups = true;
		}
		
		if(this.preloadAppWindow){
			// init the window/app in the background as soon as we're
			// rendered (but before the user has clicked/triggered the 
			// action to show the window. It will have a head start and
			// load much faster):
			this.on('render',this.getAppWindow,this);
		}
		
		// Destroy the window only when we get destroyed:
		this.on('beforedestroy',function(){
			if(this.appWindow){ this.appWindow.close(); }
			if(this.queryTask) { this.queryTask.cancel(); }
		},this);
		
		// -- Automatically hide the window if it is visible and a nav/load target
		// event happens in the main loadTarget. This can happen if, for example,
		// the user clicks an 'open' link within the grid combo to a related object
		var loadTarget = Ext.getCmp("main-load-target");
		if(loadTarget){
			loadTarget.on('navload',function(){
				if(this.appWindow && this.appWindow.isVisible()){
					this.appWindow.hide();
				}
			},this);
		}
		// --
		
		
		//this.on('destroy',function(){	console.log('destroy (' + this.id + ')'); },this);
		//this.on('render',function(){	console.log('render (' + this.id + ')'); },this);
		
	},
	
	onActionComplete: function() {
		this.fireEvent.defer(50,this,['select']);
	},
	
	actionFn: function() {
		this.displayWindow();
	},
	
	setUpdatingClass: function() {
		if (this.rendered && !this.preventMark) {
			this.el.addClass(this.updatingClass);
		}
	},
	
	clearUpdatingClass: function() {
		if (this.rendered && !this.preventMark) {
			this.el.removeClass(this.updatingClass);
		}
	},
	
	
	// setValue should only be called from the outside (not us, we call setData) so
	// it always will be a record id and NOT a display value which we need to lookup:
	setValue: function(value) {
		this.setUpdatingClass();
		delete this.dataValue;
		var disp = this.lookupDisplayValue(value);
		return this.setData(value,disp,this.valueDirty);
	},
	
	// private
	setData: function(value,disp,dirty) {
		if(!dirty) {
			this.valueDirty = false;
			this.clearUpdatingClass();
			this.displayCache[value] = disp;
		}
		this.dataValue = value;
		return this.nativeSetValue(disp);
	},
	
	findRecordIndex: function(value) {
		var store = this.appStore;
		if(!store || !value) { return -1; }
		return store.findExact(this.valueField,value);
	},
	
	// Checks to see if the current record cache has a supplied id value (valueField)
	// and returns the associated display value if it does
	lookupDispInRecords: function(value) {
		if(this.noDisplayLookups) { 
			this.lastDispRecordsLookupsFound = true;
			return value; 
		}
		
		this.lastDispRecordsLookupsFound = false;
		
		var store = this.appStore;
		if(!store || !value) { return null; }
		
		var index = this.findRecordIndex(value);
		if(index == -1) { return null; }
		
		var Record = store.getAt(index);
		if(!Record || typeof Record.data[this.displayField] == 'undefined') {
			return null;
		}
		
		// we set this global so we don't have to rely on a return value (since maybe the value
		// should be null, should be false, etc)
		this.lastDispRecordsLookupsFound = true;
		return Record.data[this.displayField];
	},
	
	lookupDisplayValue: function(value) {
		if(!value || this.noDisplayLookups) { 
			this.valueDirty = false;
			return value;
		}
		
		// If the value is not already dirty and we already have it in our cache,
		// return the cached value:
		if(!this.valueDirty && this.displayCache[value]) {
			return this.displayCache[value];
		}
		
		delete this.lastDispRecordsLookupsFound;
		var disp = this.lookupDispInRecords(value);
		if(!this.lastDispRecordsLookupsFound) {
			this.valueDirty = true; 
			// If the value is 'dirty' we start the query resolver task:
			this.queryResolveDisplayValue();
			return value;
		}
		
		this.valueDirty = false;
		return disp;
	},
	
	getValue: function() {
		if(typeof this.dataValue !== "undefined") {
			return this.dataValue;
		}
		return this.nativeGetValue();
	},
	
	displayWindow: function() {
		this.loadPending = true;
		this.getAppWindow().show();
	},
	
	getAppWindow: function() {
		if(!this.appWindow) {
			
			// New feature: GLOBAL_add_form_onPrepare
			// function can be supplied as either a config param, OR detected in
			// the parent container. Once set, the value will be passed into the
			// add form, which will in turn be picked up by any nested 
			// DataStoreAppField components within that add form, which is then
			// passed down the chain to any depth. This is essentially a "localized"
			// global variable. This feature is needed to support an API by which
			// the configuration of a hirearchy of nested grid combos can be accessed
			// by applying a setting to the top/first in the chain. This was added
			// specifically to allow changing which fields are required and which aren't
			// via toggle in javascript in the top add form. GLOBAL_add_form_onPrepare
			// is passed the config object of the add form in the same way as
			// add_form_onPrepare.
			//var oGLOBAL = (this.ownerCt && this.ownerCt.GLOBAL_add_form_onPrepare) ?
			//	this.ownerCt.GLOBAL_add_form_onPrepare : null;
			//
			var oGLOBAL = this.findParentBy(function(parent){
				return Ext.isFunction(parent.GLOBAL_add_form_onPrepare);
			});
			
			if(oGLOBAL && !this.GLOBAL_add_form_onPrepare) {
				this.GLOBAL_add_form_onPrepare = oGLOBAL;
			}
		
			var win, field = this;
			var autoLoad = this.autoLoad || { url: this.load_url };
			
			var select_fn;
			select_fn = function(Record) {
				if(!win || !win.app){ return; }
				if(!Record) {
					var records = win.app.getSelectedRecords();
					Record = records[0];
				}
				
				if(!Record) { return; }
				
				// ------- Handle special case where the grid is editable and the user makes changes
				// that they don't save before clicking select. Save them, then re-update the field
				// in case they changed the selected field (mostly for display purposes)
				// TODO: add code to handle the exception event/code path. Also need to do the same for the
				// confirm save dialog in datastore-plus which is where this code was copied from
				var store = Record.store;
				if(store.hasAnyPendingChanges()){
					var onsave;
					onsave = function() {
						store.un('saveall',onsave);
						var value = Record.data[field.valueField], 
							disp = Record.data[field.displayField];
						field.setData(value,disp);
					};
					store.on('saveall',onsave);
					store.saveAll();
				}
				// -------
				
				var value = Record.data[field.valueField], 
					disp = Record.data[field.displayField];
				
				if(typeof value != 'undefined') {
					if(typeof disp != 'undefined') {
						field.setData(value,disp);
					}
					else {
						field.setData(value,value);
					}
					
					win.hide();
				}
			};
			
			var select_btn = new Ext.Button({
				text: '&nbsp;Select',
				width: 90,
				iconCls: 'ra-icon-selection-up-blue',
				handler: function(){ select_fn(null); },
				scope: this,
				disabled: true
			});
			
			var add_btn = new Ext.Button({
				text: '<span style="font-weight:bold;font-size:1.1em;">Add New</span>',
				iconCls: 'ra-icon-selection-add',
				handler: Ext.emptyFn,
				hidden: true
			});
			
			var buttons = [
				'->',
				select_btn,
				{ text: 'Cancel', handler: function(){ win.hide(); } }
			];
				
			if(this.allowBlank){
				buttons.unshift(new Ext.Button({
					text: 'Select None (empty)',
					iconCls: 'ra-icon-selection',
					handler: function(){
						//field.dataValue = null;
						//field.setValue(null);
						field.setData(null,null);
						win.hide();
					},
					scope: this
				}));
			}
			
			// If this is an editable appgrid, convert it to a non-editable appgrid:
			var update_cmpConfig = function(conf) {
				if(conf && conf.xtype == 'appgrid2ed') {
					// Temp turned off this override because there turned out to be cases
					// where editing in the grid combo is desired. 
					// TODO: Need to revisit this, because in general, we probably don't
					// want to assume that editing should be allowed....
					//conf.xtype = 'appgrid2';
				}
				
				// Force persist immediately on create so "Add and select" will work as
				// expected
				conf.persist_immediately.create = true;
			};
			
			var cmpConfig = {
				// Obviously this is for grids... not sure if this will cause problems
				// in the case of AppDVs
				sm: new Ext.grid.RowSelectionModel({singleSelect:true}),
				
				// Turn off store_autoLoad (we'll be loading on show and special actions):
				store_autoLoad: false,
				
				// Don't allow delete per default
				store_exclude_buttons: [ 'delete' ],
				
				// If add is allowed, we need to make sure it uses a window and NOT a tab
				use_add_form: 'window',
				
				// Make sure this is off to prevent trying to open a new record after being created
				// for this context we select the record after it is created
				autoload_added_record: false,
				
				// Put the add_btn in the tbar (which we override):
				tbar:[add_btn,'->'],
				
				// Modify the add_form when (if) it is prepared, setting text more specific to this 
				// context than its defaults:
				add_form_onPrepare: function(cfg) {
					cfg.title = '<span style="font-weight:bold;font-size:1.2em;" class="with-icon ra-icon-selection-add">' +
						'&nbsp;Add &amp; Select New ';
					if(field.header) { cfg.title += field.header; };
					cfg.title += '</span>';
					Ext.each(cfg.items.buttons,function(btn_cfg){
						if(btn_cfg.name == 'save') {
							Ext.apply(btn_cfg,{
								text: '<span style="font-weight:bold;font-size:1.1em;">&nbsp;Save &amp; Select</span>',
								iconCls: 'ra-icon-selection-new',
								width: 150
							});
						}
					},this);
					
					if(field.GLOBAL_add_form_onPrepare) {
						cfg.GLOBAL_add_form_onPrepare = 
							cfg.GLOBAL_add_form_onPrepare || field.GLOBAL_add_form_onPrepare;
						field.GLOBAL_add_form_onPrepare.call(field,cfg);
					}
				}
				
			};
			Ext.apply(cmpConfig,this.cmpConfig || {});
			
			
			win = new Ext.Window({
				buttonAlign: 'left',
				hidden: true,
				title: this.win_title,
				layout: 'fit',
				width: this.win_width,
				height: this.win_height,
				closable: true,
				closeAction: 'hide',
				modal: true,
				hideBorders: true,
				items: {
					GLOBAL_add_form_onPrepare: this.GLOBAL_add_form_onPrepare,
					xtype: 'autopanel',
					bodyStyle: 'border: none',
					hideBorders: true,
					itemId: 'app',
					autoLoad: autoLoad,
					layout: 'fit',
					cmpListeners: {
						afterrender: function(){
            
              // If this is a grid, take over its rowdblclick event to
              // make it call the select_fn function
              if(this.hasListener('rowdblclick')) {
                // Clear all existing rowdblclick events
                this.events.rowdblclick = true;
                this.on('rowdblclick',function(grid,rowIndex,e){
                  select_fn(null);
                },this);
              }
							
							// Save references in the window and field:
							win.app = this, field.appStore = this.store;
							
							// -- New feature added to AppGrid2. Make sure that our value field
							// is requested in the 'columns' param
							if(win.app.alwaysRequestColumns) {
								win.app.alwaysRequestColumns[field.displayField] = true;
								win.app.alwaysRequestColumns[field.valueField] = true;
							}
							// --
								
							// Add the 'first_records_cond' (new DbicLink2 feature) which will
							// move matching records, in our case, the current value, to the top.
							// this should make the currently selected row ALWAYS be the first item
							// in the list (on every page, under every sort, etc):
							this.store.on('beforeload',function(store,options) {
								var cond = this.get_first_records_cond_param();
								options.params.first_records_cond = cond;
							},field);
							
							// Safe function to call to load/reload the store:
							var fresh_load_fn = function(){
								
								if(win.app.view) { win.app.view.scrollToTop(); }
								
								// manually clear the quicksearch:
								if(this.quicksearch_plugin) {
									this.quicksearch_plugin.field.setValue('');
									this.store.purgeParams(['fields','query']);
								}
								
								// manually clear any multifilters:
								if(this.multifilter) {
									delete this.store.filterdata;
									delete this.store.filterdata_frozen;
									this.multifilter.updateFilterBtn.call(this.multifilter);
								}
								
								this.store.store_autoLoad ? this.store.load(this.store.store_autoLoad) :
									this.store.load();
							};
							
							// one-off load call if the window is already visible:
							win.isVisible() ? fresh_load_fn.call(this) : false;
							
							// Reload the store every time the window is shown:
							win.on('beforeshow',fresh_load_fn,this);
							
							
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
							
							this.store.on('load',function(){
								
								var value = this.getValue(), disp;

								// If the value is dirty, check if this load has the Record of the current
								// value, and if it does, opportunistically update the display:
								if(this.valueDirty) {
									disp = this.lookupDisplayValue(value);
									if(this.valueDirty) {
										// If the value is still dirty, but there is an entry in the cache,
										// update the display with it, since it is still the last known/best
										// value
										var disp_cache = this.displayCache[value];
										if(disp_cache) {
											// Call setData with the 'dirty' flag on:
											this.setData(value,disp_cache,true);
										}
									}
									else {
										// If the value is no longer dirty, disp must contain the needed 
										// display value, set it:
										this.setData(value,disp);
									}
								}
								else {
									// If the value is not currently marked as dirty, still do a lookup in the
									// store to opportunistically update it, in case the value has changed on
									// the backend since the first time we fetched it:
									delete this.lastDispRecordsLookupsFound;
									disp = this.lookupDispInRecords(value);
									if(this.lastDispRecordsLookupsFound) { 
										this.setData(value,disp);
									}
								}
								
								this.loadPending = false;
								
								if(Ext.isFunction(win.app.getSelectionModel)) {
									// If the current value is in the current Record cache, try to select the
									// row in the grid
									var sm = win.app.getSelectionModel();
									var index = this.findRecordIndex(value);
									if(index != -1) { 
										sm.selectRow(index);
										if(win.app.view){
											var rowEl = new Ext.Element(win.app.view.getRow(index));
											if(rowEl) { rowEl.addClass('ra-bold-grid-row'); }
										}
									}
									else {
										sm.clearSelections();
									}
								}
							},field);
							
							// "Move" the store add button to the outer window button toolbar:
							if(this.loadedStoreButtons && this.loadedStoreButtons.add) {
								var store_add_btn = this.loadedStoreButtons.add;
								add_btn.setHandler(store_add_btn.handler);
								add_btn.setVisible(true);
								store_add_btn.setVisible(false);
							}
							
							// Disable any loadTarget that is defined. This is a hackish way to disable
							// any existing double-click open setting. TODO: do this properly
							this.loadTargetObj = null;
							
						}
					},
					cmpConfig: cmpConfig,
					update_cmpConfig: update_cmpConfig
				},
				buttons: buttons,
				listeners: {
					hide: function(){
						field.onActionComplete.call(field);
						field.validate.call(field);
						//console.log('  win: hide (' + field.id + '/' + win.id + ')');
					},
					render: function(){
						//console.log('  win: render (' + field.id + '/' + win.id + ')');
					},
					beforedestroy: function(){
						//console.log('  win: beforedestroy (' + field.id + '/' + win.id + ')');
					}
				}
			});
			
			win.render(Ext.getBody());
			
			this.appWindow = win;
		}
		
		return this.appWindow;
	},
	
	get_first_records_cond_param: function() {
		var value = this.getValue();
		var rs_cond = {};
		var colname = this.valueField;
		if(colname.search(/__/) == -1) {
			// hackish, fixme. If there is no double-underscore (aka join) we add
			// 'me.' to prevent ambiguous column error. This is very specific to DbicLink2
			colname = 'me.' + colname;
		}
		if (value) { rs_cond[colname] = value; }
		return Ext.encode(rs_cond);
	},
	
	// This task sets up a custom Ajax query task to the server to lookup the display value
	// of a given value (id) value. For simplicity the store API is not used; a custom
	// read operation is simulated. This lookup is designed to work with a DbicApp2
	// backend. The process uses Ext.util.DelayedTask to wait until the store is ready,
	// and also to wait and see if a normal read is in progress if that might be able
	// to opportunistically resolve the display value, in which case the task is cancelled.
	// Also, since this is asynchronous, it checks at the various stages of processing to
	// see if the 'dirty' status (meaning the display value isn't available yet) has been
	// resolved, in which case this task aborts at whatever stage it is at. this is very 
	// efficient....
	queryResolveDisplayValue: function(value) {
		
		var delay = this.queryResolveInterval,
			valueField = this.valueField,
			displayField = this.displayField;
		
		if(this.queryTask) { this.queryTask.cancel(); }
		
		this.queryTask = new Ext.util.DelayedTask(function(){

			if(!this.valueDirty || !this.getValue()) { return; }
			
			var store = this.appStore;
			if(!this.rendered || !store || this.loadPending) { 
				return this.queryTask.delay(delay);
			}
			
			Ext.Ajax.request({
				url: store.api.read.url,
				method: 'POST',
				params: {
					columns: Ext.encode([this.displayField,this.valueField]),
					dir: 'ASC',
					start: 0,
					limit: 1,
					no_total_count: 1,
					resultset_condition: this.get_first_records_cond_param()
				},
				success: function(response,options) {
					
					if(!this.valueDirty) { return; }
					
					var res = Ext.decode(response.responseText);
					if(res.rows) {
						var row = res.rows[0];
						if(row) {
							var val = row[valueField], disp = row[displayField];
							
							if(val == this.getValue()) {
								this.setData(val,disp);
							}
						}
					}
				},
				scope: this
			});
			
		},this);
		
		this.queryTask.delay(delay);
	}
	
});
Ext.reg('datastore-app-field',Ext.ux.RapidApp.DataStoreAppField);


Ext.ux.RapidApp.ListEditField = Ext.extend(Ext.ux.RapidApp.ClickActionField,{
	
	fieldClass: 'ra-datastore-app-field wrap-on',
	invalidClass: 'ra-datastore-app-field-invalid',
	actionOnShow: true,
	
	delimiter: ',',
	padDelimiter: false, //<-- set ', ' instead of ','
	trimWhitespace: false, //<-- must be true if padDelimiter is true
	showSelectAll: true,
	value_list: [], //<-- the values that can be set/selected
	
	initComponent: function() {
		Ext.ux.RapidApp.ListEditField.superclass.initComponent.call(this);
		
		// init
		this.getMenu();
	},
	
	onActionComplete: function() {
		this.fireEvent.defer(50,this,['select']);
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
		
		this.showMenuAt(pos);
	},
	
	showMenuAt: function(pos) {
		var menu = this.getMenu();
		menu.showAt(pos);
	},
	
	setActiveList: function(list) {
		var delim = this.delimiter;
		if(this.padDelimiter) { delim += ' '; }
		return this.setValue(list.join(delim));
	},
	
	getActiveKeys: function(){
		var str = this.getValue();
		var map = {};
		var list = str.split(this.delimiter);
		Ext.each(list,function(item){
			if(this.trimWhitespace){ item = item.replace(/^\s+|\s+$/g,""); }
			map[item] = true;
		},this);
		
		this.activeKeys = map;
		return this.activeKeys
	},
	
	applyMenuSelections: function(){
		if(this.menu && this.menu.isVisible()){
			var selected = [];
			this.menu.items.each(function(item){
				if(item.checked && item.value) { 
					selected.push(item.value); 
				}
			},this);
			this.setActiveList(selected);
			this.menu.hide();
		}
	},
	
	updateMenu: function(){
		if(this.menu) {
			var selectall_item = this.menu.getComponent('select-all');
			if(selectall_item){ 
				// Reset select all to unchecked:
				selectall_item.setChecked(false); 
			}
			var keys = this.getActiveKeys();
			var all_checked = true;
			this.menu.items.each(function(item){
				if(item.value) {
					item.setChecked(keys[item.value]);
					if(!keys[item.value]) { all_checked = false; }
				}
			},this);
			
			if(selectall_item && all_checked){
				// Set the select all checkbox to true only if all items are
				// already checked:
				selectall_item.setChecked(true,false);
			}
		}
	},
	
	getSelectAllItem: function(){
		return {
			itemId: 'select-all',
			xtype: 'menucheckitem',
			text: 'Select All',
			hideOnClick: false,
			checked: false,
			listeners: {
				checkchange: {
					scope: this,
					fn: function(itm,state) {
						this.menu.items.each(function(item){
							if(item.value) { item.setChecked(state); }
						},this);
					}
				}
			}
		}
	},
	
	getValueList: function() {
		return this.value_list;
	},
	
	// Stops the last item from being unchecked (is only set as the
	// beforecheckchange item listeners if allowBlank is false)
	itemBeforeCheckHandler: function(item,checked) {
		var count = this.getCheckedCount();
		if(!checked && count == 1) { return false; }
	},
	
	getCheckedCount: function() {
		if(!this.menu && this.menu.isVisible()) { 
			return 0;
		};
		var count = 0;
		this.menu.items.each(function(item){
			if(item.value && item.checked) { count++; }
		},this);
		
		return count;
	},
	
	getMenu: function(){
		if(!this.menu) {
			var items = [];
			if(this.showSelectAll){ 
				items.push(this.getSelectAllItem(),'-'); 
			}
			
			Ext.each(this.getValueList(),function(val){
				var cnf = {
					xtype: 'menucheckitem',
					text: val,
					value: val,
					hideOnClick: false
				};
				// add listener to prevent last item from being unchecked if this
				// field is not nullable (allowBlank false):
				if(typeof this.allowBlank != 'undefined' && !this.allowBlank) {
					cnf.listeners = {
						beforecheckchange: {
							scope: this,
							fn: this.itemBeforeCheckHandler
						}
					};
				}
				items.push(cnf);
			},this);
			
			items.push('-',{
				style: 'font-weight:bold;color:#333333;',
				text: '&nbsp;OK',
				iconCls: 'ra-icon-accept',
				hideOnClick: false,
				handler: this.applyMenuSelections,
				scope: this
			});
			
			this.menu = new Ext.menu.Menu({
				items: items
			});
			
			this.menu.on('beforeshow',this.updateMenu,this);
			this.menu.on('hide',this.onActionComplete,this);
		}
		return this.menu;
	}
	
});
Ext.reg('list-edit-field',Ext.ux.RapidApp.ListEditField);





// Extends ListEditField to use a configured store to get the value list
Ext.ux.RapidApp.MultiCheckCombo = Ext.extend(Ext.ux.RapidApp.ListEditField,{
	
	initComponent: function() {
		Ext.ux.RapidApp.MultiCheckCombo.superclass.initComponent.call(this);
		this.store.on('load',this.onStoreLoad,this);
	},
	
	getMenu: function() {
		if(!this.storeLoaded) {
			// Don't allow the menu to be created before the store is loaded
			return null;
		}
		return Ext.ux.RapidApp.MultiCheckCombo.superclass.getMenu.apply(this,arguments);
	},
	
	onStoreLoad: function() {
		this.updateValueList();
		this.storeLoaded = true;
		if(this.pendingShowAt) {
			this.showMenuAt(this.pendingShowAt);
			delete this.pendingShowAt;
		}
	},
	
	updateValueList: function() {
		var value_list = [];
		this.store.each(function(Record){
			value_list.push(Record.data[this.valueField]);
		},this);
		this.value_list = value_list;
	},
	
	showMenuAt: function(pos) {
		if(!this.storeLoaded) {
			this.pendingShowAt = pos;
			return this.store.load();
		}
		return Ext.ux.RapidApp.MultiCheckCombo.superclass.showMenuAt.apply(this,arguments);
	}
	
});
Ext.reg('multi-check-combo',Ext.ux.RapidApp.MultiCheckCombo);



Ext.ux.RapidApp.HexField = Ext.extend(Ext.form.TextArea,{
  cls: 'ra-hex-string',
  getValue : function() {
    var v = Ext.ux.RapidApp.HexField.superclass.getValue.apply(this,arguments);
    // Strip all whitespace
    v = v.replace(/\s+/g, '');
    // Strip 0x prefix
    v = v.replace(/^0x/i, '');
    v = v.toLowerCase();
    return v.hex2bin();
  },

  setValue : function(v){
    var val = v ? Ext.ux.RapidApp.formatHexStr(v.bin2hex()) : v;
    return Ext.ux.RapidApp.HexField.superclass.setValue.apply(this,[val]);
  }
});
Ext.reg('ra-hexfield',Ext.ux.RapidApp.HexField);



