package Catalyst::Plugin::RapidApp::RapidDbic;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::TabGui';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use List::Util;


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

  # Quick hack: move RapidApp::CoreSchema to the end of the list, if present
  # (this was needed after adding the local model config feature)
  #@$mdls = ((grep { $_ ne 'RapidApp::CoreSchema' } @$mdls), 'RapidApp::CoreSchema') if (
  #  List::Util::first { $_ eq 'RapidApp::CoreSchema' } @$mdls
  #);
};

before 'setup_component' => sub {
  my( $c, $component ) = @_;
  
  my $appclass = ref($c) || $c;
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
  
  my $loc_cmp_name = $component;
  $loc_cmp_name =~ s/^${appclass}\:\://;

  # -- New: read in optional RapidDbic config from the model itself, or from the main 
  #    app config under the model's config key (i.e. "Model::DB")
  my $local_cnf = scalar(
        try{ $component->config          ->{RapidDbic}  }
     || try{ $c->config->{$loc_cmp_name} ->{RapidDbic}  }
  );

  if($local_cnf) {
    my ($junk,$name) = split(join('::',$appclass,'Model',''),$component,2);
    if($name) {
      $config->{dbic_models} ||= [];
      push @{$config->{dbic_models}}, $name unless (
        List::Util::first {$_ eq $name} @{$config->{dbic_models}}
      );
      # a config for this model specified in the main app config still takes priority:
      $config->{configs}{$name} ||= $local_cnf;
      $local_cnf = $config->{configs}{$name};
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
  
  my $lim_sources = $local_cnf->{limit_sources} ? {map{$_=>1} @{$local_cnf->{limit_sources}}} : undef;
  my $exclude_sources = $local_cnf->{exclude_sources} || [];
  my %excl_sources = map { $_ => 1 } @$exclude_sources;
  
  # Base RapidApp module path:
  my $mod_path = join('/','',$c->module_root_namespace,'main');
  $mod_path =~ s/\/+/\//g; #<-- strip double //
  
  for my $class (keys %{$schema_class->class_mappings}) {
    my $source_name = $schema_class->class_mappings->{$class};
    
    next if ($lim_sources && ! $lim_sources->{$source_name});
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
    
    my $module_name = lc($model_name . '_' . $source_name);
    my $grid_url = join('/',$mod_path,$config->{dbic_tree_module_name},$module_name);
    $class->TableSpec_set_conf(
      priority_rel_columns => 1,
      open_url_multi => $grid_url,
      open_url => join('/',$grid_url,"item"),
    );
    # ----
    
    my $is_virtual = $class->_is_virtual_source;
    my $defs_i = $is_virtual ? 'ra-icon-pg-red' : 'ra-icon-pg';
    my $defm_i = $is_virtual ? 'ra-icon-pg-multi-red' : 'ra-icon-pg-multi';
    
    # Nicer defaults:
    $class->TableSpec_set_conf(
    	title => ($class->TableSpec_get_set_conf('title') || $source_name),
      title_multi => ($class->TableSpec_get_set_conf('title_multi') || "$source_name Rows"),
      iconCls => ($class->TableSpec_get_set_conf('iconCls') || $defs_i),
      multiIconCls => ($class->TableSpec_get_set_conf('multiIconCls') || $defm_i),
    );
    
    # ----------------
    # Apply some column-specific defaults:

    # Set actual column headers (this is not required but real headers are displayed nicer):
    my %col_props = %{ $class->TableSpec_get_set_conf('column_properties') || {} };
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
    
    # Set the editor to use the existing grid unless auto_editor_type is already defined 
    # *in the RapidDbic plugin config itself*. This is needed to fix a load-order problem
    # in which the TableSpec auto_editor_type could have been already set automatically to
    # 'combo' (this is why we're not checking the actual TableSpec config itself). For the
    # purposes of RapidDbic, we are taking over and superseding that layer of auto-generated 
    # configs already in action for TableSpecs. Also, if the auto_editor_type is set to
    # 'grid', replace it with the custom existing grid, too:  
    if(!$TSconfig->{auto_editor_type} || $TSconfig->{auto_editor_type} eq 'grid') {
      $class->TableSpec_set_conf(
        auto_editor_type => 'custom',
        auto_editor_params => {
          xtype => 'datastore-app-field',
          displayField => $class->TableSpec_get_set_conf('display_column'),
          autoLoad => {
            url => $class->TableSpec_get_set_conf('open_url_multi'),
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

__END__

=head1 NAME

Catalyst::Plugin::RapidApp::RapidDbic - Instant web front-ends for DBIx::Class

=head1 QUICK START

To get started very quickly with a new app, see the RapidDbic helper for bootstrapping a new app
in the manual:

=over

=item *

L<RapidApp::Manual::Bootstrap>

=back

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp::RapidDbic /;

Then, also in the main Catalyst app class:

 __PACKAGE__->config(
 
    'Plugin::RapidApp::RapidDbic' => {
      dbic_models => ['DB','OtherModel'],
      
      # All custom configs optional...
      configs => {
        DB => {
          grid_params => {
            # ...
          },
          TableSpecs => {
            # ...
          }
        },
        OtherModel => {
          # ...
        }
      }
    }
 );

Or, within individual DBIC::Schema model class(es):

 package MyApp::Model::DB;
 use Moo;
 extends 'Catalyst::Model::DBIC::Schema';

 __PACKAGE__->config(
    schema_class => 'MyApp::DB',
 
    connect_info => {
       # ...
    },
 
    RapidDbic => {
 
      # All custom configs optional...
      grid_params => {
        # to make all grids editable:
        '*defaults' => {
          updatable_colspec   => ['*'],
          creatable_colspec   => ['*'],
          destroyable_relspec => ['*'],
          # ...
        },
        MySourceA => {
          persist_immediately => {
             # Save only when clicking "Save" button...
             create  => 0, update  => 0, destroy => 0
          },
          # ...
        }
      },
      TableSpecs => {
        MySourceA => {
          title          => 'My Source Abba!',
          title_multi    => 'Abbas',
          iconCls        => 'icon-apple',
          multiIconCls   => 'icon-apples',
          # ...
        },
        SourceB => {
          display_column => 'foo',
          columns => {
            foo => { 
              title => 'Foo',
              # ...
            }
          }
        }
      },
      table_class => 'MyApp::Module::CustGridModule',
      virtual_columns => {
        # ...
      }
    }

=head1 DESCRIPTION

The RapidDbic plugin provides a very high-level, abstract configuration layer for initializing 
a structure of interfaces for accessing L<DBIC::Schema|Catalyst::Model::DBIC::Schema> models 
for Catalyst/RapidApp. These interfaces are fully functional out-of-the-box, but also provide
a robust base which can be configured and extended into various forms of custom applications.

RapidDbic itself simply assembles and configures other RapidApp plugins and modules into a useful,
working combination without any fuss, while also providing configuration hooks into those sub-modules
across different layers. This includes the L<TabGui|Catalyst::Plugin::RapidApp::TabGui> plugin for
the main interface and navigation structure, and sets of DBIC-aware modules such as grids, forms and
trees.

This hooks into a very broad ecosystem of highly customizable and extendable modules which are 
still in the process of being fully documented... The unconfigured, default state resembles a 
database admin utility, with powerful CRUD features, query builder, batch modify forms, and so on.

RapidDbic is also designed to work with other, high-level plugins to access additional turn-key
application-wide functionality, such as access and authorization with the 
L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> plugin and saved user-views with the
L<NavCore|Catalyst::Plugin::RapidApp::NavCore> plugin.

=head1 CONFIG

The only required config option is specifying at least one L<DBIC::Schema|Catalyst::Model::DBIC::Schema> 
model to enable. This can be achieved either with the C<dbic_models> option in the plugin config key
C<'Plugin::RapidApp::RapidDbic'> within the main Catalyst app class/config, or by specifying a C<'RapidDbic'>
config key in the model class(es) itself (see SYNOPSIS).

The optional additional config options for each model are then divided into two main sections, 
C<grid_params> and C<TableSpecs>, which are each further divided into each source name in the
DBIC schema.

=head2 grid_params

The grid_params section allows overriding the parameters to be supplied to the RapidApp module 
which is automatically built for each source (with a menu point for each in the navtree). By default,
this is the grid-based module L<Catalyst::Plugin::RapidApp::RapidDbic::TableBase>, but can be changed
(with the C<table_class> config option) to any module extending a DBIC-aware RapidApp module (which
are any of the modules based on the "DbicLink" ecosystem) which doesn't even necesarily need to 
be derived from a grid module at all...

For convenience, the special source name C<'*defaults'> can be used to set params for all sources
at once.

The DbicLink modules configuration documentation is still in-progress. 

=head2 TableSpecs

TableSpecs are extra schema metadata which can optionally be associated with each source/columns.
These provide extra "hints" for how to represent the schema entities in different application
interface contexts. TableSpec data is passive and is consumed by all DBIC-aware RapidApp Modules
for building their default configuration(s).

For a listing of the different TableSpec data-points which are available, see the TableSpec 
documentation in the manual:

=over

=item *

L<RapidApp::Manual::TableSpec>

=back

=head2 table_class

Specify a different RapidApp module class name to use for the source. The default is 
C<Catalyst::Plugin::RapidApp::RapidDbic::TableBase>. The C<grid_params> for each source
are supplied to the constructor of this class to create the module instances (for each source).

=head2 virtual_columns

Automatically inject virtual columns via config into the sources... More documentation TDB. 

In the meantime, see the virtual_column example in the Chinook Demo:

=over

=item *

L<Chinook Demo - 2.5 - Virtual Columns|http://www.rapidapp.info/demos/chinook/2_5>

=back


=head1 SEE ALSO

=over

=item *

L<Chinook Demo (www.rapidapp.info)|http://www.rapidapp.info/demos/chinook>

=item *

L<RapidApp::Manual::RapidDbic>

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp>

=item *

L<Catalyst::Plugin::RapidApp::TabGui>

=item *

L<Catalyst::Plugin::RapidApp::NavCore>

=item * 

L<Catalyst>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


1;

