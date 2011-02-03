package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use RapidApp::ScopedGlobals 'sEnv';
use Scalar::Util 'blessed';
use CatalystX::InjectComponent;

sub rapidApp { (shift)->model("RapidApp"); }

has 'request_id' => ( is => 'ro', default => sub { (shift)->rapidApp->requestCount; } );

# an array of stack traces which were caught during the request
has 'stack_traces' => ( is => 'rw', lazy => 1, default => sub{[]} );

around 'setup_components' => sub {
	my ($orig, $app, @args)= @_;
	# At this point, we don't have a catalyst instance yet, just the package name.
	# Catalyst has an amazing number of package methods that masquerade as instance methods later on.
	&flushLog;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		sub {
			$app->$orig(@args);  # standard catalyst setup_components
			$app->setupRapidApp; # our additional components needed for RapidApp
		}
	);
};

sub setupRapidApp {
	my $app= shift;
	my $log= RapidApp::ScopedGlobals->log;
	&flushLog;
	
	injectUnlessExist('RapidApp::RapidApp', 'RapidApp');
	
	my @names= keys %{ $app->components };
	my @controllers= grep /[^:]+::Controller.*/, @names;
	my $haveRoot= 0;
	foreach my $ctlr (@controllers) {
		if ($ctlr->isa('RapidApp::ModuleDispatcher')) {
			$log->info("RapidApp: Found $ctlr which implements ModuleDispatcher.");
			$haveRoot= 1;
		}
	}
	if (!$haveRoot) {
		$log->info("RapidApp: No Controller extending ModuleDispatcher found, using default");
		injectUnlessExist( 'RapidApp::Controller::DefaultRoot', 'Controller::RapidApp::Root' );
	}
	
	# Enable the DirectLink feature, if asked for
	$app->rapidApp->enableDirectLink
		and injectUnlessExist( 'RapidApp::Controller::DirectLink', 'Controller::RapidApp::DirectLink' );
	
	# for each view, inject it if it doens't exist
	injectUnlessExist( 'Catalyst::View::TT', 'View::RapidApp::TT' );
	injectUnlessExist( 'RapidApp::View::Viewport', 'View::RapidApp::Viewport' );
	injectUnlessExist( 'RapidApp::View::JSON', 'View::RapidApp::JSON' );
	injectUnlessExist( 'RapidApp::View::Web1Render', 'View::RapidApp::Web1Render' );
	injectUnlessExist( 'RapidApp::View::HttpStatus', 'View::RapidApp::HttpStatus' );
};

sub injectUnlessExist {
	my ($actual, $virtual)= @_;
	my $app= RapidApp::ScopedGlobals->catalystClass;
	if (!$app->components->{$virtual}) {
		sEnv->log->debug("RapidApp: Installing virtual $virtual");
		CatalystX::InjectComponent->inject( into => $app, component => $actual, as => $virtual );
	}
}

after 'setup_finalize' => sub {
	my $app= shift;
	&flushLog;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		sub { $app->rapidApp->_setup_finalize }
	);
};

# Make the scoped-globals catalystClass and log available throughout the application during request processing
# Called once, per worker thread, in class-context.
around 'run' => sub {
	my ($orig, $app, @args)= @_;
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => $app, log => $app->log },
		$orig, $app, @args
	);
};

# called once per request, in class-context
before 'handle_request' => sub {
	my ($app, @arguments)= @_;
	$app->rapidApp->incRequestCount;
};

# called once per request, to dispatch the request on a newly constructed $c object
around 'dispatch' => sub {
	my ($orig, $c, @args)= @_;
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	# provide hints for our controllers on what contect type is expected
	$c->stash->{requestContentType}=
		$c->req->header('X-RapidApp-RequestContentType')
		|| $c->req->param('RequestContentType')
		|| '';
	
	# special die handler to capture stack traces for all errors
	local $SIG{__DIE__}= \&RapidApp::TraceCapture::captureTrace;
	
	$c->stash->{onrequest_time_elapsed}= 0;
	
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystInstance => $c, log => $c->log },
		sub {
			$orig->($c, @args);
			
			# For the time being, we allow Responder objects to be thrown.   These aren't actually errors.
			# In the future, we should $c->detach($responder->action) instead of throwing them.
			# But for now, we will simply handle these as if they were dispatched properly.
			for my $err (@{ $c->error }) {
				if (blessed($err) && $err->isa('RapidApp::Responder')) {
					$c->clear_errors;
					$c->forward($err->action);
					last;
				}
			}
		}
	);
	
	# gather any stack traces we might have picked up
	$c->stack_traces([ RapidApp::TraceCapture::collectTraces ]);
	
	if (!scalar(@{$c->error}) && !defined $c->response->body) {
		$c->error('Body was not defined!  (discovered at '.__FILE__.' '.__LINE__.')');
	}
	
	scalar(@{ $c->error })
		and $c->view('RapidApp::OnError')->process($c);
	
	if (!defined $c->response->content_type) {
		$c->log->error("Body was set, but content-type was not!  This can lead to encoding errors!");
	}
};

# called after the response is sent to the client, in object-context
after 'log_response' => sub {
	my $c= shift;
	$c->rapidApp->cleanupAfterRequest($c);
};

sub flushLog {
	my $log= RapidApp::ScopedGlobals->get("log");
	if (!defined $log) {
		my $app= RapidApp::ScopedGlobals->get("catalystClass");
		$log= $app->log if defined $app;
	}
	defined $log or return;
	if (my $coderef = $log->can('_flush')){
		$log->$coderef();
	}
}


sub scream {
	my $c = shift;
	return $c->scream_color(YELLOW,@_);
}

sub scream_color {
	my $c = shift;
	my $color = shift;
	$c->log->debug("\n\n\n" . $color . BOLD . Dumper(\@_) . CLEAR . "\n\n\n");
}

1;
