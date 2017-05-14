package RapidApp::Util::Role::ModelDBIC;

use strict;
use warnings;

# Optional Moo::Role designed to work with Moo-extended Catalyst::Model::DBIC::Schema
# classes like the ones bootstrapped by rapidapp.pl which adds handy methods

use Moo::Role;
requires 'config';

use RapidApp::Util ':all';

use Module::Runtime;
use DBIx::Class::Schema::Loader;
use DBIx::Class::Schema::Diff;
use String::Random;

sub _one_off_connect {
  my $self = shift;
  
  my $schema_class = $self->config->{schema_class};
  
  Module::Runtime::require_module($schema_class);
  $schema_class->connect( $self->config->{connect_info} )
}


# New: utility method will use Schema::Loader on the deployed database and then
# return a diff using Schema::Diff to compare it to the Schema class
sub _diff_deployed_schema {
  my $self = shift;
  
  my $schema_class = $self->config->{schema_class};
  my $ref_class = join('_',$schema_class,'RefSchema',String::Random->new->randregex('[a-z0-9A-Z]{5}'));
  
  DBIx::Class::Schema::Loader::make_schema_at(
    $ref_class => {
      naming => { ALL => 'v7'},
      use_namespaces => 1,
      use_moose => 1,
      debug => 0,
    }, $self->_connect_info_as_arrayref
  );
  
  DBIx::Class::Schema::Diff->new(
    old_schema => $schema_class,
    new_schema => $ref_class
  );
}


sub _connect_info_as_arrayref {
  my $self = shift;
  [
    $self->config->{connect_info}{dsn},
    ($self->config->{connect_info}{user}||''),
    ($self->config->{connect_info}{password}||''),
    $self->config->{connect_info}
  ]
}

sub BUILD {}
after 'BUILD' => sub { (shift)->_create_origin_model_closure };
  
# This injects a
sub _create_origin_model_closure {
my $self = shift;
  my $schema_class = (ref $self->schema) or return undef;
  
  my $accessor = '_ra_catalyst_origin_model';
  
  $self->schema->{$accessor} ||= $self;
  
  unless($schema_class->can($accessor)) {
    my $func = join('::',$schema_class,$accessor);
    eval '*'.$func. ' = sub { (shift)->{'.$accessor.'} }';
  }

}

1;