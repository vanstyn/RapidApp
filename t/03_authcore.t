# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';

use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";
use Path::Class qw(file dir);

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

BEGIN {
  package TestApp2::Model::DB;
  use Moose;
  extends 'TestRA::ChinookDemo::Model::DB';
  $INC{'TestApp2/Model/DB.pm'} = __FILE__;
  1;
}

BEGIN {
  package TestApp2;
  use Moose;

  use RapidApp;
  use Catalyst qw/RapidApp::RapidDbic RapidApp::AuthCore/;

  extends 'Catalyst';

  our $VERSION = '0.01';

  __PACKAGE__->config(
    name => 'TestApp2',

    'Plugin::RapidApp::RapidDbic' => {
      # Only required option:
      dbic_models => ['DB']
    }
  );

  # Let RapidApp::Test call setup() for us so we can get accurate load time:
  #__PACKAGE__->setup();
  
  $INC{'TestApp2.pm'} = __FILE__;
  1;
}


# ----------------
# This is a development option to be able to run this test app
# interactively (i.e. just like the test server script) instead
# of actually running the tests
if($ENV{RA_INTERACTIVE}) {
  use Catalyst::ScriptRunner;
  Catalyst::ScriptRunner->run('TestApp2', 'Server');
  # the above line never returns...
  exit;
}
# ----------------

use Test::More;
use Test::HTML::Content;
use HTTP::Headers::Util qw(split_header_words);

use RapidApp::Test 'TestApp2';
  
run_common_tests();


my $root_cnt = client->browser_get_raw('/');
title_ok (
  $root_cnt => "TestApp2 v$TestApp2::VERSION - Login", 
  "root document has expected HTML <title> (login page)"
);

ok(
  my $login_res = client->post_request('/auth/login',{
    username => 'admin1', password => 'pass'
  }),
  "POST login request with default username/pass "
);

my @cook_vals = split_header_words( $login_res->header('Set-Cookie') );
my ($ses_key,$session) = @{ $cook_vals[0] || [] };

is(
  $ses_key, "testapp2_session",
  "Login succeeded with new session cookie ($session)"
);

ok(
  $login_res->is_redirect && $login_res->header('Location') eq '/',
  "Login redirects to '/'"
);


my $genre_grid = client->ajax_get_raw(
  '/main/db/db_genre',
  "Fetch genre grid"
);

ok(
  $genre_grid =~ qr!/main/db/db_genre/store/read!,
  "Saw expected string within returned genre grid content"
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
  "Read genre_grid store using session cookie"
);


done_testing;

#scream($genre_grid);