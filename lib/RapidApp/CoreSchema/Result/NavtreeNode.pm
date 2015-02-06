package RapidApp::CoreSchema::Result::NavtreeNode;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table("navtree_node");

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "pid",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "text",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "iconcls",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "expanded",
  { data_type => "tinyint", is_nullable => 1 },
  "ordering",
  { data_type => "integer", default_value => 500000, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");


__PACKAGE__->belongs_to(
  "pid",
  "RapidApp::CoreSchema::Result::NavtreeNode",
  { id => "pid" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


__PACKAGE__->has_many(
  "navtree_nodes",
  "RapidApp::CoreSchema::Result::NavtreeNode",
  { "foreign.pid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


__PACKAGE__->has_many(
  "navtree_node_to_roles",
  "RapidApp::CoreSchema::Result::NavtreeNodeToRole",
  { "foreign.node_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


__PACKAGE__->has_many(
  "saved_states",
  "RapidApp::CoreSchema::Result::SavedState",
  { "foreign.node_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

use RapidApp::Util qw(:all);

sub update {
  my $self = shift;

  # Fail-safe: prevent changes to the 'DUMMY ROOT NODE' (id 0)
  if ($self->get_column('id') == 0) {
    #warn RED.BOLD "Tried to call update() on the DUMMY ROOT NODE." . CLEAR;
    # Updated: The 'Organize Tree' section is known to try to update the dummy root 
    # node which is a harmless side-effect which we are just silently ignoring.
    # TODO: investigate the real reason and fix properly
    return undef;
  }

  return $self->next::method(@_);
}


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->TableSpec_m2m( roles => 'navtree_node_to_roles', 'role' );
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Navtree Node',
	title_multi => 'Navtree Nodes',
	#iconCls => 'ra-icon-folder',
	#multiIconCls => 'ra-icon-folders',
	display_column => 'text'
);


__PACKAGE__->TableSpec_set_conf('column_properties_ordered', 

	id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
	pid => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
	navtree_node_to_roles => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },

	text => {
		header => 'Text',
		width	=> 200,
		allow_edit => \0
	},
	
	iconcls => {
		header => 'Icon Cls',
		width	=> 150,
		allow_edit => \0,
		hidden => \1
	},
	
	expanded => {
		header => 'Expanded',
		width	=> 70,
		allow_edit => \0,
		hidden => \1
	},
	
	navtree_nodes => {
		header => 'Child Nodes',
		width => 120
	},
	
	saved_states => {
		header => 'Searches',
		width => 140
	},
	
	roles => {
		header => 'Limit Roles',
		width => 200
	}
	
);



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
