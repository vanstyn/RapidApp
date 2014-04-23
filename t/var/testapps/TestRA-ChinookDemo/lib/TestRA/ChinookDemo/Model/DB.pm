package # hide from PAUSE
     TestRA::ChinookDemo::Model::DB;

use Moose;
extends 'Catalyst::Model::DBIC::Schema';

use Path::Class qw(file);
use Catalyst::Utils;

my $db = file(Catalyst::Utils::home('TestRA::ChinookDemo'),'chinook.db');
die "test database '$db' already exists" if (-f $db);

__PACKAGE__->config(
    schema_class => 'TestRA::ChinookDemo::DB',
    
    connect_info => {
        dsn => 'dbi:SQLite:dbname=' . $db,
        user => '',
        password => '',
        sqlite_unicode => q{1},
        on_connect_call => q{use_foreign_keys},
        quote_names => q{1},
    }
);

sub BUILD {
  my $self = shift;
  
  # We're a test app, so we always deploy fresh each time:
  $self->schema->deploy;
}

1;
