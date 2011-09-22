package RapidApp::DBIC::RelationTreeFlattener;
use Moo;
use RapidApp::DBIC::RelationTreeSpec;

=head1 NAME

RapidApp::DBIC::RelationTreeFlattener

=head1 SYNOPSIS

  my $spec= RapidApp::DBIC::RelationTreeSpec->new(
    source => $db->source('Object'),
    colSpec => [qw( user.* contact.* creator_id owner_id is_deleted contact.timezone.ofs )]
  );
  
  my $flattener= RapidApp::DBIC::RelationTreeFlattener->new(spec => $spec);
  
  my $treed= {
    creator_id => 5,
    owner_id => 7,
    is_deleted => 0,
    user => { name => 'foo', password => 'yes' },
    contact => {
      first => 'John',
      last => 'Doe'
      timezone => { ofs => -500 }
    },
  };
  my $flattened= {
    creator_id => 5,
    owner_id => 7,
    is_deleted => 0,
    user_name => 'foo',
    user_password => 'yes',
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
	my $map= { toTree => {}, toFlat => {} };
	my $relTree= $self->spec->relationTree;
	_build_colmap_at_node($map, [], $relTree);
}

sub _build_colmap_at_node {
	my ($map, $path, $node)= @_;
	for my $key (keys %$node) {
		if (ref $node->{$key}) {
			_build_colmap_at_node($map, [ @$path, $key ], $node->{$key})
		}
		else {
			my $flatName= join('_', @$path, $key);
			my $treePath= [ @$path, $key ];
			$map->{toFlat}{ _pathToKey(@$treePath) }= $flatName;
			$map->{toTree}{$flatName}= $treePath;
		}
	}
	$map;
}

sub _pathToKey {
	join '', map { length($_).$_ } @_
}

sub _checkNamingConvention {
	# only one supported, for now.
	die "Unsupported naming convention: $_[0]" unless $_[0] eq '_concat_';
}

=head1 METHODS

=head2 $flatHash= $self->flatten( $hashTree )

=cut

sub flatten {
	my ($self, $hash)= @_;
	$self->_flattenNode({}, [], $self->spec->relationTree, $hash);
}

sub _flattenNode {
	my ($self, $result, $path, $spec, $node)= @_;
	for my $key (keys %$node) {
		if (ref $spec->{$key}) {
			$self->_flattenNode($result, [ @$path, $key ], $spec->{$key}, $node->{$key});
		} else {
			if (my $flatName= $self->_colmap->{toFlat}{ _pathToKey(@$path, $key) }) {
				$result->{$flatName}= $node->{$key};
			} elsif (!$self->{ignoreUnexpected}) {
				die "Illegal column/relation encountered: ".join('.',@$path,$key);
			}
		}
	}
	$result;
}

=head2 $hashTree= $self->restore( $flatHash )

=cut

sub restore {
	my ($self, $hash)= @_;
	my $toTree= $self->_colmap->{toTree};
	my $result= {};
	for my $key (keys %$hash) {
		if (my $path= $toTree->{$key}) {
			my $node= $result;
			for (@$path[0..$#$path-1]) { $node= ($node->{$_} ||= {}) }
			$node->{$path->[-1]}= $hash->{$key};
		} elsif (!$self->{ignoreUnexpected}) {
			die "Illegal flattened field name encountered: $key";
		}
	}
	$result;
}

1;