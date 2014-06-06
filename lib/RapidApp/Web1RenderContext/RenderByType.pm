package RapidApp::Web1RenderContext::RenderByType;
use Moose;
extends 'RapidApp::Web1RenderContext::Renderer';

use MRO::Compat;
use RapidApp::Web1RenderContext;

=head1 NAME

RapidApp::Web1RenderContext::RenderByType

=head1 SYNOPSIS

  my $renderer= RapidApp::Web1RenderContext::RenderByType->new;
  $renderer->apply_rendererByRef(
    HASH => $myHashRenderer,
    'Some::Class' => $myCustomRenderer,
  );
  my $cx= RapidApp::Web1RenderContext->new( renderer => $renderer );
  $cx->render($treeOfObjects);

=head1 DESCRIPTION

This module is a Web 1.0 Renderer which simply refers to a lookup table by ref type to
find the correct renderer for a given perl object.  It can also associate renderers with
ref types of 'HASH', 'ARRAY', 'REF', and so on.

=cut

has 'defaultRenderer' => ( is => 'rw', isa => 'RapidApp::Web1RenderContext::Renderer',
	default => sub { $RapidApp::Web1RenderContext::DEFAULT_RENDERER } );

has 'rendererByRef' => (
	traits	=> ['Hash'],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_rendererByRef => 'set',
	}
);

has '_rendererByRefCache' => ( is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} } );

sub renderAsHtml {
	my ($self, $renderCxt, $data)= @_;
	my $type= ref $data;
	# we use this slightly odd logic to prevent running "findRendererFor" more than once per type.
	my $renderer= exists $self->_rendererByRefCache->{$type}? $self->_rendererByRefCache->{$type}
		: ($self->_rendererByRefCache->{$type}= $self->findRendererForRef($data));
	($renderer || $self->defaultRenderer)->renderAsHtml($renderCxt, $data);
}

=head2 findRendererForRef

Attempt to find the most appropriate renderer for a given data item.

We give first precedence to explicitly configured ref types.

If nothing was configured for that exact type, we walk up the ISA
tree checking to see if each parent class was explicitly configured,
or if we have a render_TYPE method for it, or if it has a
"renderAsHtml" method.

=cut
sub findRendererForRef {
	my ($self, $data)= @_;
	my $r;
	my $type= ref $data;
	exists $self->rendererByRef->{$type} and return $self->rendererByRef->{$type};
	($r= $self->makeRendererForMethod('render_'.$type))
		and return $r;
	
	# if it is blessed
	if (blessed($data)) {
		my $isaList= mro::get_linear_isa($type);
		for my $base (@$isaList) {
			# did the user specify a renderer for this type?
			exists $self->rendererByRef->{$base}
				and return $self->rendererByRef->{$base};
			
			# try making a renderer from one of our methods
			($r= $self->makeRendererForMethod('render_'.$base))
				and return $r;
			
			# Data can be its own renderer, if the 'render' method is defined lower in the class
			#   hierarchy than any of the overrides in our renderer hashes.
			# If we didn't care about being able to override $data->render, we could have just done
			#   a "$data->can('render')" before this loop.
			defined &{$base.'::renderAsHtml'}
				and return $data;
		}
	}
	return undef;
}

=head2 makeRendererForMethod( $methodName )

If the named method exists, this returns a Renderer object which calls that method on $self.
If it doesn't exist, this returns undef.

=cut
sub makeRendererForMethod {
	my ($self, $methodName)= @_;
	my $code= $self->can($methodName) || return undef;
	return RapidApp::Web1RenderContext::RenderFunction->new(sub { $code->($self, @_) });
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;