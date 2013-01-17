Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.genericChangePW = function(username,post_url) {

	// Shouldn't come up, but check for and close existing windows:
	var winId = 'general-change-pw-window';
	var curWin = Ext.getCmp(winId);
	if(curWin){ curWin.close(); }
	
	var win;
	
	var newPwField = new Ext.form.TextField({
		name: 'new_pw',
		inputType: 'password',
		fieldLabel: 'New Password',
		allowBlank: false
	});
	
	var oldPwField = new Ext.form.TextField({
		name: 'current_pw',
		inputType: 'password',
		fieldLabel: 'Current Password',
		allowBlank: false
	});
	
	var success_fn = function(res) {
		// Check for special text in response body:
		if(res && res.responseText && res.responseText == 'bad_old_pw'){
			win.hide_mask();
			return Ext.Msg.alert('Bad Password', 'Current password incorrect');
		}

		win.close();
		Ext.Msg.alert('Success', 'Password Changed Successfully');
	};
	
	var failure_fn = function() {
		win.hide_mask();
		// Don't show a message; assume the backend set a RapidApp exception:
		//Ext.Msg.alert('Failed', 'Failed to change password');
	};
	
	var doChange = function() {
		win.show_mask();
		Ext.Ajax.request({
			url: post_url,
			method: 'POST',
			params: { 
				username: username, 
				old_pw: oldPwField.getValue(),
				new_pw: newPwField.getValue()
			},
			success: success_fn,
			failure: failure_fn
		});
	};
	
	var fp = new Ext.form.FormPanel({
		xtype: 'form',
		frame: true,
		labelAlign: 'right',
		
		//plugins: ['dynamic-label-width'],
		labelWidth: 160,
		labelPad: 15,
		bodyStyle: 'padding: 10px 25px 5px 10px;',
		defaults: { anchor: '-0' },
		autoScroll: true,
		monitorValid: true,
		buttonAlign: 'right',
		minButtonWidth: 100,
		
		items: [
			{ html: '<div class="ra-change-pw-heading">' +
					'<div>Change&nbsp;Password</div>' +
					'<div class="sub">Username:&nbsp;&nbsp;<span class="blue-text-code">' + 
						username + 
					'</span></div>' +
				'</div>'
			},
			{ xtype: 'spacer', height: 10 },
			
			oldPwField,
			newPwField,
			{
				name: 'confirm_pw',
				xtype: 'textfield',
				inputType: 'password',
				fieldLabel: 'Confirm New Password',
				allowBlank: false,
				validator: function(v) {
					if(v != newPwField.getValue()) {
						return 'Passwords do not match';
					}
					return true;
				}
			}
		],
		
		buttons: [
			{
				name: 'ok',
				text: 'Ok',
				iconCls: 'icon-key',
				formBind: true,
				handler: doChange
			},
			{
				name: 'cancel',
				text: 'Cancel',
				handler: function(btn) {
					win.close();
				},
				scope: this
			}
		]
	});
	
	

	win = new Ext.Window({
		id: winId, 
		title: 'Change Password (' + username + ')',
		layout: 'fit',
		width: 475,
		height: 350,
		minWidth: 455,
		minHeight: 350,
		closable: true,
		closeAction: 'close',
		modal: true,
		items: fp,
		show_mask: function() { win.myMask.show(); },
		hide_mask: function() { win.myMask.hide(); },
		listeners: {
			afterrender: function() {
				var El = win.getEl()
				// Create the actual mask object tied to the window
				win.myMask = new Ext.LoadMask(El, {msg:"Please wait..."});
				
				new Ext.KeyMap(El, {
					key: Ext.EventObject.ENTER,
					shift: false,
					alt: false,
					fn: function(keyCode, e){
						fp.el.select('button').item(0).dom.click();
					}
				});
			},
			show: function(){
				oldPwField.focus('',10); 
				oldPwField.focus('',100); 
				oldPwField.focus('',300);
			}
		}
	});
	
	win.show();
};