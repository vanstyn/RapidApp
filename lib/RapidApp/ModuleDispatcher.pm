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
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	# provide hints for our controllers on what contect type is expected
	$c->stash->{requestContentType}=
		$c->req->header('X-RapidApp-RequestContentType')
		|| $c->req->param('RequestContentType')
		|| '';
	
	my $result;
	
	# special die handler to capture stack traces for all errors
	local $SIG{__DIE__}= \&RapidApp::TraceCapture::captureTrace;
	my $targetModule;
	try {
		# get the root module (or sub-module, if we've been configured that way)
		$targetModule= $c->rapidApp->module($self->dispatchTarget);
		
		# now run the controller
		$result = $targetModule->THIS_MODULE->Controller($c, @args);
		$c->stash->{controllerResult} = $result;
		
		# clear any stack traces we might have picked up, since none were uncaught
		RapidApp::TraceCapture::collectTraces;
	}
	catch {
		my $err = $_;
		my @traces= RapidApp::TraceCapture::collectTraces;
		$result= $self->onException($_, \@traces);
	};
	# if the body was not set, make sure a view was chosen
	defined $c->res->body || defined $c->stash->{current_view} || defined defined $self->c->stash->{current_view_instance}
		or die "No view was selected, and a body was not generated";
	
	return $result;
}

=head2 onException( $c, $RapidApp::Error )

This is called whenever an exception is thrown from the chain of Controller calls.

Default behavior for this routine is to log the exception, dump its debugging info if present,
and render it as either a RapidApp exception (for JSON requests) or as a HTTP-500.

=cut
sub onException {
	my ($self, $err, $traces)= @_;
	
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	my $log= RapidApp::ScopedGlobals->log;
	
	if (blessed($err) and $err->isa('RapidApp::Error::CustomPrompt')) {
		$c->response->header('X-RapidApp-CustomPrompt' => $err->header_json);
		length($c->response->body) > 0 or $c->response->body("Contains X-RapidApp-CustomPrompt Data");
		return;
	}
	
	$c->stash->{exception}= $err;
	$log->error("Caught exception during module dispatch [".(ref $err || 'scalar')."]: $err");
	
	if ($self->saveErrors && (!(blessed $err && $err->isa('RapidApp::UserError')) || $self->saveUserErrors)) {
		$log->info("Writing ".scalar(@$traces)." exception trace(s) to ".$RapidApp::TraceCapture::TRACE_OUT_FILE);
		for my $trace (@$traces) {
			$ENV{FULL_TRACE} || $c->request->params->{fullTrace}?
				RapidApp::TraceCapture::writeFullTrace($trace)
				: RapidApp::TraceCapture::writeQuickTrace($trace);
		}
=pod
		defined $self->exceptionStore or die "saveErrors is set, but no exceptionStore is defined";
		my $store= $self->exceptionStore;
		ref $store or $store= $c->model($store);
		my $refId= $store->saveException($err);
		if (!$err->isUserError || $self->reportIdForUserErrors) {
			$c->stash->{exceptionRefId}= $refId;
		}
=cut
	}
	else {
		my $lastTrace= scalar(@$traces) > 0? $traces->[$#$traces] : undef;
		# not saving error, so just print it
		$log->debug($lastTrace) if defined $lastTrace;
	}
	
	# on exceptions, we either generate a 503, or a JSON response to the same effect
	if ($c->stash->{requestContentType} eq 'JSON') {
		$c->stash->{current_view}= 'RapidApp::JSON';
	}
	else {
		my $userMessage= (blessed($err) && $err->can('userMessage') && $err->userMessage);
		if (defined $userMessage && length $userMessage) {
			# TODO: change this to an actual view
			length($c->response->body) > 0
				or $c->response->body("Error : " . $userMessage);
		}
		else {
			$c->stash->{current_view}= 'RapidApp::HttpStatus';
			$c->res->status(500);
		}
	}
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
