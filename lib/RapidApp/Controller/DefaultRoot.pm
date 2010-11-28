package RapidApp::Controller::DefaultRoot;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }
with 'RapidApp::Role::TopController';
with 'RapidApp::Role::ExceptionSaver';

use RapidApp::Controller::ExceptionInspector;

__PACKAGE__->config(
	namespace => '',
);

has 'saveExceptions' => ( is => 'rw', isa => 'Bool', default => 1 );

sub BUILD {
	my $self= shift;
	
	$self->modules && scalar(keys %{$self->modules})>0 or
		die "You have not configured the top module for RapidApp.\n".
			"See perldoc -f RapidApp/DefaultRootController.pm";
}

sub approot :Path {
	my $self= shift;
	my $c= $_[0];
	if ($c->debug) {
		$self->apply_modules(exception => 'RapidApp::Controller::ExceptionInspector');
	}
	$self->Controller(@_);
}

after 'onException' => sub {
	my $self= shift;
	if ($self->saveExceptions) {
		$self->saveException(@_);
	}
};

sub end : ActionClass('RenderView') {}

no Moose;
__PACKAGE__->meta->make_immutable(1);
1;
