package RapidApp::Web1RenderContext::Renderer;
use Moose;

=head2 $renderer->renderAsHtml( $renderContext, $data )

Render the data to the specified context.

=cut
sub renderAsHtml {
	my ($self, $renderContext, $data)= @_;
	die "Unimplemented";
}

sub TO_JSON {
	my $self= shift;
	return ref $self;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
