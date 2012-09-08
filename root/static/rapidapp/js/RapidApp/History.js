/**
 * AutoHistory API:
 *
 * The module AutoHistory has the following public method:
 *   recordHistEvent(id, oldVal, newVal)
 *      id     - the component ID of a ExtJS component which supports the NavState interface,
 *      oldVal - a string representing the previous navigation state
 *      newVal - a string representing the new navigation state.
 *
 * The strings can be anything the caller wants.  They will be passed back as-is.
 *
 * The caller must support the following interface:
 *
 *   getNavState(): navVal
 *      navVal - a string representing the current navigation state
 *   setNavState(navVal)
 *      navVal - a string previously passed to recordHistEvent
 */

Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.HistoryInit = function() {
	Ext.History.init();
	Ext.History.on('change', Ext.ux.RapidApp.HashNav.handleHashChange);
}

Ext.ux.RapidApp.HashNav = {
	
	INIT_LOCATION_HASH: window.location.hash,
	ignoreHashChange: false,
	
	hashpath_to_autoLoad: function(hashpath) {
		var token = hashpath;
		
		// hashpath with or without leading #
		if(hashpath.search('#') == 0) { token = hashpath.substring(1); }
		
		// valid hashpaths must start with '!/'
		if(token.search('!/') !== 0) { return null; }
		
		var url = token.substring(1); // strip leading !
		var params = {};
		
		// double ?? means base64+json encoded query string (params):
		var parts = url.split('??');
		if(parts.length > 1) {
			url = parts.shift();
			var encP = parts.join('??');
			params = Ext.decode(base64.decode(encP));
		}
		else {
			// else, single ? is a standard urlEncoded query string
			parts = url.split('?');
			if(parts.length > 1) {
				url = parts.shift();
				params = Ext.urlDecode(parts.join('?'));
			}
		}
		
		var autoLoad = {
			url: url, 
			params: params 
		};
		
		return autoLoad;
	},
	
	isParamsUrlSafe: function(params) {
		var safe = true;
		Ext.iterate(params,function(k,v){
			if(v.search && v.search('=') !== -1) { safe = false; }
		});
		return safe;
	},
	
	autoLoad_to_hashpath: function(autoLoad){
		if(Ext.isObject(autoLoad) && Ext.isString(autoLoad.url)) { 
			// Ignore if url doesn't start with /:
			if(autoLoad.url.search('/') !== 0) { return null; }
			
			var hashpath = '#!' + autoLoad.url;
			if(Ext.ux.RapidApp.HashNav.isParamsUrlSafe(autoLoad.params)) {
				// Use standard url encoded query string:
				var encParams = autoLoad.params ? Ext.urlEncode(autoLoad.params) : '';
				if(encParams.length > 0) { 
					hashpath += '?' + encParams; 
				}
			}
			else {
				// Use special base64+json encoded query string, denoted with double '??'
				var encP = Ext.encode(autoLoad.params || {});
				if(encP !== '{}') {
					hashpath += '??' + base64.encode(encP);
				}
			}
			
			return hashpath;
		}
		return null;
	},
	
	// Set's the hashpath without doing a nav:
	setHashpath: function(autoLoad) {
		var hashpath = Ext.ux.RapidApp.HashNav.autoLoad_to_hashpath(autoLoad);
		if(hashpath) {
			Ext.ux.RapidApp.HashNav.ignoreHashChange = true;
			window.location.hash = hashpath;
		}
	},
	
	handleHashChange: function(hashpath) {
		if(Ext.ux.RapidApp.HashNav.ignoreHashChange) {
			Ext.ux.RapidApp.HashNav.ignoreHashChange = false;
			return;
		}
		
		var loadTarget = Ext.getCmp('main-load-target');
		if(!loadTarget) { return; }
		
		var autoLoad = Ext.ux.RapidApp.HashNav.hashpath_to_autoLoad(hashpath);
		if(!autoLoad) {
			// Try to reset the hashpath to the active tab
			var tab = loadTarget.getActiveTab.call(loadTarget);
			autoLoad = tab ? tab.autoLoad : null;
			return Ext.ux.RapidApp.HashNav.setHashpath(autoLoad);
		}
		
		loadTarget.loadContent({ autoLoad: autoLoad });
		Ext.ux.RapidApp.HashNav.ignoreHashChange = false;
	},
	
	/*  Ext.ux.RapidApp.HashNav.formSubmitHandler:
	 Function to be used as 'onsubmit' for any html form tag/element to
	 "submit" the form to a hashpath/loadcontent url instead of doing 
	 an actual GET/POST, directly. 
	 
	 Example:
	
		<form 
		 action="#!/main/explorer/navtree/classicdb_employees" 
		 onsubmit="return Ext.ux.RapidApp.HashNav.formSubmitHandler.apply(this,arguments);"
		>
			<label for="quick_search">Search Employees:</label>
			<input type="text" name="quick_search" />
		</form>
		
	 If 'abc123' were typed into the form/field it would load the following hashpath url:
		
		#!/main/explorer/navtree/classicdb_employees?quick_search=abc123
		
	*/
	formSubmitHandler: function(e) {

		var action = this.getAttribute('action');
		if(!action || action.search('#!/') !== 0) {
			alert("Invalid form action URL: '" + action + 
				'" - HashNav form actions must be valid hashpaths starting with \'#!/\'');
			return false;
		}
		
		var parts = action.split('?');
		if(parts.length > 2) {
			alert("Invalid form action URL: '" + action + 
				'" - multiple question-mark (?) characters are not allowed');
			return false;
		}
		
		var url = action;
		var params = {};
		
		if(parts.length > 1) {
			url = parts.shift();
			params = Ext.urlDecode(parts.join('?'));
		}
		
		for (var i = 0; i < this.elements.length; i++) {
			var name = this.elements[i].name, value = this.elements[i].value;
			if(name && value) {
				if(params[name]) {
					alert("duplicate param name '" + name + "' in HashNav form/url - not supported");
					return false;
				}
				params[name] = value;
			}
		}
		
		var hashpath = url;
		var encParams = Ext.urlEncode(params);
		if(encParams.length > 0) {
			hashpath = url + '?' + encParams;
		}
		
		window.location.hash = hashpath;
		
		// Important! the onsubmit handler *must* return false to stop the
		// normal GET/POST browser submit operation (but we also called
		// e.preventDefault() first, so this isn't also needed)
		return false;
	}
};





