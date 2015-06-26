# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;
use Test::HTML::Content;

# ----------------
# This is a development option to be able to run this test app
# interactively (i.e. just like the test server script) instead
# of actually running the tests
if($ENV{RA_INTERACTIVE}) {
  use Catalyst::ScriptRunner;
  Catalyst::ScriptRunner->run('TestRA::ChinookDemo', 'Server');
  # the above line never returns...
  exit;
}
# ----------------

use RapidApp::Test 'TestRA::ChinookDemo';

run_common_tests();


my $root_cnt = client->browser_get_raw('/');
title_ok   ($root_cnt => 'TestRA::ChinookDemo', "root document has expected HTML <title>");

# TODO: do deeper inspection of $root_url_content, follow link tags, etc

my $decoded = (client->ajax_post_decode(
  '/main/db/nodes',
  [ node => 'root' ]
) || [])->[0] || {};

my $child_nodes = $decoded->{children} || [];
my @node_ids = map {
  ref $_ && ref $_ eq 'HASH' ? $_->{id} : ()
} @$child_nodes;

is_deeply(
  \@node_ids,
  [
    "db_album",
    "db_artist",
    "db_customer",
    "db_employee",
    "db_genre",
    "db_invoice",
    "db_invoiceline",
    "db_mediatype",
    "db_playlist",
    "db_playlisttrack",
    "db_track"
  ],
  "Got expected nodes from the main navtree"
);

# TODO: we're not doing any real content testing here because the 
# returned content is *JavaScript* - not valid JSON - and we
# don't have a decoder for it yet. It is almost JSON, but
# contains raw function() definitions that JSON::PP can't
# handle. So, we're just making sure
my $genre_grid = client->ajax_get_raw('/main/db/db_genre');

ok(
  $genre_grid =~ qr!/main/db/db_genre/store/read!,
  "Saw expected string within returned genre grid content [". client->last_request_elapsed . ']'
);

# This simulates what a DataStore read currently looks like:
my $genre_read = client->ajax_post_decode(
  '/main/db/db_genre/store/read', [
             columns => '["genreid","name","tracks"]',
             fields  => '["genreid","name"]',
             limit   => '25',
             query   => '',
    quicksearch_mode => 'like',
             start   => '0'
  ]
);

# We need to clear this because its value can vary:
$genre_read->{query_time} and $genre_read->{query_time} = undef;

# Delete for now because of blessed object response:
$genre_read->{success} and delete $genre_read->{success};

is_deeply(
  $genre_read,
  {
    metaData => {
      fields => [
        {
          name => "genreid"
        },
        {
          name => "name"
        },
        {
          name => "tracks"
        },
        {
          name => "loadContentCnf"
        },
        {
          name => "___record_pk"
        }
      ],
      idProperty => "___record_pk",
      loaded_columns => [
        "genreid",
        "name",
        "tracks",
        "loadContentCnf",
        "___record_pk"
      ],
      messageProperty => "msg",
      root => "rows",
      successProperty => "success",
      totalProperty => "results"
    },
    query_time => undef,
    results => 0,
    rows => [],
    #success => bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' )
  },
  "Got expected genre_grid store read data (empty)"
);

my $foo_get = client->browser_get_raw('/foo');
is(
  $foo_get => "This is user-defined :Path controller action '/foo'",
  "Got expected content from locally-defined :Path controller action"
);

done_testing;

# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  $genre_read
#) . "\n\n";