package RapidApp::View::HttpStatus;

use strict;
use warnings;
use HTTP::Status;
use RapidApp::Include 'sugar', 'perlutil';

use base 'Catalyst::View::TT';

my %_longMessages = (
	500 => 'An error occured while processing this request',
);

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	defined $c->response->status || $c->response->status(500);
	
	my $stat= $c->response->status;
	
	my $err= $c->stash->{exception};
	if ($err && blessed($err)) {
		$err->can('userMessageTitle')
			and $c->stash->{shortStatusText} ||= $err->userMessageTitle;
		
		$err->can('userMessage')
			and $c->stash->{longStatusText} ||= $err->userMessage;
	}
	
	$c->stash->{statusCode}      ||= $stat;
	$c->stash->{shortStatusText} ||= HTTP::Status::status_message($stat);
	$c->stash->{longStatusText}  ||= $_longMessages{$stat} || "<no details>";
	$c->stash->{errorViewPath}   ||= $c->rapidApp->errorViewPath;
	
	if ($stat == 404) {
		$c->stash->{template} = 'templates/rapidapp/http-404.tt';
		$c->stash->{attemptedUrl}= $c->req->path;
	}
	else {
		$c->stash->{template} = 'templates/rapidapp/http-status.tt';
	}
	
	$c->stash->{commentSubmitPath}= $c->rapidApp->errorAddCommentPath .'/addComment';
	
	if (exists $c->stash->{exceptionRefId} and !$c->stash->{exceptionRefId}) {
		$c->stash->{exceptionRefFailure}= 1; # we don't have "defined" or "exists" in TT, so add a more convenient variable
	}
	
	$c->stash->{longStatusText}= ashtml $c->stash->{longStatusText};
	
	$self->SUPER::process($c);
}

1;