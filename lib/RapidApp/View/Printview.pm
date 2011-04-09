package RapidApp::View::Printview;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	$c->stash->{template} = 'templates/rapidapp/ext_printview.tt';
	
	# make sure config_params is a string of JSON
	if (ref $c->stash->{config_params}) {
		$c->stash->{config_params}= RapidApp::JSON::MixedEncoder::encode_json($c->stash->{config_params});
	}
	
	return $self->SUPER::process($c);
}

1;
