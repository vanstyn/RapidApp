/*
 http://www.sencha.com/forum/showthread.php?79210-ComponentDataView-Ext-components-inside-a-dataview-or-listview
*/

Ext.ns('Ext.ux');
Ext.ux.ComponentDataView = Ext.extend(Ext.DataView, {
    defaultType: 'textfield',
    initComponent : function(){
        Ext.ux.ComponentDataView.superclass.initComponent.call(this);
        this.components = [];
    },
    refresh : function(){
        Ext.destroy(this.components);
        this.components = [];
        Ext.ux.ComponentDataView.superclass.refresh.call(this);
        this.renderItems(0, this.store.getCount() - 1);
    },
    onUpdate : function(ds, record){
        var index = ds.indexOf(record);
        if(index > -1){
            this.destroyItems(index);
        }
        Ext.ux.ComponentDataView.superclass.onUpdate.apply(this, arguments);
        if(index > -1){
            this.renderItems(index, index);
        }
    },
    onAdd : function(ds, records, index){
        var count = this.all.getCount();
        Ext.ux.ComponentDataView.superclass.onAdd.apply(this, arguments);
        if(count !== 0){
            this.renderItems(index, index + records.length - 1);
        }
    },
    onRemove : function(ds, record, index){
        this.destroyItems(index);
        Ext.ux.ComponentDataView.superclass.onRemove.apply(this, arguments);
    },
    onDestroy : function(){
        Ext.ux.ComponentDataView.onDestroy.call(this);
        Ext.destroy(this.components);
        this.components = [];
    },
    renderItems : function(startIndex, endIndex){
        var ns = this.all.elements;
        var args = [startIndex, 0];
        for(var i = startIndex; i <= endIndex; i++){
            var r = args[args.length] = [];
            for(var items = this.items, j = 0, len = items.length, c; j < len; j++){
                c = items[j].render ?
                    c = items[j].cloneConfig() :
                    Ext.create(items[j], this.defaultType);
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
Ext.reg('compdataview', Ext.ux.ComponentDataView);