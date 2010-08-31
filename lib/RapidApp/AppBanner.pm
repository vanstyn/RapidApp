package RapidApp::AppBanner;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppDataView';

use Term::ANSIColor qw(:constants);

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
has 'logo_cls'					=> ( is => 'ro',	default => 'noBox' );

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

#has 'content' => ( is => 'ro', lazy => 1, default => sub {
#	my $self = shift;
#	return $self->DataView;
#});


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


#has 'IntelliTree_logo' => ( is => 'ro', default =>
sub IntelliTree_logo {
	my $self = shift;

	return 
		'<div class="intellitreeLogo">' . 
			'<a href="http://www.intellitree.com/" target="_blank"><img src="/static/rapidapp/images/intellitreeLogo.png" alt="Intellitree Logo" width="111" height="59" border="0" /></a>' .
		'</div>';
}
#);



sub item_template {
	my $self = shift;
	
	my $html = join("\n",

	'<div id="headerContainer">
	<table border="0" cellpadding="0" cellspacing="0" id="header" width="100%">
		<tr>
			<td width="1%" class="logo">
					<div class="' . $self->logo_cls .'">',
						 '<div class="topLeft"></div>
						 <div class="topRight"></div>
						 <div class="bottomLeft"></div>
						 <div class="bottomRight"></div>',		
						 '<img src="' . $self->logo . '" />
					</div>	
			</td>
			<td style="vertical-align:middle">
					<div class="middle">
						 <table border="0" cellpadding="0" cellspacing="0" >
							<tr>
								<td colspan="10">
										 <div class="links">
											  <ul>',
													#'<li><a href="#" class="first">Change Profile</a></li>',
													#'<li><a href="#">Change Password</a></li>',
											  '</ul>
										 </div>                        
									</td>
							  </tr>
							  <tr>',
									'<td class="title">' . $self->banner_title . '</td>', 
									'<td width="100%">&nbsp;</td>',
									
									'<tpl if="session &gt; 0">',
					
										'<td class="tabNoClick"><p class="username">{user}</p></td>',
										'<td class="tabClick"><a href="#" class="loggedIn">Logout</a></td>',
									'</tpl>',
									
									'<tpl if="session &lt; 1">',
										'<td class="tabClick"><a href="#" class="loggedOut">Login</a></td>',
									'</tpl>',
									
									
									#'<td class="tabNoClick"><p class="username">Username:<span class="name">Stephen Kramer</span></p></td>
									#<td class="tabClick"><a href="#" class="loggedIn">Logout</a></td>',
									
									
									'<td>' . $self->IntelliTree_logo . '</td>
									
							  </tr>
						 </table>
					</div>
			</td>
		</tr>
	</table>
	</div>');
	
	return $html;

}



sub item_template_o {

#has 'item_template' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	
		print STDERR YELLOW . BOLD . '  BANNER item_template!!!!!' . CLEAR . "\n\n\n";
	
	
	my $html = join("\n",
	#'<tpl for="."><div class="dv_selector">',
	
'<div id="headerContainer">
<table border="0" cellpadding="0" cellspacing="0" id="header">
	<tr>
		<td width="1%" rowspan="3" class="logo">
			<div class="' . $self->logo_cls .'">',
				'<div class="topLeft"></div>',
				'<div class="topRight"></div>',
				'<div class="bottomLeft"></div>',
				'<div class="bottomRight"></div>',
				'<img src="' . $self->logo . '" />
			</div>
		</td>
		<td width="99%" class="top"></td>
	</tr>
	<tr>
		<td style="vertical-align:middle">
		<div class="middle">
			<div class="links">
				<ul>' .
					#'<li><a href="#" class="first">Change Profile</a></li>' .
					#'<li><a href="#">Change Password</a></li>' .
				'</ul>
			</div>' .
					
					
			'<table border="0" cellpadding="0" cellspacing="0" >
				<tr>
					<td class="title">' . $self->banner_title . '</td>', 
					'<td width="100%">&nbsp;</td>',
					
					
					'<tpl if="session &gt; 0">',
					
						'<td class="tabNoClick"><p class="username">{user}</p></td>',
						'<td class="tabClick"><a href="#" class="loggedIn">Logout</a></td>',
					'</tpl>',
					
					'<tpl if="session &lt; 1">',
						'<td class="tabClick"><a href="#" class="loggedOut">Login</a></td>',
					'</tpl>',
										
					'<td>' . $self->IntelliTree_logo . '</td>
				</tr>
			</table>',
					
		'</div>
		</td>
	</tr>
	<tr>
		<td class="bottom">&nbsp;</td>
	</tr>
</table>
</div>'

	#'</div></tpl>'
	
	);
	
	
	
	print STDERR BLUE . BOLD . $html . CLEAR;
	
	return $html;
}
#});





has 'xtemplate_cnf_old' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return
	'<tpl for="."><div class="dv_selector">' .
	
'<div id="headerContainer">
<table border="0" cellpadding="0" cellspacing="0" id="header">
	<tr>
		<td width="1%" rowspan="3" class="logo">
			<div class="' . $self->logo_cls .'">' .
				#'<div class="topLeft"></div>' .
				#'<div class="topRight"></div>' .
				#'<div class="bottomLeft"></div>' .
				#'<div class="bottomRight"></div>' .
				'<img src="' . $self->logo .'" />
			</div>
		</td>
		<td width="99%" class="top"></td>
	</tr>
	<tr>
		<td>
		<div class="middle">
			<div class="links">
				<ul>' .
					#'<li><a href="#" class="first">Change Profile</a></li>' .
					#'<li><a href="#">Change Password</a></li>' .
				'</ul>
			</div>			
			<div class="title">' . $self->banner_title . '</div>
			<div class="intellitreeLogo"><a href="http://www.intellitree.com/" target="_blank"><img src="/static/rapidapp/images/intellitreeLogo.png" alt="Intellitree Logo" width="111" height="59" border="0" /></a></div>
			
			<div class="tabsContainer">' .
			
			
				#'<div class="tabClick"><a href="#" class="loggedIn">Logout</a></div>' .
				#'<div class="tabNoClick">' .
				#	'<span class="username">Username:<p class="name">Stephen Kramer</p></span>' .
				#'</div>' .
				
				
					'<tpl if="session &gt; 0">' .
						'<div class="tabClick"><a href="#" class="loggedIn">Logout</a></div>' .
						'<div class="tabNoClick"><span class="username">{user}</span></div>' .
					'</tpl>' .
					
					'<tpl if="session &lt; 1">' .
						'<div class="tabClick"><a href="#" class="loggedOut">Login</a></div>' .
					'</tpl>' .
				
				
				
			'</div>
			
		</div>
		</td>
	</tr>
	<tr>
		<td class="bottom">&nbsp;</td>
	</tr>
</table>
</div>' .

	'</div></tpl>'
});





