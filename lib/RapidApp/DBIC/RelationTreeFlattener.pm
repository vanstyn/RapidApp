package RapidApp::DBIC::RelationTreeFlattener;
use Moo;
use RapidApp::DBIC::ColPath;
use RapidApp::DBIC::RelationTreeSpec;
use Carp;

=head1 NAME

RapidApp::DBIC::RelationTreeFlattener

=head1 SYNOPSIS

  my $spec= RapidApp::DBIC::RelationTreeSpec->new(
    source => $db->source('Object'),
    colSpec => [qw( user.* -user.password contact.* creator_id owner_id is_deleted contact.timezone.ofs )]
  );
  
  my $flattener= RapidApp::DBIC::RelationTreeFlattener->new(spec => $spec);
  
  my $treed= {
    creator_id => 5,
    owner_id => 7,
    is_deleted => 0,
    user => { username => 'foo', department => 'billing' },
    contact => {
      first => 'John',
      last => 'Doe',
      timezone => { ofs => -500 }
    },
  };
  my $flattened= {
    creator_id => 5,
    owner_id => 7,
    is_deleted => 0,
    user_username => 'foo',
    user_department => 'billing',
    contact_first => 'John',
    contact_last => 'Doe',
    contact_timezone_ofs => -500,
  };
  
  is_deeply( $flattener->flatten($treed), $flattened, 'flatten a tree' );
  is_deeply( $flattener->restore($flattened), $treed, 'restore a tree' );

=head1 DESCRIPTION

This module takes a tree of DBIC data and flattens it into a simple hash that can be
used by things that expect a single-level hash, like ExtJS's Stores, and all the
components based on Stores like AppStoreForm2.

In the default naming convention, the key names of the flattened hash are chosen by
concatenating the path of relations that lead up to a column, separated by underscore.
This is not guaranteed to work in all cases, though, because underscore is often used
in column names.

Other naming conventions can work around this problem.  However, they have not been
tested yet with the rest of RapidApp.  So, for now, stick with "concat_"

=head1 ATTRIBUTES

=head2 spec : RapidApp::DBIC::RelationTreeSpec

The spec determines what relations and columns are considered.  Any hash keys encountered
which are not in the spec will either be ignored or throw an error, depending on the
attribute "ignoreUnexpected".

=head2 namingConvention : enum

The naming convention to use for flattening column names.  Defaults to standard "concat_"
system of DbicLink / DataStore2, which joins relation and columns with underscore.

Other (untested) schemes are "concat__" and "brief".

=head2 ignoreUnexpected : bool

Whether or not unexpected hash keys should generate exceptions.  Defaults to true (ignore them).

=cut

has spec              => ( is => 'ro', required => 1 );
has namingConvention  => ( is => 'rw', isa => \&_checkNamingConvention, default => sub { "concat_" } );
has ignoreUnexpected  => ( is => 'rw', default => sub { 1 } );

has _conflictResolver => ( is => 'ro', default => undef, init_arg => 'conflictResolver' ); # only used during constructor
has _colmap           => ( is => 'ro' );

sub BUILD {
	my $self= shift;
	# in case it is a closure, we want to release the resolver after the constructor is over.
	my $resolver= delete $self->{_conflictResolver};
	# we could declare lazy_build, but it isn't really lazy
	$self->{_colmap} ||= $self->_build__colmap($resolver);
}

sub _build__colmap {
	my ($self, $resolver)= @_;
	my (%toTree, %toFlat);
	my @excludes;
	
	my $calcFlatName= $self->can('calcFlatName_'.$self->namingConvention);
	for my $col ($self->spec->colList) {
		my $flatName= $calcFlatName->($self, $col);
		if (defined $toTree{$flatName}) {
			if ($resolver) {
				my $choice= $resolver->($col, $toTree{$flatName});
				if ("$choice" eq "$col") {
					push @excludes, "$toTree{$flatName}";
					delete $toFlat{$toTree{$flatName}};
					$toFlat{$col->key}= $flatName;
					$toTree{$flatName}= $col;
				} else {
					push @excludes, "$col";
				}
			} else {
				croak "Columns '$col' and '$toTree{$flatName}' both map to the key '$flatName'";
			}
		} else {
			$toFlat{$col->key}= $flatName;
			$toTree{$flatName}= $col;
		}
	}
	if (@excludes) {
		# need to update the spec to match our new exclusions
		$self->{spec}= $self->spec->subtract( @excludes );
	}
	
	return { toTree => \%toTree, toFlat => \%toFlat };
}

