package RapidApp::DBIC::HashTranslator;
use Moose;

use Params::Validate ':all';

has rules => ( is => 'ro', isa => 'ArrayRef' );

sub translate {
	my $self= shift;
	my %p= validate(@_, { hash => 1, context => 0 } );
	my @cxArg= $p{context}? ( $p{context} ) : ();
	for $rule (@{ $self->rules }) {
		my ($pattern, $method)= @$rule;
		my @path= grep { length $_ } split /\./, $pattern;
		$self->_translate_path($p{context}, $method, $p{hash}, @path);
	}
	return $p{hash};
}

sub _translate_path {
	my ($self, $context, $fn, $node, @path)= @_;
	# if we've arrived at the path, performt he translation
	if (!scalar @path) {
		return $context? $context->$fn(@_[3]) : $fn->(@_[3]);
	# else if we're at a hash, go deeper
	} elsif (ref $node eq 'HASH') {
		my $p= shift @path;
		if (defined $node->{$p}) {
			$self->_translate_path($context, $fn, $node->{$p}, @path);
		}
	# else if we're at an array, process each element for the remaining path
	} elsif (ref $node eq 'ARRAY') {
		$self->_translate_path($context, $fn, $_, @path) for @$node;
	}
}

__PACKAGE__->meta->make_immutable;
1;