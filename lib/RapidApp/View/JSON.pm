package RapidApp::View::JSON;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::JSON::MixedEncoder;
use Scalar::Util 'blessed', 'reftype';
use HTML::Entities;
use RapidApp::Util qw(:all);

=head1 NAME

RapidApp::View::JSON

=head1 DESCRIPTION

This view displays content as a JSON packet that will be used by RapidApp's
client-side javascript.

It also handles the awkwardness of passing data back through ExtJS's form
submissions.  Form submissions require the data to be returned as *html*
so that the browser doesn't screw it up, and then the rendered text of the
HTML should be valid JSON that the Javascript uses.

This is also where error/exceptions are processed. This view used to have complex
code for error reporting but this was removed a long time ago. This view is still in
need of general cleanup

=cut

has 'encoding' => ( is => 'rw', isa => 'Str', default => 'utf-8' );

has 'encoder' => ( is => 'rw', isa => 'RapidApp::JSON::MixedEncoder', lazy_build => 1 );
sub _build_encoder {
	return RapidApp::JSON::MixedEncoder->new
}

sub process {
	my ($self, $c)= @_;

	my $json;

	if (my $err = $c->stash->{exception}) {
		$c->log->debug("RapidApp::View::JSON exception: $err") if ($c->debug);

		$c->res->header('X-RapidApp-Exception' => 1);
		$c->res->status(500);

		my $msg= $self->getUserMessage($err) || "An internal error occured:  \n\n" . $err;
		my $title= $self->getUserMessageTitle($err) || 'Error';

		$json= {
			exception   => \1,
			success		=> \0,
			rows			=> [],
			results		=> 0,
			msg			=> $msg,
			title       => $title,
		};
	}
	else {
		$json= $c->stash->{json} || $c->stash->{jsonData} || $c->stash->{controllerResult}
			or die "None of exception, json, jsonData, controllerResult were specified.  Cannot render.";
	}

	$self->setJsonBody($c, $json);
}

# Either set the body to a json packet (for normal ajax requests) or html-encoded json
#   for file-upload forms.
sub setJsonBody {
	my ($self, $c, $json)= @_;

	my $encoding= $c->stash->{encoding} || $self->encoding;
	my $rct= $c->stash->{requestContentType};

	(!ref $json) or $json= $self->encoder->encode($json);

	$c->res->header('Cache-Control' => 'no-cache');

	if ($rct eq 'text/x-rapidapp-form-response') {
		my $hdr= $c->res->headers;
		my %headers= map { $_ => $hdr->header($_) } $hdr->header_field_names;
		my $headerJson= $self->encoder->encode(\%headers);

		$c->res->content_type("text/html; charset=$encoding");
		$c->res->body(
			'<html><body>'.
				'<textarea id="json">'.encode_entities($json).'</textarea>'.
				'<textarea id="header_json">'.encode_entities($headerJson).'</textarea>'.
			'</body></html>'
		);
	}
	else {
		$c->res->content_type("text/javascript; charset=$encoding");
		$c->res->body($json);
	}
}

sub getUserMessage {
	my ($self, $err)= @_;
	blessed($err) or return undef;
	my $method= $err->can('userMessage') || return undef;
	my $str= ashtml $err->$method();
	defined $str && length($str) or return undef;
	return $str;
}

sub getUserMessageTitle {
	my ($self, $err)= @_;
	blessed($err) or return undef;
	my $method= $err->can('userMessageTitle') || return undef;
	my $str= ashtml $err->$method();
	defined $str && length $str or return undef;
	return $str;
}

1;
