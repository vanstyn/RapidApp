package RapidApp::Role::CatalystApplication;

use strict;
use warnings;
use Moose::Role;

use CatalystX::InjectComponent;

after 'setup_components' => sub {
	my $class= shift;
	
	CatalystX::InjectComponent->inject( into => $class, component => 'RapidApp::Controller::DefaultRoot', as => 'RapidApp::Root' );
	CatalystX::InjectComponent->inject( into => $class, component => 'RapidApp::View::TT', as => 'RapidApp::TT' );
	CatalystX::InjectComponent->inject( into => $class, component => 'RapidApp::View::JSON', as => 'RapidApp::JSON' );
};

1;