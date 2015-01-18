package RapidApp::View::HttpStatus;

use strict;
use warnings;
use RapidApp::Include 'sugar', 'perlutil';

use base 'Catalyst::View::TT';

# DEPRECATED - TO BE REMOVED - Github Issue #41

1;

__END__


=head1 NAME

RapidApp::View::HttpStatus

=head1 DESCRIPTION

This module acts under most of the same API as RapidApp::View::JSON, but it tries
to handle things in a Web 1.0 manner.  For instance, the error report comment field
is rendered as a plain HTML form rather than ExtJS.

See RapidApp::View::JSON for the API.

This view converts those stash parameters into different more convenient stash
parameters, and then passes controll off to the TT template
  templates/rapidapp/http-status.tt

See RapidApp::Role::CatalystApplication->onError for the top-level of error handling.

Also note that the RapidApp::Responder::UserError isn't really an error, but uses much
of the error handling program flow.

=cut

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
	$c->stash->{shortStatusText} ||= $c->stash->{statusCode}; #HTTP::Status::status_message($stat);
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