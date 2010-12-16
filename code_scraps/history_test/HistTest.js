/*!
 * Ext JS Library 3.3.0
 * Copyright(c) 2006-2010 Ext JS, Inc.
 * licensing@extjs.com
 * http://www.extjs.com/license
 */

Ext.onReady(function() {
	Ext.History.init();
});

Ext.ns('Ext.ux.RapidApp');
Ext.ux.RapidApp.AutoHistory= {
	eventIdx: 0,
	ignoreEvent: '',
	recordHistEvent: function(id, oldval, newval) {
			var nextIdx= Ext.History.eventIdx < 9? Ext.History.eventIdx+1 : 0;
			var eventText= ''+nextIdx+':'+id+':'+oldval+':'+newval;
			if (oldval && eventText != Ext.History.ignoreEvent) {
				console.log('recordHistEvent '+eventText);
				Ext.History.newestEvent= eventText;
				Ext.History.eventIdx= nextIdx;
				Ext.History.add(eventText);
			}
			else {
				console.log('recordHistEvent '+eventText+' (ignored)');
			}
		},
	Ext.History.on('change', function(token){
		Ext.History.ignoreEvent= '';
		console.log('onChange: '+Ext.History.newestEvent+' => '+token);
		if (Ext.History.newestEvent != token) {
			var parts= token? token.split(':') : [ ];
			var newIdx= token? parseInt(parts[0]) : Ext.History.eventIdx;
			var nextIdx= newIdx < 9? newIdx+1 : 0;
			var diff= token? newIdx - Ext.History.eventIdx : -1;
			var prevEvent= Ext.History.newestEvent;
			Ext.History.newestEvent= token;
			Ext.History.eventIdx= newIdx;
			
			if (diff <= -5 || (diff > 0 && diff < 5)) { // navigating forward
				if (parts[1] && parts[2] && parts[3]) {
					var tabPanel= Ext.getCmp(parts[1]);
					Ext.History.ignoreEvent= ''+nextIdx+':'+parts[1]+':'+parts[2]+':'+parts[3];
					tabPanel.setActiveTab(parts[3]);
				}
			}
			else if (prevEvent) { // navigating backward
				parts= prevEvent.split(':');
				if (parts[1] && parts[2] && parts[3]) {
					var tabPanel= Ext.getCmp(parts[1]);
					Ext.History.ignoreEvent= ''+nextIdx+':'+parts[1]+':'+parts[3]+':'+parts[2];
					tabPanel.setActiveTab(parts[2]);
				}
			}
		}
		if (!token) {
			Ext.History.newestEvent= ''+Ext.History.eventIdx+':::';
			Ext.History.add(Ext.History.newestEvent);
		}
		console.log('  newest='+Ext.History.newestEvent+' ign='+Ext.History.ignoreEvent+' idx='+Ext.History.eventIdx);
	});
    
    var tp = new Ext.TabPanel({
        renderTo: Ext.getBody(),
        id: 'main-tabs',
        height: 300,
        width: 600,
        activeTab: 0,
        
        items: [{
            xtype: 'tabpanel',
            title: 'Tab 1',
            id: 'tab1',
            activeTab: 0,
            tabPosition: 'bottom',
            
            items: [{
                title: 'Sub-tab 1',
                //id: 'subtab1'
            },{
                title: 'Sub-tab 2',
                //id: 'subtab2'
            },{
                title: 'Sub-tab 3',
                id: 'subtab3'
            }]/*,
            
            listeners: {
                'beforetabchange': function(tabPanel, newTab, currentTab){
                    Ext.History.recordHistEvent(tabPanel.id, currentTab? currentTab.id : "", newTab? newTab.id : "");
                    return true;
                }
            }*/
        },{
            title: 'Tab 2',
            id: 'tab2'
        },{
            title: 'Tab 3',
            id: 'tab3'
        },{
            title: 'Tab 4',
            id: 'tab4'
        },{
            title: 'Tab 5',
            id: 'tab5'
        }]/*,
        
			listeners: {
				 'beforetabchange': function(tabPanel, newTab, currentTab){
					  Ext.History.recordHistEvent(tabPanel.id, currentTab? currentTab.id : "", newTab? newTab.id : "");
					  return true;
				 }
			}*/
    });
});


Ext.override(Ext.TabPanel,{

	initComponent_orig: Ext.TabPanel.prototype.initComponent,

	initComponent: function() {
		Ext.TabPanel.prototype.initComponent_orig.call(this);
		
		this.on('beforetabchange', function(tabPanel, newTab, currentTab){
			  Ext.History.recordHistEvent(tabPanel.id, currentTab? currentTab.id : "", newTab? newTab.id : "");
			  return true;
		 });
	}

});

