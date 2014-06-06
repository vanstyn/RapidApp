package RapidApp::Web1RenderContext::RenderHandler;
use Moose;
extends 'RapidApp::Handler';
extends 'RapidApp::Web1RenderContext::Renderer';

=pod

This class makes a renderer from any method which can be referred to by a RapidApp::Handler.
This class derives from handler, so it has all the same constructor options.

=cut
sub renderAsHtml {
	(shift)->call(@_);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
