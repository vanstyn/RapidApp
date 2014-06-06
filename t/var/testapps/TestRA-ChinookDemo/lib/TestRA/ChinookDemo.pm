package # hide from PAUSE
     TestRA::ChinookDemo;
use Moose;
use namespace::autoclean;

use strict;
use warnings;

use RapidApp::Test::EnvUtil;
BEGIN { $ENV{TMPDIR} or RapidApp::Test::EnvUtil::set_tmpdir_env() }

use Catalyst::Runtime 5.80;

use RapidApp;
use Catalyst qw/RapidApp::RapidDbic/;

extends 'Catalyst';

our $VERSION = '0.01';

# This is the smallest valid RapidDbic app config:
__PACKAGE__->config(
  name => 'TestRA::ChinookDemo',
  'Plugin::RapidApp::RapidDbic' => {
    dbic_models => ['DB']
  }
);

# Start the application
__PACKAGE__->setup();


1;
