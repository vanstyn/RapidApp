package RapidApp::AppAuth;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppBase';

use RapidApp::Include 'perlutil', 'sugar';

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

has 'username_key'			=> ( is => 'ro',	default => 'username' );
has 'password_key'			=> ( is => 'ro',	default => 'password' );

has 'onSuccess_eval'			=> ( is => 'ro', default => 'window.location.reload();' );

has 'ExtJS'			=> ( is => 'rw', lazy => 1, default => sub { RapidApp::ExtJS->new } );

override_defaults(
	auto_viewport => 1
);

sub BUILD {
	my $self = shift;
	$self->apply_actions(
		login				=> 'login',
		logout			=> 'logout',
		login_window	=> 'login_window',
		logout_window	=> 'logout_window',
	);
	
	# Register ourselves with RapidApp if no other has already been registered
	# This is used by the AuthRequire module to determine where to direct users who haven't logged in.
	defined $self->app->rapidApp->appAuthPath
		or $self->app->rapidApp->appAuthPath($self->module_path);
}

sub content {
	viewport(@_);
}

sub viewport {
	my $self= shift;
	
	# if authSuccessRedirect was specified in either the params or stash, we go there on successful auth
	my $windowParams= {};
	my $redirect= $self->c->stash->{authSuccessRedirect} || $self->c->request->params->{authSuccessRedirect};
	defined $redirect && length($redirect)
		and $windowParams->{onSuccess_eval}= 'window.location = '.encode_json($redirect).';';
	if (defined $self->c->session->{RapidApp_username}) {
		$windowParams->{username}= $self->c->session->{RapidApp_username};
	}
	
	$self->c->stash->{current_view} ||= 'RapidApp::TT';
	$self->c->stash->{template} ||= 'templates/rapidapp/ext_loginpage.tt';
	$self->c->stash->{title} ||= $self->module_name;
	$self->c->stash->{login_window_code}= $self->login_window($windowParams);
}

sub login_window {
	my $self = shift;
	my $params= ref $_[0] eq 'HASH'? $_[0] : { %_ };
	$params= {
		name					=> 'login_window',
		title					=> $self->login_title,
		width 				=> $self->login_width,
		height 				=> $self->login_height,
		submit_url			=> $self->base_url . '/login',
		iconCls				=> $self->login_iconCls,
		logo					=> $self->login_logo,
		banner				=> $self->login_banner,
		username_label		=> $self->username_key,
		onSuccess_eval		=> $self->onSuccess_eval,
		#onSuccess_eval		=> q~var main = Ext.getCmp('maincontainer');~ .
		#							q~main.loadData(main.itemsurl);~
		%$params
	};
	my $code =  $self->ExtJS->Login_Window_code($params);
	
	#use Data::Dumper;
	#print STDERR GREEN . Dumper($code) . CLEAR;
	
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
	success: function(response, opts) { window.location.hash = ''; window.location.reload(); }
})
}}});
~
}




sub login {
	my $self = shift;
	
	my $result = 0;
	
	# if the user is logging back in, we keep their old session and just renew the user.
	# if a new user is logging in, we throw away any existing session variables
	my $haveSessionForUser= $self->c->session_is_valid && $self->c->session->{RapidApp_username};
	$haveSessionForUser ||= '';
	
	my ($user, $pass)= ($self->c->req->params->{'username'}, $self->c->req->params->{'password'});
	
	$self->c->delete_session("user changed") unless $haveSessionForUser eq $user;
	
	if (defined $user) {
		if ($self->c->authenticate({
			$self->username_key => $user,
			$self->password_key => $pass
			}))
		{
			$self->c->log->info(' ---> Login succeeded.');
			
			# keep it handy in the session
			$self->c->session->{RapidApp_username}= $self->c->user->username;
			
			return {
				success	=> 1,
				msg		=> $user . ' logged in.'
			};
		}
	}
	
	$self->c->log->warn(' ---> Login failed.');
	
	return {
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
