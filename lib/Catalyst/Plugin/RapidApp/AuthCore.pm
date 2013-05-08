package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;


after 'setup_components' => sub {
  my $c = shift;
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));
};



1;


