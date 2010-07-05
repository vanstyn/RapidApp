package RapidApp::AppAuth;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppBase';

use Term::ANSIColor qw(:constants);

use Math::BigInt;

use RapidApp::ExtJS;


has 'login_iconCls'			=> ( is => 'ro',	default => 'icon-key' );
has 'login_logo'				=> ( is => 'ro',	default => '/static/rapidapp/images/sportsrite_tiny.png' );
has 'login_title'				=> ( is => 'ro',	default => 'Login' );
has 'login_width'				=> ( is => 'ro',	default => 350 );
has 'login_height'			=> ( is => 'ro',	default => 230 );
has 'login_banner'			=> ( is => 'ro',	default => 'Enter your username and password to login' );

has 'logout_title'			=> ( is => 'ro',	default => 'Logout...' );
has 'logout_banner'			=> ( is => 'ro',	default => 'Really Logout ?' );





has 'ExtJS'			=> ( is => 'rw', lazy => 1, default => sub { RapidApp::ExtJS->new } );

has 'actions' => ( is => 'ro', default => sub {
	my $self = shift;
	return {
		login				=> sub { $self->login				},
		logout			=> sub { $self->logout			},
		login_window	=> sub { $self->login_window	},
		logout_window	=> sub { $self->logout_window	},
	};
});



sub login_window {
	my $self = shift;
	my $code =  $self->ExtJS->Login_Window_code({
		name					=> 'login_window',
		title					=> $self->login_title,
		width 				=> $self->login_width,
		height 				=> $self->login_height,
		submit_url			=> $self->base_url . '/login',
		iconCls				=> $self->login_iconCls,
		logo					=> $self->login_logo,
		banner				=> $self->login_banner,
		onSuccess_eval		=> 'window.location.reload();'
		#onSuccess_eval		=> q~var main = Ext.getCmp('maincontainer');~ .
		#							q~main.loadData(main.itemsurl);~
	});
	
	use Data::Dumper;
	print STDERR GREEN . Dumper($code) . CLEAR;
	
	return $code;
}


sub logout_window {
	my $self = shift;
	my $params = shift;
	
return

q~Ext.Msg.show({
title: '~ . $self->logout_title . q~',
msg: '~ . $self->logout_banner . q~',
buttons: Ext.Msg.YESNO,
icon: Ext.MessageBox.QUESTION,
fn: function(buttonId) { if (buttonId=="yes") {
Ext.Ajax.request({ 
	disableCaching: true, 
	url: '~ . $self->base_url . q~/logout', 
	success: function(response, opts) { window.location.reload(); }
})
}}});
~
}




sub login {
	my $self = shift;
	
	my $result = 0;
	
	if (exists($self->c->req->params->{'username'})) {
		$result = $self->c->authenticate({
			username	=> $self->c->req->params->{'username'},
			password	=> $self->c->req->params->{'password'}
		});
	}
	
	if ($result) {
	
		#$self->c->persist_user;
	
		print STDERR BOLD . GREEN ' ---> Login succeeded.' . "\n\n" . CLEAR;
	
		return {
			success	=> 1,
			msg		=> $self->c->req->params->{'username'} . ' logged in.'
		};
	}
	
	print STDERR BOLD . RED ' ---> Login failed.' . "\n\n" . CLEAR;
	
	return{
		success	=> 0,
		msg		=> 'Logon failure.'
	};
}


sub logout {
	my $self = shift;
	
	$self->c->logout;
	$self->c->delete_session('User logout');
	
	return {
		success	=> 1,
		msg		=> 'You have been logged out.'
	};
}






no Moose;
#__PACKAGE__->meta->make_immutable;
1;
