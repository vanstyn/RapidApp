package RapidApp::Responder::UserError;

use Moose;
extends 'RapidApp::Responder';

use HTML::Entities;

has 'userMessage' => ( is => 'rw', isa => 'Str', required => 1 );
has 'isHtml' => ( is => 'rw', default => 0 );

# treat single arguments as the attribute 'userMessage'
around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	if (scalar(@args) == 1 && !ref $args[0]) {
		unshift @args, 'userMessage';
	}
	
	return $class->$orig(@args);
};

sub writeResponse {
	my ($self, $c)= @_;
	
	$c->stash->{exception}= $self;
	
	my $text= $self->userMessage;
	if (!$self->isHtml) {
		$text= join('<br />', encode_entities(split "\n", $text));
	}
	
	$c->response->status(500);
	$c->response->content_type("text/html");
	
	my $rct= $c->stash->{requestContentType};
	if ($rct eq 'JSON') {
		$c->response->body("Error: ".$text);
	}
	elsif ($rct eq 'text/x-rapidapp-form-response') {
		# Because ExtJS must read the string from the source of an IFrame, we must encode in HTML
		# But, form responses must be JSON, so we encode the JSON as HTML.  (yes, it's ugly)
		my $json= RapidApp::JSON::MixedEncoder::encode_json({
			'X-RapidApp-Exception' => 1,
			msg => $text,
			success => \0,
		});
		$c->response->body(encode_entities($json));
	}
	else {
		$c->response->body("Error: ".$text);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;