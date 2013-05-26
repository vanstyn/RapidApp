package Catalyst::Plugin::RapidApp::RequestLogger;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

# Plugin logs all requests to CoreSchema

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;


after 'setup_components' => sub {
  my $c = shift;
  
  # This same model/schema is used by AuthCore:
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));
  
};

before 'dispatch' => sub {
  my $c = shift;
  $c->model('RapidApp::CoreSchema::Request')->record_Request($c);
  1;
};

1;


