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
	$c->stash->{errorViewPath}= $c->rapidApp->errorViewPath;
	
	if ($c->response->status == 404) {
		$c->stash->{template} = 'templates/rapidapp/http-404.tt';
		$c->stash->{attemptedUrl}= $c->req->path;
	}
	else {
		$c->stash->{template} = 'templates/rapidapp/http-status.tt';
	}
	
	if (exists $c->stash->{exceptionRefId} and !$c->stash->{exceptionRefId}) {
		$c->stash->{exceptionRefFailure}= 1; # we don't have "defined" or "exists" in TT, so add a more convenient variable
	}
	
	$self->SUPER::process($c);
}

1;