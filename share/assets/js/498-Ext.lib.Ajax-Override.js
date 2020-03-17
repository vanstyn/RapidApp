/**
 *    *** Custom Ext.lib.Ajax library for RapidApp ***
 *
 * Overrides ext-adapter behavior for allowing queuing of AJAX requests.
 *
 * This code was adapted from here:
 *  http://www.sencha.com/forum/showthread.php?19171-2.0rc1-Queue-for-concurrent-Ajax-calls
 *
 * But has been reworked and had its logic updated to match the version of Ext.lib.Ajax found
 * in Ext JS 3.4 (since the above was a modified version from 3.0). Additionally, request
 * header functionality which was broken as of the original version from the above thread has
 * been fixed in this file
 *
**/

Ext.lib.Ajax = function() {

    /**
     * @type {Array} _queue A FIFO queue for processing pending requests
     */
    var _queue = [];

    /**
     * @type {Number} _activeRequests The number of requests currently being processed.
     */
    var _activeRequests = 0;

    /**
     * @type {Number} _concurrentRequests The number of max. concurrent requests requests allowed.
     */
    var _concurrentRequests = 2;

    switch (true) {
        case Ext.isIE8:
            _concurrentRequests = window.maxConnectionsPerServer;
        break;
        case Ext.isIE:
            _concurrentRequests = 2;
        break;
        case Ext.isSafari:
        case Ext.isChrome:
        case Ext.isGecko3:
            _concurrentRequests = 4;
        break;
    }

    var activeX = ['Msxml2.XMLHTTP.3.0',
                   'Msxml2.XMLHTTP'],
        CONTENTTYPE = 'Content-Type';

    // private
    function setHeader(o) {
        var conn = o.conn,
            prop,
            headers = {};

        function setTheHeaders(conn, headers){
            for (prop in headers) {
                if (headers.hasOwnProperty(prop)) {
                    conn.setRequestHeader(prop, headers[prop]);
                }
            }
        }

        Ext.apply(headers, pub.headers, pub.defaultHeaders);
        setTheHeaders(conn, headers);
        delete pub.headers;
    }

    // private
    function createExceptionObject(tId, callbackArg, isAbort, isTimeout) {
        return {
            tId : tId,
            status : isAbort ? -1 : 0,
            statusText : isAbort ? 'transaction aborted' : 'communication failure',
            isAbort: isAbort,
            isTimeout: isTimeout,
            argument : callbackArg
        };
    }

    // private
    function initHeader(label, value) {
        (pub.headers = pub.headers || {})[label] = value;
    }

    // private
    function createResponseObject(o, callbackArg) {
        var headerObj = {},
            headerStr,
            conn = o.conn,
            t,
            s,
            // see: https://prototype.lighthouseapp.com/projects/8886/tickets/129-ie-mangles-http-response-status-code-204-to-1223
            isBrokenStatus = conn.status == 1223;

        try {
            headerStr = o.conn.getAllResponseHeaders();
            Ext.each(headerStr.replace(/\r\n/g, '\n').split('\n'), function(v){
                t = v.indexOf(':');
                if(t >= 0){
                    s = v.substr(0, t).toLowerCase();
                    if(v.charAt(t + 1) == ' '){
                        ++t;
                    }
                    headerObj[s] = v.substr(t + 1);
                }
            });
        } catch(e) {}

        return {
            tId : o.tId,
            // Normalize the status and statusText when IE returns 1223, see the above link.
            status : isBrokenStatus ? 204 : conn.status,
            statusText : isBrokenStatus ? 'No Content' : conn.statusText,
            getResponseHeader : function(header){return headerObj[header.toLowerCase()];},
            getAllResponseHeaders : function(){return headerStr;},
            responseText : conn.responseText,
            responseXML : conn.responseXML,
            argument : callbackArg
        };
    }

    // private
    function releaseObject(o)
    {
        //console.log(o.tId+" releasing");
        _activeRequests--;

        o.conn = null;
        o = null;

        _processQueue();
    }

    // private
    function handleTransactionResponse(o, callback, isAbort, isTimeout) {
        if (!callback) {
            releaseObject(o);
            return;
        }

        var httpStatus, responseObject;

        try {
            if (o.conn.status !== undefined && o.conn.status != 0) {
                httpStatus = o.conn.status;
            }
            else {
                httpStatus = 13030;
            }
        }
        catch(e) {
            httpStatus = 13030;
        }

        if ((httpStatus >= 200 && httpStatus < 300) || (Ext.isIE && httpStatus == 1223)) {
            responseObject = createResponseObject(o, callback.argument);
            if (callback.success) {
                if (!callback.scope) {
                    callback.success(responseObject);
                }
                else {
                    callback.success.apply(callback.scope, [responseObject]);
                }
            }
        }
        else {
            switch (httpStatus) {
                case 12002:
                case 12029:
                case 12030:
                case 12031:
                case 12152:
                case 13030:
                    responseObject = createExceptionObject(o.tId, callback.argument, (isAbort ? isAbort : false), isTimeout);
                    if (callback.failure) {
                        if (!callback.scope) {
                            callback.failure(responseObject);
                        }
                        else {
                            callback.failure.apply(callback.scope, [responseObject]);
                        }
                    }
                    break;
                default:
                    responseObject = createResponseObject(o, callback.argument);
                    if (callback.failure) {
                        if (!callback.scope) {
                            callback.failure(responseObject);
                        }
                        else {
                            callback.failure.apply(callback.scope, [responseObject]);
                        }
                    }
            }
        }

        releaseObject(o);
        responseObject = null;
    }

    function checkResponse(o, callback, conn, tId, poll, cbTimeout){
        if (conn && conn.readyState == 4) {
            clearInterval(poll[tId]);
            poll[tId] = null;

            if (cbTimeout) {
                clearTimeout(pub.timeout[tId]);
                pub.timeout[tId] = null;
            }
            handleTransactionResponse(o, callback);
        }
    }

    function checkTimeout(o, callback){
        pub.abort(o, callback, true);
    }

    // private
    function handleReadyState(o, callback){
        callback = callback || {};
        var conn = o.conn,
            tId = o.tId,
            poll = pub.poll,
            cbTimeout = callback.timeout || null;

        if (cbTimeout) {
            pub.conn[tId] = conn;
            pub.timeout[tId] = setTimeout(checkTimeout.createCallback(o, callback), cbTimeout);
        }
        poll[tId] = setInterval(checkResponse.createCallback(o, callback, conn, tId, poll, cbTimeout), pub.pollInterval);
    }

    /**
     * Pushes the request into the queue if a connection object can be created
     * na dimmediately processes the queue.
     *
     */
    function asyncRequest(method, uri, callback, postData, options)
    {
        var o = getConnectionObject();

        if (!o) {
            return null;
        } else {
            _queue.push({
               o        : o,
               method   : method,
               uri      : uri,
               callback : callback,
               postData : postData,
               options  : options
            });
            //console.log(o.tId+" was put into the queue");
            var head = _processQueue();

            if (head) {
                //console.log(o.tId+" is being processed a the  head of queue");
                return head;
            } else {
                //console.log(o.tId+" was put into the queue and will be processed later on");
                return o;
            }
        }
    }

    /**
     * Initiates the async request and returns the request that was created,
     * if, and only if the number of currently active requests is less than the number of
     * concurrent requests.
     */
    function _processQueue()
    {
        var to = _queue[0];
        if (to && _activeRequests < _concurrentRequests) {
            to = _queue.shift();
            _activeRequests++;
            return _asyncRequest(to.method, to.uri, to.callback, to.postData, to.options);
        }
    }


    // private
    function _asyncRequest(method, uri, callback, postData, options) {
        var o = getConnectionObject() || null;

        if (o) {
            o.conn.open(method, uri, true);

            // ------
            // New: we have to manually apply this in order for the headers to get carried
            // from/through the queue process. This is needed because of the ugly way in
            // which request headers are set via a temp global variable
            if(options && options.headers) {
              // pub.headers is the global Ext.lib.Ajax.headers object, it will get deleted
              // by setHeader(o) call further down
              pub.headers = pub.headers || {};
              Ext.apply(pub.headers,options.headers);
            }
            // ------

            if (pub.useDefaultXhrHeader) {
                initHeader('X-Requested-With', pub.defaultXhrHeader);
            }

            if(postData && pub.useDefaultHeader && (!pub.headers || !pub.headers[CONTENTTYPE])){
                initHeader(CONTENTTYPE, pub.defaultPostHeader);
            }

            if (pub.defaultHeaders || pub.headers) {
                setHeader(o);
            }

            handleReadyState(o, callback);
            o.conn.send(postData || null);
        }
        return o;
    }

    // private
    function getConnectionObject() {
        var o;

        try {
            if (o = createXhrObject(pub.transactionId)) {
                pub.transactionId++;
            }
        } catch(e) {
        } finally {
            return o;
        }
    }

    // private
    function createXhrObject(transactionId) {
        var http;

        try {
            http = new XMLHttpRequest();
        } catch(e) {
            for (var i = Ext.isIE6 ? 1 : 0; i < activeX.length; ++i) {
                try {
                    http = new ActiveXObject(activeX[i]);
                    break;
                } catch(e) {}
            }
        } finally {
            return {conn : http, tId : transactionId};
        }
    }

    var pub = {
        request : function(method, uri, cb, data, options) {
            if(options){
                var me = this,
                    xmlData = options.xmlData,
                    jsonData = options.jsonData,
                    hs;

                Ext.applyIf(me, options);

                if(xmlData || jsonData){
                    hs = me.headers;
                    if(!hs || !hs[CONTENTTYPE]){
                        initHeader(CONTENTTYPE, xmlData ? 'text/xml' : 'application/json');
                    }
                    data = xmlData || (!Ext.isPrimitive(jsonData) ? Ext.encode(jsonData) : jsonData);
                }
            }
            return asyncRequest(method || options.method || "POST", uri, cb, data, options);
        },

        serializeForm : function(form) {
            var fElements = form.elements || (document.forms[form] || Ext.getDom(form)).elements,
                hasSubmit = false,
                encoder = encodeURIComponent,
                name,
                data = '',
                type,
                hasValue;

            Ext.each(fElements, function(element){
                name = element.name;
                type = element.type;

                if (!element.disabled && name) {
                    if (/select-(one|multiple)/i.test(type)) {
                        Ext.each(element.options, function(opt){
                            if (opt.selected) {
                                hasValue = opt.hasAttribute ? opt.hasAttribute('value') : opt.getAttributeNode('value').specified;
                                data += String.format("{0}={1}&", encoder(name), encoder(hasValue ? opt.value : opt.text));
                            }
                        });
                    } else if (!(/file|undefined|reset|button/i.test(type))) {
                        if (!(/radio|checkbox/i.test(type) && !element.checked) && !(type == 'submit' && hasSubmit)) {
                            data += encoder(name) + '=' + encoder(element.value) + '&';
                            hasSubmit = /submit/i.test(type);
                        }
                    }
                }
            });
            return data.substr(0, data.length - 1);
        },

        useDefaultHeader : true,
        defaultPostHeader : 'application/x-www-form-urlencoded; charset=UTF-8',
        useDefaultXhrHeader : true,
        defaultXhrHeader : 'XMLHttpRequest',
        poll : {},
        timeout : {},
        conn: {},
        pollInterval : 50,
        transactionId : 0,

        abort : function(o, callback, isTimeout)
        {
            var me = this,
                tId = o.tId,
                isAbort = false;

            //console.log(o.tId+" is aborting - was "+o.tId+" in progress?: "+me.isCallInProgress(o));

            if (me.isCallInProgress(o)) {
                o.conn.abort();
                clearInterval(me.poll[tId]);
                me.poll[tId] = null;

                clearTimeout(pub.timeout[tId]);
                me.timeout[tId] = null;

                // @ext-bug 3.0.2 why was this commented out? if the request is aborted
                // programmatically, the timeout for the "timeout"-handler is never destroyed,
                // thus this method would at least be called once, if the initial reason is
                // that no timeout occured.
                //if (isTimeout) {
                //    me.timeout[tId] = null;
                //}

                  handleTransactionResponse(o, callback, (isAbort = true), isTimeout);
            } else {
                // check here if the current call was in progress. This might not be the case
                // if the connection was put into the queue, waiting to get triggered
                for (var i = 0, max_i = _queue.length; i < max_i; i++) {
                    if (_queue[i].o.tId == o.tId) {
                        _queue.splice(i, 1);
                        //console.log(o.tId+" was not a call in progress, thus removed from the queue at "+i);
                        break;
                    }
                }

            }

            return isAbort;
        },

        isCallInProgress : function(o) {
            // if there is a connection and readyState is not 0 or 4
            return o.conn && !{0:true,4:true}[o.conn.readyState];
        }
    };
    return pub;
}();
