
// --------
// http://www.sencha.com/forum/showthread.php?33475-Tip-Long-menu-overflow/page2
Ext.override(Ext.menu.Menu, {
    // See http://extjs.com/forum/showthread.php?t=33475&page=2
    showAt : function(xy, parentMenu, /* private: */_e) {
        this.parentMenu = parentMenu;
        if (!this.el) {
            this.render();
        }
        if (_e !== false) {
            this.fireEvent("beforeshow", this);
            xy = this.el.adjustForConstraints(xy);
        }
        this.el.setXY(xy);

        // Start of extra logic to what is in Ext source code...
        // See http://www.extjs.com/deploy/ext/docs/output/Menu.jss.html
        // get max height from body height minus y cordinate from this.el
        var maxHeight = this.maxHeight || Ext.getBody().getHeight() - xy[1];
        if (this.el.getHeight() > maxHeight) {
            // set element with max height and apply vertical scrollbar
            this.el.setHeight(maxHeight);
            this.el.applyStyles('overflow-y: auto;');
        }
        // .. end of extra logic to what is in Ext source code

        this.el.show();
        this.hidden = false;
        this.focus();
        this.fireEvent("show", this);
    },
	 
	// Added 2012-04-02 by HV: further turn off the default tiny menu scroller functions:
	enableScrolling: false
	 
});
// --------


// Mouse-over/hover fix:
// http://www.sencha.com/forum/showthread.php?69090-Ext.ux.form.SuperBoxSelect-as-seen-on-facebook-and-hotmail&p=515731#post515731
Ext.override(Ext.ux.form.SuperBoxSelectItem, {
	enableElListeners : function() {
		this.el.on('click', this.onElClick, this, {stopEvent:true});
		//this.el.addClassOnOver('x-superboxselect-item x-superboxselect-item-hover');
		this.el.addClassOnOver('x-superboxselect-item-hover');
	}
});


// Override to get rid of the input cursor if editable is false
Ext.override(Ext.ux.form.SuperBoxSelect,{
	initComponent_orig: Ext.ux.form.SuperBoxSelect.prototype.initComponent,
	initComponent: function () {
		this.initComponent_orig.apply(this,arguments);
		this.on('afterrender',function(combo) {
			if(combo.editable === false && combo.hideInput === true) {
				combo.inputEl.removeClass("x-superboxselect-input");
				combo.inputEl.setVisible(false);
			}
		});
	}
});


/**
 * We override Connection so that **Every** AJAX request gets our processing added to it.
 * We first set up a closure that can re-issue the current request, and then check headers
 *   to see if we want to interrupt the current one.
 */
