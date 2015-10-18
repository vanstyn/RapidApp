Ext.ns('Ext.ux.Bool2yesno');
Ext.ux.Bool2yesno = function(val) {
  if (val == null || val === "") { return Ext.ux.showNull(val); }
  if (val > 0) { return 'Yes'; }
  return 'No';
}


Ext.ns('Ext.ux.showNull');
Ext.ux.showNull = function(val) {
  if (val == null) { return '<span class="ra-null-val">(not&nbsp;set)</span>'; }
  if (val === "") { return '<span class="ra-null-val">(empty&nbsp;string)</span>'; }
  return val;
}

Ext.ns('Ext.ux.showNullusMoney');
Ext.ux.showNullusMoney = function(val) {
  if (val == null || val === "") { return Ext.ux.showNull(val); }
  return Ext.util.Format.usMoney(val);
}


Ext.ux.RapidApp.renderUtcDate= function(dateStr) {
  try {
    var dt= new Date(Date.parseDate(dateStr, "Y-m-d g:i:s"));
    var now= new Date();
    var utc= dt.getTime();
    dt.setTime(utc + Ext.ux.RapidApp.userPrefs.timezoneOffset*60*1000);
    var fmt= (now.getTime() - dt.getTime() > 1000*60*60*24*365)? Ext.ux.RapidApp.userPrefs.dateFormat : Ext.ux.RapidApp.userPrefs.nearDateFormat;
    return '<span class="RapidApp-dt"><s>'+utc+'</s>'+dt.format(fmt)+'</span>';
  } catch (err) {
    return dateStr + " GMT";
  }
}


Ext.ux.RapidApp.IconClsRenderFn = function(val) {
  if (val == null || val === "") { return Ext.ux.showNull(val); }
  //return '<div style="width:16px;height:16px;" class="' + val + '"></div>';
  return '<div class="with-icon ' + val + '">' + val + '</div>';
}


Ext.ux.RapidApp.renderRed = function(val) {
  return '<span style="color:red;">' + val + '</span>'; 
}

Ext.ux.RapidApp.boolCheckMark = function(val) {
  if (val == null || val === "" || val <= 0) { 
    return [
      '<img src="',Ext.BLANK_IMAGE_URL,
      '" class="ra-icon-12x12 ra-icon-cross-light-12x12">'
    ].join('');
  }
  return [
    '<img src="',Ext.BLANK_IMAGE_URL,
    '" class="ra-icon-12x12 ra-icon-checkmark-12x12">'
  ].join('');
}

// Returns a date formatter function based on the supplied format:
Ext.ux.RapidApp.getDateFormatter = function(format,allow_zero) {
  if (!format) { format = "Y-m-d H:i:s"; }
  return function(date) {
    if(!allow_zero && date && Ext.isString(date)) {
      // New: handle the common case of an empty/zero date
      //  better than 'Nov 30, 00-1 12:00 AM' which is what the typical format returns
      if(date == '0000-00-00' || date == '0000-00-00 00:00:00') {
        return ['<span class="ra-null-val">',date,'</span>'].join('');
      }
    }
    var dt = date instanceof Date ? date : Date.parseDate(date,"Y-m-d H:i:s");
    if (! dt) { return date; }
    return dt.format(format);
  }
}


Ext.ux.RapidApp.renderPencil = function(val) {
  return [
    '<span>',val,'</span>',
    '<img src="',Ext.BLANK_IMAGE_URL,'" class="ra-icon-14x14 ra-icon-gray-pencil">'
  ].join('');
}



Ext.ux.RapidApp.renderJSONjsDump = function(v) {
  try {
    var obj = Ext.decode(v);
    var dump = jsDump.parse( obj );
    return '<pre>' + dump + '</pre>';
  } catch(err) {
    //console.log('ERROR: ' + err);
    return Ext.ux.showNull(v); 
  }
}

Ext.ux.RapidApp.renderMonoText = function(v) {
  return '<pre class="ra-pre-wrap">' + v + '</pre>';
}

