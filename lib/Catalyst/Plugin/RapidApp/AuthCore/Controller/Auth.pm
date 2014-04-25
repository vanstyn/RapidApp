package Catalyst::Plugin::RapidApp::AuthCore::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' };

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;

# 'login' is the POST target of the new HTML login form:
sub login :Local :Args(0) {
  my $self = shift;
	my $c = shift;
  
  # NEW: allow this action to be dual-use to display the login page
  # for GET requests, and handle the login for POST requests
  return $self->render_login_page($c) if ($c->req->method eq 'GET');

  
  # if the user is logging back in, we keep their old session and just renew the user.
  # if a new user is logging in, we throw away any existing session variables
  my $haveSessionForUser = ($c->session_is_valid && $c->session->{RapidApp_username}) ? 1 : 0;
  
  # If a username has been posted, we force a re-login, even if we already have a session:
  $haveSessionForUser = 0 if ($c->req->params->{'username'});
  
  $self->handle_fresh_login($c) unless ($haveSessionForUser);
  
  my $hashpath = $c->req->params->{hashpath} || '';
  
  $c->response->redirect('/' . $hashpath);
  $c->response->body(' ');
  return $c->detach;
}

sub logout :Local :Args(0) {
  my $self = shift;
  my $c = shift;
  
  $c->logout;
  $c->delete_session('logout');
  
  my $redirect = $c->req->params->{redirect} || '/';
  $redirect = "/$redirect" unless ($redirect =~ /^\//); #<-- enforce local
  
  $c->response->redirect($redirect);
  return $c->detach;
}

# For session timeout, re-auth by RapidApp JavaScript client:
sub reauth :Local :Args(0) {
	my $self = shift;
	my $c = shift;
	
	my ($user, $pass)= ($c->req->params->{'username'}, $c->req->params->{'password'});
	
	$c->stash->{current_view} = 'RapidApp::JSON';
  $c->stash->{json} = $self->do_login($c,$user,$pass) ? 
    { success	=> 1, msg => $user . ' logged in.' } :
    { success	=> 0,	msg => 'Logon failure.' };
}

# To be called within any controller to auth if needed
sub auth_verify :Private {
	my $self = shift;
	my $c = shift;
  
  if ($c->session_is_valid and $c->user_exists) {
    $c->res->header('X-RapidApp-Authenticated' => $c->user->username);
  }
  else {
    $c->res->header('X-RapidApp-Authenticated' => 0);
    if ( $c->stash->{requestContentType} eq 'JSON' ) {
      $c->res->body('not authenticated');
      return $c->detach;
    }
    $self->render_login_page($c);
  }
};


sub do_login {
	my $self = shift;
  my $c = shift;
	my $user = shift;
	my $pass = shift;
  
	if($c->authenticate({ username => $user, password => $pass })) {
    $c->session->{RapidApp_username} = $user;
    $c->log->info("Successfully authenticated user '$user'") if ($c->debug);
    $c->user->update({ 
      last_login_ts => DateTime->now( time_zone => 'local' ) 
    });
    
    # Something is broken!
    $c->_save_session_expires;
    
    return 1;
  }
  else {
    $c->log->info("Authentication failed for user '$user'") if ($c->debug);
    return 0;
  }
}


sub handle_fresh_login {
	my $self = shift;
	my $c = shift;
	
	my ($user, $pass)= ($c->req->params->{'username'}, $c->req->params->{'password'});
	
	# Don't try to login if there is no username supplied:
	return unless ($user and $user ne '');
	
	try{$c->logout};
	
	return if ($self->do_login($c,$user,$pass));
	
	$c->session->{login_error} ||= 'Authentication failure';
  
  # Something is broken!
  $c->_save_session_expires;
	
	my $hashpath = $c->req->params->{hashpath} || '';
	$c->response->redirect('/' . $hashpath);
	$c->response->body(' ');
	return $c->detach;
}




#sub valid_username {
#	my $self = shift;
#	my $username = shift;
#	my $c = $self->c;
#	
#	my $User = $self->c->model('DB::User')->search_rs({
#		'me.username' => $username
#	})->first or return 0;
#	
#	my $reason;
#	my $ret = $User->can_login(\$reason);
#	$c->session->{login_error} = $reason if (!$ret && $reason);
#	return $ret;
#}


sub render_login_page {
	my $self = shift;
  my $c = shift or die '$c object arg missing!';
	my $cnf = shift || {};
  
  my $config = $c->config->{'Plugin::RapidApp::AuthCore'} || {};
  $config->{login_template} ||= 'rapidapp/public/login.html';
  
  my $ver_string = ref $c;
  my $ver = eval('$' . $ver_string . '::VERSION');
  $ver_string .= ' v' . $ver if ($ver);
	
	$cnf->{error_status} = delete $c->session->{login_error}
		if($c->session && $c->session->{login_error});
  
  # New: preliminary rendering through the new Template::Controller:
  my $TC = $c->template_controller;
  my $body = $TC->template_render($config->{login_template},{
    login_logo_url => $config->{login_logo_url}, #<-- default undef
    form_post_url => join('/','',$self->action_namespace($c),'login'),
		ver_string	=> $ver_string,
    title => $ver_string . ' - Login',
		%$cnf
  },$c);
  
  $c->response->content_type('text/html; charset=utf-8');
  $c->response->status(200);
  $c->response->body($body);
  return $c->detach;
	
	#%{$c->stash} = (
	#	%{$c->stash},
	#	template => $config->{login_template},
  #  login_logo_url => $config->{login_logo_url}, #<-- default undef
  #  form_post_url => '/auth/login',
	#	ver_string	=> $ver_string,
  #  title => $ver_string . ' - Login',
	#	%$cnf
	#);
	#
	#return $c->detach( $c->view('RapidApp::TT') );
}
#######################################
#######################################



1;


