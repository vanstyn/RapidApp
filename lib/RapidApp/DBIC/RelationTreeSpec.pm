package RapidApp::DBIC::RelationTreeSpec;
use strict;
use warnings;
use Params::Validate;
use Carp;
use RapidApp::DBIC::ColPath;
use RapidApp::Debug 'DEBUG';

=head1 NAME

RapidApp::DBIC::RelationTreeSpec

=head1 SYNOPSIS

  RapidApp::DBIC::RelationTreeSpec->new(
    source => $schema->source('Object'),
    colSpec => [ qw(
      col1 col2 col3 col4
      foo.*
      foo.bar.*
      baz.col1
	  baz.col5
	  blah.*
	  -blah.internal
	  -blah.secret
	)],
  );
  
=head1 DESCRIPTION

This package describes a set of columns, and a set of utility methods to query which things
are in the set.  And thats all, really.

It lets you specify columns, wildcard "*" columns, and exclusions "-".  You can specify the
names of DBIC relations using dot notation, and they will be followed.

This package is used by other useful packages like RelationTreeExtractor and RelationTreeFlattener
and DbicLink to reduce the burden of having to use awkward attributes to describe which columns
should be part of the result.

=head1 ATTRIBUTES

=head2 source : DBIx::Class::ResultSource

The result source that the column spec is relative to.

=cut
sub source {
	(scalar(@_) == 1) or croak "Can't set colSpec";
	$_[0]->{source};
}

=head2 colSpec : array[scalar]

The exact structure that was passed to the constructor.  It can be modified only if the
spec has not been resolved.

=cut
sub colSpec {
	(scalar(@_) == 1) or croak "Can't set colSpec";
	# Usually colSpec has been specified to the constructor.  But, sometimes
	# we have colTree and not colSpec and have to generate a virtual spec.
	return $_[0]->{colSpec} ||= do {
		my @ret;
		my @todo= ( [ '', $_[0]->colTree ] );
		while (@todo) {
			my ($prefix, $node)= @{ pop @todo };
			for (keys %$node) {
				if (ref $node->{$_}) { push @todo, [ $prefix.$_.'.', $node->{$_} ] }
				else { push @ret, $prefix.$_ }
			}
		}
		\@ret;
	};
}

=head2 colArray : array[array[scalar]]

An array of all columns, each as an arrayref of relation names followed by a column name.

This list is sorted alphabetically by relation and column name.

=cut
sub colArray {
	(scalar(@_) == 1) or croak "Can't set colArray";
	return $_[0]->{colArray} ||= do {
		my ($recurse, @ret);
		$recurse= sub {
			my ($path, $node)= @_;
			for (sort keys %$node) {
				if (ref $node->{$_}) { $recurse->( [ @$path, $_ ], $node->{$_} ); }
				else { push @ret, RapidApp::DBIC::ColPath->new(@$path, $_) }
			}
		};
		$recurse->( [], $_[0]->colTree );
		\@ret;
	};
}

=head2 colList : list( array[scalar] )

This is simply the de-referenced $self->colArray

=cut
sub colList {
	my $self= shift;
	return @{ $self->colArray };
}

=head2 colTree : hash[ rel => rel => ... => col => 1 ]

The tree of relations and columns that the spec refers to.
This is the most definitive attribute, and the only one that
is never lazily built.

=cut
sub colTree {
	(scalar(@_) == 1) or croak "Can't set coltree";
	$_[0]->{colTree};
}

=head2 relTree : hash[ rel => rel => {} ]

Returns a tree of only the relations. Same as colTree, but minus the columns.

Example:

  colTree: { foo => 1, bar => 2, baz => { a => 1, b => 2, c => 3 } }
  relTree: { baz => {} }

=cut
sub relTree {
	(scalar(@_) == 1) or croak "Can't set relTree";
	return $_[0]->{relTree} ||= do {
		my ($recurse, $ret)= {};
		$recurse= sub {
			my ($dst, $src)= @_;
			$recurse->( ($dst->{$_} ||= {}), $src->{$_} ) for grep { ref $src->{$_} } keys %$src;
		};
		$recurse->( $ret, $_[0]->{relTree} );
		$ret;
	};
}

=head1 METHODS

=head2 $class->new( source => $optionalDbicSource, colSpec => \@colList )

=cut

sub new {
	my $class= shift;
	my %params= validate(@_, { source => 1, colSpec => 0, colTree => 0 });
	$params{colSpec} || $params{colTree} or croak "Must specify one of colSpec or colTree";
	$params{colTree} ||= $class->resolveSpec($params{source}, $params{colSpec});
	bless \%params, $class;
}

=head2 $self->intersect( @spec || \@spec || $RelationTreeSpec )

Takes either a arrayref of column specifications, a direct list of column specifications, or another
RelationTreeSpec object.

Calculates a new RelationTreeSpec object which is the intersection of the columns in common
between the two sets of columns.

=cut
sub intersect {
	my $self= shift;
	return $self unless scalar(@_) && defined $_[0];
	my $peerColTree= !ref($_[0])? $self->resolveSpec($self->source, [ @_ ] ) :
	                 ref($_[0]) eq 'ARRAY'? $self->resolveSpec($self->source, $_[0] ) :
	                 $_[0]->can('colTree')? $_[0]->colTree :
	                 croak("Invalid spec param given for ->intersect");
	my $recurse;
	$recurse= sub {
		my ($dest, $a, $b)= @_;
		for my $key (keys %$a) {
			my ($aa, $bb)= ($a->{$key}, $b->{$key});
			next unless defined $aa && defined $bb;
			if (ref $aa and ref $bb) {
				$recurse->( (my $subHash= {}), $a->{$key}, $b->{$key});
				$dest->{$key}= $subHash if scalar keys %$subHash;
			} elsif (!ref($aa) && !ref($bb)) {
				$dest->{$key}= 1;
			}
		}
	};
	$recurse->( (my $intersect= {}), $self->colTree, $peerColTree );
	return (ref $self)->new(source => $self->source, colTree => $intersect);
}