Ext.override(Ext.data.Connection,{
	//request_orig: Ext.data.Connection.prototype.request,
	//request: function(opts) {
	//	return this.request_orig(opts);
	//},
	
	handleResponse_orig: Ext.data.Connection.prototype.handleResponse,
	handleResponse : function(response){
		this.fireEvent('requestcomplete',this,response,response.argument.options);
		
		var options = response.argument.options;
		
		var thisConn = this;
		var success_callback_repeat = function(newopts) {
			// Optional changes/additions to the original request options:
			if(Ext.isObject(newopts)) {
				Ext.iterate(newopts,function(key,value){
					Ext.apply(options[key],value);
				});
			}
			thisConn.request(options);
		};
		
		var orig_args= arguments;
		var current_callback_continue= function() { thisConn.handleResponse_orig.apply(thisConn,orig_args); };
		
		Ext.ux.RapidApp.handleCustomServerDirectives(response, current_callback_continue, success_callback_repeat);
	},
	
	doFormUpload_orig: Ext.data.Connection.prototype.doFormUpload,
	doFormUpload : function(o, ps, url){
		var thisConn= this;
		var success_callback_repeat = function(newopts) {
			// Optional changes/additions to the original request options:
			if(Ext.isObject(newopts)) {
				Ext.iterate(newopts,function(key,value){
					Ext.apply(o[key],value);
				});
			}
			thisConn.doFormUpload(o, ps, url);
		};
		
		// had to copy/paste from Ext.data.Connection, since there were no smaller routines to subclass...
		var id = Ext.id(),
			doc = document,
			frame = doc.createElement('iframe'),
			form = Ext.getDom(o.form),
			hiddens = [],
			hd,
			encoding = 'multipart/form-data',
			buf = {
				target: form.target,
				method: form.method,
				encoding: form.encoding,
				enctype: form.enctype,
				action: form.action
			};
		
		Ext.fly(frame).set({
			id: id,
			name: id,
			cls: 'x-hidden',
			src: Ext.SSL_SECURE_URL
		}); 
		
		doc.body.appendChild(frame);
		
		if(Ext.isIE){
			document.frames[id].name = id;
		}
		
		Ext.fly(form).set({
			target: id,
			method: 'POST',
			enctype: encoding,
			encoding: encoding,
			action: url || buf.action
		});
		
		var addParam= function(k, v){
			hd = doc.createElement('input');
			Ext.fly(hd).set({
				type: 'hidden',
				value: v,
				name: k
			});
			form.appendChild(hd);
			hiddens.push(hd);
		};
		
		addParam('RequestContentType', 'text/x-rapidapp-form-response');
		Ext.iterate(Ext.urlDecode(ps, false), addParam);
		if (o.params)
			Ext.iterate(o.params, addParam);
		if (o.headers)
			Ext.iterate(o.headers, addParam);
		
		function cb(){
			var me = this,
				r = {responseText : '',
					responseXML : null,
					responseHeaders : {},
					getResponseHeader: function(key) { return this.responseHeaders[key]; },
					argument : o.argument},
				doc,
				firstChild;
			
			try{
				doc = frame.contentWindow.document || frame.contentDocument || WINDOW.frames[id].document;
				if(doc){
					// Here, we modify the ExtJS stuff to also include out-of-band data that would normally be
					//   in the headers.  We store it in a second textarea
					var header_json_textarea= doc.getElementById('header_json');
					var json_textarea= doc.getElementById('json');
					
					if (header_json_textarea) {
						r.responseHeaderJson= header_json_textarea.value;
						r.responseHeaders= Ext.decode(r.responseHeaderJson) || {};
					}
					
					if (json_textarea) {
						r.responseText= json_textarea.value;
					}
					else if (doc.body) {
						if(/textarea/i.test((firstChild = doc.body.firstChild || {}).tagName)){ 
							r.responseText = firstChild.value;
						}else{
							r.responseText = doc.body.innerHTML;
						}
					}
					
					r.responseXML = doc.XMLDocument || doc;
				}
			}
			catch(e) {}
			
			Ext.EventManager.removeListener(frame, 'load', cb, me);
			
			me.fireEvent('requestcomplete', me, r, o);
			
			function current_callback_continue(fn, scope, args){
				if(Ext.isFunction(o.success)) o.success.apply(o.scope, [r, o]);
				if(Ext.isFunction(o.callback)) o.callback.apply(o.scope, [o, true, r]);
			}
			
			Ext.ux.RapidApp.handleCustomServerDirectives(r, current_callback_continue, success_callback_repeat);
			
			if(!me.debugUploads){
				setTimeout(function(){Ext.removeNode(frame);}, 100);
			}
		}
		
		Ext.EventManager.on(frame, 'load', cb, this);
		form.submit();
		
		Ext.fly(form).set(buf);
		Ext.each(hiddens, function(h) {
			Ext.removeNode(h);
		});
	}
});





Ext.override(Ext.BoxComponent, {
	initComponent: function() {


		// All-purpose override allowing eval code in config
		var thisB = this;
		if (thisB.afterRender_eval) { this.on('afterrender', function() { eval(thisB.afterRender_eval); }) }
		var config = this;
		if (this.init_evalOverrides) {
			for ( var i in this.init_evalOverrides ) {
				config[i] = eval(this.init_evalOverrides[i]);
			}
			Ext.apply(this, Ext.apply(this.initialConfig, config));
		}
		Ext.BoxComponent.superclass.initComponent.apply(this, arguments);
	}
	//,afterRender: function() {
		//this.superclass.afterRender.call(this);
	//	if (this.afterRender_eval) { eval(this.afterRender_eval); }

	//}
});



