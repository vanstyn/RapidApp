package RapidApp::CoreSchema::Result::NavtreeNodeToRole;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table("navtree_node_to_role");

__PACKAGE__->add_columns(
  "node_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "role",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 64 },
);
__PACKAGE__->set_primary_key("node_id", "role");

__PACKAGE__->belongs_to(
  "node",
  "RapidApp::CoreSchema::Result::NavtreeNode",
  { id => "node_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


__PACKAGE__->belongs_to(
  "role",
  "RapidApp::CoreSchema::Result::Role",
  { role => "role" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Nav Node to Role Link',
	title_multi => 'Nav Node to Role Links',
	#iconCls => 'ra-icon-arrow-sprocket',
	#multiIconCls => 'ra-icon-arrow-sprockets',
	display_column => 'node_id',
	priority_rel_columns => 1,
);

__PACKAGE__->TableSpec_set_conf('column_properties_ordered', 

	node_id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },

	node => {
		header => 'Node',
		width	=> 150,
	},
	
	role => {
		header => 'role',
		width	=> 150,
	}
	
);


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
