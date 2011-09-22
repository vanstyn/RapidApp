package RapidApp::DBIC::RelationTreeSpec;
use strict;
use warnings;
use Params::Validate;
use Carp;

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
  
If you don't have the database object at creation time, you can
resolve the column names later.  But, make sure you do, or you'll get
an exception when you try to use the spec!
  
  my $spec= RapidApp::DBIC::RelationTreeSpec->new(colSpec => \@colSpecList, source => undef);
  $spec->resolve( $schema->source('Object') );

=head1 DESCRIPTION

This package describes a set of columns, and a set of utility methods to query which things
are in the set.  And thats all, really.

It lets you specify columns, wildcard "*" columns, and exclusions "-".  You can specify the
names of DBIC relations using dot notation, and they will be followed.

This package is used by other useful packages like RelationTreeExtractor and RelationTreeFlattener
and DbicLink to reduce the burden of having to use weird attributes to describe which columns
should be part of the result.

=head1 ATTRIBUTES

=head2 colSpec

The exact structure that was passed to the constructor.  It can be modified only if the
spec has not been resolved

=head2 relationTree

The tree of relations and columns that the spec referred to.  This is only available
if you passed a "source" to the constructor, or if you called "->resolve($source)".

=cut

sub colSpec {
	(scalar(@_) == 1) or croak "Can't change colSpec after RelationTreeSpec has been resolved!  Try creating a new one.";
	$_[0]->{colSpec};
}

# returns a nested hash of relation and column names, with relations => {} and columns => 1
sub relationTree {
	(scalar(@_) == 1) or croak "Can't set relationTree";
	$_[0]->{relationTree};
}

# returns a long list of "relation[...].column" names
sub allCols {
	my $self= shift;
	return $self->{allCols} ||= do {
		my @ret;
		my @todo= ( [ [], $self->relationTree ] );
		while (@todo) {
			my ($path, $node)= @{ pop @todo };
			for (keys %$node) {
				if (ref $node->{$_}) { push @todo, [[ @$path, $_ ], $node->{$_} ]; }
				else { push @ret, join('.',@$path,$_) }
			}
		}
		[ sort @ret ];
	};
}

=head1 METHODS

=head2 $class->new( source => $optionalDbicSource, cols => \@colList )

=cut

sub new {
	my $class= shift;
	my %params= validate(@_, { source => 0, colSpec => 1 });
	my $self= bless { colSpec => validateSpec(undef,$params{colSpec}) }, $class.'::Unresolved';
	$self->resolve( $params{source} ) if $params{source};
	return $self;
}

=head2 $self->validateSpec( \@spec )

Returns the spec if it is valid.  Throws an exception if it is not.

=cut
sub validateSpec {
	my ($self, $spec)= @_;
	(ref($spec) eq 'ARRAY') or croak "colSpec must be an array";
	for my $specItem (@$spec) {
		unless (defined $specItem) { carp "Warning: undef found in RelationTreeSpec colSpec list"; next; }
		(ref $specItem) and croak "Column specification items must be plain scalars";
		($specItem =~ /^-?([-_A-Za-z0-9]+|\*)(\.([-_A-Za-z0-9]+|\*))*$/) or croak "Invalid column specification: '$specItem'";
	}
	return $spec;
}

=head2 $self->resolve( $dbicSource )

If you did not pass a DBIC source object to the constructor, you need to call this method
before you can access any other properties.

Calling this method additional times has no effect.  If you want to resolve against a different
schema, you need to create a new RelationTreeSpec.

Returns $self, possibly re-blessed as a complete RelationTreeSpec.

=cut
sub resolve {
	# no-op, because if we were not resolved, we would be an instance of RapidApp::DBIC::RelationTreeSpec::Unresolved
	return shift;
}

package RapidApp::DBIC::RelationTreeSpec::Unresolved;
use strict;
use warnings;
use Carp;
our @ISA= ('RapidApp::DBIC::RelationTreeSpec');

=head1 UNRESOLVED SPECS

If a spec is not resolved (by passing a schema source in the constructor) it will be
blessed as a special 'Unresolved' object.  This object will throw exceptions on most
of the methods of the regular Spec object, since they can't be known without access
to the schema.  When ->resolve($source) is called, the object will be reblessed as a
proper RelationTreeSpec, and behave normally.

=cut

# colSpec is read/write until resolved
sub colSpec {
	my $self= shift;
	if (@_) { $self->{colSpec}= $self->validateSpec((ref($_[0]) eq 'ARRAY')? $_[0] : [ @_ ]); }
	return $self->{colSpec};
}

for (qw( relationTree allCols )) {
	eval "sub $_ { croak 'Cannot call $_() until after resolve()'; }";
}

sub resolve {
	my ($self, $source)= @_;
	
	# calculate the hash-tree of columns and relations
	my $tree= {};
	for my $specItem (@{ $self->{colSpec} }) {
		my $remove= ($specItem =~ s/^-//)? 1 : 0;   # is it an exclusion rule?
		my @parts= split(/\./, $specItem);  # split a.b.c into [ 'a', 'b', 'c' ]
		_resolve_spec_item($tree, $source, $remove, @parts); # apply this spec to $tree
	}
	$self->{relationTree}= $tree;
	use Data::Dumper;
	
	# now re-bless ourselves as a resolved instance
	my $resolvedClass= ref($self);
	$resolvedClass =~ s/::Unresolved$//;
	bless $self, $resolvedClass;
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
		} elsif ($remove) {
			delete $tree->{$item};
		} else {
			$tree->{$item} ||= {};
		}	
	} else {
		if (@subparts) { croak "Cannot access $item.".join('.',@subparts)."; $item is a column"; }
		elsif ($remove) { delete $tree->{$item}; }
		else { $tree->{$item}= 1; }
	}
}

1;