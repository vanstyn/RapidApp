package RapidApp::DefaultOverride;

use Exporter 'import';
use Hash::Merge 'merge';
our $merger= Hash::Merge->new('LEFT_PRECEDENT');

our @EXPORT_OK= qw(override_defaults override_default merge_defaults merge_default);

=head1 NAME

RapidApp::DefaultOverride

=head1 SYNOPSIS

  package ParentClass;
  use Moose;
  has 'foo' => ( is => 'rw', isa => 'Int', default => -3 );
  has 'bar' => ( is => 'rw', isa => 'HashRef', default => sub {{ a => 1, b => 2 }} );
  has 'baz' => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );
  has 'complicated' => ( is => 'rw', isa => 'HashRef', default => { something => 'whatever' } );
  
  1;
  
  package SubClass;
  use Moose;
  extends 'ParentClass';
  
  override_defaults({
    foo => 37
  });
  merge_defaults({
    bar => { a => 12, b => 16 },
    baz => { x => -1, y => 0, z => 1 },
    complicated => sub { my ($self, $v)= @_; return $self->complex_processing($v); },
  });
  
  1;

=head1 DESCRIPTION

These utility functions handle the various mechanisms required to properly override or merge
the default value of an attribute which was defined in a parent class.
(actually, it can override defaults for attributes defined in the current class too, but that
isn't recommended)

An 'override' causes the default to be computed in an entirely new way.  The original code
used to create the default is ignored and not executed.

The new default can be anything that would notmally be valid for a default.

A 'merge' finds out what the original default was, and then either (if you passed a coderef)
calls the given coderef to calculate the new value, or (if you passed anything else)
merges the specified value with the original value using

  our $merge= Hash::Merge->new('LEFT_PRECENDENT');
  $merge->merge($given, $orig)

If you want behavior different than LEFT_PRECEDENT, just pass your own merge method, which can
call Hash::Merge with your own parameters.

These methods will work with any defined Moose attributes, including those form Roles.

These methods might also work inside Roles, as well, but this isn't tested.

=head1 METHODS

=head2 override_defaults \%attrSpecs

  override_defaults( {
    attr1 => $val1,
    attr2 => sub { my $self= shift; return $self->method; },
  } );

The package name of the caller is found using the 'caller' method, so this should be
considered a sugar method.  For automated use, call 'override_default' directly.

=cut
sub override_defaults {
	my $class= caller;
	my $args= ref $_[0] eq 'HASH'? $_[0] : { @_ };
	while (my ($name, $newDefault)= each %$args) {
		override_default($class, $name, $newDefault);
	}
}

=head2 override_default( $class, $attrName, $newDefault )

  override_default( $class, $attrName, $refToSomeValue )
  override_default( $class, $attrName, sub { my $self= shift; return $self->whatever(); } )

=cut
sub override_default {
	my ($class, $name, $newDefault)= @_;
	my $prevAttr= $class->meta->find_attribute_by_name($name);
	
	# If we have a builder method, we override it using an "around" method modifier
	#  which completely ignores the actual method.
	if ($prevAttr->builder) {
		$class->meta->add_around_method_modifier($prevAttr->builder, sub { $newDefault });
	}
	# Else, we create a new attribute with the given default.
	else {
		$class->meta->add_attribute($prevAttr->clone_and_inherit_options(default => $newDefault));
	}
}

=head2 merge_defaults \%attrSpecs

  merge_defaults( {
    attr1 => { hash => 'keys', to => 'merge', with => '' },
    attr2 => sub { my ($self, $v)= @_; $self->my_merge_routine($v); },
  } );

The package name of the caller is found using the 'caller' method, so this should be
considered a sugar method.  For automated use, call 'merge_default' directly.

=cut
sub merge_defaults {
	my $class= caller;
	my $args= ref $_[0] eq 'HASH'? $_[0] : { @_ };
	while (my ($name, $newDefault)= each %$args) {
		merge_default($class, $name, $newDefault);
	}
}

=head2 merge_default( $class, $attrName, $newDefault )

  override_default( $class, $attrName, { hash => 'of', keys => 'to', merge => '' } )
  override_default( $class, $attrName, sub { my ($self, $prevVal)= @_; return $self->whatever($prevVal); )

=cut
sub merge_default {
	my ($class, $name, $newDefault)= @_;
	my $prevAttr= $class->meta->find_attribute_by_name($name);
	
	# If we have a builder method, we get the ancestor value by calling the method
	#  and override it using an "around" method modifier
	if ($prevAttr->builder) {
		my $fn= (ref $newDefault eq 'CODE')?
			sub {
				my ($orig, $cls, $self)= @_;
				my $ancestorVal= $cls->$orig($self);
				$newDefault->($self, $ancestorVal);
			}
			:
			sub {
				my ($orig, $cls, $self)= @_;
				my $ancestorVal= $cls->$orig($self);
				$RapidApp::DefaultOverride::merger->merge($newDefault, $ancestorVal);
			};
		$class->meta->add_around_method_modifier($prevAttr->builder, $fn);
	}
	# Else, we get the ancestor value by finding the ancestor attribute and getting its default
	#   and then overrid eit by creating a new attribute.
	else {
		my $fn= (ref $newDefault eq 'CODE')?
			sub {
				my $self= shift;
				my $ancestorVal= $prevAttr->default($self);
				$newDefault->($self, $ancestorVal);
			}
			:
			sub {
				my $self= shift;
				my $ancestorVal= $prevAttr->default($self);
				$RapidApp::DefaultOverride::merger->merge($newDefault, $ancestorVal);
			};
		$class->meta->add_attribute($prevAttr->clone_and_inherit_options(default => $fn));
	}
}

1;

# package Foo;

# use Moose;

# has 'bar' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { my $self= shift; join(',', qw(a b c d e f), $self->baz) } );
# has 'baz' => ( is => 'ro', isa => 'Str', default => 'Something' );
# has 'hash' => ( is => 'rw', isa => 'HashRef', default => sub {
	# { a => 1, b => 2, c => 3 }
# });
# has 'built' => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );
# sub _build_built {
	# my $self= shift;
	# return { %{$self->hash}, x => -1, y => -1, z => -1 };
# }
# has 'nodef' => ( is => 'rw', isa => 'Int' );

# no Moose;
# __PACKAGE__->meta->make_immutable;

# package Foo2;

# use Moose::Role;

# has 'x1' => ( is => 'ro', isa => 'Str', lazy => 1, default => 'Default' );
# has 'x2' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
# sub _build_x2 {
	# return [12345];
# }

# no Moose;
# 1;

# package Bar;

# use Moose;
# extends 'Foo';
# with 'Foo2';
# DefaultSetter->import;
# use Data::Dumper;

# override_defaults( {
	# 'baz' => 'Different',
	# 'x1' => 'String',
# } );

# merge_defaults( {
	# 'bar' => sub { my ($self, $prev)= @_; return $prev . ',BAZ!!!!'; },
	# 'hash' => { c => 5, d => 9 },
	# 'built' => { x => '.', y => '.', z => '.' },
	# 'nodef' => sub { print "\n\n".Dumper(@_)."\n\n" },
	# 'x2' => [45],
# } );

# no Moose;
# __PACKAGE__->meta->make_immutable;

# package main;
# use Data::Dumper;

# my $b= Bar->new;
# print $b->bar."\n";
# print Dumper($b->hash);
# print Dumper($b->built);
# print $b->x1."\n".Dumper($b->x2)."\n";
