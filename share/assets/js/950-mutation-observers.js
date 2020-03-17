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
  // For good measure, make sure we only process a given node once:
  if(el.raMoExpandableMaxHeightInitialized) { return; }
  el.raMoExpandableMaxHeightInitialized = true;

  // Do nothing if we contain another ra-mo-expandable-max-height element:
  //  Not yet decided if this should be done. What would really need to happen in this case is
  //  to somehow figure out what the max-height of the children are, and then turn them
  //  off or us off depending on which is smaller. For now, with this commented out, nested
  //  layers display when the parent is smaller than the child, while may not be ideal, is at
  //  least arguably the most expected behaviour
  //if(el.getElementsByClassName('ra-mo-expandable-max-height')[0]) { return; }

  var CssStyle = window.getComputedStyle(el,null); // live object representing current styles
  var hasMaxHeight = function() {
    var prop = CssStyle.getPropertyValue('max-height');
    return prop && prop != '' && prop != 'none' ? true : false;
  }

  var resetMH;
  if(!hasMaxHeight()) {
    // Set max-height via special 'mh-PIXELS' class name (e.g. 'mh-235')
    for (var i = 0; i < el.classList.length; i++) {
      var parts = el.classList[i].split('-');
      if(parts.length == 2 && parts[0] == 'mh' && parseInt(parts[1])) {
        resetMH = el.style['max-height'];
        el.style['max-height'] = parts[1]+'px';
        break;
      }
    }
  }

  var getRealHeights = function() {
    var heights;
    if(el.offsetParent) {
      heights = [el.clientHeight,el.scrollHeight];
    }
    else {
      // If we're here, el.offsetParent is not defined...
      // this means we're not currently rendered/visible, so we can't find out our dimensions. To
      // get the browser to tell us what they really are, we have to create a temp hidden element,
      // move our element to it, then retrieve the dimensions, then move it back to the original
      // parent element and then clean-up/remove the temp element.
      var origParent = el.parentElement;
      var origSibling = el.nextSibling;

      var hidEl = document.createElement('div');
      hidEl.style.opacity = 0;
      hidEl.style.position = 'absolute';
      document.body.appendChild(hidEl);
      hidEl.appendChild(el);

      heights = [el.clientHeight,el.scrollHeight];

      if(origSibling) {
        origParent.insertBefore(el,origSibling);
      }
      else {
        origParent.appendChild(el);
      }

      document.body.removeChild(hidEl);
    }
    return heights;
  }

  var getPctShown = function() {
    var heights = getRealHeights() || [];
    if(!heights[1]) { return 100; }
    var pct = Math.floor((heights[0]/heights[1])*10000);
    if(! pct) { return 100; }
    return pct < 500 ? pct/100 : Math.floor(pct/100);
  }

  // Do nothing if nothing is hidden:
  if(getPctShown() == 100) {
    // if we already changed the max-height due to special class we need to set it back
    if(typeof resetMH != undefined) { el.style['max-height'] = resetMH; }
    return;
  }

  // This only works if there is a max-height:
  if(!hasMaxHeight()) { return; }

  var origMH = el.style['max-height'];

  var wrapEl = document.createElement('div');
  el.parentNode.insertBefore(wrapEl,el);
  wrapEl.appendChild(el);

  var toggleWrap = document.createElement('div');
  toggleWrap.style['padding-top']   = '5px';
  toggleWrap.style['text-align']    = 'center';

  var toggle = document.createElement('a');
  toggle.style['color']         = '#0088cc';

  toggleWrap.appendChild(toggle);

  var updateToggle = function() {
    if(toggle.raMoToggleExpanded) {
      el.style['max-height'] = 'none';
      toggle.innerHTML = '[ show less ]';
    }
    else {
      el.style['max-height'] = origMH;
      var pct = getPctShown();
      toggle.innerHTML = pct + '% [ show more ]';
    }
  }

  var toggleFn = function(e) {
    e.stopPropagation();
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

  wrapEl.appendChild(toggleWrap);
});
