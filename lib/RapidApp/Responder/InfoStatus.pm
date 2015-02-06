package RapidApp::Responder::InfoStatus;

use Moose;
extends 'RapidApp::Responder';

use RapidApp::Util qw(:all);
use HTML::Entities;


# Dead simple responder that can be thrown as an excption to abort something
# without displaying a message box. The response status can be set, and an optional
# info message header can be set. This is useful in cases where I user cancels
# from within customprompt logic and an exception has to be thrown to escape
# backend business logic safely (such as during a database transaction) but
# there is no actionable exception/message for the user.

has 'status', is => 'ro', isa => 'Int', default => 200;
has 'msg', is => 'ro', isa => 'Str', default => '';


sub writeResponse {
	my ($self, $c)= @_;
	
	# X-RapidApp-Info header not used yet, but it is intended to display a non-invasive status/info message
	$c->response->header('X-RapidApp-Info' => $self->msg);
	
	$c->response->status($self->status);
	$c->response->body('');
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;