# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/var/testapps/TestRA-ChinookDemo/lib";

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Test::More;

ok(
  use_ok('Catalyst::Test', 'TestRA::ChinookDemo'),
  "  * Loaded testapp 'TestRA::ChinookDemo' (via Catalyst::Test)"
);

action_ok(
  '/assets/rapidapp/misc/static/images/rapidapp_powered_logo_tiny.png',
  "Fetched RapidApp logo from the Misc asset controller"
);

action_notfound(
  '/assets/rapidapp/misc/static/some/bad/file.txt',
  "Invalid asset path not found as expected"
);

done_testing;