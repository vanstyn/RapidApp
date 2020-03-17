Ext.ns('Ext.ux.RapidApp.layout');

/*
  Custom Toolbar layout - currently only extends overflow menu to
  include text items ('tbtext' specifically)
*/
Ext.ux.RapidApp.layout.ToolbarLayout = Ext.extend(Ext.layout.ToolbarLayout, {

  type: 'ra_toolbar',
 
  // WARNING: this is a private method, so the API could change in
  // the future. This is written specifically for ExtJS 3.4.0.
  addComponentToMenu : function(menu, component) {
  
        if (component instanceof Ext.Toolbar.Separator) {
            menu.add('-');

        } else if (Ext.isFunction(component.isXType)) {
            if (component.isXType('splitbutton')) {
                menu.add(this.createMenuConfig(component, true));

            } else if (component.isXType('button')) {
                menu.add(this.createMenuConfig(component, !component.menu));

            } else if (component.isXType('buttongroup')) {
                component.items.each(function(item){
                     this.addComponentToMenu(menu, item);
                }, this);
            }
            
            // -- Extended functionality:
            else if (component.isXType('tbtext')) {
              var cnf = this.createMenuConfig(component, !component.menu);
              cnf.text = component.el.dom.innerHTML;
              menu.add(cnf);
            }
            // --
        }
    }
});

Ext.Container.LAYOUTS.ra_toolbar = Ext.ux.RapidApp.layout.ToolbarLayout;
