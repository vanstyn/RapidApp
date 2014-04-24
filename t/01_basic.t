# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;
use Test::HTML::Content;

use RapidApp::Test 'TestRA::ChinookDemo';

run_common_tests();

ok(
  my $root_cnt = get('/'),
  'Fetch (GET) root document URL "/"'
);

title_ok   ($root_cnt => 'TestRA::ChinookDemo', "root document has expected HTML <title>");

# TODO: do deeper inspection of $root_url_content, follow link tags, etc

my $decoded = (ajax_post_decode(
  '/main/db/nodes',
  [ node => 'root' ],
  "Fetch main navtree nodes"
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

done_testing;


# -- for debugging:
#
#use Data::Dumper::Concise;
#print STDERR "\n\n" . Dumper(
#  $decoded
#) . "\n\n";