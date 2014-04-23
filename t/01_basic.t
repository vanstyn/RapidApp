# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;
use Catalyst::Test 'TestRA::ChinookDemo';

action_ok(
  '/assets/rapidapp/misc/static/images/rapidapp_powered_logo_tiny.png',
  "Fetched RapidApp logo from the Misc asset controller"
);

action_notfound(
  '/assets/rapidapp/misc/static/some/bad/file.txt',
  "Bad asset path not found"
);

done_testing;