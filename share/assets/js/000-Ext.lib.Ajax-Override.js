/* http://www.sencha.com/forum/showthread.php?19171-2.0rc1-Queue-for-concurrent-Ajax-calls */

/**
 * Overrides ext-adapter behavior for allowing queuing of AJAX requests.
 *
 */
/*
 * Portions of this code are based on pieces of Yahoo User Interface Library
 * Copyright (c) 2007, Yahoo! Inc. All rights reserved.
 * YUI licensed under the BSD License:
 * http://developer.yahoo.net/yui/license.txt
 */
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

    var activeX = [
        'MSXML2.XMLHTTP.3.0',
        'MSXML2.XMLHTTP',
        'Microsoft.XMLHTTP'
    ], CONTENTTYPE = 'Content-Type';

    // private
    function setHeader(o)
    {
        var conn = o.conn, prop;

        function setTheHeaders(conn, headers) {
            for (prop in headers) {
                if (headers.hasOwnProperty(prop)) {
                    conn.setRequestHeader(prop, headers[prop]);
                }
            }
        }

        if (pub.defaultHeaders) {
            setTheHeaders(conn, pub.defaultHeaders);
        }

        if (pub.headers) {
            setTheHeaders(conn, pub.headers);
            delete pub.headers;
        }
    }

    // private
    function createExceptionObject(tId, callbackArg, isAbort, isTimeout)
    {
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
    function initHeader(label, value)
    {
        (pub.headers = pub.headers || {})[label] = value;
    }

    // private
    function createResponseObject(o, callbackArg)
    {
        var headerObj = {},
            headerStr,
            conn = o.conn,
            t,
            s;

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
            status : conn.status,
            statusText : conn.statusText,
            getResponseHeader : function(header){return headerObj[header.toLowerCase()];},
            getAllResponseHeaders : function(){return headerStr},
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
    function handleTransactionResponse(o, callback, isAbort, isTimeout)
    {
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

    // private
    function handleReadyState(o, callback)
    {
        callback = callback || {};
        var conn = o.conn,
            tId = o.tId,
            poll = pub.poll,
            cbTimeout = callback.timeout || null;

        if (cbTimeout) {
            pub.timeout[tId] = setTimeout(function() {
                pub.abort(o, callback, true);
            }, cbTimeout);
        }

        poll[tId] = setInterval(
            function() {
                if (conn && conn.readyState == 4) {
                    clearInterval(poll[tId]);
                    poll[tId] = null;

                    if (cbTimeout) {
                        clearTimeout(pub.timeout[tId]);
                        pub.timeout[tId] = null;
                    }

                    handleTransactionResponse(o, callback);
                }
            },
            pub.pollInterval);
    }

    /**
     * Pushes the request into the queue if a connection object can be created
     * na dimmediately processes the queue.
     *
     */
    function asyncRequest(method, uri, callback, postData)
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
               postData : postData
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
            return _asyncRequest(to.method, to.uri, to.callback, to.postData, to.o);
        }
    }


    // private
    function _asyncRequest(method, uri, callback, postData, o)
    {
        if (o) {
            o.conn.open(method, uri, true);

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
    function getConnectionObject()
    {
        var o;

        try {
            //console.log(pub.transactionId+" is the current transaction id");
            if (o = createXhrObject(pub.transactionId)) {
                pub.transactionId++;
            }
        } catch(e) {
        } finally {
            return o;
        }
    }

    // private
    function createXhrObject(transactionId)
    {
        var http;

        try {
            http = new XMLHttpRequest();
        } catch(e) {
            for (var i = 0; i < activeX.length; ++i) {
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
                    data = xmlData || (Ext.isObject(jsonData) ? Ext.encode(jsonData) : jsonData);
                }
            }
            return asyncRequest(method || options.method || "POST", uri, cb, data);
        },

        serializeForm : function(form)
        {
            var fElements = form.elements || (document.forms[form] || Ext.getDom(form)).elements,
                hasSubmit = false,
                encoder = encodeURIComponent,
                element,
                options,
                name,
                val,
                data = '',
                type;

            Ext.each(fElements, function(element) {
                name = element.name;
                type = element.type;

                if (!element.disabled && name){
                    if(/select-(one|multiple)/i.test(type)){
                        Ext.each(element.options, function(opt) {
                            if (opt.selected) {
                                data += String.format("{0}={1}&",
                                                     encoder(name),
                                                     encoder((opt.hasAttribute ? opt.hasAttribute('value') : opt.getAttribute('value') !== null) ? opt.value : opt.text));
                            }
                        });
                    } else if(!/file|undefined|reset|button/i.test(type)) {
                        if(!(/radio|checkbox/i.test(type) && !element.checked) && !(type == 'submit' && hasSubmit)){

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