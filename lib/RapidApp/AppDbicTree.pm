package RapidApp::AppDbicTree;
use Moose;
extends 'RapidApp::AppNavTree';

#
# general purpose navtree for automatic grid/dbiclink access to DBIC sources
#

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;

has 'dbic_models', is => 'ro', isa => 'ArrayRef[Str]', required => 1;
has 'table_class', is => 'ro', isa => 'Str', required => 1;

sub BUILD {
	my $self = shift;
	
	Module::Runtime::require_module($self->table_class);
	
	# init
	$self->TreeConfig;
}


has 'TreeConfig', is => 'ro', isa => 'ArrayRef[HashRef]', lazy => 1, default => sub {
	my $self = shift;
	
	
	my @items = ();
	
	foreach my $model (@{$self->dbic_models}) {
		my $orig_model = $model;
		# Support Schema::Result syntax: (quick/dirty)
		my ($top_model,$result) = split(/\:\:/,$model,2);
		$model = $top_model if ($result) ;
		
		my $M = $self->app->model($model) or die "No such model '$model'";
		die "Model '$model' does not appear to be a DBIC Schema Model." 
			unless ($M->can('schema'));
		
		my @children = ();
		my $schema = $M->schema;
		my @sources = $result ? ($result) : ($schema->sources);
		foreach my $source (@sources) {
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
		};
		
		push @items, {
			id		=> lc($model) . '_tables',
			text	=> $orig_model,
			iconCls	=> 'icon-server_database',
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