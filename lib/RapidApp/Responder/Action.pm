package RapidApp::Responder::Action;

use Moose;
extends 'Catalyst::Action';

has '

# override the Catalyst::Action attributes in the most efficient method possible
sub class { '' }
sub namespace { '' }
sub reverse { (ref shift).'->writeResponse' }
sub name { ref shift }
sub code { shift->can('writeResponse') }

sub dispatch {
	writeResponse(@_);
}

sub execute {
	my ($self, $controller, $c)= @_;
	$self->writeResponse($c);
}

sub writeResponse {
	my ($self, $c)= @_;
	die "Unimplemented";
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
