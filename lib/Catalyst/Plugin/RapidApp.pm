package Catalyst::Plugin::RapidApp;
use Moose::Role;
use namespace::autoclean;

# Built-in plugins required for all RapidApp Applications:
with qw(
 RapidApp::Role::CatalystApplication
 RapidApp::CatalystX::SimpleCAS
 RapidApp::CatalystX::AutoAssets
);

use RapidApp::AttributeHandlers;

1;


