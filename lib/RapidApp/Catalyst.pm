package RapidApp::Catalyst;

# Built-in plugins required for all RapidApp Applications:
use Catalyst qw(
+RapidApp::Role::CatalystApplication
+RapidApp::CatalystX::SimpleCAS
+RapidApp::CatalystX::AutoAssets
);

use Moose;
extends 'Catalyst';

use RapidApp::AttributeHandlers;



1;