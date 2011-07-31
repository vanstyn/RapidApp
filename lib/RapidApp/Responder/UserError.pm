package RapidApp::Responder::UserError;

use Moose;
extends 'RapidApp::Responder';

#use overload '""' => \&_stringify_static; # to-string operator overload
use HTML::Entities;

=head1 NAME

RapidApp::Responder::UserError

=head1 DESCRIPTION

This "responder" takes advantage of the existing error-displaying codepaths
in RapidApp to (possibly) interrupt the current AJAX request and display the
message to the user.

See RapidApp::Sugar for the "die usererr" syntax.

See RapidApp::View::JSON for the logic this module ties into.

=cut

# Note that this is considered text, unless it is an instance of RapidApp::HTML::RawHtml
has userMessage      => ( is => 'rw', isa => 'Str|Object', required => 1 );
sub isHtml { return (ref (shift)->userMessage)->isa('RapidApp::HTML::RawHtml'); }

# same for the title
has userMessageTitle => ( is => 'rw', isa => 'Str|Object' );

sub writeResponse {
	my ($self, $c)= @_;
	
	my $rct= $c->stash->{requestContentType};
	$c->stash->{exception}= $self;
	if ($rct eq 'JSON' || $rct eq 'text/x-rapidapp-form-response') {
		$c->forward('View::RapidApp::JSON');
	}
	else {
		$c->response->status(200);
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