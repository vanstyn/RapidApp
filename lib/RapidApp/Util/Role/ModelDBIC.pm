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
  
  my ($schema_class,$dsn,$user,$pass) = (
    $self->config->{schema_class}, 
    $self->config->{connect_info}{dsn},
    $self->config->{connect_info}{user}, 
    $self->config->{connect_info}{password}
  );
  
  Module::Runtime::require_module($schema_class);
  $schema_class->connect($dsn,$user,$pass)
}


1;