Ext.override(Ext.Container, {
	onRender: function() {
		Ext.Container.superclass.onRender.apply(this, arguments);
		
		if (this.onRender_eval) { eval(this.onRender_eval); }

		var thisC = this;

		if (this.ajaxitems && Ext.isArray(this.ajaxitems)) {

			for (i in this.ajaxitems) {
				if (this.ajaxitems[i]['url']) {

					alert(this.ajaxitems[i]['url']);

					Ext.Ajax.request({
						disableCaching: true,
						url: this.ajaxitems[i]['url'],
						params: this.ajaxitems[i]['params'],
						success: function(response, opts) {
							var imported_data = eval('(' + response.responseText + ')');
							thisC.add(new Ext.Container(imported_data));
							thisC.doLayout();
						},
						failure: function(response, opts) {
							alert('AJAX ajaxitems FAILED!!!!!!');
						}
					});
				}
			}
		}
	}
});




Ext.override(Ext.ux.grid.GridFilters, {

	initOrig: Ext.ux.grid.GridFilters.prototype.init,

	init: function(grid) {
		this.initOrig.apply(this, arguments);

		if (this.init_state) {

			for (i in this.init_state.filters) {
				for (p in this.init_state.filters[i]) {
					var orig = this.init_state.filters[i][p];
					if (p == 'before' || p == 'after' || p == 'on') {
						this.init_state.filters[i][p] = Date.parseDate(orig,"Y-m-d\\TH:i:s");
					}
				}
			}

			this.applyState(grid,this.init_state);
			grid.applyState(this.init_state);
			//console.dir(this.init_state);
		}
	},

	getState: function () {
		var filters = {};
		this.filters.each(function (filter) {
			if (filter.active) {
				filters[filter.dataIndex] = filter.getValue();
			}
		});
		return filters;
	}
});



// Tweaks to Saki's "CheckTree" (http://checktree.extjs.eu/) -- 2010-03-27 by HV
Ext.override(Ext.ux.tree.CheckTreePanel, {
	// This is required in order to get initial checked state:
	afterRender:function() {
		Ext.ux.tree.CheckTreePanel.superclass.afterRender.apply(this, arguments);
		this.updateHidden();
	 },

	 // This adds unchecked items to the posted list... Unchecked start with '-', checked start with '+'
	 getValue:function() {
		var a = [];
		this.root.cascade(function(n) {
			if(true === n.attributes.checked) {
				if(false === this.deepestOnly || !this.isChildChecked(n)) {
					a.push('+' + n.id);
				}
			}
			else {
				a.push('-' + n.id);
			}
		}, this);
		a.shift(); // Remove root element
		return a;
	}
});


/* Override to force it to not display the checkbox if "checkbox" is null */
Ext.override(Ext.ux.tree.CheckTreeNodeUI, {

	renderElements:function(n, a, targetNode, bulkRender){

		/* This override was required to support NO checkbox */
		var checkbox_class = 'x-tree-checkbox';
		if (n.attributes.checked == null) { checkbox_class = 'x-tree-checkbox-no-checkbox'; }
		/* ------------------------------------------------- */

		this.indentMarkup = n.parentNode ? n.parentNode.ui.getChildIndent() :'';
		var checked = n.attributes.checked;
		var href = a.href ? a.href : Ext.isGecko ? "" :"#";
		  var buf = [
			 '<li class="x-tree-node"><div ext:tree-node-id="',n.id,'" class="x-tree-node-el x-tree-node-leaf x-unselectable ', a.cls,'" unselectable="on">'
			,'<span class="x-tree-node-indent">',this.indentMarkup,"</span>"
			,'<img src="', this.emptyIcon, '" class="x-tree-ec-icon x-tree-elbow" />'
			,'<img src="', a.icon || this.emptyIcon, '" class="x-tree-node-icon',(a.icon ? " x-tree-node-inline-icon" :""),(a.iconCls ? " "+a.iconCls :""),'" unselectable="on" />'
			,'<img src="'+this.emptyIcon+'" class="' + checkbox_class +(true === checked ? ' x-tree-node-checked' :'')+'" />'
			,'<a hidefocus="on" class="x-tree-node-anchor" href="',href,'" tabIndex="1" '
			,a.hrefTarget ? ' target="'+a.hrefTarget+'"' :"", '><span unselectable="on">',n.text,"</span></a></div>"
			,'<ul class="x-tree-node-ct" style="display:none;"></ul>'
			,"</li>"
		].join('');
		var nel;
		if(bulkRender !== true && n.nextSibling && (nel = n.nextSibling.ui.getEl())){
			this.wrap = Ext.DomHelper.insertHtml("beforeBegin", nel, buf);
		}else{
			this.wrap = Ext.DomHelper.insertHtml("beforeEnd", targetNode, buf);
		}
		this.elNode = this.wrap.childNodes[0];
		this.ctNode = this.wrap.childNodes[1];
		var cs = this.elNode.childNodes;
		this.indentNode = cs[0];
		this.ecNode = cs[1];
		this.iconNode = cs[2];
		this.checkbox = cs[3];
		this.cbEl = Ext.get(this.checkbox);
		this.anchor = cs[4];
		this.textNode = cs[4].firstChild;
	} // eo function renderElements
});




