Ext.ns('Ext.ux.RapidApp.AppDV');

Ext.ux.RapidApp.AppDV.ClickBox = Ext.extend(Ext.ux.RapidApp.ClickBox, {
	setValue: function(val) {
		this.value = val;
	}
});
Ext.reg('appdv-clickbox', Ext.ux.RapidApp.AppDV.ClickBox);


Ext.ux.RapidApp.AppDV.edit_field_handler = function(field,args) {
	console.log(field + ': ' + this.value);
	var e = args[1];
	var parent = e.parentNode;
	
	console.dir(parent);
	//console.log('Ext.ux.RapidApp.AppDV.edit_field_handler');
	console.dir(args);
}


Ext.ux.RapidApp.AppDV.click_handler = function(dv, index, domEl, event) {
	var target = event.getTarget(null,null,true);

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
	console.log(fieldname);
	
	var topEl = new Ext.Element(domEl);
	
	//console.dir(topEl);
	
	var valueEl = topEl.child('div.appdv-field-value.' + fieldname);
	//if (!valueEl) { return; }
	
	var dataEl = valueEl.child('div.data');
	var Store = dv.getStore()
	var Record = Store.getAt(index);
	
	if (valueEl.hasClass('editing')) {
	
		var Field = dv.FieldCmp[index][fieldname];
		var val = Field.getValue();
	
		Record.set(fieldname,val);
		//Record.commit();
		Store.save();
	
		valueEl.removeClass('editing');
		dv.FieldCmp[index][fieldname].destroy();
		dataEl.setVisible(true);
	}
	else {
		valueEl.addClass('editing');
		
		var cnf = {};
		Ext.apply(cnf,dv.FieldCmp_cnf[fieldname]);
		Ext.apply(cnf,{
			value: Record.data[fieldname],
			renderTo: valueEl
		});
		
		var Field = Ext.ComponentMgr.create(cnf,'field');

		if(Field.resizable) {
			var resizer = new Ext.Resizable(Field.wrap, {
				pinned: true,
				handles: 's,e,se',
				width: 600,
				height: 200,
				minWidth: 600,
				minHeight: 200,
				dynamic: true,
				listeners : {
					'resize' : function(resizable, height, width) {
						Field.setSize(height,width);
					}
				}
			});
		}


		
		dataEl.setVisibilityMode(Ext.Element.DISPLAY);
		dataEl.setVisible(false);
		Field.show();
		if(!Ext.isObject(dv.FieldCmp)) { dv.FieldCmp = {} }
		if(!Ext.isObject(dv.FieldCmp[index])) { dv.FieldCmp[index] = {} }
		dv.FieldCmp[index][fieldname] = Field;
		
	}
	

}


