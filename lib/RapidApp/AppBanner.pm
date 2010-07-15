package RapidApp::AppBanner;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppBase';

use RapidApp::AppAuth;

has 'no_persist'				=> ( is => 'rw',	default => 1 );

has 'height'			=> ( is => 'ro',	default => 50 );
has 'logo'				=> ( is => 'ro',	default => '/static/images/logo.png' );
has 'username_key'	=> ( is => 'ro',	default => 'username' );

has 'login_banner' => ( is => 'ro',	default => sub {
	my $self = shift;
	return $self->topmost_module->login_banner if ($self->topmost_module->can('login_banner'));
	return 'Login to the system';
});

has 'login_iconCls'			=> ( is => 'ro',	default => 'icon-key' );
has 'login_logo'				=> ( is => 'ro',	default => '/static/rapidapp/images/sportsrite_tiny.png' );
has 'login_title'				=> ( is => 'ro',	default => 'Login' );
has 'login_width'				=> ( is => 'ro',	default => 350 );
has 'login_height'			=> ( is => 'ro',	default => 230 );

has 'logout_title'			=> ( is => 'ro',	default => 'Logout...' );
has 'logout_banner'			=> ( is => 'ro',	default => 'Really Logout ?' );

has 'username_key'			=> ( is => 'ro',	default => 'username' );
has 'password_key'			=> ( is => 'ro',	default => 'password' );

has 'modules' => (is => 'ro', default => sub {
	return {
		auth			=> 'RapidApp::AppAuth'
	}
});

has 'modules_params' => (is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		auth => {
			login_banner	=> $self->login_banner,
			login_iconCls	=> $self->login_iconCls,
			login_logo		=> $self->login_logo,
			login_title		=> $self->login_title,
			login_width		=> $self->login_width,
			login_height	=> $self->login_height,
			logout_title	=> $self->logout_title,
			logout_banner	=> $self->logout_banner,
			username_key	=> $self->username_key,
			password_key	=> $self->password_key
		}
	}
});


has 'content' => ( is => 'ro', lazy => 1, default => sub {

#sub content {
	my $self = shift;
	return {
		xtype				=> 'container',
		region			=> 'north',
		layout			=> 'border',
		height			=> $self->height,
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
});

has 'current_user_area' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $list = [];
	
	if (defined $self->c and $self->c->user_exists) {
		$list = [
			'->',
			$self->c->user->get($self->username_key),
			#$self->c->user . ' Logged in.',
			#{ xtype => 'tbseparator' },
			#$self->change_password_button,
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
});


sub login_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Login',
		iconCls			=> 'icon-key',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('~ . $self->base_url . q~/auth/login_window');~
	};
}




sub logout_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Logout',
		iconCls			=> 'icon-logout',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('~ . $self->base_url . q~/auth/logout_window');~
	};
}


sub change_password_button {
	my $self = shift;

	return {
		xtype				=> 'dbutton',
		text				=> 'Change Password',
		iconCls			=> 'icon-key',
		boxMaxWidth		=> 100,
		handler_func	=> q~Ext.ux.FetchEval('~ . $self->base_url . q~/auth/change_pw_window_window');~
	};
}




1;
