Ext.namespace('Ext.ux.form.HtmlEditor');

Ext.Toolbar.Break = Ext.extend(Ext.Toolbar.Item, {
  render: Ext.emptyFn,
  isBreak: true
});
Ext.reg('tbbreak', Ext.Toolbar.Break);

Ext.apply(Ext.layout.ToolbarLayout.prototype, {
  onLayout: function(ct, target) {
    var tableIndex = 0, targetTable;
    var layout = this;
    function cleanupRows() {
      layout.cleanup(layout.leftTr);
      layout.cleanup(layout.rightTr);
      layout.cleanup(layout.extrasTr);
    }
    function nextTable() {
      if (!target.dom.childNodes[tableIndex]) {
        var align = ct.buttonAlign == 'center' ? 'center' : 'left';
        target.insertHtml('beforeEnd', String.format(layout.tableHTML, align));
      }
      targetTable = Ext.fly(target.dom.childNodes[tableIndex]);
      if (tableIndex) {
        cleanupRows();
        targetTable.addClass('x-toolbar-add-row');
      }
      tableIndex++;
      layout.leftTr   = targetTable.child('tr.x-toolbar-left-row', true);
      layout.rightTr  = targetTable.child('tr.x-toolbar-right-row', true);
      layout.extrasTr = targetTable.child('tr.x-toolbar-extras-row', true);
      layout.side = ct.buttonAlign == 'right' ? layout.rightTr : layout.leftTr;
    }
    if (!this.leftTr) {
      target.addClass('x-toolbar-layout-ct');
      if (this.hiddenItem === undefined) {
        this.hiddenItems = [];
      }
    }
    nextTable();
    var items = ct.items.items, position = 0;
    for (var i = 0, len = items.length, c; i < len; i++, position++) {
      c = items[i];
      if (c.isBreak) {
        nextTable();
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
    cleanupRows();
    this.fitToSize(target);
  }
});

Ext.apply(Ext.Toolbar.prototype, {
  lookupComponent: function(c) {
    if (Ext.isString(c)) {
      if (c == '.') {
        c = new Ext.Toolbar.Break();
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
  addBreak: function() {
    this.add(new Ext.Toolbar.Break());
  }
});

Ext.ux.form.HtmlEditor.Break = function() {
  var editor;
  return {
    init: function(htmlEditor) {
      editor = htmlEditor;
      editor.on('render', function() {
        editor.getToolbar().addBreak();
      }, this);
    }
  };
};
