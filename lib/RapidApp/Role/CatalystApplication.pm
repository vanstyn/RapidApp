package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use RapidApp::ScopedGlobals 'sEnv';
use Scalar::Util 'blessed';
use CatalystX::InjectComponent;
use RapidApp::CatalystX::SimpleCAS::TextTranscode;
use RapidApp::TraceCapture;
use Hash::Merge;
use RapidApp::Log;
use RapidApp::Debug 'DEBUG';
use Text::SimpleTable::AutoWidth;

# initialize properties of our debug messages
RapidApp::Debug->default_instance->applyChannelConfig({
	'auth'          => { color => GREEN,     },
	'controller'    => { color => MAGENTA,   },
	'dbiclink'      => { color => MAGENTA,   },
	'db'            => { color => BOLD.GREEN,},
	'web1render'    => { color => CYAN,      },
});

sub rapidApp { (shift)->model("RapidApp"); }

has 'request_id' => ( is => 'ro', default => sub { (shift)->rapidApp->requestCount; } );

# An array of stack traces which were caught during the request
# We assign this right at the end of around("dispatch")
has 'stack_traces' => ( is => 'rw', lazy => 1, default => sub{[]} );

# make sure to create a RapidApp::Log object, because we depend on its methods
around 'setup_log' => sub {
	my ($orig, $app, @args)= @_;
	my $ret= $app->$orig(@args);
	my $log= $app->log;
	if (!$log->isa("RapidApp::Log")) {
		$app->log( RapidApp::Log->new(origLog => $log) );
	}
	return $ret;
};


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

# we can't get the complete ->config until after ConfigLoader has run
after 'setup_plugins' => \&processConfig;

sub processConfig {
	my $app= shift;
	
	my $log= $app->log;
	my $logCfg= $app->config->{Debug} || {};
	if ($logCfg->{channels}) {
		RapidApp::Debug->default_instance->applyChannelConfig($logCfg->{channels});
	}
}

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
	injectUnlessExist( 'RapidApp::CatalystX::SimpleCAS::TextTranscode', 'Controller::SimpleCas::TextTranscode' );
	
	# for each view, inject it if it doens't exist
	injectUnlessExist( 'Catalyst::View::TT', 'View::RapidApp::TT' );
	injectUnlessExist( 'RapidApp::View::Viewport', 'View::RapidApp::Viewport' );
	injectUnlessExist( 'RapidApp::View::Printview', 'View::RapidApp::Printview' );
	injectUnlessExist( 'RapidApp::View::JSON', 'View::RapidApp::JSON' );
	injectUnlessExist( 'RapidApp::View::Web1Render', 'View::RapidApp::Web1Render' );
	injectUnlessExist( 'RapidApp::View::HttpStatus', 'View::RapidApp::HttpStatus' );
	injectUnlessExist( 'RapidApp::View::OnError', 'View::RapidApp::OnError' );
};

