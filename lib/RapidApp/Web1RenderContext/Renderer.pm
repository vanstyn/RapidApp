package RapidApp::Web1RenderContext::Renderer;
use Moose;

=head2 $renderer->renderAsHtml( $renderContext, $data )

Render the data to the specified context.

=cut
sub renderAsHtml {
	die "Unimplemented";
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
