package RapidApp::Layout::BannerBody;

use strict;
use warnings;

use Moose;
extends 'Catalyst::Model';


has 'logo' 						=> ( is => 'ro',	default => ''				);
has 'banner_height'			=> ( is => 'ro',	default => 10				);

has 'browser_panel'			=> ( is => 'ro',	default => sub {{}}		);
has 'c'							=> ( is => 'rw'	);


sub main_viewpanel {
	my $self = shift;
	$self->c(shift);

	return {
		layout => 'border',
		xtype		=> 'container',
		items		=> [
			$self->main_toolbar,
			$self->browser_panel
		]
	};
}



sub main_toolbar {
	my $self = shift;
	return {
		xtype				=> 'container',
		region			=> 'north',
		layout			=> 'border',
		height			=> $self->banner_height,
		border			=> 0,
		bodyBorder 		=> 0,
		hideBorders		=> 1,
		cls				=> 'sbl-panel-body-noborder',
		autoEl			=> {},
		defaults	=> {
			bodyCssClass	=> 'sbl-panel-body-noborder',
		},
		items		=> [
			{
				region	=> 'west',
				width		=> 400,
				margins		=> {
					left		=> 4,
					right		=> 4,
					top		=> 6,
					bottom	=> 4
				},
				#html		=> '<img src="/assets/rapidapp/images/static/dbi_explorer_logo.gif">',
				html		=> '<img src="' . $self->logo . '">',
				
			},
			{
				region	=> 'center',
				layout	=> 'border',
				defaults	=> {
					bodyCssClass	=> 'sbl-panel-body-noborder',
				},
				items		=> [
					$self->current_user_area,
					{
						region	=> 'center',
						layout	=> 'fit',
						
					}
				]
			}
		]
	};
}


sub current_user_area {
	my $self = shift;
	
	my $list = [];
	
	if (defined $self->c and $self->c->user_exists) {
		$list = [
			'->',
			$self->c->user->get('email'),
			{ xtype => 'tbseparator' },
			$self->change_password_button,
			{ xtype => 'tbseparator' },
			$self->logout_button
		];
	}
	else {
		$list = [
			'->',
			'Not logged in',
			{ xtype => 'tbseparator' },
			$self->login_button
		];
	}

	return {
		region		=> 'north',
		xtype			=> 'panel',
		margins		=> {
			left	=> 10,
			right	=> 10
		},
		#boxMaxWidth			=> 200,
		height		=> 0,
		bbar			=> { items => $list	}
	};
}


sub login_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Login',
		iconCls			=> 'icon-key',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('/object/login_window/');~
	};
}




sub logout_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Logout',
		iconCls			=> 'icon-logout',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('/object/logout_window/');~
	};
}


sub change_password_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Change Password',
		iconCls			=> 'icon-key',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('/change_pw_window/');~
	};
}



1;
