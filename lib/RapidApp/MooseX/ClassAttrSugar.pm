package RapidApp::MooseX::ClassAttrSugar; 

=head1 NAME

MooseX::ClassAttrSugar - Create add methods for merging defaults of HashRef attributes 

=head1 SYNOPSIS

  package MyApp::Parent;
  
  use Moose;
  
  has 'foo_configs' => ( is => 'ro', builder => '_build_foo_configs', isa => 'HashRef' );
  sub _build_foo_configs { +{ 'base_setting1' => 'Some data' } }
  
  # then later ...
  package MyApp::Subclass;
  
  use Moose;
  extends 'MyApp::Parent';
  
  use MooseX::ClassAttrSugar;
  setup_apply_methods_for('foo_configs');
  apply_default_foo_configs(
    setting2  => 'Some other data',
    setting3  => 'Some more data'
  );
  
  
  # then later...
  
  my $obj = MyApp::Subclass->new;
  
  # $obj->foo_configs is initialized containing:
  # {
  #   base_setting1  => 'Some data',
  #   setting2       => 'Some other data',
  #   setting3       => 'Some more data'
  # }
  
  $obj->apply_foo_configs(
    setting4         => 'blah',
    setting5         => 'baz'
  );
  
  # $obj->foo_configs is now:
  # {
  #   base_setting1  => 'Some data',
  #   setting2       => 'Some other data',
  #   setting3       => 'Some more data',
  #   setting4       => 'blah',
  #   setting5       => 'baz'
  # }


=head1 TODO

Add support for other types, like ArrayRef
Get flamed in #moose :)

=head1 AUTHOR

vs following mst's directions

=cut


use strict;
use Moose;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
	with_meta => [ 'setup_apply_methods_for' ]
);


# Create a 'apply_default_$attr_name' method to be called in class (not object) context
# that will allow merging in hash data into the attribute's already existing 
# default value (as set by a builder method, not 'default'). Also create apply_$attr_name
# which can be called in object context
sub setup_apply_methods_for {
	my $meta = shift;
	my $attr_name = shift;
	
	my $attr = $meta->find_attribute_by_name($attr_name) or die "attribute $attr_name not found.";
	my $constraint = $attr->type_constraint or die "Only attributes of type HashRef are supported.";
	$constraint->is_a_type_of('HashRef') or die "Only attributes of type HashRef are supported.";
	$attr->has_builder or die "Only attributes with builder methods are supported";
	my $builder = $attr->builder;
	#$class->can($builder) or die $builder . ' builder method does not exist';
	
	my $apply_default_method = 'apply_default_' . $attr_name;
	my $apply_method = 'apply_' . $attr_name;
	
	# Class context:
	$meta->add_method($apply_default_method => sub { 
		my @to_add = @_;
		@to_add = %{$to_add[0]} if (ref($to_add[0]) eq 'HASH');
		$meta->add_around_method_modifier(
			$builder => sub { 
				my ($orig, $self) = (shift, shift); 
				my $l = $self->$orig(@_); 
				return { 
					%{$l}, 
					@to_add 
				} 
			}
		); 
	});
		
	# Object context:
	$meta->add_method($apply_method => sub { 
		
		if(ref($_[0]) && $_[0]->can($attr_name)) {
			my $obj = shift;
			my %new = @_;
			%new = %{$_[0]} if (ref($_[0] eq 'HASH'));
			return @{$obj->$attr_name}{keys %new} = values %new;
		}
	});
}


1;