Ext.ux.RapidApp.getWithIconClsRenderer = function(icon_cls) {
  return function(value, metaData) {
    if(icon_cls) { metaData.css = 'grid-cell-with-icon ' + icon_cls; }
    return value;
  };
}

Ext.ux.RapidApp.getRendererStatic = function(str,meta) {
  meta = meta || {};
  return function(value,metaData) { 
    Ext.apply(metaData,meta);
    return str; 
  }
}




// Takes an image tag (html string) and makes it autosize via max-width:100%
Ext.ux.RapidApp.imgTagAutoSizeRender = function(v,maxheight) {
  //if(v.search('<img ') !== 0) { return v; }
  var div = document.createElement('div');
  div.innerHTML = v;
  var domEl = div.firstChild;
  if(domEl && domEl.tagName == 'IMG') { 
    var El = new Ext.Element(domEl);
    var styles = 'max-width:100%;height:auto;width:auto;';
    if(maxheight) { styles += 'max-height:' + maxheight + ';'; }
    El.applyStyles(styles);
    if(El.dom.getAttribute('width')) { El.dom.removeAttribute('width'); }
    if(El.dom.getAttribute('height')) { El.dom.removeAttribute('height'); }
    return div.innerHTML;
  }
  else {
    return v;
  }
}


Ext.ux.RapidApp.getImgTagRendererDefault = function(src,w,h,alt) {
  var def = '<img ';
  if(src){ def += 'src="' + src + '" '; }
  if(w && w != 'autosize'){ def += 'width="' + w + '" '; }
  if(h){ def += 'height="' + h + '" '; }
  if(alt){ def += 'alt="' + alt + '" '; }
  def += '>';
  
  return function(v) {
    if(!v) { return def; }
    if(w == 'autosize') {
      var maxheight = h;
      return Ext.ux.RapidApp.imgTagAutoSizeRender(v); 
    }
    return v;
  }
}


Ext.ux.RapidApp.getRendererPastDatetimeRed = function(format) {
  var renderer = Ext.ux.RapidApp.getDateFormatter(format);
  return function(date) {
    var dt = Date.parseDate(date,"Y-m-d H:i:s");
    if (! dt) { dt = Date.parseDate(date,"Y-m-d"); }
    
    if (! dt) { return Ext.ux.showNull(date); }
    
    var out = renderer(date);
    var nowDt = new Date();
    // in the past:
    if(nowDt > dt) { return '<span style="color:red;">' + out + '</span>'; }
    return out;
  }
}

Ext.ux.RapidApp.num2pct = function(num) {
  if (num != 0 && isFinite(num)) {
    num = Ext.util.Format.round(100*num,2) + '%';
  }
  if(num == 0) { num = '0%'; }
  return num;
}


Ext.ux.RapidApp.NO_DBIC_REL_LINKS = false;

