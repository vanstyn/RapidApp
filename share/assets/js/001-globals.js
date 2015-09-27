//Ext.Ajax.timeout = 120000; // 2 minute timeout (default is 30 seconds)
Ext.Ajax.timeout = 90000; // 1.5 minute timeout (default is 30 seconds)

Ext.ns('Ext.ux.RapidApp.util');

// Base namespace reserved for client/user apps
Ext.ns('RA.ux');

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

// Based on Ext.ux.RapidApp.HashNav.updateTitle()
Ext.ux.RapidApp.util.parseFirstTextFromHtml = function(str) {
  if(str && Ext.isString(str)) {
    // if it looks like a tag, attempt to parse it and use its innerHTML
    if(str.search('<') == 0){
      var el = document.createElement( 'div' );
      el.innerHTML = str;
      if(el && el.children.length > 0) {
        return Ext.ux.RapidApp.util.parseFirstTextFromHtml(el.children[0].innerHTML);
      }
    }
    
    // This will have any html entities decoded, and stripped of leading/trailing whitespace:
    var txtarea = document.createElement( 'textarea' );
    txtarea.innerHTML = str;
    str = txtarea.value.replace(/^\s+|\s+$/g,'');
  }

  return str;
};