package RapidApp::Responder;
use Moose;

=head1 NAME

RapidApp::Responder

=head1 SYNOPSIS

package MyModule;
sub content {
	if ($error) die RapidApp::Responser::MyErrorResponder->new(\%params);
	return RapidApp::Responser::MyNormalResponder->new(\%params);
}

=head1 DESCRIPTION

A "Responder" is much like a Catalyst::View, except it is designed to be allocated per request,
and it can be thrown.  This is much more convenient and less error-prone than setting view
parameters, putting the view name in the stash, and forwarding to the view.

In fact, I would have naamed the class "View" if that weren't so likely to lead to confusion.

=head1 ATTRIBUTES

=head2 action

For interoperability with Catalyst, a Responder can be converted into a Catalyst::Action.  This
attribute will create or return a cached Action object which runs this responder.

=cut

has 'action' => ( is => 'ro', lazy_build => 1, init_arg => undef );

sub _build_action {
	my $self= shift;
	my $cls= ref $self;
	return Catalyst::Action->new({
		name      => 'writeResponse',
		code      => $self->can('writeResponse'),
		reverse   => $cls.'->writeResponse',
		class     => $self,
		namespace => $cls,
	});
}

=head1 METHODS

=head2 $responder->writeResponde($c)

This is the main processing method of Responder, much like View->process($c);

It fills in the fields of $c->response

=cut

sub writeResponse {
	my ($self, $c)= @_;

	$c->response->status(500);
	$c->response->content_type("text/plain");
	$c->response->body("Unable to generate content for ".$c->stash->{requestContentType});
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
