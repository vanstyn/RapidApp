package Catalyst::Plugin::RapidApp::RapidDbic;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::TabGui';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;


before 'setup_components' => sub {
  my $c = shift;
  
  $c->config->{'Plugin::RapidApp::RapidDbic'} ||= {};
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
  $config->{dbic_models} ||= [];
  
  $config->{dbic_tree_module_name} = 'db';
  $config->{table_class} ||= 'Catalyst::Plugin::RapidApp::RapidDbic::TableBase';
  $config->{navcore_default_views} //= 1;
  $config->{configs} ||= {};
  
  $c->config->{'Plugin::RapidApp::TabGui'} ||= {};
  my $tgui_cnf = $c->config->{'Plugin::RapidApp::TabGui'};
  $tgui_cnf->{navtrees} ||= [];
  
  push @{$tgui_cnf->{navtrees}}, {
    module => $config->{dbic_tree_module_name},
    class => 'RapidApp::AppDbicTree',
    params => {
      dbic_models => $config->{dbic_models},
      table_class	=> $config->{table_class},
      configs => $config->{configs},
      # optional 'menu_require_role' will hide the *menu points*
      # of each dbic model from the navtree, but access to the
      # actual grids will still be allowed (i.e. via saved search)
      menu_require_role => $config->{menu_require_role}
    }
  };
};

# Validate we got a valid RapidDbic config by the end of setup_components or die:
after 'setup_components' => sub {
  my $c = shift;
  
  my $cfg = $c->config->{'Plugin::RapidApp::RapidDbic'};
  die "No 'Plugin::RapidApp::RapidDbic' config specified!" unless (
    $cfg && ref($cfg) eq 'HASH' && scalar(keys %$cfg) > 0
  );
  
  my $mdls = $cfg->{dbic_models};
  die "Plugin::RapidApp::RapidDbic: No dbic_models specified!" unless (
    $mdls && ref($mdls) eq 'ARRAY' && scalar(@$mdls) > 0
  );
};

before 'setup_component' => sub {
  my( $c, $component ) = @_;
  
  my $appclass = ref($c) || $c;
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
  
  # -- New: read in optional RapidDbic config from the model itself:
  my $local_cnf = try{$component->config->{RapidDbic}};
  if($local_cnf) {
    my ($junk,$name) = split(join('::',$appclass,'Model',''),$component,2);
    if($name) {
      $config->{dbic_models} ||= [];
      push @{$config->{dbic_models}}, $name unless (
        List::Util::first {$_ eq $name} @{$config->{dbic_models}}
      );
      # a config for this model specified in the main app config still takes priority:
      $config->{configs}{$name} ||= $local_cnf;
    }
  }
  $local_cnf ||= {};
  # --
  
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
  
  # Base RapidApp module path:
  my $mod_path = join('/','',$c->module_root_namespace,'main');
  $mod_path =~ s/\/+/\//g; #<-- strip double //
  
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
    my $grid_url = join('/',$mod_path,$config->{dbic_tree_module_name},$module_name);
    $class->TableSpec_set_conf(
      priority_rel_columns => 1,
      open_url_multi => $grid_url,
      open_url => join('/',$grid_url,"item"),
    );
    # ----
    
    # Nicer defaults:
    $class->TableSpec_set_conf(
    	title => ($class->TableSpec_get_set_conf('title') || $source_name),
      title_multi => ($class->TableSpec_get_set_conf('title_multi') || "$source_name Rows"),
      iconCls => ($class->TableSpec_get_set_conf('iconCls') || 'ra-icon-pg'),
      multiIconCls => ($class->TableSpec_get_set_conf('multiIconCls') || 'ra-icon-pg-multi'),
    );
    
    # ----------------
    # Apply some column-specific defaults:

    # Set actual column headers (this is not required but real headers are displayed nicer):
    my %col_props = %{ $class->TableSpec_get_conf('column_properties') || {} };
    for my $col ($class->columns,$class->relationships) {
      $col_props{$col}{header} ||= $col;
    }
    
    # For single-relationship columns (belongs_to) we want to hide
    # the underlying fk_column because the relationship column name
    # handles setting it for us. In typical RapidApps this is done manually,
    # currently... Check for the config option globally or individually:
    if($local_cnf->{hide_fk_columns} || $config->{hide_fk_columns}) {
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
    }
    
    $class->TableSpec_set_conf( column_properties => %col_props ) 
      if (keys %col_props > 0);
    # ----------------
    

    # --- apply TableSpec configs specified in the plugin config:
    my $TSconfig = try{$config->{configs}->{$model_name}->{TableSpecs}->{$source_name}} || {};
    $class->TableSpec_set_conf( $_ => $TSconfig->{$_} ) for (keys %$TSconfig);
    # ---
    
    # Set the editor to use the grid unless auto_editor_type is already defined
    unless($class->TableSpec_get_conf('auto_editor_type')) {
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

after 'setup_finalize' => sub {
  my $c = shift;
  
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'} or die
    "No 'Plugin::RapidApp::RapidDbic' config specified!";
  
  # If enabled and available, initialize all rows for Default Model/Source views:
  if($config->{navcore_default_views} && $c->_navcore_enabled) {
    my $rootModule = $c->model('RapidApp')->rootModule;
    
    my $AppTree = $rootModule->Module('main')->Module($config->{dbic_tree_module_name});
    my @source_models = $AppTree->all_source_models;
    my $Rs = $c->model('RapidApp::CoreSchema::DefaultView');
    $Rs->find_or_create(
      { source_model => $_ },
      { key => 'primary' }
    ) for (@source_models);
  }
};


1;


