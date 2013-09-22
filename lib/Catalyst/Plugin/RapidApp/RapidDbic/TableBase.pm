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

# Note: setting the default individually instead of setting
# persist_all_immediately because the latter takes priority
# and we want our consumers to be able to set these without
# having to also set 'persist_all_immediately => 0'
has '+persist_immediately', default => sub {{
  create => 1,
  update => 1,
  destroy => 1
}};

has '+use_add_form', default => sub {
  my $self = shift;
  # Default to tab unless 'create' is not set to persist_immediately
  return (
    $self->persist_all_immediately ||
    jstrue( $self->persist_immediately->{create} )
  ) ? 'tab' : undef;
};

has '+use_edit_form', default => 'window';
has '+use_column_summaries', default => 1;
has '+use_autosize_columns', default => 1;
has '+auto_autosize_columns', default => 0;

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
  
  $self->add_plugin('grid-custom-headers');
	
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

