package RapidApp::ModuleDispatcher;

use Moose;
use RapidApp::Include 'perlutil';

use RapidApp::TraceCapture;
use Scalar::Util 'blessed';

# Which RapidApp module to dispatch to.  By default, we dispatch to the root.
# If you had multiple ModuleDispatchers, you might choose to dispatch to deeper in the tree.
has 'dispatchTarget'        => ( is => 'rw', isa => 'Str',  default => "/");

=head2 $ctlr->dispatch( $c, @args )

dispatch takes a catalyst instance, and a list of path arguments.  It does some setup work,
and then calls "Controller" on the target module to begin handling the arguments.

dispatch takes care of the special exception handling/saving, and also sets up the
views to display the exceptions.

It also is responsible for cleaning temporary values from the Modules after the request is over.

=cut
sub dispatch {
	my ($self, $c, @args)= @_;
	
	# get the root module (or sub-module, if we've been configured that way)
	my $targetModule= $c->rapidApp->module($self->dispatchTarget);
		
	# now run the controller
	my $result = $targetModule->THIS_MODULE->Controller($c, @args);
	$c->stash->{controllerResult} = $result;
	
	# if the body was not set, make sure a view was chosen
	defined $c->res->body || defined $c->stash->{current_view} || defined $c->stash->{current_view_instance}
		or die "No view was selected, and a body was not generated";
	
	return $result;
}

1;
