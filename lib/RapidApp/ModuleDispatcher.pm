package RapidApp::ModuleDispatcher;

use Moose;
use RapidApp::Include 'perlutil';

use RapidApp::Role::ExceptionStore;
use RapidApp::TraceCapture;
use Scalar::Util 'blessed';

# either an exceptionStore instance, or the name of a catalyst Model implementing one
has 'exceptionStore'        => ( is => 'rw', isa => 'Maybe[RapidApp::Role::ExceptionStore|Str]' );

# Whether to save errors to whichever ExceptionStore is available via whatever configuration
# If this is true and no ExceptionStore is configured, we die
has 'saveErrors'            => ( is => 'rw', isa => 'Bool', default => 0 );

# Whether to record an exception even if "$err->isUserError" is true
has 'saveUserErrors'        => ( is => 'rw', isa => 'Bool', default => 1 );

# Whether to also show the tracking ID to the user for UserErrors (probably only desirable for debugging)
has 'reportIdForUserErrors' => ( is => 'rw', isa => 'Bool', default => 0 );

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
	defined $c->res->body || defined $c->stash->{current_view} || defined defined $self->c->stash->{current_view_instance}
		or die "No view was selected, and a body was not generated";
	
	return $result;
}


=pod
sub dieConverter {
	die $_[0] if ref $_[0];
	my $stopTrace= 0;
	die &RapidApp::Error::capture(
		join(' ', @_),
		{ lateTrace => 0, traceArgs => { frame_filter => sub { noCatalystFrameFilter(\$stopTrace, @_) } } }
	);
}

sub noCatalystFrameFilter {
	my ($stopTrace, $params)= @_;
	return 0 if $$stopTrace;
	my ($pkg, $subName)= ($params->{caller}->[0], $params->{caller}->[3]);
	return 0 if ($pkg eq __PACKAGE__ && $subName =~ /^RapidApp::Error:/);
	$$stopTrace= $subName eq __PACKAGE__.'::dispatch';
	return RapidApp::Error::ignoreSelfFrameFilter($params);
}
=cut
1;
