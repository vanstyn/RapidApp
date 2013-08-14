package Catalyst::Plugin::RapidApp::TabGui;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;

sub _navcore_enabled { 
  my $c = shift;
  return (
    $c->does('Catalyst::Plugin::RapidApp::NavCore') ||
    $c->registered_plugins('RapidApp::NavCore') #<-- this one doesn't seem to apply
  ) ? 1 : 0;
}

sub _authcore_enabled { 
  my $c = shift;
  return (
    $c->does('Catalyst::Plugin::RapidApp::AuthCore') ||
    $c->registered_plugins('RapidApp::NavCore') #<-- this one doesn't seem to apply
  ) ? 1 : 0;
}

before 'setup_components' => sub {
  my $c = shift;
  
  my $config = $c->config->{'Plugin::RapidApp::TabGui'} or die
    "No 'Plugin::RapidApp::TabGui' config specified!";
  
  $config->{title} ||= $c->config->{name};  
  $config->{nav_title} ||= $config->{title};
  
  # --- We're aware of the AuthCore plugin, and if it is running we automatically 
  # set a banner with a logout link if no banner is specified:
  if($c->_authcore_enabled) {
    $config->{banner_template} ||= 'templates/rapidapp/simple_auth_banner.tt';
  }
  # ---
  
  my @navtrees = ();
  
  if($config->{template_navtree_regex}) {
   push @navtrees, ({
      module => 'tpl_navtree',
      class => 'RapidApp::AppTemplateTree',
      params => {
        template_regex => $config->{template_navtree_regex}
      }
    });
  }
  
  # New: add custom navtrees by config:
  push @navtrees, @{$config->{navtrees}} if (exists $config->{navtrees});
  
  # --- We're also aware of the NavCore plugin. If it is running we stick its items
  # at the **top** of the navigation tree:
  unshift @navtrees, (
    {
      module => 'navtree',
      class => 'Catalyst::Plugin::RapidApp::NavCore::NavTree',
      params => {
        title => 'Foo'
      }
    },
    { xtype => 'spacer', height => '5px' } 
  ) if ($c->_navcore_enabled);
  # ---
  
  my $main_module_params = {
    title => $config->{nav_title},
    right_footer => $config->{title},
    iconCls => 'ra-icon-catalyst-transparent',
    navtrees => \@navtrees
  };
  
  if($config->{dashboard_template}) {
    $main_module_params->{dashboard_class} = 'RapidApp::AppHtml';
    $main_module_params->{dashboard_params} = {
      get_html => sub {
        my $self = shift;
        my $vars = { c => $self->c };
        return $self->c->template_render($config->{dashboard_template},$vars);
      }
    };
  }
  
  # remap banner_template -> header_template
  $main_module_params->{header_template} = $config->{banner_template}
    if($config->{banner_template});
  
  my @copy_params = qw(
    dashboard_url
    navtree_footer_template
    navtree_load_collapsed
    navtree_disabled
  );
  $config->{$_} and $main_module_params->{$_} = $config->{$_} for (@copy_params);
  
  my $cnf = {
    rootModuleClass => 'RapidApp::RootModule',
    rootModuleConfig => {
      app_title => $config->{title},
      main_module_class => 'RapidApp::AppExplorer',
      main_module_params => $main_module_params
    }
  };
    
  # Apply base/default configs to 'Model::RapidApp':
  $c->config( 'Model::RapidApp' => 
    Catalyst::Utils::merge_hashes($cnf, $c->config->{'Model::RapidApp'} || {} )
  );
};

1;


