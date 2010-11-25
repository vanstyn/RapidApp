package RapidApp::View::TT;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	
	return $self->SUPER::process($c);
}

1;
