# -*- perl -*-

# This test checks whether
# 1) table monikers are generated in singular (Album, not Albums),
# 2) final '+' in table names is replaced with Plus (albums+ -> AlbumPlus)
# See https://github.com/vanstyn/RapidApp/issues/184

use strict;
use warnings;

use Test::More;
use File::Temp;
use Catalyst::Helper::Model::DBIC::Schema::ForRapidDbic;
use Catalyst::Helper;
use DBIx::Class::Schema;
use RapidApp::Helper;
use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

my $app_class;
BEGIN { $app_class = 'TestMonikerNaming' }

my $tmpdir = File::Temp::tempdir(
    "$app_class-XXXXX",
    DIR      => $ENV{TMPDIR},
    CLEANUP  => 1,
);

# Create a temporary sqlite db

my (undef, $dbfile) = File::Temp::tempfile(
    'XXXXX',
    DIR => $tmpdir,
    SUFFIX => '.db',
    EXLOCK => 0,
    UNLINK => 1,
);

my $dsn = "dbi:SQLite:dbname=$dbfile";

BEGIN {
    eval "package ${app_class}::Model::DB;";
    use Moose;
    extends 'Catalyst::Model::DBIC::Schema';

    __PACKAGE__->config(
        schema_class => "${app_class}::DB",
    
        connect_info => {
            dsn => $dsn,
            sqlite_unicode => q{1},
            on_connect_call => q{use_foreign_keys},
            quote_names => q{1},
        },

        no_deploy => 1
    );
    $INC{"${app_class}/Model/DB.pm"} = __FILE__;
}

my $schema = DBIx::Class::Schema->connect($dsn);

# Create tables using raw SQL to avoid any possible table name
# corrections from DBI/DBIx::Class

my $sql1 = <<'SQL';
CREATE TABLE [Albums]
(
    [AlbumId] INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    [Title] NVARCHAR(160)  NOT NULL
);
SQL
my $sql2 = <<'SQL';
CREATE TABLE [Albums+]
(
    [AlbumId] INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    [Title] NVARCHAR(160)  NOT NULL
);
SQL

$schema->storage->dbh_do(
    sub {
        my (undef, $dbh) = @_;
        $dbh->do($sql1);
        $dbh->do($sql2);
    },
);

$schema->storage->disconnect; # Make sure temporary file will be removed

# Emulate static schema creation by rapidapp.pl by calling
# Catalyst::Helper::Model::DBIC::Schema::_gen_static_schema directly

my $package = 'Catalyst::Helper::Model::DBIC::Schema::ForRapidDbic';
my $schema_class = "${app_class}::DB";

my $helper = RapidApp::Helper->new_with_traits({
    '.newfiles' => 0,
    'makefile'  => 0,
    'scripts'   => 0,
    'traits'    => ['RapidApp::Helper::Traits::RapidDbic'],
    name        => $app_class,
    base => $tmpdir,
    extra_args  => [ '--dsn',
                     "dbi:sqlite:dbname=$dbfile"],
    #bootstrap_cmd => "rapidapp.pl --helpers RapidDbic TestMonikerNaming -- --dsn $dsn",
});

my @args = (
    'create=static',
    'generate_pod=0',
    'preserve_case=1',
    $dsn,
    '',
    '',
    'quote_names=1',
    'sqlite_unicode=1',
    'on_connect_call=use_foreign_keys',
);

my $dbic_helper = $package->new(
    helper => $helper,
    schema_class => $schema_class,
    args => \@args
);
$dbic_helper->_gen_static_schema;

$dbic_helper->schema_class->storage->disconnect; # Make sure temporary file will be removed

# Expected tree:
# t/var/tmp/TestMonikerNaming-XXXXX/lib/TestMonikerNaming/
#   DB
#     Result
#       AlbumsPlus.pm
#       Albums.pm
#   DB.pm

# This module gets loaded in _gen_static_schema
ok(exists $INC{"$app_class/DB.pm"}, "$app_class/DB.pm loaded");
# These modules get loaded in DBIx::Class::Schema::Loader::Base::_reload_class
ok(exists $INC{"$app_class/DB/Result/AlbumsPlus.pm"}, "$app_class/DB/Result/AlbumsPlus.pm loaded");
ok(exists $INC{"$app_class/DB/Result/Albums.pm"}, "$app_class/DB/Result/Albums.pm loaded");

done_testing;
