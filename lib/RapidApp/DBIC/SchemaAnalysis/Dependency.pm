package RapidApp::DBIC::SchemaAnalysis::Dependency;

use Moose;

=head1 DESCRIPTION

This object represents a dependency of a column on a key of another column.

This concept could be greatly expanded, so I made an official interface for it.
However, right now the code required is pretty simple, so I didn't bother making the interface
generic with a subclass to handle the col-dep-on-foreign-key scenario.

=cut

# skipping any validation to speed things up, since we create and use a lot of these
has 'source' => ( is => 'ro', required => 1 );
has 'col'    => ( is => 'ro', required => 1 );
sub colKey { my $self= shift; return $self->source . '.' . $self->col; }

# we don't name this 'foreign_colKey' because foreign keys can point to foreign keys which point to foreign keys and so on.
# "origin_colKey" is the table/column where the key originated.  i.e. the one with "auto_increment" set on it.
has 'origin_colKey' => ( is => 'ro', required => 1 );

sub is_relevant {
	my ($self, $engine, $item)= @_;
	my $val= $item->data->{$self->col};
	# Only worry about columns whose value is given in the input
	# Only swap the value if it was given as a scalar.  Hashes indicate fancy DBIC stuff
	return defined $val && !ref $val;
}

sub resolve {
	my ($self, $engine, $item)= @_;
	
	my $colN= $self->col;
	my $oldVal= $item->data->{$colN};
	# find the new value for the key
	my $newVal= $engine->translate_key($self->origin_colKey, $oldVal);
	# we can't resolve this dep unless a translated value is known
	return 0 unless defined $newVal;
	$item->remapped_data->{$colN}= $newVal;
	return 1;
}

__PACKAGE__->meta->make_immutable;
1;