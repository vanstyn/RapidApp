// This tiny javascript should be loaded in the *external* document root
// to enable handling hashpaths (#!/some/rapidapp/path) and redirecting 
// into authenticated, ExtJS/RapidApp tab pages. This is only needed when
// a custom, non-login page is set (e.g. if 'public_root_template' is set
// in the 'Plugin::RapidApp::AuthCore' config)

// This is designed to be loaded only when Ext isn't:
if(typeof Ext == 'undefined') {

  // Only applies to root href '/' (i.e. paths starting with '/#!/...'):
  function rapidapp_external_hashchange() {
    var path = window.location.pathname, hash = window.location.hash;
    if(path == '/' && hash.search('#!/') == 0) {
      window.location.href = window.location.href.replace(
        '/#!/', '/auth/login/#!/'
      );
    }
  }
  
  // Set listeners:
  window.onload = window.onload || rapidapp_external_hashchange;
  window.onhashchange = window.onhashchange || rapidapp_external_hashchange;
}