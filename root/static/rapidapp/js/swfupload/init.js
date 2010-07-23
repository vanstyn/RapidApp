Ext.onReady(function(){

    Ext.QuickTips.init();
    
    // turn on validation errors beside the field globally
    Ext.form.Field.prototype.msgTarget = 'side';


    /*====================================================================
     * Individual checkbox/radio examples
     *====================================================================*/
    
    // Using checkbox/radio groups will generally be easier and more flexible than
    // using individual checkbox and radio controls, but this shows that you can
    // certainly do so if you only need a single control, or if you want to control  
    // exactly where each check/radio goes within your layout.
  
    
    // combine all that into one huge form
    fp = new Ext.ux.SwfUploadPanel({
        title: 'SWF Upload (Max Filesize 1 MB)',
        frame: true,
		post_params : {
                    "ASPSESSID" : session
                },
        upload_url : 'upload.aspx',
        labelWidth: 110,
        width: 600,
        height: 400,
        renderTo:'placeholder'
    });
});