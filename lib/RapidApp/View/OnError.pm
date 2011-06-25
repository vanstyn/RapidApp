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
	my @errors= @{$c->error};
	
	if (!scalar(@errors)) {
		push @errors, "Using View::RapidApp::OnError without any errors... this is an error in itself";
		$log->error($errors[0]);
	}
	
	my $err= $errors[0];
	my $rct= $c->stash->{requestContentType};
	DEBUG('controller', 'OnError->process( rct == '.$rct.' )');
	
	# on exceptions, we either generate a 500, or a JSON response to the same effect
	if ($rct eq 'JSON' || $rct eq 'text/x-rapidapp-form-response') {
		$c->stash->{exception}= $err;
		$c->view('RapidApp::JSON')->process($c);
	}
	else {
		$c->res->status((blessed($err) && $err->isa('RapidApp::Responder::UserError'))? 200 : 500);
		$c->stash->{exception}= $err;
		$c->view('RapidApp::HttpStatus')->process($c);
	}
}

1;