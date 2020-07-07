package # hide from PAUSE
     TestRA::ChinookDemo::Model::DB;

my $test_config= $main::TestRA_ChinookDemo_Model_DB_config;
use Moose;
extends 'Catalyst::Model::DBIC::Schema';
with 'RapidApp::Util::Role::ModelDBIC'
  if $test_config && $test_config->{RapidDbic};

use strict;
use warnings;

__PACKAGE__->config(
  schema_class => 'TestRA::ChinookDemo::DB',

  connect_info => {
    dsn => 'dbi:SQLite::memory:',
    sqlite_unicode => q{1},
    on_connect_call => q{use_foreign_keys},
    quote_names => q{1},
  },

  no_deploy => 0,

  # Test scripts can inject RapidDbic config via environment variable
  ($test_config? %$test_config : ()),
);

sub BUILD {
  my $self = shift;
  
  # We're a test app, so by default we deploy fresh each time:
  $self->schema->deploy unless ($self->config->{no_deploy});
}

1;
