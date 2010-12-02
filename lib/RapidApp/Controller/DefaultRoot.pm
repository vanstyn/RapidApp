package RapidApp::Controller::DefaultRoot;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }
with 'RapidApp::Role::TopController';

=head1 NAME

RapidApp::Controller::DefaultRoot

=head1 DESCRIPTION

This module is injected into the user's application unless they define a different controller
that extends TopController.  This is merely the default, if they didn't specify one.

=head1 CONFIGURATION

This module (like any other RapidApp module) needs to have a list of its sub-modules.

You can specify this using the Catalyst config system:

  MyApp::Controller::RapidApp::Root:
    modules:
      main: MyApp::Modules::Main

along with any of the attributes for TopController.

=head1 EXTENDING

Rather than extending from this class (which would only save you a few lines), you can just
as easily write your own controller which inherits from TopController:

  package MyApp::Controller::Root;
  
  use Moose;
  use namespace::autoclean;
  BEGIN { extends 'Catalyst::Controller'; }
  with 'RapidApp::Role::TopController';
  
  __PACKAGE__->config( namespace => '' );
  
  sub approot :Path {
    my ($self, $c, @args)= @_;
    $self->Controller($c, @args);
  }
  
  sub end : ActionClass('RenderView') {}
  
  no Moose;
  __PACKAGE__->meta->make_immutable(1);
  1;

The benefits you do gain from extending this default are the ability to plug in
other RapidApp features like Direct Links or Exception Logging.  However, these
features could also be easily plugged into a custom top controller.

=cut

use RapidApp::Controller::ExceptionInspector;

__PACKAGE__->config( namespace => '' );

=pod
sub BUILD {
	my $self= shift;
	
	$self->modules && scalar(keys %{$self->modules})>0 or
		die "You have not configured the top module for RapidApp.\n".
			"See perldoc -f lib/RapidApp/Controller/DefaultRoot.pm";
}
=cut


sub approot :Path {
	my ($self, $c, @args)= @_;
	
	# support for RapidApp features
	if ($c->debug) {
		$self->apply_modules(exception => 'RapidApp::Controller::ExceptionInspector');
	}
	$self->Controller(@_);
}

sub end : ActionClass('RenderView') {}

no Moose;
__PACKAGE__->meta->make_immutable(1);
1;
