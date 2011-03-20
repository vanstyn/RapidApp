Ext.ns('Ext.ux.RapidApp.AppDV');

Ext.ux.RapidApp.AppDV.ClickBox = Ext.extend(Ext.ux.RapidApp.ClickBox, {
	setValue: function(val) {
		this.value = val;
	}
});
Ext.reg('appdv-clickbox', Ext.ux.RapidApp.AppDV.ClickBox);

Ext.ux.RapidApp.AppDV.afterrender_handler = function(dv) {
	this.ModuleCmp = {};
	
	var dvEl = dv.getEl();
	console.log(dv.itemSelector);
	var selectorEl = dvEl.child(dv.itemSelector);
	console.dir(selectorEl);
	
	
	if(Ext.isObject(this.ModuleCmp_cnf)) {
		Ext.iterate(this.ModuleCmp_cnf,function(module,cnf){
			
			console.log(cnf.renderToSelector);
			
			//console.dir(dvEl);
			
			console.dir(dvEl.child('div.appdv-submodule'));
			
			var renderDiv = dvEl.child(cnf.renderToSelector);
			console.dir(renderDiv);
			
			cnf.renderTo = renderDiv;
			
			this.ModuleCmp[module] = Ext.ComponentMgr.create(cnf,'panel');
			this.ModuleCmp[module].show();
		},this);
	}
}

Ext.ux.RapidApp.AppDV.edit_field_handler = function(field,args) {
	console.log(field + ': ' + this.value);
	var e = args[1];
	var parent = e.parentNode;
	
	console.dir(parent);
	//console.log('Ext.ux.RapidApp.AppDV.edit_field_handler');
	console.dir(args);
}


Ext.ns('Ext.ux.form');
Ext.ux.form.FieldTip = Ext.extend(Object, {
    init: function(field){
        field.on({
            focus: function(){
                if(!this.tip){
                    this.tip = new Ext.Tip({
                        title: this.qtitle,
                        html: this.qtip,
                    });
                }
                this.tip.showBy(this.el, 'tl-tr?');
            },
            blur: function(){
                if(this.tip){
                    this.tip.hide();
                }
            },
            destroy: function(){
                if(this.tip){
                    this.tip.destroy();
                    delete this.tip;
                }
            }
        });
    }
});
Ext.preg('fieldtip', Ext.ux.form.FieldTip);





Ext.ux.RapidApp.AppDV.click_handler = function(dv, index, domEl, event) {
	var target = event.getTarget(null,null,true);

	console.dir(target);

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
		dv.FieldCmp[index][fieldname].destroy();
		dataEl.setVisible(true);
	}
	else {
		valueEl.addClass('editing');
		
		var cnf = {};
		Ext.apply(cnf,dv.FieldCmp_cnf[fieldname]);
		Ext.apply(cnf,{
			value: Record.data[fieldname],
			//renderTo: valueEl
			renderTo: fieldEl
		});
		
		if(!cnf.width) {
			cnf.width = dataEl.getWidth();
		}
		
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


