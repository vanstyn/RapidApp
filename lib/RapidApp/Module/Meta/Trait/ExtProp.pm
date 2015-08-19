package RapidApp::Module::Meta::Trait::ExtProp;

# Attribute Trait for Ext config properties (EXPERIMENTAL)
#

use Moose::Role;
Moose::Util::meta_attribute_alias('ExtProp');

use RapidApp::Util ':all';


# Same as the attribute name by default, but allow override:
has 'ext_name', is => 'ro', isa => 'Str', lazy => 1, default => sub { (shift)->name };

sub get_ext_value {
  my ($attr, $obj) = @_;
  
  my $value = $attr->get_value($obj);
  
  if($attr->has_type_constraint && $attr->type_constraint->equals('Bool')) {
    return $value ? \1 : \0;
  }
  
  return $value
}


sub _apply_ext_value {
  my ($attr, $obj) = @_;
  $obj->apply_extconfig( $attr->ext_name => $attr->get_ext_value($obj) )
}

# Hook all events which set the value and automatically apply 
# to the extconfig of the object/instance

after 'set_initial_value' => sub { (shift)->_apply_ext_value(@_) };
after 'set_raw_value'     => sub { (shift)->_apply_ext_value(@_) };


1;