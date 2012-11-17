Ext.ns('Ext.ux.RapidApp');

Ext.ux.RapidApp.genericChangePW = function(username,post_url) {

	var win;
	
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
			{
				name: 'current_pw',
				xtype: 'textfield',
				inputType: 'password',
				fieldLabel: 'Current Password',
			},
			{
				name: 'new_pw',
				xtype: 'textfield',
				inputType: 'password',
				fieldLabel: 'New Password',
			},
			{
				name: 'confirm_pw',
				xtype: 'textfield',
				inputType: 'password',
				fieldLabel: 'Confirm New Password',
			},
		],
		
		buttons: [
			{
				name: 'change',
				text: 'Change Password',
				iconCls: 'icon-save',
				width: 175,
				formBind: true,
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
		title: 'Change Password (' + username + ')',
		layout: 'fit',
		width: 450,
		height: 350,
		minWidth: 425,
		minHeight: 350,
		closable: true,
		closeAction: 'close',
		modal: true,
		items: fp
	});
	
	win.show();
};