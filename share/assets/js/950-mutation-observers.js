// http://ryanmorr.com/using-mutation-observers-to-watch-for-element-availability/
// https://github.com/ryanmorr/ready
(function(win) {
    'use strict';

    var listeners = [], 
    doc = win.document, 
    MutationObserver = win.MutationObserver || win.WebKitMutationObserver,
    observer;

    /*
     * Checks a selector for new matching
     * elements and invokes the callback 
     * if one is found
     * 
     * @param {String} selector
     * @param {Function} fn
     * @api private
     */
    function checkSelector(selector, fn) {
        var elements = doc.querySelectorAll(selector), i = 0, len = elements.length, element;
        for (; i < len; i++) {
            element = elements[i];
            // Make sure the callback isn't invoked with the 
            // same element more than once
            if (!element.ready) {
                element.ready = true;
                // Invoke the callback with the element
                fn.call(element, element);
            }
        }
    }

    /*
     * Check all selectors for new elements
     * following a change in the DOM
     * 
     * @api private
     */
    function checkListeners() {
        for (var i = 0, len = listeners.length, listener; i < len; i++) {
            listener = listeners[i];
            checkSelector(listener.selector, listener.fn);
        }
    }

    /*
     * Add a selector to watch for when a matching
     * element becomes available in the DOM
     * 
     * @param {String} selector
     * @param {Function} fn
     * @api public
     */
    function ready(selector, fn) {
        // Store the selector and callback to be monitored
        listeners.push({
            selector: selector,
            fn: fn
        });
        if (!observer) {
            // Watch for changes in the document
            observer = new MutationObserver(checkListeners);
            observer.observe(doc.documentElement, {
                childList: true,
                subtree: true
            });
        }
        // Check if the element is currently in the DOM
        checkSelector(selector, fn);
    }

    // Expose `ready`
    if (typeof module !== 'undefined' && module.exports) {
        module.exports = ready;
    } else if(typeof define === 'function' && define.amd) {
        define(function(){ return ready; });
    } else {
        win['ready'] = ready;
    }
            
})(this);


/* 
  usage:
  
  <div class="ra-mo-expandable-max-height">
    <div class="content" style="max-height: 150px; overflow: hidden;">
      ... long content ...
    </div>
  </div>
  
*/
ready('.ra-mo-expandable-max-height', function(el) {
  var contentEl = el.getElementsByClassName('content')[0];
  if(!contentEl) { return; }
  
  var getPctShown = function() {
    if(!contentEl.clientHeight) { return 0; }
    var pct = Math.floor((contentEl.clientHeight/contentEl.scrollHeight)*10000);
    if(! pct) return 0;
    return pct < 500 ? pct/100 : Math.floor(pct/100);
  }
  
  // Do nothing if nothing is hidden:
  if(getPctShown() == 100) { return; }

  var origMH = contentEl.style['max-height'];
  
  var toggle = document.createElement('a');
  //toggle.raMoToggleExpanded     = true; // so will get flipped to false on init
  toggle.style['display']       = 'block';
  toggle.style['padding-top']   = '5px';
  toggle.style['text-align']    = 'center';
  toggle.style['color']         = '#0088cc';

  var updateToggle = function() {
    if(toggle.raMoToggleExpanded) {
      contentEl.style['max-height'] = 'none';
      toggle.innerHTML = '[ show less ]';
    }
    else {
      contentEl.style['max-height'] = origMH;
      var pct = getPctShown();
      toggle.innerHTML = pct + '% [ show more ]';
    }
  }
  
  var toggleFn = function() {
    if(toggle.raMoToggleExpanded) {
      toggle.raMoToggleExpanded = false;
    }
    else {
      toggle.raMoToggleExpanded = true;
    }
    updateToggle();
  }
  
  toggle.onclick = toggleFn;
  
  updateToggle(); //init

  el.appendChild(toggle);
});

