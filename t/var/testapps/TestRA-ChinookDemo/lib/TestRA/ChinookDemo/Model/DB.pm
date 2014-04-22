package # hide from PAUSE
     TestTestRA::ChinookDemo::Model::DB;
use Moose;
extends 'Catalyst::Model::DBIC::Schema';

use Path::Class qw(file);
use Catalyst::Utils;

my $db = file(Catalyst::Utils::home('TestTestRA::ChinookDemo'),'chinook.db');

__PACKAGE__->config(
    schema_class => 'TestTestRA::ChinookDemo::DB',
    
    connect_info => {
        dsn => 'dbi:SQLite:dbname=' . $db,
        user => '',
        password => '',
        sqlite_unicode => q{1},
        on_connect_call => q{use_foreign_keys},
        quote_names => q{1},
    }
);


1;