Ext.ux.RapidApp.DbicRelRestRender = function(c) {
  // -- New: support case of no record object and render the disp/value outright. This
  // is an unusual use case, but could happen if the user calls the column 'renderer'
  // manually with a single value argument (see server-side code for the renderer 
  // which wraps/calls this function). This is the best way to handle this case:
  if(typeof c.record == 'undefined') {
    return Ext.ux.showNull(c.disp || c.value);
  }
  // --

  var disp = c.disp || c.record.data[c.render_col] || c.value;
  var key_value = c.record.data[c.key_col];

  // multi-rel: no link for 0 records:
  // UPDATE: *DO* show links for 0 now that these can be used to add new related records
  //if(c.multi_rel && c.value == '0') { return disp; }
  
  if(!c.value) { 
    if(!disp && !key_value) {
      // If everything is unset, including the key_col value itself,
      // we render like a normal empty value. It is only when the 
      // key_col is set but the value/disp is not (indicating a broken
      // or missing link/relationship) that we want to render the special 
      // "unavailable" string (see the following code block) -- SEE UPDATED
      // NOTE BELOW
      return Ext.ux.showNull(key_value);
    }
    c.value = key_value; 
  }
  
  if(!c.value)    { return disp; }
  if(!disp)       { return c.value; }
  if(!c.open_url)  { return disp; }
  
  var url = '#!' + c.open_url + '/';
  if(c.rest_key) { url += c.rest_key + '/'; }

  // Added for GitHub #119 -- don't show links for bad rels
  if(!key_value && key_value != '0' && key_value != '') { 
    return c.is_phy_colname ? disp : Ext.ux.showNull(key_value); 
  }

  if(c.rs) {
    // For multi-rel. value actually only contains the count of related
    // rows. key_value will contain the id of the row from which the rs originated
    url += key_value + '/rel/' + c.rs; 
  }
  else {
    // For single-rel
    url += c.value;
  }
  
  if(Ext.ux.RapidApp.NO_DBIC_REL_LINKS) {
    return disp;
  }
  
  return disp + "&nbsp;" + Ext.ux.RapidApp.inlineLink(
    url,
    "<span>open</span>",
    "ra-nav-link ra-icon-magnify-tiny",
    null,
    "Open/view: " + disp
  );
}


Ext.ux.RapidApp.DbicSingleRelationshipColumnRender = function(c) {
  var disp = c.record.data[c.render_col];
  var key_value = c.record.data[c.key_col];

  if(!c.value) { 
    if(!disp && !key_value) {
      // If everything is unset, including the key_col value itself,
      // we render like a normal empty value. It is only when the 
      // key_col is set but the value/disp is not (indicating a broken
      // or missing link/relationship) that we want to render the special 
      // "unavailable" string (see the following code block) -- SEE UPDATED
      // NOTE BELOW
      return Ext.ux.showNull(key_value);
    }
    c.value = key_value; 
  }
  
  if(c.value == null && disp == null) {
    // UPDATE: this code path will actually never occur now (after adding the
    // above call to 'showNull'). It will either display the normal null/empty
    // output or the value of the key, so this never happens!! But, after some
    // other improvements to relationship column handling, they now work correctly
    // (I think) with unset values/broken links, which they didn't before, and
    // this alternate display was actually added as a workaround for that problem
    // and is now not even needed/helpful. TODO: after verifying this is in fact true,
    // clean up the logic in this function and remove this and other not-needed
    // code and logic... Also see about applying a special style when the link
    // *is* broken and the key value is being displayed instead of the related
    // render value (I tried to do this already but it wasn't working immediately
    // and I had other, more important things to do at the time)...
    return '<span style="font-size:.90em;color:darkgrey;">' +
      '&times&nbsp;unavailable&nbsp;&times;' +
    '</span>';
  }
  
  if(!c.value)    { return disp; }
  if(!disp)       { return c.value; }
  if(!c.open_url)  { return disp; }
  
  var loadCfg = { 
    title: disp, 
    autoLoad: { 
      url: c.open_url, 
      params: { ___record_pk: "'" + c.value + "'" } 
    }
  };
    
  var url = "#loadcfg:" + Ext.urlEncode({data: Ext.encode(loadCfg)});

  return disp + "&nbsp;" + Ext.ux.RapidApp.inlineLink(
    url,
    "<span>open</span>",
    "ra-nav-link ra-icon-magnify-tiny",
    null,
    "Open/view: " + disp
  );
}




Ext.ux.RapidApp.prettyCsvRenderer = function(v) {
  if(!v) { return Ext.ux.showNull(v); }
  var sep = '<span style="color: navy;font-size:1.2em;font-weight:bold;">,</span> ';
  var list = v.split(',');
  Ext.each(list,function(item){
    // strip whitespace:
    item = item.replace(/^\s+|\s+$/g,"");
  },this);
  return list.join(sep);
}


