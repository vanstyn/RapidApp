package RapidApp::ExtJS;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Grid code object
#
#
# 2009-10-24:	Version 0.2 (HV)
#	Made "Strip Received Headers" actually work when enabled


use strict;
use JSON::PP;

use Moose;



my $VERSION = '0.1';




sub Login_Window_code {
	my $self = shift;
	my $Params = shift;
	
	return undef unless (defined $Params->{submit_url});
	
	$Params->{onSuccess_eval} = q~Ext.getCmp('~ . $Params->{name} . q~').close();~ . $Params->{onSuccess_eval};
	
	$Params->{name} 		= 'login_window'	unless (defined $Params->{name});
	$Params->{title} 		= 'Login'			unless (defined $Params->{title});
	$Params->{height}		= 230 				unless (defined $Params->{height});
	$Params->{width} 		= 300 				unless (defined $Params->{width});
	$Params->{iconCls}	= 'icon-key' 		unless (defined $Params->{iconCls});
	$Params->{banner} 	= 'Login' 			unless (defined $Params->{banner});
	
	$Params->{username_label} 	= 'username' 			unless (defined $Params->{username_label});
	
	if (defined $Params->{logo}) {
		$Params->{logo} = '<img src="' . $Params->{logo} . '" style="padding-right:10px">';
	}
	
	return $self->Window_code({
		close_first	=> 1,
		name			=> $Params->{name},
		title			=> $Params->{title},
		height		=> $Params->{height},
		width			=> $Params->{width},
		iconCls		=> $Params->{iconCls},
		layout		=> 'fit',
		items			=>  {
			xtype						=> 'submitform',
			url						=> $Params->{submit_url},
			bodyStyle				=> 'padding:5px 5px 0',
			id							=> 'login_form',
			frame						=> 1,
			autoScroll				=> 1,
			show_result				=> 0,
			#focus_field_id			=> 'username_field',
			#activeItem				=> 'username_field',
			submitOnEnter			=> 1,
			onSuccess_eval			=> $Params->{onSuccess_eval},
											
			onFail_eval				=> q~Ext.getCmp('password_field').reset();~ .
											q~var info_box = Ext.get('login_info_box');~ .
											q~Ext.DomHelper.overwrite(info_box, { id: 'login_info_box', ~ .
												q~html: '<center><div style="color: red; font-weight: bolder;">' + action.result.msg + '</div></center<br>' });~ .
											q~info_box.fadeIn({ duration: 2 });~ . 
											q~info_box.fadeOut({ duration: 2 });~,
			defaults	=> {
				xtype		=> 'textfield',
				labelStyle	=> 'text-align:right;',
			},
			items		=> [
				{
					xtype			=> 'box',
					html			=> '<div style="font-size:175%">' . $Params->{logo} . $Params->{banner} . '</div>'
				},{
					xtype			=> 'box',
					id				=> 'login_info_box',
					html			=> '<br><br>',
				
				},{
					id				=> 'username_field',
					itemId		=> 'username_field',
					name			=> 'username',
					fieldLabel	=> $Params->{username_label}
				},{
					id				=> 'password_field',
					name			=> 'password',
					fieldLabel	=> 'password',
					inputType	=> 'password'
				}
			],
			buttons	=> [
				{
					xtype					=> 'dbutton',
					text					=> 'Login',
					id						=> 'login_button',
					submitFormOnEnter	=> 1,
					handler_func		=> q~var formPanel = btn.findParentByType('submitform'); ~ .
												q~formPanel.submitProcessor();~
				},
				{
					xtype					=> 'dbutton',
					text					=> 'Cancel',
					handler_func		=> q~btn.findParentByType('window').close();~
				}
			]
		},
		#listeners => {
		#	afterrender => RapidApp::JSONFunc->new( raw => 1, func =>
		#		'function(fp) {' .
		#			'var field = Ext.getComponent("username_field");' . 
		#			'field.focus("",10);' .
		#		'}'
		#	)
		#}
	}) . q~var field = Ext.getCmp('username_field'); field.focus('',10); field.focus('',200); field.focus('',500);~,


}



sub Window_code {
	my $self = shift;
	my $Params = shift;
	
	$Params->{name} = 'nameless_window' unless ($Params->{name});
	$Params->{id} = $Params->{name} unless ($Params->{id});
	$Params->{height}	= 300 unless (defined $Params->{height});
	$Params->{width}	= 400 unless (defined $Params->{width});
	$Params->{autoLoad} = {
		url		=> $Params->{url},
		scripts	=> 1
	} if ($Params->{url} and not $Params->{autoLoad});

	$Params->{autoLoad}->{params} = $Params->{params} if ($Params->{params} and not $Params->{autoLoad});

	my $no_show = 0;
	if ($Params->{do_not_show}) {
		delete $Params->{do_not_show};
		$no_show = 1;
	}
	
	my $code = '';
	
	if ($Params->{close_first}) {
		delete $Params->{close_first};
		$code .= 
			q~var win = Ext.getCmp('~ . $Params->{name} . q~'); ~ .
			q~if (win) { win.close(); } ~;
	}
	
	$code .= 'var ' . $Params->{name} . ' = ' . 
		'new Ext.Window(' . JSON::PP::json_encode($Params) . '); ';
	
	$code .= $Params->{name} . '.show();' unless ($no_show);
	
	return $code;
		
		#$Params->{name} . q~.on('beforeclose',Ext.removeNode(Ext.get('VncViewer').remove));~
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;