/*
Ext.override(Ext.chart.LineChart, {
	initComponent: function() {
		var config = this;
		if (this.xAxis && this.xAxis['xtype']) {
			if(this.xAxis['xtype'] == 'categoryaxis') { config['xAxis'] = new Ext.chart.CategoryAxis(this.xAxis); }
			if(this.xAxis['xtype'] == 'numericaxis') { config['xAxis'] = new Ext.chart.NumericAxis(this.xAxis); }
		}
		if (this.yAxis && this.yAxis['xtype']) {
			if(this.yAxis['xtype'] == 'categoryaxis') { config['yAxis'] = new Ext.chart.CategoryAxis(this.yAxis); }
			if(this.yAxis['xtype'] == 'numericaxis') { config['yAxis'] = new Ext.chart.NumericAxis(this.yAxis); }
		}
		Ext.apply(this, Ext.apply(this.initialConfig, config));
		Ext.chart.LineChart.superclass.initComponent.apply(this, arguments);
	}
});
*/


var pxMatch = /(\d+(?:\.\d+)?)px/;
Ext.override(Ext.Element, {
		  getViewSize : function(contentBox){
				var doc = document,
					 me = this,
					 d = me.dom,
					 extdom = Ext.lib.Dom,
					 isDoc = (d == doc || d == doc.body),
					 isBB, w, h, tbBorder = 0, lrBorder = 0,
					 tbPadding = 0, lrPadding = 0;
				if (isDoc) {
					 return { width: extdom.getViewWidth(), height: extdom.getViewHeight() };
				}
				isBB = me.isBorderBox();
				tbBorder = me.getBorderWidth('tb');
				lrBorder = me.getBorderWidth('lr');
				tbPadding = me.getPadding('tb');
				lrPadding = me.getPadding('lr');

				// Width calcs
				// Try the style first, then clientWidth, then offsetWidth
				if (w = me.getStyle('width').match(pxMatch)){
					 if ((w = Math.round(w[1])) && isBB){
						  // Style includes the padding and border if isBB
						  w -= (lrBorder + lrPadding);
					 }
					 if (!contentBox){
						  w += lrPadding;
					 }
					 // Minimize with clientWidth if present
					 d.clientWidth && (d.clientWidth < w) && (w = d.clientWidth);
				} else {
					 if (!(w = d.clientWidth) && (w = d.offsetWidth)){
						  w -= lrBorder;
					 }
					 if (w && contentBox){
						  w -= lrPadding;
					 }
				}

				// Height calcs
				// Try the style first, then clientHeight, then offsetHeight
				if (h = me.getStyle('height').match(pxMatch)){
					 if ((h = Math.round(h[1])) && isBB){
						  // Style includes the padding and border if isBB
						  h -= (tbBorder + tbPadding);
					 }
					 if (!contentBox){
						  h += tbPadding;
					 }
					 // Minimize with clientHeight if present
					 d.clientHeight && (d.clientHeight < h) && (h = d.clientHeight);
				} else {
					 if (!(h = d.clientHeight) && (h = d.offsetHeight)){
						  h -= tbBorder;
					 }
					 if (h && contentBox){
						  h -= tbPadding;
					 }
				}

				return {
					 width : w,
					 height : h
				};
		  }
});

