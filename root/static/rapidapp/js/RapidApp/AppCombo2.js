
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
				if (addclass) { 
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
Ext.ux.RapidApp.StaticCombo = Ext.extend(Ext.form.ComboBox,{
	mode: 'local',
	triggerAction: 'all',
	editable: false,
	value_list: false, //<-- set value_list to an array of the static values for the combo dropdown
	valueField: 'valueField',
	displayField: 'displayField',
	initComponent: function() {
		if (this.value_list) {
			var data = [];
			Ext.each(this.value_list,function(item,index){
				//data.push([index,item]);
				data.push([item,item]); //<-- valueField and displayField are identical
			});
			this.store = new Ext.data.ArrayStore({
				fields: [
					this.valueField,
					this.displayField
				],
				data: data
			});
		}
		Ext.ux.RapidApp.StaticCombo.superclass.initComponent.apply(this,arguments);
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
		
		if(this.actionOnShow) {
			this.callActionFn();
		}
	},
	
	callActionFn: function() {
		if(this.actionRunning) { return; }
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
		//this.actionRunning = false;
		this.callActionFn(e);
	},
	
	// Make us look like a combo with an 'expand' function:
	expand: function(){
		this.callActionFn();
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
		if(typeof itm == "undefined") { return; }

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
						hideOnClick: true,
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
					scope:this,
					
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
				this.selectValue(this.getValue());
			},this);
			/*************************************************/
			
			this.clickMenu.on('show',this.updateItemsStyles,this);
			
		}
		return this.clickMenu;
	},
	
	actionFn: function() {
		
		var pos = this.getEl().getXY();
		
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
	
	uploadUrl: '/simplecas/upload_image',
	
	maxImageWidth: null,
	
	resizeWarn: true,
	
	minHeight: 2,
	minWidth: 2,
	
	getUploadUrl: function() {
		url = this.uploadUrl;
		if(this.maxImageWidth) { url += '/' + this.maxImageWidth; }
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



