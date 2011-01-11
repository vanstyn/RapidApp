package RapidApp::Web1RenderContext::RenderFunction;
use strict;
use warnings;
use RapidApp::Web1RenderContext::Renderer;
our @ISA= ( 'RapidApp::Web1RenderContext::Renderer' );

=pod

This class is for functions with arguments of the form
  function( $context, $data )
If the function requires any other parameters, use RapidApp::Web1RenderContext::RenderMethod instead.

We skip Moose, because our needs are very simple and lots of these will get created.

=cut
sub new {
	my ($class, $code)= @_;
	scalar(@_) == 2 && (ref $code eq 'CODE') or die "Invalid arguments";
	return bless \$code, $class;
}

sub renderAsHtml {
	my $self= shift;
	($$self)->(@_);
}

1;