Ext.override(Ext.layout.ColumnLayout, {
	 onLayout : function(ct, target, targetSize){
		  var cs = ct.items.items, len = cs.length, c, i;

		  if(!this.innerCt){
				// the innerCt prevents wrapping and shuffling while
				// the container is resizing
				this.innerCt = target.createChild({cls:'x-column-inner'});
				this.innerCt.createChild({cls:'x-clear'});
		  }
		  this.renderAll(ct, this.innerCt);

		  var size = targetSize || target.getViewSize(true);

		  if(size.width < 1 && size.height < 1){ // display none?
				return;
		  }

		  var w = size.width - this.scrollOffset,
				h = size.height,
				pw = w;

		  this.innerCt.setWidth(w);

		  // some columns can be percentages while others are fixed
		  // so we need to make 2 passes

		  for(i = 0; i < len; i++){
				c = cs[i];
				if(!c.columnWidth){
					 pw -= (c.getSize().width + c.getPositionEl().getMargins('lr'));
				}
		  }

		  pw = pw < 0 ? 0 : pw;

		  for(i = 0; i < len; i++){
				c = cs[i];
				if(c.columnWidth){
					 c.setSize(Math.floor(c.columnWidth * pw) - c.getPositionEl().getMargins('lr'));
				}
		  }
		  // Do a second pass if the layout resulted in a vertical scrollbar (changing the available width)
		  if (!targetSize && ((size = target.getViewSize(true)).width != w)) {
				this.onLayout(ct, target, size);
		  }
	 }
});

/* http://www.sencha.com/forum/showthread.php?95486-Cursor-Position-in-TextField&p=609639&viewfull=1#post609639 */
Ext.override(Ext.form.Field, {

    setCursorPosition: function(pos) {
       var el = this.getEl().dom;
		 if(!el) { return; } // <-- rare cases this is undef and throws error
       if (el.createTextRange) {
          var range = el.createTextRange();
          range.move("character", pos);
          range.select();
       } else if(typeof el.selectionStart == "number" ) { 
          el.focus(); 
          el.setSelectionRange(pos, pos); 
       } else {
         //alert('Method not supported');
         return;
       }
    },

    getCursorPosition: function() {
       var el = this.getEl().dom;
       var rng, ii=-1;
       if (typeof el.selectionStart=="number") {
          ii=el.selectionStart;
       } else if (document.selection && el.createTextRange){
          rng=document.selection.createRange();
          rng.collapse(true);
          rng.moveStart("character", -el.value.length);
          ii=rng.text.length;
       }
       return ii;
    }
   
});


/* --------------------------------------------------------- */
/* ---------------------------------------------------------

     NEW: GLOBAL 'ADVANCED_CONFIG' OVERRIDE FOR ALL Ext.Component BASED CLASSES
     
     Optionally loads any additonal config parameters from the special config 
     property 'advanced_config' if 'advanced_config_active' is also present and
     set to truthy value.
     
     This is here primarily for saved searches. Note: this is a very powerful,
     and thus possibly dangerous functionality. But the risk is at the point where
     this config property is loaded.

*/
var Orig_Ext_Component_initComponent = Ext.Component.prototype.initComponent;
Ext.override(Ext.Component, {
	initComponent: function() {

		// If there is a store within this component, optionally copy the 
		// advanced_config properties from it:
		if(this.store) {
			Ext.applyIf(this,Ext.copyTo({},this.store,[
				'advanced_config',
				'advanced_config_active',
				'advanced_config_json'
			]));
		}
		
		// Optionally load from JSON string:
		if(this.advanced_config_active && this.advanced_config_json) {
			this.advanced_config = this.advanced_config || 
				Ext.decode(this.advanced_config_json);
		}
		
		if(this.advanced_config_active && this.advanced_config) {
			Ext.apply(this,this.advanced_config);
		}
	
		Orig_Ext_Component_initComponent.call(this);
	}
});
/* --------------------------------------------------------- */
/* --------------------------------------------------------- */


