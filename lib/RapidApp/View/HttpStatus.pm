package RapidApp::View::HttpStatus;

use strict;
use warnings;

use base 'Catalyst::View::TT';

my $codes = {
	500 => {
		short => 'Internal Server Error',
		long  => 'An error occured while processing this request',
	},
};

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	defined $c->response->status || $c->response->status(500);
	
	my $stat= $c->response->status;
	$c->stash->{statusCode}= $stat;
	$c->stash->{shortStatusText}= $codes->{$stat}->{short};
	$c->stash->{longStatusText}=  $codes->{$stat}->{long};
	
	if ($c->response->status == 404) {
		$c->stash->{template} = 'templates/rapidapp/http-404.tt';
		$c->stash->{attemptedUrl}= $c->req->path;
	}
	else {
		$c->stash->{template} = 'templates/rapidapp/http-status.tt';
	}
	
	if (defined $c->stash->{exceptionLogId} and !length $c->stash->{exceptionLogId}) {
		$c->stash->{exceptionLogFailure}= 1;
	}
	
	$self->SUPER::process($c);
}

1;