// Renders a positive, negative, or zero number as green/red/black dash
Ext.ux.RapidApp.increaseDecreaseRenderer = function(v) {
  if (v == null || v === "") { return Ext.ux.showNull(v); }
  if(v == 0) { return  '<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
  if(v < 0) { return   '<span style="color:red;font-weight:bold;">' + v + '</span>'; }
  return           '<span style="color:green;font-weight:bold;">+' + v + '</span>'; 
};

// Renders pct up tp 2 decimal points (i.e. .412343 = 41.23%) in green or red for +/-
Ext.ux.RapidApp.increaseDecreasePctRenderer = function(val) {
  if (val == null || val === "") { return Ext.ux.showNull(val); }
  var v = Math.round(val*10000)/100;
  if(v == 0) { return  '<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
  if(v < 0) { return   '<span style="color:red;font-weight:bold;">-' + Math.abs(v) + '%</span>'; }
  return           '<span style="color:green;font-weight:bold;">+' + v + '%</span>'; 
};

// Renders money up tp 2 decimal points (i.e. 41.2343 = $41.23) in green or red for +/-
Ext.ux.RapidApp.increaseDecreaseMoneyRenderer = function(val) {
  if (val == null || val === "") { return Ext.ux.showNull(val); }
  var v = Math.round(val*100)/100;
  if(v == 0) { return  '<span style="color:#333333;font-size:1.3em;font-weight:bolder;">&ndash;</span>'; }
  if(v < 0) { return   '<span style="color:red;font-weight:bold;">' + Ext.util.Format.usMoney(v) + '</span>'; }
  return           '<span style="color:green;font-weight:bold;">+' + Ext.util.Format.usMoney(v) + '</span>'; 
};


// Returns the infitity character instead of the value when it is
// a number greater than or equal to 'maxvalue'. Otherwise, the value
// is returned as-is.
Ext.ux.RapidApp.getInfinityNumRenderer = function(maxvalue,type) {
  if(!Ext.isNumber(maxvalue)) { 
    return function(v) { return Ext.ux.showNull(v); }; 
  }
  return function(v) {
    if(Number(v) >= Number(maxvalue)) {
      // also increase size because the default size of the charater is really small
      return '<span title="' + v + '" style="font-size:1.5em;">&infin;</span>';
    }
    
    if(type == 'duration') {
      return Ext.ux.RapidApp.renderDuration(v);
    }
    
    return Ext.ux.showNull(v);
  }
};




Ext.ux.RapidApp.renderDuration = function(seconds,suffixed) {
  if(typeof seconds != 'undefined' && seconds != null && moment) {
    return '<span title="' + seconds + ' seconds">' +
      moment.duration(Number(seconds),"seconds").humanize(suffixed) +
    '</span>'
  }
  else {
    return Ext.ux.showNull(seconds);
  }
}

Ext.ux.RapidApp.renderDurationSuf = function(seconds) {
  return Ext.ux.RapidApp.renderDuration(seconds,true);
}

Ext.ux.RapidApp.renderDurationPastSuf = function(v) {
  if(typeof v != 'undefined' && v != null && moment) {
    var seconds = Math.abs(Number(v));
    return Ext.ux.RapidApp.renderDurationSuf(-seconds);
  }
  else {
    return Ext.ux.showNull(v);
  }
}


// Renders a short, human-readable duration/elapsed string from seconds.
// The seconds are divided up into 5 units - years, days, hours, minutes and seconds -
// but only the first two are shown for readability, since if its '2y, 35d',
// you probably don't care about the exact hours minutes and seconds ( i.e.
// '2y, 35d, 2h, 4m, 8s' isn't all that useful and a lot longer)
Ext.ux.RapidApp.renderSecondsElapsed = function(s) {

  if(!s) {
    return Ext.ux.showNull(s);
  }

  var years = Math.floor    ( s / (365*24*60*60));
  var days  = Math.floor   (( s % (365*24*60*60)) / (24*60*60));
  var hours = Math.floor  ((( s % (365*24*60*60)) % (24*60*60)) / (60*60));
  var mins  = Math.floor (((( s % (365*24*60*60)) % (24*60*60)) % (60*60)  / 60));
  var secs  =             ((( s % (365*24*60*60)) % (24*60*60)) % (60*60)) % 60;
  
  var list = [];
  if(years) { list.push(years + 'y'); }
  if(days)  { list.push(days  + 'd'); }
  if(hours) { list.push(hours + 'h'); }
  if(mins)  { list.push(mins  + 'm'); }
  if(secs)  { list.push(secs  + 's'); }
  
  if (list.length == 0) {
    return Ext.ux.showNull(s);
  }
  else if (list.length == 1) {
    return list[0];
  }
  else {
    return list[0] + ', ' + list[1];
  }
}



// renders a json array of arrays into an HTML Table
Ext.ux.RapidApp.jsonArrArrToHtmlTable = function(v) {

  var table_markup;
  try {
    var arr = Ext.decode(v);
    var rows = [];
    Ext.each(arr,function(tr,r) {
      var cells = [];
      Ext.each(tr,function(td,c) {
        var style = '';
        if(r == 0) {
          style = 'font-size:1.1em;font-weight:bold;color:navy;min-width:50px;';
        }
        else if (c == 0) {
          style = 'font-weight:bold;color:#333333;padding-right:30px;';
        }
        else {
          style = 'font-family:monospace;padding-right:10px;';
        }
        cells.push({
          tag: 'td',
          html: td ? '<div style="' + style + '">' +
            td + '</div>' : Ext.ux.showNull(td)
        })
      });
      rows.push({
        tag: 'tr',
        children: cells
      });
    });
    
    table_markup = Ext.DomHelper.markup({
      tag: 'table',
      cls: 'r-simple-table',
      children: rows
    });
  }catch(err){};

  return table_markup ? table_markup : v;
}

Ext.ux.RapidApp.withFilenameIcon = function(val) {
  var parts = val.split('.');
  var ext = parts.pop().toLowerCase();

  var icon_cls = 'ra-icon-document';

  if(ext == 'pdf')  { icon_cls = 'ra-icon-page-white-acrobat'; }
  if(ext == 'zip')  { icon_cls = 'ra-icon-page-white-compressed'; }
  if(ext == 'xls')  { icon_cls = 'ra-icon-page-white-excel'; }
  if(ext == 'xlsx') { icon_cls = 'ra-icon-page-excel'; }
  if(ext == 'ppt')  { icon_cls = 'ra-icon-page-white-powerpoint'; }
  if(ext == 'txt')  { icon_cls = 'ra-icon-page-white-text'; }
  if(ext == 'doc')  { icon_cls = 'ra-icon-page-white-word'; }
  if(ext == 'docx') { icon_cls = 'ra-icon-page-word'; }
  if(ext == 'iso')  { icon_cls = 'ra-icon-page-white-cd'; }

  return [
    '<span class="with-icon ', icon_cls,'">',
      val,
    '</span>'
  ].join('');
}


Ext.ux.RapidApp.renderBase64 = function(str) {

  try {
    return Ext.util.Format.htmlEncode(
      base64.decode(
        // strip any newlines:
        str.replace(/(\r\n|\n|\r)/gm,"")
      )
    );
  } catch(err) { 
    return str; 
  }
}

// http://stackoverflow.com/a/15405953
String.prototype.hex2bin = function () {
  var i = 0, l = this.length - 1, bytes = [];
  for (i; i < l; i += 2) {
    bytes.push(parseInt(this.substr(i, 2), 16));
  }
  return String.fromCharCode.apply(String, bytes);
}

String.prototype.bin2hex = function () {
  var i = 0, l = this.length, chr, hex = '';
  for (i; i < l; ++i) {
    chr = this.charCodeAt(i).toString(16)
    hex += chr.length < 2 ? '0' + chr : chr;
  }
  return hex;
}

Ext.ux.RapidApp.formatHexStr = function(str) {
  
  // http://stackoverflow.com/a/4017825
  function splitStringAtInterval (string, interval) {
    var result = [];
    for (var i=0; i<string.length; i+=interval)
      result.push(string.substring (i, i+interval));
    return result;
  }
  
  str = ['0x',str.toUpperCase()].join('');
  return splitStringAtInterval(str,8).join(' ');
}

Ext.ux.RapidApp.renderHex = function(s) {
  if(s) {
    var orig_length = s.length;
    var hex_str = Ext.ux.RapidApp.formatHexStr(s.bin2hex());
    return [
      '<code ',
        'title="binary data (length ',orig_length,')" ',
        'class="ra-hex-string">',
        hex_str,
      '</code>'
    ].join('');
  }
  else {
    return Ext.ux.showNull(s);
  }
}

// Returns a renderer that will return an img tag with its data
// embedded as base64. This is useful for blob columns which
// contain raw/binary image data
Ext.ux.RapidApp.getEmbeddedImgRenderer = function(mime_type) {
  mime_type = mime_type || 'application/octet-stream';
  return function(data) {
    if(data) {
      return ['<img src="data:',mime_type,';base64,',base64.encode(data),'">'].join('');
    }
    else {
      return Ext.ux.showNull(data);
    }
  }
}


Ext.ux.RapidApp.renderCasLink = function(v){
  if(typeof v != 'undefined' && v != null) {
    var parts = v.split('/');

    if(parts.length <= 2) {
      var sha1 = parts[0], filename = parts[1] || parts[0];
      var cls = ['filelink'];
      var fnparts = filename.split('.');
      if (fnparts.length > 1) {
        cls.push(fnparts.pop().toLowerCase());
      }
      var url = ['_ra-rel-mnt_/simplecas/fetch_content/',sha1,'/',filename].join('');
      return [
        '<div class="',cls.join(' '),'">',
          '<span>',filename,'</span>',
          '<a ',
            'href="',url,'" ',
            'target="_self" ',
            'class="ra-icon-paperclip-tiny"',
          '>save</a>',
        '</div>'
      ].join('');
    }
    else {
      // unexpected currently...
      return v;
    }
  }
  else {
    return Ext.ux.showNull(v);
  }
}



Ext.ux.RapidApp.extractImgSrc = function(str) {
  var div = document.createElement('div');
  div.innerHTML = str;
  var domEl = div.firstChild;
  if(domEl && domEl.tagName == 'IMG') {
    return domEl.getAttribute('src');
  }
  return null;
}


Ext.ux.RapidApp.renderCasImg = function(v) {
  var url, pfx = Ext.ux.RapidApp.AJAX_URL_PREFIX || '';
  if(!v) {
    url = [pfx,'/assets/rapidapp/misc/static/images/img-placeholder.png'].join('');
  }
  else {
    // Handle legacy, full <img> tag values
    if(v.search('<img ') == 0) {
      var src = Ext.ux.RapidApp.extractImgSrc(v);
      if(!src) { return v; }
      var parts = src.split('simplecas/fetch_content/');
      if(parts.length == 2) {
        v = parts[1];
      }
      else {
        return v;
      }
    }
    var parts = v.split('/');
    if(parts.length <= 2) {
      // Just for reference, this is what we expect:
      //var sha1 = parts[0], filename = parts[1] || 'image.png';
      url = ['_ra-rel-mnt_/simplecas/fetch_content/',v].join('');
    }
    else {
      // unexpected currently...
      return v;
    }
  }

  return [
    '<img src="',url,'" ',
    'style="max-width:100%;max-height:100%;">'
  ].join('');
}

Ext.ux.RapidApp.nl2brWrap = function(v) {
  return v && v.length > 1 ? [
    '<span class="ra-wrap-on">',
      Ext.util.Format.nl2br(v),
    '</span>'
  ].join('') : v;
}



Ext.ux.RapidApp.renderNegativeRed = function(v) {
  if (v == null || v === "") { return Ext.ux.showNull(v); }
  var color = v <= 0 ? 'red' : '#333333';
  return ['<span style="color:',color,';font-weight:bold;">',v,'</span>'].join('');
};
