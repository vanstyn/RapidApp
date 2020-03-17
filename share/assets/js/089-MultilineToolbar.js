
/*
 *
 * Taken from http://www.sencha.com/forum/showthread.php?109569-Multiline-Toolbar-Extension&highlight=HtmlEditor+css
 *
*/

Ext.Toolbar.Break = Ext.extend(Ext.Toolbar.Item, {
  render: Ext.emptyFn,
  isBreak: true
});

Ext.reg('tbbreak', Ext.Toolbar.Break);

Ext.apply(Ext.Toolbar.prototype, {

  // Override the lookupComponent code to cater for the Break Item
  lookupComponent: function(c) {
    if (Ext.isString(c)) {

      // New code
      if (c == '.') {
        c = new Ext.Toolbar.Break();

      // Existing code
      } else if (c == '-') {
        c = new Ext.Toolbar.Separator();
      } else if (c == ' ') {
        c = new Ext.Toolbar.Spacer();
      } else if (c == '->') {
        c = new Ext.Toolbar.Fill();
      } else {
        c = new Ext.Toolbar.TextItem(c);
      }
      this.applyDefaults(c);
    } else {
      if (c.isFormField || c.render) {
        c = this.createComponent(c);
      } else if (c.tag) {
        c = new Ext.Toolbar.Item({autoEl: c});
      } else if (c.tagName) {
        c = new Ext.Toolbar.Item({el:c});
      } else if (Ext.isObject(c)) {
        c = c.xtype ? this.createComponent(c) : this.constructButton(c);
      }
    }
    return c;
  },

  // Add a function for adding a Break item
  addBreak: function() {
    this.add(new Ext.Toolbar.Break());
  }
  
});

// Override existing Toolbar onLayout with enhanced layout functionality
// Overriding the function makes it available to all toolbars
Ext.apply(Ext.layout.ToolbarLayout.prototype, {

  // onLayout is the function to override
  onLayout: function(ct, target) {
    var tableIndex = 0, targetTable;
    var layout = this;

    // Function to cleanup toolbar rows
    // Was previously called once but is now called for each toolbar table
    function cleanupRows() {
      layout.cleanup(layout.leftTr);
      layout.cleanup(layout.rightTr);
      layout.cleanup(layout.extrasTr);
    }

    // Function to add a new toolbar table
    // Is called for each toolbar row
    function nextTable() {

      // Create new table if not already created (could have been added after render)
      if (!target.dom.childNodes[tableIndex]) {
        var align = ct.buttonAlign == 'center' ? 'center' : 'left';
        target.insertHtml('beforeEnd', String.format(layout.tableHTML, align));
      }

      // Focus on current table
      targetTable = Ext.fly(target.dom.childNodes[tableIndex]);

      // If second or greater table then clean up previous table
      // and add a class that adds a spacer between tables
      if (tableIndex) {
        cleanupRows();
        targetTable.addClass('x-toolbar-add-row');
      }

      // Increment table index
      tableIndex++;

      // Assign specific row handlers
      layout.leftTr   = targetTable.child('tr.x-toolbar-left-row', true);
      layout.rightTr  = targetTable.child('tr.x-toolbar-right-row', true);
      layout.extrasTr = targetTable.child('tr.x-toolbar-extras-row', true);
      layout.side = ct.buttonAlign == 'right' ? layout.rightTr : layout.leftTr;
    }

    // If running for the first time, perform necessary functionality
    if (!this.leftTr) {
      target.addClass('x-toolbar-layout-ct');
      if (this.hiddenItem == undefined) {
        this.hiddenItems = [];
      }
    }

    // Create and/or select first toolbar table
    nextTable();

    // Loop though toolbar items
    var items = ct.items.items, position = 0;
    for (var i = 0, len = items.length, c; i < len; i++, position++) {
      c = items[i];

      // If item is the new toolbar break item then...
      if (c.isBreak) {

        // ...create and/or select additional toolbar table
        nextTable();

      // Existing code...
      } else if (c.isFill) {
        this.side = this.rightTr;
        position = -1;
      } else if (!c.rendered) {
        c.render(this.insertCell(c, this.side, position));
      } else {
        if (!c.xtbHidden && !this.isValidParent(c, this.side.childNodes[position])) {
          var td = this.insertCell(c, this.side, position);
          td.appendChild(c.getPositionEl().dom);
          c.container = Ext.get(td);
        }
      }
    }

    // Clean up last toolbar table
    cleanupRows();

    this.fitToSize(target);
  }
});


Ext.ux.form.HtmlEditor.Break = function() {

  // PRIVATE

  // pointer to Ext.form.HtmlEditor
  var editor;

  // Render Toolbar Break
  function onRender() {
    editor.getToolbar().addBreak();
  }

  // PUBLIC

  return {

    // Ext.ux.form.HtmlEditor.Break.init
    // called upon instantiation
    init: function(htmlEditor) {
      editor = htmlEditor;

      // Call onRender when Toolbar rendered
      editor.on('render', onRender, this);
    }
  }
};
