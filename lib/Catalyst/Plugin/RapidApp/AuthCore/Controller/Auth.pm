package Catalyst::Plugin::RapidApp::AuthCore::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' };

use RapidApp::Util qw(:all);
require Module::Runtime;
require Catalyst::Utils;

# 'login' is the POST target of the new HTML login form:
sub login :Chained('/') :PathPart('auth/login') :Args(0) {
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
  
  return $self->do_redirect($c);
}

sub logout :Chained('/') :PathPart('auth/logout')  :Args(0) {
  my $self = shift;
  my $c = shift;
  
  $c->delete_session('logout');
  $c->logout;
  $c->delete_expired_sessions;
  
  return $self->do_redirect($c);
}

sub do_redirect {
  my ($self, $c, $href) = @_;
  $c ||= RapidApp->active_request_context;
  $href ||= $c->req->params->{redirect} || '/';
  
  my $pfx = $c->mount_url || '';
  $href =~ s/^${pfx}//;

  # If the client is still trying to redirect to '/auth/login' after login,
  # it probably means they haven't configured any custom login redirect rules,
  # send them to the best default location, the root module:
  if($href =~ /^\/auth\/login\// && $c->session->{RapidApp_username}) {
    my $new = join('/','',$c->module_root_namespace,'');
    $new =~ s/\/+/\//g; #<-- strip double //
    # Automatically swap '/auth/login/' for '/' (or where the root module is)
    $href =~ s/^\/auth\/login\//${new}/;
  }

  $href = "/$href" unless ($href =~ /^\//); #<-- enforce local
  $c->response->redirect("$pfx$href");
  return $c->detach;
}

# For session timeout, re-auth by RapidApp JavaScript client:
sub reauth :Chained('/') :PathPart('auth/reauth') :Args(0) {
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
  
  $c->delete_expired_sessions;
  
  if ($c->session && $c->session_is_valid and $c->user_exists) {
    $c->res->header('X-RapidApp-Authenticated' => $c->user->username);
  }
  else {
    $c->res->header('X-RapidApp-Authenticated' => 0);
    if ( $c->is_ra_ajax_req ) {
      # The false X-RapidApp-Authenticated header will automatically trigger
      # reauth prompt by the JS client, if available
      $c->res->header( 'Content-Type' => 'text/plain' );
      $c->res->body('not authenticated');
      return $c->detach;
    }
    else {
      # If this is a normal browser request (not Ajax) return the login page:
      return $self->render_login_page($c);
    }
  }
};


sub do_login {
	my $self = shift;
  my $c = shift;
	my $user = shift;
	my $pass = shift;
  
  $c->delete_expired_sessions;
  
	if($c->authenticate({ username => $user, password => $pass })) {
    $c->session->{RapidApp_username} = $user;
    
    # New: set the X-RapidApp-Authenticated header now so the response
    # itself will reflect the successful login (since in either case, the
    # immediate response is a simple redirect). This is for client info/debug only
    $c->res->header('X-RapidApp-Authenticated' => $c->user->username);

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
	
  # Honor/persist the client's redirect if set and not '/'. Otherwise,
  # redirect them back to the default login page. The theory is that
  # their redirect target should be the same thing which displayed the
  # login form to begin with. We want to redirect them so they are still
  # on the login form to see the login error and be able to try again, but
  # also maintain their redirect target across multiple failed login attempts.
  # We don't assume this is the case by default for the root '/', but
  # we don't need to worry about preserving the client's redirect target
  # to '/' because it is already the default redirect target after login.
  my $t = $c->req->params->{redirect};
  my $redirect = ($t && $t ne '/' && $t ne '') ? $t : '/auth/login';
  return $self->do_redirect($c,$redirect);
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

=head1 NAME

Catalyst::Plugin::RapidApp::AuthCore::Controller::Auth - AuthCore Authentication Controller

=head1 DESCRIPTION

This is the controller which is automatically injected at C</auth> by the 
L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> plugin and should not be called directly. 

See the L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> plugin documentation for more info.

=head1 SEE ALSO

=over

=item *

L<Catalyst::Plugin::RapidApp::AuthCore>

=item *

L<RapidApp::Manual>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


