package Catalyst::Plugin::RapidApp::RapidDbic;
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

before 'setup_components' => sub {
  my $c = shift;
  
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'} or die
    "No 'Plugin::RapidApp::RapidDbic' config specified!";
  
  die "Plugin::RapidApp::RapidDbic: No dbic_models specified!"
    unless ($config->{dbic_models});
  
  $config->{title} ||= $c->config->{name};  
  $config->{nav_title} ||= 'Loaded DBIC Sources';
  $config->{table_class} ||= 'Catalyst::Plugin::RapidApp::RapidDbic::TableBase';
  $config->{configs} ||= {};
  
  #my $appclass = ref($c) || $c;
  #my %active_models = ();
  #foreach my $model (@{$config->{dbic_models}}) {
  #  my ($schema,$result) = split(/\:\:/,$model,2);
  #  $active_models{$appclass."::Model::".$schema}++;
  #}
  #$config->{_active_models} = \%active_models;
  
  my @navtrees = ({
    module => 'db',
    class => 'RapidApp::AppDbicTree',
    params => {
      dbic_models => $config->{dbic_models},
      table_class	=> $config->{table_class},
      configs => $config->{configs}
    }
  });
  
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
  
  my $main_module_params = {
    title => $config->{nav_title},
    right_footer => $config->{title},
    iconCls => 'icon-catalyst-transparent',
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
  
  $main_module_params->{header_template} = $config->{banner_template}
    if($config->{banner_template});
  
  
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


before 'setup_component' => sub {
  my( $c, $component ) = @_;
  
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'} or die
    "No 'Plugin::RapidApp::RapidDbic' config specified!";
  
  die "Plugin::RapidApp::RapidDbic: No dbic_models specified!"
    unless ($config->{dbic_models});
  
  my $appclass = ref($c) || $c;
  my %active_models = ();
  foreach my $model (@{$config->{dbic_models}}) {
    my ($schema,$result) = split(/\:\:/,$model,2);
    $active_models{$appclass."::Model::".$schema}++;
  }
  return unless ($active_models{$component});
  
  
  # this doesn't seem to work, and why is it here?
  #my $suffix = Catalyst::Utils::class2classsuffix( $component );
  #my $config = $c->config->{ $suffix } || {};
  my $cmp_config = try{$component->config} || {};
  
  my $cnf = { %$cmp_config, %$config };
  
  # Look for the 'schema_class' key, and if found assume this is a
  # DBIC model. This is currently overly broad by design
  my $schema_class = $cnf->{schema_class} or return;
  
  # We have to make sure the TableSpec component has been loaded on
  # each Result class *early*, before 'Catalyst::Model::DBIC::Schema'
  # gets ahold of them. Otherwise problems will happen if we try to
  # load it later:
  my ($model_name) = reverse split(/\:\:/,$component); #<-- educated guess, see temp/hack below
  Module::Runtime::require_module($schema_class);
  
  my $exclude_sources = try{$config->{configs}{$model_name}{exclude_sources}} || [];
  my %excl_sources = map { $_ => 1 } @$exclude_sources;
  
  for my $class (keys %{$schema_class->class_mappings}) {
    my $source_name = $schema_class->class_mappings->{$class};
    
    next if ($excl_sources{$source_name});
    
    my $virtual_columns = try{$config->{configs}{$model_name}{virtual_columns}{$source_name}};
    if ($class->can('TableSpec_cnf')) {
      die "Cannot setup virtual columns on $class - already has TableSpec loaded"
        if ($virtual_columns);
    }
    else {
      $class->load_components('+RapidApp::DBIC::Component::TableSpec');
      $class->add_virtual_columns(%$virtual_columns) if ($virtual_columns);
      $class->apply_TableSpec;
    }

    # ----
    # *predict* (guess) what the auto-generated grid module paths will be and set
    # the open url configs so that cross table links are able to work. this is 
    # just a stop-gap until this functionality is factored into the RapidApp API 
    # officially, somehow...
    my $module_name = lc($model_name . '_' . $class->table);
    my $grid_url = '/main/navtree/' . $module_name;
    $class->TableSpec_set_conf(
      priority_rel_columns => 1,
      open_url_multi => $grid_url,
      open_url => $grid_url."/item",
    );
    # ----
    

    # ---
    # For single-relationship columns (belongs_to) we want to hide
    # the underlying fk_column because the relationship column name
    # handles setting it for us. In typical RapidApps this is done manually,
    # currently...
    if($config->{hide_fk_columns}) {
      my %col_props = ( $class->TableSpec_get_conf('column_properties') || () );
      for my $rel ( $class->relationships ) {
        my $rel_info = $class->relationship_info($rel);
        next unless ($rel_info->{attrs}->{accessor} eq 'single');
        my $fk_columns = $rel_info->{attrs}->{fk_columns} || {};
        $col_props{$_} =
          # hides the column in the interface:
          { no_column => \1, no_multifilter => \1, no_quick_search => \1 }
          # exclude columns with the same name as the rel (see priority_rel_columns setting)
          for (grep { $_ ne $rel } keys %$fk_columns);
      }
      $class->TableSpec_set_conf( column_properties => %col_props )
        if (keys %col_props > 0);
    }
    # ---

    # --- apply TableSpec configs specified in the plugin config:
    
    my $TSconfig = try{$config->{configs}->{$model_name}->{TableSpecs}->{$source_name}} || {};
    $class->TableSpec_set_conf( $_ => $TSconfig->{$_} ) for (keys %$TSconfig);
    # ---
    
    # If there are more than 3 columns, set the editor to the full-blown (combo) grid
    # instead of simple dropdown:
    my @cols = $class->columns;
    if(scalar(@cols) > 3) {
      $class->TableSpec_set_conf(
        auto_editor_type => 'custom',
        auto_editor_params => {
          xtype => 'datastore-app-field',
          displayField => $class->TableSpec_get_conf('display_column'),
          autoLoad => {
            url => $class->TableSpec_get_conf('open_url_multi'),
            params => {}
          }
        }
      );
    }
    
  }
};


1;


