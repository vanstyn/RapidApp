/**
 * FormPanel plugin for fields autoWidth
 *
 * Include it in your FormPanel as plugin and set field width to 'auto' - it will
 * automatically expand all your fields to match FormPanel container width.
 *
 * @author    Artur Bodera
 * @date      27 March 2008
 *
 * @license Ext.ux.form.FieldAutoExpand is licensed under the terms of
 * the Open Source LGPL 3.0 license.  Commercial use is permitted to the extent
 * that the code/component(s) do NOT become part of another Open Source or Commercially
 * licensed development library or toolkit without explicit permission.
 * 
 * License details: http://www.gnu.org/licenses/lgpl.html
 */
 
/*global Ext */
 
Ext.ns('Ext.ux.form');
 
/**
 * @class Ext.ux.form.FieldAutoExpand
 * @extends Ext.util.Observable
 *
 * Creates new FieldAutoExpand plugin
 * @constructor
 * @param {Object} config The config object
 */
Ext.ux.form.FieldAutoExpand = function(config) {
	Ext.apply(this, config);
 
	// {{{
	this.addEvents(
		/**
		 * @event autoexpand
		 * Fires after auto expanding (shrinking) a field.
		 * @param {Ext.form.Field} field
		 * @param {Number} new width
		 * @param {Ext.ux.form.FieldAutoExpand} plugin object
		 */
		 'autoexpand',
 
		 /**
		 * @event beforeautoexpand
		 * Fires just before field is auto expanded (shrunk). Return false to stop expanding.
		 * @param {Ext.form.Field} field
		 * @param {Number} new width
		 * @param {Ext.ux.form.FieldAutoExpand} plugin object
		 */
		 'beforeautoexpand'
	);
 
	Ext.ux.form.FieldAutoExpand.superclass.constructor.call(this);
};
 
Ext.extend(Ext.ux.form.FieldAutoExpand, Ext.util.Observable, {
 
	// configuration options
	// {{{
	/**
	 * @cfg {Number} offsetFix	Amount of pixels to add (substract) due to elements offset.
	 */
	offsetFix: -10,
 
	/**
	 * @cfg {Number} labelOffsetFix Amount of pixels to add (substract) when label is visible.
	 */
	labelOffsetFix: -5,
 
	/**
	 * @cfg {Number} sideMsgFix Amount of pixels to add (substract) for the field validation icon
	 */
	sideMsgFix: -25,
 
	/**
	 * @cfg {Number} FieldAutoExpand Maximum field width
	 */
	autoExpandMax: 0,
 
 
	// methods
	// {{{
	/**
	 * Init function
	 * @param {Ext.form.FormPanel} formPanel Parent panel for this plugin
	 */
	init:function(formPanel) {
		this.panel = formPanel;
		this.form = this.panel.getForm();
		this.autoWidthFields = [];
		this.panel.on('afterlayout',this.init2,this,{single:true});
		this.panel.on('add',this.init2,this);
		this.panel.on('remove',this.init2,this);
 
	}, // eo function init
 
	// }}}
 
	// {{{
	/**
	 * Scans fields and prepares listener
	 * @private
	 */
	init2:function(){
		this.autoWidthFields = [];
		this.form.items.each(function(f){
			if((f.width == 'auto' || !f.width) && !f.grow)
				this.autoWidthFields[this.autoWidthFields.length] = f;
		},this);
 
		// Adjusts field widths when laying out elements.
		this.panel.on('afterlayout',this.fitWidths,this);
	}, // eo function init2
	// }}}
	// {{{
	/**
	 * Adjusts field widths.
	 * @private
	 */
	fitWidths:function() {
		Ext.each(this.autoWidthFields,function(f){
			if(!this.width1){
				// field width if the label is hidden
				this.width4 = this.form.getEl().down('.x-form-item').getSize(true).width + this.offsetFix;
 
				// field width if the label is hidden and there is validation icon on the side
				this.width3 = this.width4 + this.sideMsgFix;
 
				// field width if the label is visible
				this.width2 = this.width4 - this.panel.labelWidth + this.labelOffsetFix;//
 
				// field width if the label is visible and we have validation icon on the side
				this.width1 = this.width2 + this.sideMsgFix;			
			}
 
			if(!f.hideLabel){	
				if(f.msgTarget == 'side')
					var width = this.width1;
				else
					var width = this.width2;
			}else{
				if(f.msgTarget == 'side')
					var width = this.width3;
				else
					var width = this.width4;
			}
 
			if(this.autoExpandMax && width > this.autoExpandMax)
				width = this.autoExpandMax;
			if(f.autoExpandMax && width > f.autoExpandMax)
				width = f.autoExpandMax;
 
			if(true !== this.eventsSuspended && false === this.fireEvent('beforeautoexpand', f, width,this)) {
				return;
			}else{
				f.setWidth(width);
				this.fireEvent('autoexpand', f, width,this);
			}
		},this);
 
		this.width1 = 0;
	} // eo function fitWidths
	// }}}
});
 
// register xtype
Ext.reg('fieldautoexpand', Ext.ux.form.FieldAutoExpand);
 
// eof