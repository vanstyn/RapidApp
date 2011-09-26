package RapidApp::DBIC::RelationTreeFlattener;
use Moo;
use RapidApp::DBIC::ColPath;
use RapidApp::DBIC::RelationTreeSpec;

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

The key names of the flattened hash are chosen by concatenating the path of relations
that lead up to a column, separated by underscore.  This is not guaranteed to work in
all cases, though, because underscore is often used in column names.  In the future,
this module might support other naming schemes, such as simple incrementing numeric
key names, or flatten to an array rather than a hash.

=head1 ATTRIBUTES

=head2 spec : RapidApp::DBIC::RelationTreeSpec

The spec determines what relations and columns are considered.  Any hash keys encountered
which are not in the spec will either be ignored or throw an error, depending on the
attribute "ignoreUnexpected".

=head2 namingConvention : enum

The naming convention to use for flattening column names.  Defaults to only supported
value of "_concat_"

=head2 ignoreUnexpected : bool

Whether or not unexpected hash keys should generate exceptions.  Defaults to true.

=cut

has spec             => ( is => 'ro', required => 1 );
has namingConvention => ( is => 'rw', isa => \&_checkNamingConvention, default => sub { "_concat_" } );
has ignoreUnexpected => ( is => 'rw', default => sub { 1 } );

has _colmap          => ( is => 'ro', lazy => 1, builder => '_build__colmap' );
sub _build__colmap {
	my $self= shift;
	my (%toTree, %toFlat);
	for my $col ($self->spec->colList) {
		my $flatName= join('_', @$col);
		$toFlat{$col->key}= $flatName;
		if (exists $toTree{$flatName}) {
			if (ref($toTree{$flatName}) eq 'ARRAY') {
				push @{ $toTree{$flatName} }, $col;
			} else {
				carp "Columns $col and $toTree{$flatName} both map to the key $flatName";
				$toTree{$flatName}= [ $toTree{$flatName}, $col ];
			}
			$toTree{$flatName}= $col;
		}
	}
	return { toTree => \%toTree, toFlat => \%toFlat };
}

sub _checkNamingConvention {
	# only one supported, for now.
	die "Unsupported naming convention: $_[0]" unless $_[0] eq '_concat_';
}

=head1 METHODS

=head2 $flatHash= $self->flatten( $hashTree )

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
				DEBUG(foo => col => [@$path, $key], colKey => RapidApp::DBIC::ColPath::key([@$path, $key]));
				if (my $flatName= $toFlat->{ RapidApp::DBIC::ColPath::key([@$path, $key]) }) {
					# Check for case where two columns map to the same key
					if (exists $result->{$flatName}) {
						if (!ref($result->{$flatName}) || !ref($node->{$key}) || $result->{$flatName} ne $node->{$key}) {
							croak "Conflicting values written to $flatName: $colPath = $node->{$key}, but other column was $result->{$flatName}";
						}
					}
					$result->{$flatName}= $node->{$key};
				} elsif (!$self->{ignoreUnexpected}) {
					die "Illegal column/relation encountered: ".join('.',@$path,$key);
				}
			}
		}
	}
	$result;
}

=head2 $keyName= $self->colToFlatKey( \@colPath )

Converts a column specified by relation path into the name of a key used for the flattened view.

=cut
sub colToFlatKey {
	my $self= shift;
	my $path= ref($_[0]) eq 'ARRAY'? $_[0] : [ @_ ];
	return $self->_colmap->{toFlat}{ _pathToKey( @$path ) };
}

=head2 $hashTree= $self->restore( $flatHash )

Take a flattened hash and restore it to its treed form.

=cut
sub restore {
	my ($self, $hash)= @_;
	my $toTree= $self->_colmap->{toTree};
	my $result= {};
	for my $key (keys %$hash) {
		if (exists $toTree->{$key}) {
			if (ref($toTree->{$key}) eq 'ARRAY') {
				for my $colPath (@{ $toTree->{$key} }) {
					$colPath->assignToHashTree( $result, $hash->{$key} );
				}
			} else {
				$toTree->{$key}->assignToHashTree( $result, $hash->{$key} );
			}
		} elsif (!$self->{ignoreUnexpected}) {
			die "Illegal flattened field name encountered: $key";
		}
	}
	$result;
}

=head2 $colPath= $self->flatKeyToCol( $key )

Returns the column (or columns!) that map to the specified flat key.

In scalar context, only returns one column, since there ought to only be one.

=cut
sub flatKeyToCol {
	my ($self, $key)= @_;
	my $colPath= $self->_colmap->{toTree}{$key};
	return undef unless defined $colPath;
	return $colPath unless ref($colPath) eq 'ARRAY';
	return wantarray? @$colPath : $colPath->[0];
}

=head2 $newFlattener= $self->subset( @colspec || \@colspec || $relationTreeSpec )

This method creates a new RelationTreeFlattener which only deals with a subset of the
columns of the current one.   An especially useful feature of this method is that the
new RelationTreeFlattener uses the same name mapping as the current one, which might
not be the case if you were to create a RelationTreeFlattener from the smaller column
list.

=cut
sub subset {
	my ($self, @colSpec)= @_;
	my $colSubset= $self->spec->insersect(@colSpec);
	my $curMap= $self->_colmap->{toFlat};
	my (%toTree, %toFlat);
	for my $col ($colSubset->colList) {
		my $key= $col->key;
		my $flatName= $curMap->{$key};
		$toFlat{$key}= $flatName;
		if (exists $toTree{$flatName}) {
			# user has already been warned.  So just do it.
			ref($toTree{$flatName}) eq 'ARRAY'
				or $toTree{$flatName}= [ $toTree{$flatName} ];
			push @{ $toTree{$flatName} }, $col;
		}
	}
	return $self->new(
		spec => $colSubset,
		namingConvention => $self->namingConvention,
		ignoreUnexpected => $self->ignoreUnexpected,
		_colmap => { toTree => \%toTree, toFlat => \%toFlat }
	);
}

1;