/* -- Old component-id-based history code

Ext.ux.RapidApp.HistoryInit = function() {
	Ext.History.init();
	Ext.History.on('change', function(token) { Ext.ux.RapidApp.AutoHistory.handleHistChange(token); });
	Ext.ux.RapidApp.AutoHistory.installSafeguard();
};


Ext.ux.RapidApp.AutoHistory= {
	navIdx: 0,
	wrapIdx: function(idx) { return idx > 99? (idx - 100) : (idx < 0? idx + 100 : idx); },
	isForwardNav: function(oldIdx, newIdx) { var diff= this.wrapIdx(newIdx-oldIdx); return diff < 50; },
	currentNav: '',
	
	// add a fake nav event to prevent the user from backing out of the page
	installSafeguard: function() {
		this.currentNav= ''+this.navIdx+':::';
		Ext.History.add(this.currentNav);
	},
	
	// follow a nav event given to us by the application
	recordHistEvent: function(id, oldval, newval) {
		if (!newval) return;
		
		this.navIdx= this.wrapIdx(this.navIdx+1);
		this.currentNav= ''+this.navIdx+':'+id+':'+oldval+':'+newval;
		//console.log('recordHistEvent '+this.currentNav);
		
		Ext.History.add(this.currentNav);
	},
	
	performNav: function(id, newVal) {
		if (!id) return;
		if (!newVal) return;
		var target= Ext.getCmp(id);
		if (!target) return;
		//console.log('AutoHistory.performNav: '+id+'->setNav '+newVal);
		target.setNavState(newVal);
	},
	
	// respond to user back/forward navigation, but ignore ones generated by recordHistEvent
	handleHistChange: function(navTarget) {
		if (!navTarget) {
			if (this.currentNav) {
				var parts= this.currentNav.split(':');
				this.performNav(parts[1], parts[2]);
			}
			this.installSafeguard();
			return;
		}
		
		// ignore events caused by recordHistEvent
		if (navTarget != this.currentNav) {
			//console.log('AutoHistory.handleHistChange: '+this.currentNav+' => '+navTarget);
			var parts= navTarget.split(':');
			var navTargetIdx= parseInt(parts[0]);
			if (this.isForwardNav(this.navIdx, navTargetIdx)) {
				this.performNav(parts[1], parts[3]);
			}
			else {
				var parts= this.currentNav.split(':');
				this.performNav(parts[1], parts[2]);
			}
			this.currentNav= navTarget;
			this.navIdx= navTargetIdx;
		}
	}
};


Ext.override(Ext.TabPanel, {
	initComponent_orig: Ext.TabPanel.prototype.initComponent,
	initComponent: function() {
		//this.constructor.prototype.initComponent.call(this);
		this.initComponent_orig.apply(this,arguments);
		this.internalTabChange= 0;
		
		this.on('beforetabchange', function(tabPanel, newTab, currentTab) {
			if (newTab && currentTab && !this.internalTabChange) {
				Ext.ux.RapidApp.AutoHistory.recordHistEvent(tabPanel.id, currentTab.id, newTab.id);
			}
			this.internalTabChange= 0;
			return true;
		});
	},
	setNavState: function(navVal) {
		var newTab= Ext.getCmp(navVal);
		if (newTab) {
			this.internalTabChange= 1;
			this.setActiveTab(newTab);
		}
	},
	getNavState: function() { return this.getActiveTab()? this.getActiveTab().id : ""; }
});

*/