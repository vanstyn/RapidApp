package RapidApp::Responder;

use Moose;

has 'action' => ( is => 'ro', lazy_build => 1 );

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

sub writeResponse {
	my ($self, $c)= @_;
	
	$c->status(500);
	$c->content_type("text/plain");
	$c->body("Unable to generate content for ".$c->stash->{requestContentType});
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
