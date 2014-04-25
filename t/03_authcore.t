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

#use TestApp1;

use Test::More;
use RapidApp::Test 'TestApp2';
  
run_common_tests();



done_testing;