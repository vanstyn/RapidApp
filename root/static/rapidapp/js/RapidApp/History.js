
Ext.ns('Ext.ux.RapidApp.History');
Ext.ux.RapidApp.History.recordHistEvent=
	function(id, oldval, newval) {
		var nextIdx= Ext.ux.RapidApp.History.eventIdx < 9? Ext.ux.RapidApp.History.eventIdx+1 : 0;
		var eventText= ''+nextIdx+':'+id+':'+oldval+':'+newval;
		if (oldval && eventText != Ext.ux.RapidApp.History.ignoreEvent) {
			console.log('recordHistEvent '+eventText);
			Ext.ux.RapidApp.History.newestEvent= eventText;
			Ext.ux.RapidApp.History.eventIdx= nextIdx;
			Ext.History.add(eventText);
		}
		else {
			console.log('recordHistEvent '+eventText+' (ignored)');
			if (!Ext.ux.RapidApp.History.newestEvent) {
				Ext.ux.RapidApp.History.newestEvent= ''+Ext.ux.RapidApp.History.eventIdx+':::';
				Ext.History.add(Ext.ux.RapidApp.History.newestEvent);
			}
		}
	};

Ext.ux.RapidApp.History.eventIdx= 0;
Ext.ux.RapidApp.History.ignoreEvent= '';
Ext.ux.RapidApp.History.handleHistChange=
	function(token) {
		Ext.ux.RapidApp.History.ignoreEvent= '';
		console.log('onChange: '+Ext.ux.RapidApp.History.newestEvent+' => '+token);
		if (Ext.ux.RapidApp.History.newestEvent != token) {
			var parts= token? token.split(':') : [ ];
			var newIdx= token? parseInt(parts[0]) : Ext.ux.RapidApp.History.eventIdx;
			var nextIdx= newIdx < 9? newIdx+1 : 0;
			var diff= token? newIdx - Ext.ux.RapidApp.History.eventIdx : -1;
			var prevEvent= Ext.ux.RapidApp.History.newestEvent;
			Ext.ux.RapidApp.History.newestEvent= token;
			Ext.ux.RapidApp.History.eventIdx= newIdx;
			
			if (diff <= -5 || (diff > 0 && diff < 5)) { // navigating forward
				if (parts[1] && parts[2] && parts[3]) {
					var tabPanel= Ext.getCmp(parts[1]);
					Ext.ux.RapidApp.History.ignoreEvent= ''+nextIdx+':'+parts[1]+':'+parts[2]+':'+parts[3];
					tabPanel.setActiveTab(parts[3]);
				}
			}
			else if (prevEvent) { // navigating backward
				parts= prevEvent.split(':');
				if (parts[1] && parts[2] && parts[3]) {
					var tabPanel= Ext.getCmp(parts[1]);
					Ext.ux.RapidApp.History.ignoreEvent= ''+nextIdx+':'+parts[1]+':'+parts[3]+':'+parts[2];
					tabPanel.setActiveTab(parts[2]);
				}
			}
		}
		if (!token) {
			Ext.ux.RapidApp.History.newestEvent= ''+Ext.ux.RapidApp.History.eventIdx+':::';
			Ext.History.add(Ext.ux.RapidApp.History.newestEvent);
		}
		console.log('  newest='+Ext.ux.RapidApp.History.newestEvent+' ign='+Ext.ux.RapidApp.History.ignoreEvent+' idx='+Ext.ux.RapidApp.History.eventIdx);
	};

Ext.onReady(function() {
	Ext.History.init();
	Ext.History.on('change', function(token) { Ext.ux.RapidApp.History.handleHistChange(token); });
});

Ext.override(Ext.TabPanel,{
	initComponent_orig: Ext.TabPanel.prototype.initComponent,
	initComponent: function() {
		this.initComponent_orig.apply(this,arguments);
		
		this.on('beforetabchange', function(tabPanel, newTab, currentTab){
			  Ext.ux.RapidApp.History.recordHistEvent(tabPanel.id, currentTab? currentTab.id : "", newTab? newTab.id : "");
			  return true;
		 });
	}
});