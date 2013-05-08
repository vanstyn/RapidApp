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
  
  $c->response->redirect('/');
  $c->response->body(' ');
  return $c->detach;
}

# For session timeout, re-auth by RapidApp JavaScript client:
sub reauth :Local :Args(0) {
	my $self = shift;
	my $c = shift;
	
	my ($user, $pass)= ($c->req->params->{'username'}, $c->req->params->{'password'});
	
	$c->stash->{current_view} = 'RapidApp::JSON';
	
	return {
		success	=> 1,
		msg		=> $user . ' logged in.'
	} if ($self->do_login($c,$user,$pass));
	
	return {
		success	=> 0,
		msg		=> 'Logon failure.'
	};
}

# To be called within any controller to auth if needed
sub auth_verify :Private {
	my $self = shift;
	my $c = shift;
  
  $self->render_login_page($c) unless ($c->session_is_valid and $c->user_exists);
};


sub do_login {
	my $self = shift;
  my $c = shift;
	my $user = shift;
	my $pass = shift;
  
	if($c->authenticate({ username => $user, password => $pass })) {
    $c->log->info("Successfully authenticated user '$user'");
    $c->session->{fooo} = 'blah'; 
    $c->user->update({ 
      last_login_ts => DateTime->now( time_zone => 'local' ) 
    });
    
    # Something is broken!
    $c->_save_session_expires;
    
    return 1;
  }
  else {
    $c->log->info("Authentication failed for user '$user'");
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
  my $c = shift;
	my $cnf = shift || {};
  
  my $ver_string = ref $c;
  my $ver = eval('$' . $ver_string . '::VERSION');
  $ver_string .= ' v' . $ver if ($ver);
	
	$cnf->{error_status} = delete $c->session->{login_error}
		if($c->session && $c->session->{login_error});
	
	%{$c->stash} = (
		%{$c->stash},
		template 	=> 'templates/rapidapp/login.tt',
    form_post_url => '/auth/login',
		ver_string	=> $ver_string,
		%$cnf
	);
	
	return $c->detach( $c->view('RapidApp::TT') );
}
#######################################
#######################################



1;