has 'xtemplate_cnf_older' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return
	'<tpl for="."><div class="dv_selector">' .
	
'<table border="0" cellpadding="0" cellspacing="0" id="header">
	<tr>' .
		'<td width="15%" rowspan="3" class="logo"><div class="' . $self->logo_cls .'"><img src="' . $self->logo .'" /></div></td>' .
		#'<td width="15%" rowspan="3" class="logo"><div class="whiteBox"><img src="' . $self->logo .'" /></div></td>' .
		'<td width="85%" class="top">
			<div class="links">
				<ul>' .
					'<li><a href="#" class="first">Change Profile</a></li>' .
					'<li><a href="#">Change Password</a></li>' .
				'</ul>
			</div>
		</td>
	</tr>
	<tr>
		<td class="middle">
			<div class="title">' . $self->banner_title . '</div>
			<div class="intellitreeLogo"><a href="http://www.intellitree.com/" target="_blank"><img src="/static/rapidapp/images/intellitreeLogo.png" alt="Intellitree Logo" width="111" height="59" border="0" /></a></div>
			<div class="tabsContainer">' .
			
			
				#'<div class="tabClick"><a href="#" class="loggedIn">Logout</a></div>' .
				#'<div class="tabNoClick">' .
				#	'<span class="username">Username:<p class="name">Stephen Kramer</p></span>' .
				#'</div>' .
				
				
					'<tpl if="session &gt; 0">' .
						'<div class="tabClick"><a href="#" class="loggedIn">Logout</a></div>' .
						'<div class="tabNoClick"><span class="username">{user}</span></div>' .
					'</tpl>' .
					
					'<tpl if="session &lt; 1">' .
						'<div class="tabClick"><a href="#" class="loggedOut">Login</a></div>' .
					'</tpl>' .
				
				
				
			'</div>
		</td>
	</tr>
	<tr>
		<td class="bottom">&nbsp;</td>
	</tr>
</table>' .

	'</div></tpl>'
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
