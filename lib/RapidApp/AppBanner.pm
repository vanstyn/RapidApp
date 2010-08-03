package RapidApp::AppBanner;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppDataView';

use RapidApp::AppAuth;

has 'modules' => (is => 'ro', default => sub {
	return {
		auth			=> 'RapidApp::AppAuth'
	}
});

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

has 'banner_title'			=> ( is => 'ro',	default => 'RapidApp Application' );
has 'logo_cls'					=> ( is => 'ro',	default => 'logo' );

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
	my $self = shift;
	return $self->DataView;
});


has 'content_old' => ( is => 'ro', lazy => 1, default => sub {
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






has 'storeId' => ( is => 'ro', lazy_build => 1 );
sub _build_storeId {
	my $self = shift;
	return 'banner-store';
}



has 'dv_baseconfig' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		autoHeight		=> \1,
		singleSelect	=> \1,
		itemSelector	=> 'div.dv_selector',
		emptyText		=> 'Error',
		listeners		=> $self->listeners,
	};
});


has 'xtemplate_cnf' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return
	'<tpl for=".">' .
		'<div id="header" class="dv_selector">' .
			#'<div class="logoWhiteBox"><img src="' . $self->logo .'" width="166" height="115" /></div>' .
			'<div class="' . $self->logo_cls . '"><img src="' . $self->logo .'"/></div>' .
			'<div class="title">' . $self->banner_title . '</div>' .
					
				'<div class="tabsContainer">' .

					'<tpl if="session &gt; 0">' .
						'<div class="tab"><a href="#" class="loggedIn">Logout</a></div>' .
						'<div class="tab"><a href="#" class="username">{user}</a></div>' .
					'</tpl>' .
					
					'<tpl if="session &lt; 1">' .
						'<div class="tab"><a href="#" class="loggedOut">Login</a></div>' .
					'</tpl>' .
				
				'</div>' .
			
			'<div class="intellitreeLogo">' .
				'<a href="http://www.intellitree.com/">' .
					'<img src="/static/rapidapp/images/intellitreeLogo.png" alt="Intellitree Logo" width="111" height="59" border="0" />' .
				'</a>' .
			'</div>' .
			'<div class="links">' .
				'<ul>' .
					#'<li><a href="#" class="first">Change Profile</a></li>' .
					#'<li><a href="#">Change Password</a></li>' .
				'</ul>' .
			'</div>' .
		'</div>' .
	'</tpl>'
});




#has 'read_records_coderef' => ( is => 'ro', lazy => 1, default => sub {
sub read_records_coderef {
	my $self = shift;
	return sub {
	
		my $d = {
			session => 0
		};
		
		if (defined $self->c and $self->c->user_exists) {
			$d->{session} = 1;
			$d->{user} = $self->c->user->get($self->username_key);
		}

		return {
			rows => [ $d ],
			results => 1
		};
	};
}





has 'listeners' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		click => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(dv, index, htmlEl, event){ ' .
				'dv.getEl().repaint();' .
				'var Record = dv.getStore().getAt(index);' . #'console.dir(arguments);' .
				'if (!Ext.isEmpty(event.getTarget("a.loggedIn"))) {' .
					q~Ext.ux.FetchEval('~ . $self->base_url . q~/auth/logout_window');~ .
				'}' .
				'if (!Ext.isEmpty(event.getTarget("a.loggedOut"))) {' .
					q~Ext.ux.FetchEval('~ . $self->base_url . q~/auth/login_window');~ .
				'}' .
			'}'
		)
	};
});













1;
