package RapidApp::Role::AuthController;
use strict;
use warnings;

=pod

=head1 DESCRIPTION

New role designed to enforce RapidApp authenticated sessions in
normal Controllers (i.e. not RapidApp 'Modules')

This is an alternative to 'AuthRequire' which is specific to Modules
and will be depricated along with Modules in the future

=cut

use Moose::Role;

requires '_app';

# TODO: is this bad? Doesn't seem immediately possible with: sub begin :Private {...}
before '_BEGIN' => sub {
	my ( $self, $c ) = @_;
	$self->enforce_rapidapp_session($c);
};

sub enforce_rapidapp_session {
	my ( $self, $c ) = @_;
  
  # ignored if session plugin isn't loaded:
  return unless $c->can('session_is_valid');
  
	unless ($c->session_is_valid and $c->user_exists) {
		$c->res->header('X-RapidApp-Authenticated' => 0);
		$c->res->header( 'Content-Type' => 'text/plain' );
    $c->res->body('No session');
		$c->detach;
	}
}

1;