package RapidApp::Role::AuthRequire;
#
# -------------------------------------------------------------- #
#


use strict;
use Moose::Role;
requires 'c';
requires 'Controller';
requires 'render_data';
requires 'content';
#with 'RapidApp::Role::Controller';


our $VERSION = '0.1';


has 'non_auth_content'		=> ( is => 'rw',	default => '' );




#around 'Controller' => sub {
#	my $orig = shift;
#	my $self = shift;
#
#	
#	return $self->$orig(@_);
#};



sub kill_session {
	my $self = shift;
	
	$self->c->logout;
	return $self->c->delete_session('kill_session()');
}




around 'Controller' => sub {
	my $orig = shift;
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	$self->c($c);
	
	unless ($self->c->session_is_valid and $self->c->user_exists) {
		$self->kill_session;
		return $self->render_data($self->non_auth_content);
	}
	
	return $self->$orig(@_);
};


#around 'content' => sub {
#	my $orig = shift;
#	my $self = shift;
#	
#	return $self->non_auth_content unless (
#		defined $self->c and
#		$self->c->user_exists
#	);
#	
#	return $self->$orig(@_);
#};



1;