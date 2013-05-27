package Catalyst::Plugin::RapidApp::RapidDbic::TableBase;

use strict;
use warnings;
use Moose;
extends 'RapidApp::DbicAppGrid3';
with 
  'RapidApp::AppGrid2::Role::ExcelExport',
  # This is a bit of overlap/entaglement needed for 'NavCore' to be able to
  # work. However, NavCore is not always enabled, and this role only
  # enables itself if it is (i.e. Plugin::NavCore is present)
  'Catalyst::Plugin::RapidApp::NavCore::GridRole'
;

#use RapidApp::DbicAppPropertyPage;

use RapidApp::Include qw(sugar perlutil);
use Switch 'switch';

has '+use_column_summaries', default => 1;
has '+use_autosize_columns', default => 1;
has '+auto_autosize_columns', default => 0;

has 'page_class', is => 'ro', isa => 'Str', default => 'RapidApp::DbicAppPropertyPage';
has 'page_params', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'no_page', is => 'ro', isa => 'Bool', default => 0;

has 'source_model', is => 'ro', isa => 'Maybe[Str]', default => undef;

# This is an option of RapidApp::AppGrid2 that will allow double-click to open Rows:
has '+open_record_class', lazy => 1, default => sub {
	my $self = shift;
	return undef if ($self->no_page);
  return {
		class => $self->page_class,
		params => {
			ResultSource => $self->ResultSource,
			get_ResultSet => $self->get_ResultSet, 
			#TableSpec => $self->TableSpec,
			include_colspec => clone( $self->include_colspec ),
			updatable_colspec => clone( $self->updatable_colspec ),
			persist_all_immediately => $self->persist_all_immediately,
      persist_immediately => $self->persist_immediately,
      %{ clone( $self->page_params ) }
		}
	};
};

has '+include_colspec', default => sub{[qw(*)]};

# default to read-only:
has '+updatable_colspec', default => undef;
has '+creatable_colspec', default => undef;
has '+destroyable_relspec', default => undef;

has '+persist_all_immediately', default => 0;
has '+persist_immediately', default => sub {{
	create	=> \1,
	update	=> \1,
	destroy	=> \0
}};


has 'extra_extconfig', is => 'ro', isa => 'HashRef', default => sub {{}};

# This is highly specific to the RapidDbic and NavCore plugins:
has '_rapiddbic_default_views_model_name', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub {
  my $self = shift;
  my $c = $self->app;
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
   
  return (
     $config->{navcore_default_views} && 
    $c->_navcore_enabled
  ) ? 'RapidApp::CoreSchema::DefaultView' : undef;
};


sub BUILD {
	my $self = shift;
  
	# Need to turn on "use_add_form" (tab or window) to use a form to create new rows.
	# without this the new row would be created with empty default values, instantly
	$self->apply_extconfig(
		use_add_form => 'tab',
		use_edit_form => 'window',
		autoload_added_record => \1
	);
	
	# Turn off editing for primary columns:
	$self->apply_columns( $_ => { allow_edit => \0 } ) for ($self->ResultSource->primary_columns);
	
	
	# Apply a width to all columns:
	#$self->apply_to_all_columns({ width => 130 });
	(exists $self->columns->{$_}->{width}) or $self->apply_columns( $_ => { width => 130 } )
		for @{$self->column_order};
	
	# Apply a larger width to rel columns:
	$self->apply_columns( $_ => { width => 175 } ) for ($self->ResultSource->relationships);
	
	# Init joined columns hidden:
	$self->apply_columns( $_ => { hidden => \1 } ) 
		for (grep { $_ =~ /__/ } @{$self->column_order});
    
  my $extra_cnf = $self->extra_extconfig;
  $self->apply_extconfig( %$extra_cnf ) if (keys %$extra_cnf > 0);

}

# This is highly specific to the RapidDbic and NavCore plugins. Manually load
# a saved search if a 'DefaultView' has been specified for this Source/Model in
# the CoreSchema database
before 'load_saved_search' => sub { (shift)->before_load_saved_search };
sub before_load_saved_search {
	my $self = shift;
	
  my $model_name = $self->_rapiddbic_default_views_model_name or return;
  my $Rs = $self->c->model($model_name);
  my $DefaultView = $Rs->find($self->source_model) or return;
  
  my $SavedState = $DefaultView->view or return;
  
  my $state_data = $SavedState->get_column('state_data');
  my $search_data = $self->json->decode($state_data) or die usererr "Error deserializing grid_state";
	$self->apply_to_all_columns( hidden => \1 );
	return $self->batch_apply_opts_existing($search_data);
};


1;