=head2 $self->union( @spec || \@spec || $relationTreeSpec )

Takes either a arrayref of column specifications, a direct list of column specifications, or another
RelationTreeSpec object.

Calculates a new RelationTreeSpec object which is the intersection of the columns in common
between the two sets of columns.

=cut

sub union {
	my $self= shift;
	return $self unless scalar(@_) && defined $_[0];
	my $peerColTree= !ref($_[0])? $self->resolveSpec($self->source, [ @_ ] ) :
	                 ref($_[0]) eq 'ARRAY'? $self->resolveSpec($self->source, $_[0] ) :
	                 $_[0]->can('colTree')? $_[0]->colTree :
	                 croak("Invalid spec param given for ->intersect");
	my ($recurse, $union)= (undef, {});
	$recurse= sub {
		my ($dest, $src)= @_;
		for my $key (keys %$src) {
			if (ref $src->{$key}) {
				my $subDest= ($dest->{$key} ||= {});
				ref $subDest or croak "$_ is a column in self, but a relation in peer";
				$recurse->( $subDest, $src->{$key} );
			} else {
				ref ($dest->{$key} ||= 1) and croak "$_ is a relation in self, but a column in peer";
			}
		}
	};
	$recurse->( $union, $self->colTree ); # clone
	$recurse->( $union, $peerColTree );   # merge
	return (ref $self)->new(source => $self->source, colTree => $union);
}

=head2 $self->subtract( @spec || \@spec || $relationTreeSpec )

Takes either a arrayref of column specifications, a direct list of column specifications, or another
RelationTreeSpec object.

Calculates a new RelationTreeSpec object which is the current spec's columns
excluding any of the columns in the given spec.

=cut

sub subtract {
	my $self= shift;
	return $self unless scalar(@_) && defined $_[0];
	my $peerColTree= !ref($_[0])? $self->resolveSpec($self->source, [ @_ ] ) :
	                 ref($_[0]) eq 'ARRAY'? $self->resolveSpec($self->source, $_[0] ) :
	                 $_[0]->can('colTree')? $_[0]->colTree :
	                 croak("Invalid spec param given for ->intersect");
	my $recurse;
	$recurse= sub {
		my ($dest, $a, $b)= @_;
		for my $key (keys %$a) {
			my ($aa, $bb)= ($a->{$key}, $b->{$key});
			if (ref $aa) {
				$recurse->((my $subHash= {}), $aa, $bb || {});
				$dest->{$key}= $subHash if scalar keys %$subHash;
			} else {
				$dest->{$key}= 1 unless $bb;
			}
		}
	};
	$recurse->( (my $difference= {}), $self->colTree, $peerColTree );
	return (ref $self)->new(source => $self->source, colTree => $difference);
}

=head2 $class->validateSpec( \@spec )

Returns the spec if it is valid.  Throws an exception if it is not.

=cut
sub validateSpec {
	my ($class, $spec)= @_;
	(ref($spec) eq 'ARRAY') or croak "colSpec must be an array";
	for my $specItem (@$spec) {
		unless (defined $specItem) { carp "Warning: undef found in RelationTreeSpec colSpec list"; next; }
		(ref $specItem) and croak "Column specification items must be plain scalars";
		($specItem =~ /^-?([-_A-Za-z0-9]+|\*)(\.([-_A-Za-z0-9]+|\*))*$/) or croak "Invalid column specification: '$specItem'";
	}
	return $spec;
}

=head2 $colTree= $class->resolveSpec( $dbicSource, $colSpec )

This method is usually run during the constructor, but can be used to avoid creating
objects and just cut to the chase.

=cut
sub resolveSpec {
	my ($class, $source, $spec)= @_;
	
	# calculate the hash-tree of columns and relations
	my $tree= {};
	$class->validateSpec($spec);
	for my $specItem (@$spec) {
		my $remove= substr($specItem, 0, 1) eq '-';   # is it an exclusion rule?
		my @parts= split(/\./, $remove? substr($specItem,1) : $specItem);  # split a.b.c into [ 'a', 'b', 'c' ]
		_resolve_spec_item($tree, $source, $remove, @parts); # apply this spec to $tree
	}
	DEBUG(colspec => spec => $spec, 'resolve as tree:', $tree);
	$tree;
}

sub _resolve_spec_item {
	my ($tree, $source, $remove, $item, @subparts)= @_;
	
	if ($item eq '*') {
		for ($source->columns) {
			_resolve_spec_item($tree, $source, $remove, $_, @subparts);
		}
	} elsif ($source->has_relationship($item)) {
		if (@subparts) {
			_resolve_spec_item($tree->{$item} ||= {}, $source->related_source($item), $remove, @subparts);
			delete $tree->{$item} unless scalar keys %{ $tree->{$item} };
		} elsif ($remove) {
			delete $tree->{$item};
		} else {
			$tree->{$item} ||= {};
		}	
	} elsif ($source->has_column($item)) {
		if (@subparts) { croak "Cannot access $item.".join('.',@subparts)."; $item is a column"; }
		elsif ($remove) { delete $tree->{$item}; }
		else { $tree->{$item}= 1; }
	} else {
		croak "No such column or relationship '$item' in source ".$source->source_name;
	}
}

1;