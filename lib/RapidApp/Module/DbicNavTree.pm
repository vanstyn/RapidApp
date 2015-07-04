package RapidApp::Module::DbicNavTree;

use strict;
use warnings;

# ABSTRACT: general purpose navtree for auto grid access to DBIC sources

use Moose;
extends 'RapidApp::Module::NavTree';


use RapidApp::Util qw(:all);
require Module::Runtime;

has 'dbic_models', is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef;
has 'table_class', is => 'ro', isa => 'Str', required => 1;
has 'configs', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'menu_require_role', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

has 'dbic_model_tree', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
  my $self = shift;
  die "Must supply either 'dbic_models' or 'dbic_model_tree'" unless ($self->dbic_models);
  my $list = parse_dbic_model_list($self->app,@{$self->dbic_models});
  
  # validate models:
  for my $itm (@$list) {
    my $Model = $self->app->model($itm->{model});
    die "Error: model '$itm->{model}' is not a Catalyst::Model::DBIC::Schema"
      unless ($Model->isa('Catalyst::Model::DBIC::Schema'));
    
    warn join("\n",'',
      "  WARNING: using DBIC model '$itm->{model}' without 'quote_names' enabled.",
      "  It is strongly reccomended that this setting be enabled...",
      "  (Set env var RAPIDAPP_ISSUE99_IGNORE to supress this message)",'',''
    ) unless ($Model->connect_info->{quote_names} || $ENV{RAPIDAPP_ISSUE99_IGNORE});
  }
  
  # strip excludes/limits:
  for my $itm (@$list) {
    my $mdl_cfg = $self->configs->{$itm->{model}} || {};
    my $exclude_sources = $mdl_cfg->{exclude_sources} || [];
    my %excl_sources = map { $_ => 1 } @$exclude_sources;
    @{$itm->{sources}} = grep { ! $excl_sources{$_} } @{$itm->{sources}};
    my $lim = $mdl_cfg->{limit_sources} ? {map{$_=>1} @{$mdl_cfg->{limit_sources}}} : undef;
    if($lim) {
      @{$itm->{sources}} = grep { $lim->{$_} } @{$itm->{sources}};
    }
  }
  
  return $list;
};

# return a flat list of all loaded source models:
sub all_source_models {
  my $self = shift;
  my @list = ();
  foreach my $hash (@{$self->dbic_model_tree}) {
    push @list, map { $hash->{model} . '::' . $_ } @{$hash->{sources}};
  }
  return @list;
}


# General func instead of class method for use in other packages (temporary):
sub parse_dbic_model_list {
  my $c = shift;
  my @models = @_;
  
  my %schemas = ();
  my %sources = ();
  my @list = ();
  for my $model (@models) {
    die "Bad argument" if (ref $model);
    my $Model = $c->model($model) or die "No such model '$model'";
    my ($schema, $result) = ($model);
    
    if($Model->isa('DBIx::Class::ResultSet')){
      my @parts = split(/\:\:/,$model);
      $result = pop @parts;
      $schema = join('::',@parts);
    }
  
    my $M = $c->model($schema) or die "No such model '$schema'";
    die "Model '$schema' does not appear to be a DBIC Schema Model." 
      unless ($M->can('schema'));
    
    unless ($schemas{$schema}) {
      $schemas{$schema} = [];
      push @list, {
        model => $schema,
        sources => $schemas{$schema}
      };
    }
    
    # Either add specific/supplied result, or all results. Skip duplicates:
    my @results = $result ? ($result) : $M->schema->sources;
    $sources{$schema . '::' . $_}++ or push @{$schemas{$schema}}, $_ for (@results);
  }
  
  return \@list;
}


sub BUILD {
  my $self = shift;
  
  Module::Runtime::require_module($self->table_class);
  
  # menu_require_role only applies to the top level/navtree nodes which
  # simply hides the links, but preserves access to the real pages/data
  $self->apply_extconfig( require_role => $self->menu_require_role ) if (
    ! $self->require_role &&
    $self->menu_require_role
  );
  
  # init
  $self->TreeConfig;
}


has 'TreeConfig', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
  my $self = shift;
  
  my @items = ();
  for my $s (@{$self->dbic_model_tree}) {
    my $model = $s->{model};
    my $schema = $self->app->model($model)->schema;
    
    my $require_role = $self->require_role || try{$self->configs->{$model}{require_role}};
    my $menu_req_role = $require_role || $self->menu_require_role;
    
    my @children = ();
    for my $source (sort @{$s->{sources}}) {
      my $Source = $schema->source($source) or die "Source $source not found!";
      
      my $cust_def_config = try{$self->configs->{$model}{grid_params}{'*defaults'}} || {};
      my $cust_config = try{$self->configs->{$model}{grid_params}{$source}} || {};
      # since we're using these params over and over we need to protect refs in deep params
      # since currently DataStore/TableSpec modules modify params like include_colspec in
      # place (note this probably needs to be fixed in there for exactly this reason)
      my $cust_merged = clone( Catalyst::Utils::merge_hashes($cust_def_config,$cust_config) );
      
      my $grid_class = $cust_merged->{grid_class} ? delete $cust_merged->{grid_class} :
        try{$self->configs->{$model}{grid_class}} || $self->table_class;
      
      #my $table = $Source->schema->class($Source->source_name)->table;
      #$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
      my $module_name = lc(join('_',$model,$source));
      $module_name =~ s/\:\:/_/g;
      $self->apply_init_modules( $module_name => {
        class => $grid_class,
        params => {
          require_role => $require_role,
          %$cust_merged, 
          ResultSource => $Source, 
          source_model => $model . '::' . $source,
        }
      });
      
      my $class = $schema->class($source);
      my $text = $class->TableSpec_get_conf('title_multi') || $source;
      my $iconCls = $class->TableSpec_get_conf('multiIconCls') || 'ra-icon-application-view-detail';
      push @children, {
        id      => $module_name,
        text    => $text,
        iconCls    => $iconCls ,
        module    => $module_name,
        params    => {},
        expand    => 1,
        children  => [],
        require_role => $menu_req_role
      }
    }
    
    
    my $exclude_sources = try{$self->configs->{$model}{exclude_sources}} || [];
    my $expand = (try{$self->configs->{$model}{expand}}) ? 1 : 0;
    my $text = (try{$self->configs->{$model}{text}}) || $model;
    my $template = try{$self->configs->{$model}{template}};
    
    
    my $dbd_driver = $schema->storage->dbh->{Driver}->{Name} || '';
    my $iconcls = (try{$self->configs->{$model}{iconCls}}) || (
      $dbd_driver eq 'SQLite' 
      ? 'ra-icon-page-white-database' 
      : 'ra-icon-server-database'
    );
    
    my $module_name = lc($model);
    $module_name =~ s/\:\:/_/g;
    $self->apply_init_modules( $module_name => {
      class => 'RapidApp::Module::DbicSchemaGrid',
      params => { 
        Schema => $self->app->model($model)->schema,
        tabTitle => $text,
        tabIconCls => $iconcls,
        exclude_sources => $exclude_sources,
        header_template => $template,
        require_role => $require_role
      }
    });
    
    my $itm_id = lc($model) . '_tables';
    $itm_id =~ s/\:\:/_/g;
    push @items, {
      id    => $itm_id,
      text  => $text,
      iconCls  => $iconcls,
      module    => $module_name,
      params  => {},
      expand  => $expand,
      children  => \@children,
      require_role => $menu_req_role
    };
  }
  
  return \@items;
};



#### --------------------- ####


no Moose;
__PACKAGE__->meta->make_immutable;
1;