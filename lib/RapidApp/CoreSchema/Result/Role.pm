package RapidApp::CoreSchema::Result::Role;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table('role');

__PACKAGE__->add_columns(
  "role",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("role");

__PACKAGE__->has_many(
  "user_to_roles",
  "RapidApp::CoreSchema::Result::UserToRole",
  { "foreign.role" => "self.role" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "navtree_node_to_roles",
  "RapidApp::CoreSchema::Result::NavtreeNodeToRole",
  { "foreign.role" => "self.role" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Role',
	title_multi => 'Roles',
	#iconCls => 'icon-user1-preferences',
	#multiIconCls => 'icon-user1-preferences-many',
	display_column => 'role',
  priority_rel_columns => 1,
);

__PACKAGE__->TableSpec_set_conf('column_properties_ordered', 

	role => {
		header => 'Role',
		width	=> 150,
	},
	
	description => {
		header => 'Description',
		width	=> 350,
	},
	
);

__PACKAGE__->meta->make_immutable;
1;
