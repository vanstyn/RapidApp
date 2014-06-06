package Catalyst::Plugin::RapidApp;
use Moose::Role;
use namespace::autoclean;

use RapidApp;

# Built-in plugins required for all RapidApp Applications:
with qw(
 RapidApp::Role::CatalystApplication
 RapidApp::CatalystX::SimpleCAS
 RapidApp::Role::AssetControllers
);

use RapidApp::AttributeHandlers;

1;


