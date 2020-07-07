# -*- perl -*-

=head1 DESCRIPTION

This test case verifies the ability to override pieces of quicksearch.
There isn't an official API for this yet, but there is at least one
project out there using this method, which will need updated if the
internals of quicksearch ever change.

This example overrides chain_Rs_req_quicksearch to make a change to the
returned resultset.  (doesn't matter what, just that the code ran when
overriding that method)

Then it also overrides _resolve_quicksearch_condition to make one
per-column change to the way that the search expression is generated.
This couldn't be done in chain_Rs_req_quicksearch because all the
columns together get applied in one single { -or => [] } clause.
(subclassing chain_Rs_req_quicksearch would be sufficient if there were
 an official API to reach back into the ResultSet clauses and inspect
 and modify them)

=cut

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;

BEGIN {
  # This class is a RapidApp::Module that performs the overriding we want to test.
  package TestRA::Grid1;
  use Moose;
  extends 'Catalyst::Plugin::RapidApp::RapidDbic::TableBase';
  
  sub chain_Rs_req_quicksearch {
    my ($self, $rs, $params)= @_;
    return $self->next::method($rs, $params)
      ->search(undef, { '+columns' => { test => \'-1' } });
  }

  sub _resolve_quicksearch_condition {
    my ($self, $field, $query, $opt) = @_;
    if ($field eq 'name') {
      return { $field => { like => $query.'%' } };
    } else {
      return $self->next::method($field, $query, $opt);
    }
  }

  $main::TestRA_ChinookDemo_Model_DB_config= {
    RapidDbic => {
      grid_params => {
        Artist => {
          grid_class => 'TestRA::Grid1',
        }
      }
    }
  };
}

use RapidApp::Test 'TestRA::ChinookDemo';
my $db= TestRA::ChinookDemo->model('DB')->schema;

# Add some test data to the Artist table.
$db->resultset('Artist')->create($_) for
  { artistid => 1, name => 'none' },
  { artistid => 2, name => 'foobar' },
  { artistid => 3, name => 'barfoo' };

my $decoded = client->ajax_post_decode(
  '/main/db/db_artist/store/read',
  [
    columns   => '["artistid","name"]',
    qs_fields => '["name"]',
    qs_query  => 'foo',
    quicksearch_mode => 'like',
  ]
);

# Two records would normally match a search for "foo", but the custom Grid
# changed it so that searches on 'name' only look for a prefix, not suffix.
is( $decoded->{results}, 1, 'returned only 1 row' );

# Verify which record it returned.
is( $decoded->{rows}[0]{artistid}, 2, 'returned row having foo prefix' );

# Verify that the extra change to the resultset made by the Grid takes effect.
is( $decoded->{rows}[0]{test}, -1, 'custom RS change was applied' );

done_testing;

