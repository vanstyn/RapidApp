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

ok(
  my $root_cnt = get('/'),
  'Fetch (GET) root document URL "/"'
);

title_ok (
  $root_cnt => "TestApp2 v$TestApp2::VERSION - Login", 
  "root document has expected HTML <title> (login page)"
);

ok(
  my $login_res = post_request('/auth/login',{
    username => 'admin', password => 'pass'
  }),
  "POST login request with default username/pass"
);

my @cook_vals = split_header_words( $login_res->header('Set-Cookie') );
my ($ses_key,$session) = @{ $cook_vals[0] || [] };

is(
  $ses_key, "testapp2_session",
  "Login succeeded with new session cookie ($session)"
);


done_testing;