# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;

BEGIN {
  use RapidApp::DBIC::Component::TableSpec;
  use TestRA::ChinookDemo::DB;
  my $pkg = 'TestRA::ChinookDemo::DB::Result::Artist';

  $pkg->load_components('+RapidApp::DBIC::Component::TableSpec');

  $pkg->add_virtual_columns(
    some_cool_virtual_column => {
      data_type => "varchar",
      sql => 'SELECT "fooo"',
    }
  );

  $pkg->apply_TableSpec;
}


use RapidApp::Test 'TestRA::ChinookDemo';

ok(
  my $aRs = TestRA::ChinookDemo->model('DB::Artist'),
  'Get Artist ResultSet via model accessor'
);

ok( 
  my $NewArtist = $aRs->create({
    name => 'Banjo People' 
  }),
  "Insert a test row (Artist table)"
);

is_deeply(
  { $NewArtist->get_columns },
  {
    artistid => 1,
    name => "Banjo People",
    some_cool_virtual_column => "fooo"
  },
  "Saw expected virtual column in ->get_columns"
);

ok(
  $NewArtist->can('some_cool_virtual_column'),
  "Virtual column accessor exists"
);

is(
  $NewArtist->some_cool_virtual_column => "fooo",
  "Virtual column returned expected value via accessor"
);

is(
  $NewArtist->get_column('some_cool_virtual_column') => "fooo",
  "Virtual column returned expected value via get_column"
);

ok(
  my $albRs = TestRA::ChinookDemo->model('DB::Album'),
  'Get Album ResultSet via model accessor'
);

ok(
  my $NewAlbum = $albRs->create({
    title => "Banjo 3000",
    artistid => 1
  }),
  "Create new Album with artistid value"
);


# -----
# This test is known to fail on DBIx::Class 0.082899_15 (dev release)
#  bisect shows the first breaking commit:
#  https://github.com/dbsrgits/dbix-class/commit/786c1cddede6675b9fc5fc46ae4e1e136ef2c392
ok(
  my $NewAlbum = $albRs->create({
    title => "Death Metal Banjo Skullcrush",
    artistid => $NewArtist
  }),
  "Create new Album with artist Row object"
);
# The failure/error output on these dbic versions is:
#
#    DBIx::Class::ResultSource::resolve_relationship_condition(): The key 'some_cool_virtual_column' 
#    supplied as part of 'foreign_values' during relationship resolution is not a column on related 
#    source 'Artist' at t/04_virtual_columns.t line 88
#
# -----

done_testing;

