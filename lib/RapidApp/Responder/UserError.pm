package RapidApp::Responder::UserError;

use Moose;
extends 'RapidApp::Responder';

has 'userMessage' => ( is => 'rw', isa => 'Str', required => 1 );
has 'isHtml' => ( is => 'rw', default => 0 );

# treat single arguments as the attribute 'userMessage'
around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	if (scalar(@args) == 1) {
		unshift @args, 'userMessage';
	}
	
	return $class->$orig(@args);
};

sub writeResponse {
	my ($self, $c)= @_;
	
	$c->stash->{exception}= $self;
	if ($c->stash->{requestContentType} eq 'JSON') {
		$c->view('RapidApp::JSON')->process($c);
	}
	else {
		$c->status(503);
		$c->content_type("text/plain");
		$c->body("Error: ".$self->userMessage);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;