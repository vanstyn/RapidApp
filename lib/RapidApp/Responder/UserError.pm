package RapidApp::Responder::UserError;

use Moose;
extends 'RapidApp::Responder';

#use overload '""' => \&_stringify_static; # to-string operator overload
use HTML::Entities;

has 'userMessage' => ( is => 'rw', isa => 'Str', required => 1 );
has 'isHtml' => ( is => 'rw', default => 0 );

sub writeResponse {
	my ($self, $c)= @_;
	
	my $text= $self->userMessage;
	if (!$self->isHtml) {
		$text= join('<br />', encode_entities(split "\n", $text));
	}
	
	my $rct= $c->stash->{requestContentType};
	if ($rct eq 'JSON' || $rct eq 'text/x-rapidapp-form-response') {
		$c->stash->{exception}= $self;
		$c->forward('View::RapidApp::JSON');
	}
	else {
		$c->response->status(500);
		$c->stash->{longStatusText}= $text;
		$c->forward('View::RapidApp::HttpStatus');
	}
}

sub stringify {
	return (shift)->userMessage;
}

sub _stringify_static {
	return (shift)->stringify;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;