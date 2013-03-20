package Catalyst::Plugin::RapidApp::RapidDbic;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;


before 'setup_components' => sub {
  my $c = shift;
  
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'} or die
    "No 'Plugin::RapidApp::RapidDbic' config specified!";
  
  die "Plugin::RapidApp::RapidDbic: No dbic_models specified!"
    unless ($config->{dbic_models});
  
  $config->{title} ||= $c->config->{name};  
  $config->{nav_title} ||= 'Loaded DBIC Sources';
  $config->{table_class} ||= 'Catalyst::Plugin::RapidApp::RapidDbic::TableBase';
  
  # Apply base/default configs to 'Model::RapidApp':
  $c->config( 'Model::RapidApp' => 
    Catalyst::Utils::merge_hashes({
      rootModuleClass => 'RapidApp::RootModule',
      rootModuleConfig => {
        app_title => $config->{title},
        main_module_class => 'RapidApp::AppExplorer',
        main_module_params => {
          title => $config->{nav_title},
          right_footer => $config->{title},
          iconCls => 'icon-server_database',
          navtree_class => 'RapidApp::AppDbicTree',
          navtree_params => {
            dbic_models => $config->{dbic_models},
            table_class	=> $config->{table_class}
          }
        }
      }
    }, $c->config->{'Model::RapidApp'} || {} )
  );
  
};


before 'setup_component' => sub {
  my( $c, $component ) = @_;
  
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
  
  my $suffix = Catalyst::Utils::class2classsuffix( $component );
  my $config = $c->config->{ $suffix } || {};
  my $cmp_config = try{$component->config} || {};
  
  my $cnf = { %$cmp_config, %$config };
  
  # Look for the 'schema_class' key, and if found assume this is a
  # DBIC model. This is currently overly broad by design
  my $schema_class = $cnf->{schema_class} or return;
  
  # We have to make sure the TableSpec component has been loaded on
  # each Result class *early*, before 'Catalyst::Model::DBIC::Schema'
  # gets ahold of them. Otherwise problems will happen if we try to
  # load it later:
  Module::Runtime::require_module($schema_class);
  for my $class (keys %{$schema_class->class_mappings}) {
    next if ($class->can('TableSpec_cnf'));
    $class->load_components('+RapidApp::DBIC::Component::TableSpec');
    $class->apply_TableSpec;
  }

};


1;


