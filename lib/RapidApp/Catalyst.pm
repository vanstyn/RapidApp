package RapidApp::Catalyst;

# Built-in plugins required for all RapidApp Applications:
use Catalyst qw(
	+RapidApp::Role::CatalystApplication
	+RapidApp::CatalystX::SimpleCAS	
);

use base 'Catalyst';

use RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);


1;