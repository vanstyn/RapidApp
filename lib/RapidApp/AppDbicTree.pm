package RapidApp::AppDbicTree;
use Moose;
extends 'RapidApp::AppNavTree';

#
# general purpose navtree for automatic grid/dbiclink access to DBIC sources
#

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;

has 'dbic_models', is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef;
has 'table_class', is => 'ro', isa => 'Str', required => 1;
has 'configs', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'dbic_model_tree', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
	my $self = shift;
	die "Must supply either 'dbic_models' or 'dbic_model_tree'" unless ($self->dbic_models);
	my $list = parse_dbic_model_list($self->app,@{$self->dbic_models});
  
  # strip excludes:
  for my $itm (@$list) {
    my $exclude_sources = try{$self->configs->{$itm->{model}}{exclude_sources}} || [];
    my %excl_sources = map { $_ => 1 } @$exclude_sources;
    @{$itm->{sources}} = grep { ! $excl_sources{$_} } @{$itm->{sources}};
  }
  
  return $list;
};


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
	
	# init
	$self->TreeConfig;
}


has 'TreeConfig', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
	my $self = shift;
	
	my @items = ();
	for my $s (@{$self->dbic_model_tree}) {
		my $model = $s->{model};
		my $schema = $self->app->model($model)->schema;
		my @children = ();
		for my $source (sort @{$s->{sources}}) {
			my $Source = $schema->source($source) or die "Source $source not found!";
			
      my $cust_def_config = try{$self->configs->{$model}{grid_params}{'*defaults'}} || {};
      my $cust_config = try{$self->configs->{$model}{grid_params}{$source}} || {};
      # since we're using these params over and over we need to protect refs in deep params
      # since currently DataStore/TableSpec modules modify params like include_colspec in
      # place (note this probably needs to be fixed in there for exactly this reason)
      my $cust_merged = clone( Catalyst::Utils::merge_hashes($cust_def_config,$cust_config) );
      
			my $module_name = lc($model . '_' . $Source->from);
      $module_name =~ s/\:\:/_/g;
			$self->apply_init_modules( $module_name => {
				class => $self->table_class,
				params => { %$cust_merged, ResultSource => $Source }
			});
			
			my $class = $schema->class($source);
			my $text = $class->TableSpec_get_conf('title_multi') || $source;
			my $iconCls = $class->TableSpec_get_conf('multiIconCls') || 'icon-application-view-detail';
			push @children, {
				id			=> $module_name,
				text		=> $text,
				iconCls		=> $iconCls ,
				module		=> $module_name,
				params		=> {},
				expand		=> 1,
				children	=> []
			}
		}
		
    my $exclude_sources = try{$self->configs->{$model}{exclude_sources}} || [];
		my $expand = (try{$self->configs->{$model}{expand}}) ? 1 : 0;
    my $iconcls = (try{$self->configs->{$model}{iconCls}}) || 'icon-server_database';
    my $text = (try{$self->configs->{$model}{text}}) || $model;
    my $template = try{$self->configs->{$model}{template}};
		
		my $module_name = lc($model);
    $module_name =~ s/\:\:/_/g;
		$self->apply_init_modules( $module_name => {
			class => 'RapidApp::DbicSchemaGrid',
			params => { 
				Schema => $self->app->model($model)->schema,
				tabTitle => $text,
				tabIconCls => $iconcls,
        exclude_sources => $exclude_sources,
        header_template => $template
			}
		});
    
    my $itm_id = lc($model) . '_tables';
    $itm_id =~ s/\:\:/_/g;
		push @items, {
			id		=> $itm_id,
			text	=> $text,
			iconCls	=> $iconcls,
			module		=> $module_name,
			params	=> {},
			expand	=> $expand,
			children	=> \@children
		};
	}
	
	return \@items;
};


#### --------------------- ####


no Moose;
__PACKAGE__->meta->make_immutable;
1;