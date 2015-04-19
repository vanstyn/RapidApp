//Ext.Ajax.timeout = 120000; // 2 minute timeout (default is 30 seconds)
Ext.Ajax.timeout = 90000; // 1.5 minute timeout (default is 30 seconds)

Ext.ns('Ext.ux.RapidApp.util');

Ext.ux.RapidApp.util.everyEvent = function(observable,fn) {
  Ext.iterate(observable.events,function(event_name,v) {
    observable.on(event_name,function(){
      fn.call(observable,event_name,arguments);
    },observable);
  });
};

Ext.ux.RapidApp.util.logEveryEvent = function(observable) {
  Ext.ux.RapidApp.util.everyEvent(observable,function(event_name){
    console.log(event_name);
  });
};

Ext.ux.RapidApp.util.dumpEveryEvent = function(observable) {
  Ext.ux.RapidApp.util.everyEvent(observable,function(event_name){
    console.dir(arguments);
  });
};
