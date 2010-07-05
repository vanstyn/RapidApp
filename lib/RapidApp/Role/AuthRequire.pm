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




around 'Controller' => sub {
	my $orig = shift;
	my $self = shift;
	my ( $c, $opt, @args ) = @_;
	
	$self->c($c);
	
	return $self->render_data($self->non_auth_content) unless (
		defined $self->c and
		$self->c->user_exists
	);
	
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