sub injectUnlessExist {
	my ($actual, $virtual)= @_;
	my $app= RapidApp::ScopedGlobals->catalystClass;
	if (!$app->components->{$virtual}) {
		$app->debug && $app->log->debug("RapidApp: Installing virtual $virtual");
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
around 'dispatch' => \&_rapidapp_top_level_dispatch;

sub _rapidapp_top_level_dispatch {
	my ($orig, $c, @args)= @_;
	
	# put the debug flag into the stash, for easy access in templates
	$c->stash->{debug} = $c->debug;
	
	# provide hints for our controllers on what contect type is expected
	$c->stash->{requestContentType}=
		$c->req->header('X-RapidApp-RequestContentType')
		|| $c->req->param('RequestContentType')
		|| '';
	
	# special die handler to capture stack traces for all errors
	local $SIG{__DIE__}= \&RapidApp::TraceCapture::captureTrace
		if $c->rapidApp->enableTraceCapture;
	
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
	$c->stack_traces([ RapidApp::TraceCapture::collectTraces ])
		if $c->rapidApp->enableTraceCapture;
	
	if (!scalar(@{$c->error}) && !defined $c->response->body) {
		$c->error('Body was not defined!  (discovered at '.__FILE__.' '.__LINE__.')');
	}
	
	if (scalar(@{$c->error})) {
		$c->onError;
	}
	
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

=head2 onError

This method handles the logic of what to do in the event of an error.

First, note that we have nifty "Responder" objects that can be thrown as exceptions
but which are not actually errors.  Those objects do not come through here, but they
later use some of the error logic in View::HttpStatus and View::JSON

This method checks to see if the error should be saved as error reports, and if so,
generates the report, saves it, and sets stash parameters so that View::JSON and
View::HttpStatus can display the report details.

=cut
sub onError {
	my $c= shift;
	my $log= $c->log;
	
	my @errors= @{$c->error};
	my @traces= @{$c->stack_traces};
	
	# print them, first
	$log->error($_) for (@errors);
	
	# then optionally save them
	if ($c->rapidApp->saveErrorReports && scalar(@errors)) {
		# I don't know what would cause multiple errors, so don't bother handling that, but warn about it just in case
		if (scalar(@errors) > 1) {
			$log->warn("multiple (".scalar(@errors).") errors encountered, but only saving the first");
		}
		
		# buld a report
		my $err= shift @errors;
		my $report= RapidApp::ErrorReport->new(
			exception => $err,
			traces => \@traces,
			debugInfo => $c->_collect_debug_info_for_error_report,
		);
		
		# save the report
		my $errorStore= $c->rapidApp->resolveErrorReportStore;
		my $reportId= $errorStore->saveErrorReport($report);
		defined $reportId
			or $log->error("Failed to save error report");
		$c->stash->{exceptionRefId}= $reportId;
		$c->stash->{exceptionPromptForComment}= $reportId && $errorStore->updateEnabled && $c->rapidApp->errorAddCommentPath;
		$c->stash->{exceptionFailedToAddComment}= index($c->req->path, substr($c->rapidApp->errorAddCommentPath,1)) >= 0;
	}
	elsif ($c->debug) {
		# not saving error, so log the stack trace
		$log->info("Writing ".scalar(@traces)." exception trace(s) to ".RapidApp::TraceCapture::traceLogName);
		&flushLog;
		
		if ($ENV{FULL_TRACE} || $c->request->params->{fullTrace}) {
			RapidApp::TraceCapture::writeFullTrace($_) for (@traces);
		} else {
			RapidApp::TraceCapture::writeQuickTrace($_) for (@traces);
		}
	}
	
	$c->view('RapidApp::OnError')->process($c);
	$c->clear_errors;
}

sub _collect_debug_info_for_error_report {
	my $c= shift;
	my $info= {};
	# absolutely do not let this code stop us from saving the report
	try {
		$info->{path}=   $c->request->path;
		$info->{params}= $c->request->parameters;
		$info->{uid}=    defined $c->user? $c->user->id : 'no user';
		$info->{uname}=  defined $c->user? $c->user->username : '??';
		$info->{isSys}=  $c->session->{isSystemAccount}? 'yes':'no';
	}
	catch {
		my $msg= ''.$_;
		$msg= substr($msg, 0, 64).'...' if length($msg) > 64;
		$info->{err}= "(error building debug info: '$msg')";
	};
	return $info;
}


#######################################################################################
#  The following is mostly copy/pasted from Catalyst::Plugin::Unicode::Encoding.
#  RapidApp aims to be "utf-8 everywhere", and this saves the user from the need to include
#   that module, and allows us to extend it a bit at the same time.
#######################################################################################

use Encode 2.21 ();
our $CHECK = Encode::FB_CROAK | Encode::LEAVE_SRC;
our $codec = Encode::find_encoding('utf8') or die "Missing encoder for utf8";

before 'finalize_headers' => \&properly_encode_response;
after 'prepare_uploads' => \&properly_decode_request;
after 'prepare_action' => \&properly_decode_action_params;

sub properly_encode_response {
	my $c= shift;
	my @encoded;

	$c->properly_encode_body && push @encoded, 'body';
	
	# also encode headers
	for my $ra_hdr (grep { $_ =~ /^X-RapidApp/ } $c->response->headers->header_field_names) {
		my @val= $c->response->headers->header($ra_hdr);
		for (@val) {
			if (utf8::is_utf8($_)) {
				push @encoded, $ra_hdr;
				$_= $codec->encode($_, $CHECK);
			}
		}
		$c->response->headers->header($ra_hdr => \@val);
	}
	
	DEBUG('controller', "Encoded to utf-8: ", @encoded);
}

sub properly_encode_body {
	my $c= shift;
	my $body = $c->response->body;

	DEBUG('controller', "no body set at encode-time") unless defined($body);
	return 0 unless defined($body);

	my ($ct, $ct_enc) = $c->response->content_type;

	# Only touch 'text-like' contents
	unless ($c->response->content_type =~ m!^text|xml$|javascript$|/JSON$!) {
		DEBUG('controller', "content-type is not a recognizable \"text\" format");
		return 0 unless utf8::is_utf8($body);
		$c->log->error("Body of response is unicode, but content type is not \"text\"... encoding at utf8 just in case, but you should fix the content type or the data!!!");
	}

	if ($ct_enc && $ct_enc =~ /charset=(.*?)$/) {
		if (uc($1) ne $codec->mime_name) {
			$c->log->warn("Unicode::Encoding is set to encode in '" .
				$codec->mime_name .
				"', content type is '$1', not encoding ");
			return 0;
		}
	} else {
		DEBUG('controller', "defaulting content-type charset to utf-8");
		$c->res->content_type($c->res->content_type . "; charset=" . $codec->mime_name);
	}

	# Encode expects plain scalars (IV, NV or PV) and segfaults on ref's
	if (ref(\$body) eq 'SCALAR') {
		$c->response->body( $codec->encode( $body, $CHECK ) );
		return 1;
	}
	return 0;
}

# Note we have to hook here as uploads also add to the request parameters
sub properly_decode_request {
	my $c = shift;
	my @decoded;

	for my $key (qw/ parameters query_parameters body_parameters /) {
		for my $value ( values %{ $c->request->{$key} } ) {

			# TODO: Hash support from the Params::Nested
			if ( ref $value && ref $value ne 'ARRAY' ) {
				next;
			}
			for ( ref($value) ? @{$value} : $value ) {
				# N.B. Check if already a character string and if so do not try to double decode.
				#      http://www.mail-archive.com/catalyst@lists.scsys.co.uk/msg02350.html
				#      this avoids exception if we have already decoded content, and is _not_ the
				#      same as not encoding on output which is bad news (as it does the wrong thing
				#      for latin1 chars for example)..
				if (!Encode::is_utf8( $_ )) {
					push @decoded, $key;
					$_ = $codec->decode( $_, $CHECK );
				}
			}
		}
	}
	
	for my $value ( values %{ $c->request->uploads } ) {
		push @decoded, $value.'->{filename}';
		for ( ref($value) eq 'ARRAY' ? @{$value} : $value ) {
			$_->{filename} = $codec->decode( $_->{filename}, $CHECK );
		}
	}
	
	# also decode headers we care about
	for my $ra_hdr (grep { $_ =~ /^X-RapidApp/ } $c->req->headers->header_field_names) {
		my @val= $c->req->headers->header($ra_hdr);
		push @decoded, $ra_hdr;
		@val= map { $codec->decode($_, $CHECK) } @val;
		$c->req->headers->header($ra_hdr => \@val);
	}
	DEBUG('controller', "Decoded from utf8: ", @decoded);
}

sub properly_decode_action_params {
	my $c = shift;

	foreach (@{$c->req->arguments}, @{$c->req->captures}) {
		$_ = Encode::is_utf8( $_ ) ? $_ : $codec->decode( $_, $CHECK );
	}
}

# reset stats for each request:
before 'dispatch' => sub { %$RapidApp::Functions::debug_around_stats = (); };
after 'dispatch' => \&_report_debug_around_stats;

sub _report_debug_around_stats {
	my $c = shift;
	my $stats = $RapidApp::Functions::debug_around_stats || return;
	return unless (ref($stats) && keys %$stats > 0);
	
	my $total = $c->stats->elapsed;
	
	my $auto_width = 'calls';
	my @order = qw(class sub calls min/max/avg total pct);
	
	$_->{pct} = ($_->{total}/$total)*100 for (values %$stats);
	
	my $tsum = 0;
	my $csum = 0;
	my $count = 0;
	my @rows = ();
	foreach my $stat (sort {$b->{pct} <=> $a->{pct}} values %$stats) {
		$tsum += $stat->{total};
		$csum += $stat->{calls};
		$count++;
		
		$stat->{$_} = sprintf('%.3f',$stat->{$_}) for(qw(min max avg total));
		$stat->{'min/max/avg'} = $stat->{min} . '/' . $stat->{max} . '/' . $stat->{avg};
		$stat->{pct} = sprintf('%.1f',$stat->{pct}) . '%';

		push @rows, [ map {$stat->{$_}} @order ];
	}

	my $tpct = sprintf('%.1f',($tsum/$total)*100) . '%';
	$tsum = sprintf('%.3f',$tsum);
	
	my $t = Text::SimpleTable::AutoWidth->new(
		max_width => Catalyst::Utils::term_width(),
		captions => \@order
	);

	$t->row(@$_) for (@rows);
	$t->row(' ',' ',' ',' ',' ',' ');
	$t->row('(' . $count . ' Tracked Functions)','',$csum,'',$tsum,$tpct);
	
	my $table = $t->draw;
	
	my $display = BOLD . "Tracked Functions (debug_around) Stats (current request):\n" . CLEAR .
		BOLD.MAGENTA . $table . CLEAR .
		BOLD . "Catalyst Request Elapsed: " . YELLOW . sprintf('%.3f',$total) . CLEAR . "s\n\n";
	
	print STDERR "\n" . $display;
}

1;
