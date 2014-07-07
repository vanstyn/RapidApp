Ext.ns('Ext.ux.ErrorTrace');
Ext.ux.ErrorTrace.toggleThing= function (ref, type, hideMsg, showMsg) {
 var css = document.getElementById(type+'-'+ref).style;
 css.display = css.display == 'block' ? 'none' : 'block';

 var hyperlink = document.getElementById('toggle-'+ref);
 hyperlink.textContent = css.display == 'block' ? hideMsg : showMsg;
}

Ext.ux.ErrorTrace.toggleArguments= function (ref) {
 toggleThing(ref, 'arguments', 'Hide function arguments', 'Show function arguments');
}

Ext.ux.ErrorTrace.toggleLexicals= function (ref) {
 toggleThing(ref, 'lexicals', 'Hide lexical variables', 'Show lexical variables');
}
