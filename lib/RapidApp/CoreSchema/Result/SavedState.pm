package RapidApp::CoreSchema::Result::SavedState;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table("saved_state");


__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "title",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "subtitle",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "node_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "user_id" =>  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "ordering",
  { data_type => "integer", default_value => 500001, is_nullable => 0 },
  "iconcls",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "url",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "params",
  { data_type => "text", is_nullable => 1 },
  "state_data",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


__PACKAGE__->belongs_to(
  "node",
  "RapidApp::CoreSchema::Result::NavtreeNode",
  { id => "node_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

__PACKAGE__->belongs_to(
  "user",
  "RapidApp::CoreSchema::Result::User",
  { id => "user_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

sub loadContentCnf {
	my $self = shift;
	
	#my $params = $self->decoded_params;
	#$params->{search_id} = $self->get_column('id');
  
  my $url = '/view/' . $self->get_column('id');
  
  # New: if there is no state_data or params, use the declared URL outright:
  $url = $self->url unless($self->params || $self->state_data);

	return {
		title		=> $self->title,
		iconCls	=> $self->iconcls,
		autoLoad => {
			#New REST url:
			url => $url
			#url => $self->url,
			#params => $params,
		}
	};
}


# Called from the tree module to get custom attrs
sub customAttrs {
  my $self = shift;
  
  # If there no state_data or params, this this is a 'link' node type, and we return
  # a packet for 'customAttrs'. See the NavTree grid for additional logic.
  return $self->params || $self->state_data  ? undef : { url => $self->url }
}


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Saved View',
	title_multi => 'Saved Views',
	iconCls => 'ra-icon-data-view',
	multiIconCls => 'ra-icon-data-views',
	display_column => 'title',
  auto_editor_type => 'grid'
);

__PACKAGE__->TableSpec_set_conf('column_properties_ordered', 

	id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
	node_id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
  user_id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
	
	title => {
		header => 'View Name/Title',
		width	=> 170,
	},
	
	subtitle => {
		header => 'Subtitle',
		width	=> 225,
		hidden => \1
	},
  
  ordering => {
    header => 'Order Num',
    hidden => 1
  },
	
	iconcls => {
		width	=> 110,
		header => 'Icon Class',
	},
	
	url => {
		width	=> 150,
		header => 'Url',
		allow_edit => \0
	},
	
	params => {
		width	=> 250,
		header => 'Params',
		renderer => 'Ext.ux.RapidApp.renderJSONjsDump',
    hidden => \1,
		allow_edit => \0,
		allow_view => \1
	},
	
	state_data => {
		width	=> 250,
		header => 'State Data',
		renderer => 'Ext.ux.RapidApp.renderJSONjsDump',
		#allow_edit => \0,
		hidden => \1
	},
	
	node => {
		width	=> 175,
		header => 'Navtree Parent Node',
	},
  
  user => {
		width	=> 130,
		header => 'User',
	},
	
);


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
