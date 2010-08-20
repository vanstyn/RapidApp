/**
	* @class extswfuploadbtn
	* @extends Ext.Button
	* simple button extended with an swfupload multifile dialog and realtime progress bars
	* @param {Object} conf The configuration object
	* @cfg {String} text The text to place on the button
	* @cfg {Object} postparams The params object to be passed as POST var to backend
	* @cfg {Integer} minWidth The minimum width of the button
	* @cfg {String} tooltop The tooltip for the button (not working now...)
	* @cfg {String} id The Ext ID to asign to the button
	* @cfg {Integer} fileuploadlimit Maximum number of file to upload per session, default: 20
	* @cfg {Integer} filequeuelimit Maximum number of files to queue per session, default: 20
	* @cfg {Boolean} hidden Whether to render hidden or not, default: true
	* @cfg {Integer} statuswindowheight The height of the status window
	* @cfg {Boolean} disabled Whether to render disabled or not, default: true
	* @cfg {String} placeholder The DOM name to use for flash object, auto added to 
	* the button's div, default btnUploadHolder
	* @cfg {Boolean} jsonresponses Server returns json encoded stream, default: true
	* @cfg {String} jsonresponsefield Field name of json server response, default: msg
	* @cfg {String} uploadurl The url to use for backend processing of uploads, default: null
	* @cfg {String} flashurl The url to use for access to swfupload.swf, default: null
	* @cfg {String} filesizelimit The maximum file size allowed, default "2 MB"
	* @cfg {String} buttonimageurl The url to retrieve the FLASH button image, will overlay the default Ext button, default:  null
	* @cfg {Constant} buttonwindowmode The mode for the FLASH screen, default: SWFUpload.WINDOW_MODE.TRANSPARENT
	* @cfg {Function} uploadstarthandler Override local handler, default: myCustomUploadStartHandler
	* @cfg {Function} uploadsuccesshandler Override local handler, default: myCustomUploadSuccessHandler
	* @cfg {Function} uploadprogresshandler Override local handler, default: myCustomProgressHandler
	* @cfg {Function} filequeuedhandler Override local handler, default: myCustomFileQueuedHandler
	* @cfg {Function} filedialogcompletehandler Override local handler, default: myCustomDialogCompleteHandler
	* @cfg {Function} filedialogstarthandler Override local handler, default: myCustomFileDialogStartHandler
	* @cfg {Function} filequeueerrorhandler Override local handler, default: myCustomFileQueueErrorHandler
	* @cfg {Function} fileuploaderrorhandler Override local handler, default myCustomFileUploadErrorHandler
	* @cfg {Boolean} hideoncomplete Whether to hide the display window on completion or not, default: false
	* @cfg {Boolean} isSingle Whether or not to allow only single file upload or not, default: false
	* @cfg {String} iconpath Path to icon collection, default: '/fw-sales/wp-content/plugins/funeralworks_obituary_plugin/extjs/resources/images/icons/'
	*
	* needs following css for correct positioning of button overlay
	*	.swfupload {
	*	    position: absolute;
	*	    z-index: 1;
	*	    vertical-align: top;
	*	    text-align: center;
	*	}
	*/

	
	Ext.ux.swfbtn = function(cfg){
	    this.text = cfg.text || "Add Slides";
	    this.minWidth = cfg.minWidth || 84;
	    this.tooltip = cfg.tooltip ||  '';
	    this.id = cfg.id || 'addmemphotobtn';
	    this.hidden = cfg.hidden || false;
	    this.disabled = cfg.disabled || false;
	    this.statuswindowheight = cfg.statuswindowheight || 150;
	    this.icon = cfg.icon || '';

	    var iconpath = cfg.iconpath || '/fw-sales/wp-content/plugins/funeralworks_obituary_plugin/extjs/resources/images/icons/';
	    var swfu, selectedrow, msg, numfiles=0, totalbytes=0, extrapostparams=new Array();
	    var custompostparams = cfg.customparams || '';
	    
    	var fileprogressbar = new Ext.ProgressBar({
    		text: 'File upload progress',
    		hidden: true,
    		height: 25,
    		autoWidth: true
    	});
    	
    	var o = new Ext.ProgressBar({
    		text: 'Overall progress',
    		height: 25,
    		hidden: true,
    		autoWidth: true
    	});
    	
	    var filestore = new Ext.data.JsonStore({
    		data: [],
    		fields: ['id', 'index', 'name', 'size', 'type', 'creationdate', 'modificationdate', 'filestatus']
    	});

		var rec = Ext.data.Record.create([
			{name: 'id', mapping: 'id'},
			{name: 'index', mapping: 'index'},
			{name: 'name', mapping: 'name'},
			{name: 'size', mapping: 'size'},
			{name: 'type', mapping: 'type'},
			{name: 'creationdate', mapping: 'creationdate'},
			{name: 'modificationdate', mapping: 'modificationdate'},
			{name: 'filestatus', mapping: 'filestatus'}
		]);
		
		function translateSwfStatus(val, meta, rec, row, col, store){
			switch(val){
				case -1 :
					text = "Queued";
				break;
				case -2:
					text = "Uploading";
				break;
				case -3:
					text = "ERROR";
				break;
				case -4:
					text = "Completed";
				break;
				default:
					text = val;
				break;
			}
			return(text);
		}
		
		var cm = new Ext.grid.ColumnModel({
			defaults: {
				sortable: true
			},
			columns: [
				{header: 'Name', width: 150, dataIndex: 'name'},
				{header: 'Size', width: 60, dataIndex: 'size'},
				{header: 'Created', width: 300, dataIndex: 'creationdate'},
				{id: 'filestatus', header: 'Status', width: 100, dataIndex: 'filestatus', renderer: translateSwfStatus}
			]
		});
		
		var addfiles = new Ext.Button({
			text: cfg.isSingle ? 'Select File':'Add Files to Queue',
			icon: iconpath + '/add.png',
			style: 'padding-right: 10px;',
			listeners: {
				'render': function(btn) {
		        	// create a div to render to
		    		Ext.get(this.id).child('em').insertFirst({tag: 'span', id: cfg.placeholder || 'btnUploadHolder'});
		    		var settings = {
			    		button_window_mode: SWFUpload.WINDOW_MODE.TRANSPARENT,
				    	button_placeholder_id: cfg.placeholder || 'btnUploadHolder',
				    	button_image_url: cfg.buttonimageurl || '',
				    	button_width: cfg.buttonwidth || Ext.get(this.id).getWidth(),
				    	button_height: cfg.buttonheight || 20,
						upload_url: cfg.uploadurl || '',
						flash_url: cfg.flashurl || '',
						post_params: cfg.postparams,	// actaully set dynamically in local handlers
						file_types: cfg.filetypes || "",
						file_types_description: cfg.filetypesdescription || "Web Image Files",
						file_size_limit: cfg.filesizelimit || "2 MB",
						file_post_name: cfg.filepostname || 'Filedata',
						file_upload_limit: cfg.fileuploadlimit || 0,
						file_queue_limit: cfg.filequeuelimit || 0,
						file_dialog_start_handler: cfg.filedialogstarthandler || myCustomFileDialogStartHandler,
						upload_start_handler: cfg.uploadstarthandler || myCustomUploadStartHandler,
						upload_success_handler: cfg.uploadsuccesshandler || myCustomUploadSuccessHandler,
						upload_progress_handler: cfg.progresshandler || myCustomProgressHandler,
						file_queued_handler: cfg.filequeuedhandler || myCustomFileQueuedHandler,
						file_dialog_complete_handler: cfg.dialogcompletehandler || myCustomDialogCompleteHandler,
						file_queue_error_handler: cfg.filequeueerror || myCustomFileQueueErrorHandler,
						upload_error_handler: cfg.uploaderrorhandler || myCustomUploadErrorHandler,
						upload_complete_handler: cfg.uploadcompletehandler || myCustomUploadCompleteHandler,
						custom_settings: cfg.customsettings || {},
						debug: cfg.debug || false
					};
		    		var serverMessages="";	    	

		    		function myCustomFileDialogStartHandler(){
				    }
			
				    function myCustomDialogCompleteHandler(numselected, numqueued, num){
				    	// display the progress bar window
				    	if(numselected) {
				    		if(cfg.isSingle && num > 1){
				    			myCustomFileQueueErrorHandler('', SWFUpload.QUEUE_ERROR.QUEUE_LIMIT_EXCEEDED, '1');
				    			clearqueue();
				    		} else {
						    	totalbytessent = 0;
						    	swffilessent = 0;
						    	lastbytecount = 0;
					    		upload.enable();
					    		clearq.enable();
				    		}
					    }
				    }
			
				    function myCustomFileQueuedHandler(f){
				    	var myrec = new rec({
				    		id: f.id,
				    		index: f.index,
				    		name: f.name,
				    		size: f.size,
				    		type: f.type,
				    		creationdate: f.creationdate,
				    		modificationdate: f.modificationdate,
				    		filestatus: f.filestatus
				    	});
				    	filestore.add(myrec);
				    	totalbytes += f.size;
				    	if(cfg.isSingle) {
				    		addfiles.disable();
				    	}
				    }
			
					function myCustomFileQueueErrorHandler(file, ec, m){
						try { // Handle this error separately because we don't want to create a FileProgress element for it.                 
							switch (ec) {
				                 case SWFUpload.QUEUE_ERROR.QUEUE_LIMIT_EXCEEDED:
		                         	msg = ": You have attempted to queue too many files.\n" + (message === 0 ? "You have reached the upload limit." : "You may select " + (message > 1 ? "up to " + message + " files." : "one file."));                         
		                         case SWFUpload.QUEUE_ERROR.FILE_EXCEEDS_SIZE_LIMIT:                        
		                         	msg = " is too big.  Not queued for upload.";                         
		                         	this.debug("Error Code: File too big, File name: " + file.name + ", File size: " + file.size + ", Message: " + message);                         
		                         case SWFUpload.QUEUE_ERROR.ZERO_BYTE_FILE:                         
		                         	msg = " is empty.  Not queued for upload.  Please select another file.";                         
		                         	this.debug("Error Code: Zero byte file, File name: " + file.name + ", File size: " + file.size + ", Message: " + message);                         
		                         case SWFUpload.QUEUE_ERROR.INVALID_FILETYPE:                         
		                         	msg = " is not an allowed file type. Not queued for upload.";                         
		                         	this.debug("Error Code: Invalid File Type, File name: " + file.name + ", File size: " + file.size + ", Message: " + message);                         
		                         default:                         
		                         	msg = ": An error occurred with the upload. Try again later.";                         
		                         	this.debug("Error Code: " + errorCode + ", File name: " + file.name + ", File size: " + file.size + ", Message: " + message);                         
		                     }         
		                 } catch (e) {         } 	
		                Ext.MessageBox.show({
		                	title: 'File Selection Error',
		                	msg: (file ? 'File '+file.name+msg:cfg.isSingle ? 'Too many files selected.  Max is '+m+', queue cleared.  Please select a single file only.':"Undefined error"),
		                	buttons: Ext.MessageBox.OK,
		                	scope: this
		                });
						return;
					}
					
					function myCustomUploadErrorHandler(file, e, m){
						Ext.MessageBox.show({
							title: 'File Upload Error',
							msg: m,
							buttons: Ext.MessageBox.OK,
							fn: function() {
								clearq.disable();
								if(!cfg.isSingle) {
									o.updateProgress(0, 'Overall Progress');
									o.hide();
								}
								fileprogressbar.updateProgress(0);
								fileprogressbar.hide();
							}
						});
					}
					
					function myCustomUploadStartHandler(file){
						var pp = cfg.postparams;
						var parms = extrapostparams[swffilessent];
						Ext.each(parms, function(item, ind, all){
							eval("pp."+ item.id +" = item.val;");
						});
			    		numfiles = filestore.getCount();
			    		swfu.setPostParams(pp);
			    		if(!o.isVisible() && !cfg.isSingle) o.show();
			    		if(!fileprogressbar.isVisible()) fileprogressbar.show();
			    		cancelupload.enable();
			    		clearq.disable();
				    	var r = filestore.findExact('id', file.id);
				    	if(r != -1) {
				    		var rec = filestore.getAt(r);
				    		rec.set('filestatus', file.filestatus);
				    	}
			    		fileprogressbar.updateProgress(0, 'Sending '+file.name+' (file '+(swffilessent+1)+' of '+numfiles+')');
				    	return true;
				    }
			
				    function myCustomUploadSuccessHandler(file, server_data, receivedResponse){
				    	lastbytecount = 0;
				    	++swffilessent;
			    		if(cfg.jsonresponses) {
			    			var json = Ext.util.JSON.decode(server_data);
			       			serverMessages += json.msg;
			    		} else {
			    			serverMessages += server_data;
			    		}
			       		serverMessages += "<br><br>";
				    	if(swffilessent == filestore.getCount()) {
				    		
                            // added by HV because this code sucks:
                            if (cfg.completehandler) { return cfg.completehandler(arguments); }
                            //
                            
                            Ext.MessageBox.show({
				    			title: 'Upload Complete',
				    			msg: serverMessages,
				    			buttons: Ext.MessageBox.OK,
				    			fn: function() {
				    				filestore.removeAll();
				    				serverMessages = "";
				    			}
				    		});
			    			numfiles = 0;
			    			totalbytes = 0;
			    			fileprogressbar.hide();
			    			o.hide();
			    			clearq.disable();
			    			upload.disable();
			    			delfile.disable();
			    			extrapostparams = [];
							// reload store data if we have a store defined
				    		// note: must have global scope
				    		if(cfg.store){
					    		eval(cfg.store+'.reload();');
					    	}
					    	if(cfg.hideoncomplete) gridwin.hide();
				    	}
				    	cancelupload.disable();
				    }
				    
				    function myCustomProgressHandler(file, b, t){
				    	// update progress bar with new information
				    	totalbytessent += b - lastbytecount;
				    	fileprogressbar.updateProgress((b/t), 'Sending '+file.name+' (file '+(swffilessent+1)+' of '+numfiles+') ('+b+'/'+t+')');
				    	if(!cfg.isSingle) o.updateProgress((totalbytessent/totalbytes));
				    	lastbytecount = b;
				    }
				    
				    function myCustomUploadCompleteHandler(f){
				    	var r = filestore.findExact('id', f.id);
				    	if(r != -1) {
				    		var rec = filestore.getAt(r);
				    		rec.set('filestatus', f.filestatus);
				    	}
				    	if(cfg.isSingle){
				    		gridwin.hide();
				    	}
				    }
				    
			    	swfu = new SWFUpload(settings);
				}
			}
		});

		var delfile = new Ext.Button({
			text: cfg.isSingle ? 'Delete File':'Delete File from Queue',
			icon: iconpath+'/delete.png',
			style: 'padding-right: 10px;',
			disabled: true,
			handler: function(){
				var f = filestore.getAt(selectedrow);
				swfu.cancelUpload(f.data.id, false);
				filestore.removeAt(selectedrow);
				addfiles.enable();
				this.disable();
			}
		});
		
		var cancelupload = new Ext.Button({
			text: 'Cancel Upload',
			icon: iconpath+'/cancel.png',
			style: 'padding-right: 10px;',
			disabled: true,
			handler: clearqueue
		})
		
		var upload = new Ext.Button({
			text: 'Begin Upload',
			icon: iconpath+'/arrow_up.png',
			style: 'padding-right: 10px;',
			disabled: true,
			handler: function() {
	    		if(custompostparams){
		   			var formwindows = [];
	    			var results = {};
	    			var i=0;
	    			var numqueued = filestore.getCount();
	    			var filesprocessed = 0;
	    			// var tform = {}; 
	    			// while(i < numqueued){
	    			filestore.each(function(rec){
		    			eval("var formid = 'tform"+i+"';");
		    			eval("var winid = 'swfuploadwin"+rec.data.id+"';");
		    			eval("var buttonid = '"+formid+"button0';");
		    			var btn = new Ext.Button({
    						text: 'Save Data',
    						id: buttonid,
    						listeners: {
    							'click': function(){
	    							filesprocessed += 1;
	    							eval("var t = Ext.getCmp('tform"+i+"').getForm();");
	    							var tt = t.getValues();
	    							var record = [];
	    							Ext.each(t.items.items, function(item, ind, all){
	    								var id = item.name;
	    								var value = t.findField(id).getValue();
	    								record.push({id: id, val: value});
	    							});
									extrapostparams[i] = record;
									formwindows[i].close();
	    							if(filesprocessed == numqueued){
	    								swfu.startUpload();
	    							} else {
	    								if(i++ < numqueued) {
	    									formwindows[i].show();
	    								}
	    							}
    							}
    						}		    			
		    			});
		    			
	    				if(!cfg.form) {
		    				var tform = new Ext.form.FormPanel({
		    					id: formid,
		    					layout: 'form',
		    					bodyStyle: 'padding: 10px;',
		    					title: rec.data.name+': Additional Information Required',
		    					autoWidth: true,
		    					autoHeight: true,
		    					buttons: [btn],
		    					keys: [{
							    	key: [10,13],
							    	handler: function(t, e){
							    		this.fireEvent('click');
							    	},
							    	scope: btn
		    					}]
		    				});
		    				Ext.each(custompostparams, function(item, index, all){
		    					switch(item.fieldtype){
		    						case 'checkbox':
		    							var fld = new Ext.form.Checkbox({
		    								name: item.title,
				    						fieldLabel: item.label,
				    						allowBlank: item.allowBlank || true
		    							});
		    						break;
		    						default:
				    					var fld = new Ext.form.TextField({
				    						name: item.title,
				    						fieldLabel: item.label,
				    						maxLength: item.maxlength,
				    						allowBlank: item.allowBlank || true
				    					});
				    				break;
		    					}
		    					tform.add(fld);
			    			});
	    				} else {
	    					// preconfigured form passed in as argument
	    					var tform = cfg.form.cloneConfig({
	    						id: formid,
	    						bodyStyle: 'padding: 10px;',
	    						buttons: [btn],
	    						keys: [{
							    	key: [10,13],
							    	handler: function(t, e){
							    		this.fireEvent('click');
							    	},
							    	scope: btn
		    					}]
	    					});
	    				}
	    				
	    				tform.on({
	    					'afterrender': function() {
			    				var w = this.el.getWidth();
			    				var z = this.el.getHeight();
			    				this.ownerCt.setWidth((w+50));
			    				this.ownerCt.setHeight((z+30));
			    			}
	    				});
	    				
		    			var winoptions = {
		    				id: winid, 
		    				layout: 'fit',
		    				autoHeight: true, 
		    				autoWidth: false,
		    				width: 300,
		    				autoScroll: true,
		    				closeAction: 'close', 
		    				hidden: true, 
		    				modal: true, 
		    				items: [tform]
		    			}; 
		    			formwindows[i] = new Ext.Window(winoptions);
		    			formwindows[i].on({
		    				'show': function() {
			    				var form = Ext.getCmp(formid).getForm();
			    				var fld = form.items.items[0];
			    				fld.focus(false, 50);
			    			}
		    			});
		    			i++;
		    		});
		    		
		    		i = 0;
		    		formwindows[0].show();
	    		} else {
	    			swfu.startUpload();
	    		}
			}
			// scope: Ext.getCmp(cfg.id || 'addmemphotobtn')
		});
		
		function clearqueue(){
			filestore.each(function(rec){
				var id = rec.data.id;
				swfu.cancelUpload(id, false);
			});
			filestore.removeAll();
			clearq.disable();
			upload.disable();
		}
		
		var clearq = new Ext.Button({
			text: 'Clear Queue',
			disabled: true,
			hidden: cfg.isSingle ? true:false,
			icon: iconpath+'/world_delete.png',
			handler: clearqueue
		});
		
		var grid = new Ext.grid.GridPanel({
			header: false,
			store: filestore,
			cm: cm,
			viewConfig: {
				forceFit: true
			},
			width: 600,
			height: cfg.isSingle ? 100:380,
			autoScroll: true,
			frame: true,
			stripeRows: true,
			bbar: [addfiles, delfile, clearq, cancelupload, upload],
			listeners: {
				rowclick: function(g, row, e){
					selectedrow = row;
					delfile.enable();
				}
			}
		});

		var errorpanel = new Ext.Panel({
			width: 600,
			autoHeight: true
		});

		var gridwin = new Ext.Window({
            id: cfg.id + '-win',
			title: 'File Upload Queue',
			closeAction: 'hide',
			autoScroll: true,
			modal: true,
			width: 614,
			autoHeight: true,
			items: [o, errorpanel, grid, fileprogressbar]
		});
		
		gridwin.on('show', function(){
			addfiles.enable();
			fileprogressbar.hide();
			fileprogressbar.updateProgress(0);
			cancelupload.disable();
			upload.disable();
			if(cfg.isSingle) {
				filestore.removeAll();
			}
		});
		
	    Ext.ux.swfbtn.superclass.constructor.call(this);
	
	    this.addListener({
	    	'click': function() {
	    		gridwin.show();
	    	},
			scope: this
		}); 
	}
	
Ext.extend(Ext.ux.swfbtn, Ext.Button);