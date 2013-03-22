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

has 'dbic_model_tree', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
	my $self = shift;
	die "Must supply either 'dbic_models' or 'dbic_model_tree'" unless ($self->dbic_models);
	return parse_dbic_model_list($self->app,@{$self->dbic_models});
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
		my ($schema,$result) = split(/\:\:/,$model,2);
		
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
		for my $source (@{$s->{sources}}) {
			my $Source = $schema->source($source) or die "Source $source not found!";
			
			my $module_name = lc($model . '_' . $Source->from);
			$self->apply_init_modules( $module_name => {
				class => $self->table_class,
				params => { ResultSource => $Source }
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
		
		my $iconcls = 'icon-server_database';
		
		my $module_name = lc($model);
		$self->apply_init_modules( $module_name => {
			class => 'RapidApp::DbicSchemaGrid',
			params => { 
				Schema => $self->app->model($model)->schema,
				tabTitle => $model,
				tabIconCls => $iconcls
			}
		});
		
		push @items, {
			id		=> lc($model) . '_tables',
			text	=> $model,
			iconCls	=> $iconcls,
			module		=> $module_name,
			params	=> {},
			expand	=> 1,
			children	=> \@children
		};
	}
	
	return \@items;
};


#### --------------------- ####


no Moose;
__PACKAGE__->meta->make_immutable;
1;