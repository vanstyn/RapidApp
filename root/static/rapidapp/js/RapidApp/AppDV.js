Ext.ns('Ext.ux.RapidApp.AppDV');


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



Ext.ux.RapidApp.AppDV.DataView = Ext.extend(Ext.DataView, {
	 //defaultType: 'textfield',
	 initComponent : function(){
			Ext.each(this.items,function(item) {
				item.ownerCt = this;
			},this);
			Ext.ux.RapidApp.AppDV.DataView.superclass.initComponent.call(this);
			this.components = [];
	 },
	 
	 refresh : function(){
		  Ext.destroy(this.components);
		  this.components = [];
		  Ext.ux.RapidApp.AppDV.DataView.superclass.refresh.call(this);
		  this.renderItems(0, this.store.getCount() - 1);
	 },
	 onUpdate : function(ds, record){
		  var index = ds.indexOf(record);
		  if(index > -1){
				this.destroyItems(index);
		  }
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onUpdate.apply(this, arguments);
		  if(index > -1){
				this.renderItems(index, index);
		  }
	 },
	 onAdd : function(ds, records, index){
		  var count = this.all.getCount();
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onAdd.apply(this, arguments);
		  if(count !== 0){
				this.renderItems(index, index + records.length - 1);
		  }
	 },
	 
	 onRemove : function(ds, record, index){
		  this.destroyItems(index);
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onRemove.apply(this, arguments);
	 },
	 onDestroy : function(){
		  Ext.ux.RapidApp.AppDV.DataView.superclass.onDestroy.call(this);
		  Ext.destroy(this.components);
		  this.components = [];
	 },
	 renderItems : function(startIndex, endIndex){
		  var ns = this.all.elements;
		  var args = [startIndex, 0];
		  for(var i = startIndex; i <= endIndex; i++){
				var r = args[args.length] = [];
				for(var items = this.items, j = 0, len = items.length, c; j < len; j++){
				
					// c = items[j].render ?
					//	  c = items[j].cloneConfig() :
						
						// RapidApp specific:
						// Components are stored as serialized JSON to ensure they
						// come out exactly the same every time:
						c = Ext.create(Ext.decode(items[j]), this.defaultType);
						  
					 r[j] = c;
					 if(c.renderTarget){
						  c.render(Ext.DomQuery.selectNode(c.renderTarget, ns[i]));
					 }else if(c.applyTarget){
						  c.applyToMarkup(Ext.DomQuery.selectNode(c.applyTarget, ns[i]));
					 }else{
						  c.render(ns[i]);
					 }
					 
					 if(Ext.isFunction(c.setValue) && c.applyValue){
						  c.setValue(this.store.getAt(i).get(c.applyValue));
						  c.on('blur', function(f){
							this.store.getAt(this.index).data[this.dataIndex] = f.getValue();
						  }, {store: this.store, index: i, dataIndex: c.applyValue});
					 }
					 
				}
		  }
		  this.components.splice.apply(this.components, args);
	 },
	 destroyItems : function(index){
		  Ext.destroy(this.components[index]);
		  this.components.splice(index, 1);
	 }
});
Ext.reg('appdv', Ext.ux.RapidApp.AppDV.DataView);


