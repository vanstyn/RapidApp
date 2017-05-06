package RapidApp::Util::Role::ModelDBIC;

use strict;
use warnings;

# Optional Moo::Role designed to work with Moo-extended Catalyst::Model::DBIC::Schema
# classes like the ones bootstrapped by rapidapp.pl which adds handy methods

use Moo::Role;
requires 'config';

use Module::Runtime;


sub _one_off_connect {
  my $self = shift;
  
  my $schema_class = $self->config->{schema_class};
  
  Module::Runtime::require_module($schema_class);
  $schema_class->connect( $self->config->{connect_info} )
}


1;