package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;


before 'setup_components' => sub {
  my $c = shift;
  
  #my $config = $c->config->{'Plugin::RapidApp::AuthCore'} or die
  #  "No 'Plugin::RapidApp::AuthCore' config specified!";
  #
  #die "Plugin::RapidApp::AuthCore: No schema_class specified!"
  #  unless ($config->{schema_class});
  #  

  
  my $cnf = {
    db_file => 'core_schema.db'
  };
  
   $c->config( 'Model::RapidApp::CoreSchema' => 
    Catalyst::Utils::merge_hashes($cnf, $c->config->{'Model::RapidApp::CoreSchema'} || {} )
  );
  
 
};


after 'setup_components' => sub {
  my $c = shift;
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));
};



1;