sub calcFlatName_concat_ {
	my ($self, $col)= @_;
	join('_', @$col)
}

sub calcFlatName_concat__ {
	my ($self, $col)= @_;
	join('__', @$col)
}

sub calcFlatName_brief {
	my ($self, $col)= @_;
	join('__', (scalar(@$col) > 1)? @$col[-2..-1] : ($col->[0]) );
}

sub calcFlatName_sequential {
	my ($self, $col)= @_;
	'c'.$self->{_nextSequentialColNum}++;
}

sub _checkNamingConvention {
	__PACKAGE__->can('calcFlatName_'.$_[0]) or die "Can't resolve method for naming convention ".$_[0];
}

=head1 METHODS

=head2 $flatHash= $self->flatten( $hashTree )

Takes a tree of values and converts it to a flattened hash.

Example:

  {
    foo => 12,
    bar => { baz => 13 }
  }

Becomes:

  {
    foo => 12,
    bar_baz => 13,
  }

=cut
use RapidApp::Debug "DEBUG";
sub flatten {
	my ($self, $hash)= @_;
	my $toFlat= $self->_colmap->{toFlat};
	my $result= {};
	my @worklist= ( [ [], $hash, $self->spec->colTree ] );
	while (@worklist) {
		my ($path, $node, $spec)= @{ pop @worklist };
		for my $key (keys %$node) {
			if (ref $spec->{$key}) {
				push @worklist, [ [ @$path, $key ], $node->{$key}, $spec->{$key} ];
			} else {
				if (my $flatName= $toFlat->{ RapidApp::DBIC::ColPath::key([@$path, $key]) }) {
					$result->{$flatName}= $node->{$key};
				} elsif (!$self->{ignoreUnexpected}) {
					croak "Column/relation '".join('.',@$path,$key)."' is not part of the spec for this flattener";
				}
			}
		}
	}
	$result;
}

=head2 $keyName= $self->colToFlatKey( @colPath || \@colPath || $ColPath )

Converts a column specified by relation path into the name of a key used for the flattened view.

=cut
sub colToFlatKey {
	my $self= shift;
	my $colPath= RapidApp::DBIC::ColPath->coerce(@_);
	return $self->_colmap->{toFlat}{$colPath->key};
}

=head2 $hashTree= $self->restore( $flatHash )

Take a flattened hash and restore it to its treed form.

Reverse of ->flatten();

=cut
sub restore {
	my ($self, $hash)= @_;
	my $toTree= $self->_colmap->{toTree};
	my $result= {};
	for my $key (keys %$hash) {
		if (exists $toTree->{$key}) {
			$toTree->{$key}->assignToHashTree( $result, $hash->{$key} );
		} elsif (!$self->{ignoreUnexpected}) {
			die "Illegal flattened field name encountered: $key";
		}
	}
	$result;
}

=head2 $colPath= $self->flatKeyToCol( $key )

Returns the column that maps to the specified flat key.

=cut
sub flatKeyToCol {
	my ($self, $key)= @_;
	return $self->_colmap->{toTree}{$key};
}


=head2 $colPath= $self->flatKeyToCol( $key )

Returns a list (not arrayref) of all flat key names supported by this flattener.

=cut
sub getAllFlatKeys {
	my $self= shift;
	return keys %{ $self->_colmap->{toTree} };
}

=head2 $newFlattener= $self->subset( @colspec || \@colspec || $relationTreeSpec )

This method creates a new RelationTreeFlattener which only deals with a subset of the
columns of the current one.   An especially useful feature of this method is that the
new RelationTreeFlattener uses the exact same name mapping as the current one, which
might not be the case if you were to create a RelationTreeFlattener from the smaller
column list.

=cut
sub subset {
	my ($self, @colSpec)= @_;
	my $colSubset= $self->spec->intersect(@colSpec);
	my $curMap= $self->_colmap->{toFlat};
	my (%toTree, %toFlat);
	for my $col ($colSubset->colList) {
		my $key= $col->key;
		my $flatName= $curMap->{$key};
		$toFlat{$key}= $flatName;
		$toTree{$flatName}= $col;
	}
	return ref($self)->new(
		spec => $colSubset,
		namingConvention => $self->namingConvention,
		ignoreUnexpected => $self->ignoreUnexpected,
		_colmap => { toTree => \%toTree, toFlat => \%toFlat }
	);
}

1;