package RapidApp::View::HttpStatus;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	defined $c->response->status || $c->response->status(500);
	
	# TODO: XXX select a template based on the status
	$c->stash->{template} = 'templates/rapidapp/404.tt';
	$c->stash->{title} ||= $c->config->{name};
	$c->stash->{statusCode}= $c->response->status;
	
	# TODO: XXX select message details based on status code
	$c->stash->{attemptedUrl}= $c->req->path;
	
	if (defined $c->stash->{exceptionLogId}) {
		my $id= $c->stash->{exceptionLogId};
		$c->stash->{message} .= length($id)?
			"\n\nThe details of this error have been kept for debugging.\nReference number $id"
			: "\n\nThe details of this error could not be saved.";
	}
	
	$self->SUPER::process($c);
}

1;