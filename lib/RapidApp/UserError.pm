package RapidApp::UserError;

use Moose;
extends 'RapidApp::Error';

sub userMessage {
	(shift)->message;
}

1;