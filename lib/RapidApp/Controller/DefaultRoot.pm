package RapidApp::Controller::DefaultRoot;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }
with 'RapidApp::Role::TopController';

__PACKAGE__->config(
	namespace => '',
);

sub BUILD {
	my $self= shift;
	
	$self->modules && scalar(keys %{$self->modules})>0 or
		die "You have not configured the top module for RapidApp.\n".
			"See perldoc -f RapidApp/DefaultRootController.pm";
}

sub approot :Path {
	(shift)->Controller(@_);
}

sub end : ActionClass('RenderView') {}

no Moose;
__PACKAGE__->meta->make_immutable(1);
1;
