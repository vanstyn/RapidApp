package RapidApp::View::OnError;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::ErrorReport;

=head1 NAME

RapidApp::View::OnError

-or-

MyApp::View::RapidApp::OnError

=head1 DESCRIPTION

This is installed into the user's app as MyApp::View::RapidApp::OnError.

This is called whenever errors are added to the Catalyst instance and the body was not set.

Default behavior for this routine is to log the exception, optionally record it to a file
(or other ExceptionStore) and render it as either a RapidApp exception (for JSON requests)
or as a HTTP-500.

=cut

sub process {
	my ($self, $c)= @_;
	
	my $log= $c->log;
	$log->warn("got here");
	my @errors= @{$c->error};
	my @traces= @{$c->stack_traces};
	
	if (!scalar(@errors)) {
		push @errors, "Using View::RapidApp::OnError without any errors... this is an error in itself";
		$log->error(@errors);
	}
	elsif (scalar(@errors) > 1) {
		$log->warn("multiple (".scalar(@errors).") errors encountered, performing processing on the first");
	}
	
	my $err= $errors[0];
	
	if ($c->rapidApp->saveErrorReports) {
		my $report= RapidApp::ErrorReport->new(
			exception => $err,
			traces => \@traces,
		);
		my $errorStore= $c->rapidApp->resolveErrorReportStore;
		my $reportId= $errorStore->saveErrorReport($report);
		defined $reportId
			or $log->error("Failed to save error report");
		$c->stash->{exceptionRefId}= $reportId;
	}
	else {
		my $lastTrace= scalar(@traces) > 0? $traces[-1] : undef;
		# not saving error, so just print it
		$log->debug($lastTrace) if defined $lastTrace;
	}
	
	# on exceptions, we either generate a 503, or a JSON response to the same effect
	if ($c->stash->{requestContentType} eq 'JSON') {
		$c->stash->{exception}= $err;
		$c->view('RapidApp::JSON')->process($c);
	}
	else {
		$c->res->status(500);
		my $userMessage= (blessed($err) && $err->can('userMessage') && $err->userMessage);
		if (defined $userMessage && length $userMessage) {
			$c->stash->{longStatusText}= $userMessage;
		}
		$c->stash->{exception}= $err;
		$c->view('RapidApp::HttpStatus')->process($c);
	}
}

=pod
	if ($c->rapidApp->saveErrors) {
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

1;