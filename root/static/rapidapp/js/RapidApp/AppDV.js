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
	var clickParent = target.parent('div.appdv-click-el');
	if(!clickParent) { return; }
	
	var node = clickParent.dom;
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
	
	console.dir(valueEl);
	
	
	
	//console.dir(clickParent);
	
	var Record = dv.getStore().getAt(index);
	
	//console.dir(event);
	
	
	//var target = event.getTarget();
	//console.dir(htmlEl);
	//console.dir(target);
	
	
	//console.dir(event.getRelatedTarget());
	
	//console.dir(Record);
	//console.dir(arguments);

}


