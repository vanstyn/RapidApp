package RapidApp::CoreSchema::Result::Role;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table('role');

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "role",
  { data_type => "varchar", is_nullable => 0, is_foreign_key => 1, size => 64 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("role_name", ["role"]);

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
	iconCls => 'ra-icon-user-pref',
	multiIconCls => 'ra-icon-user-prefs',
	display_column => 'role',
  priority_rel_columns => 1,
);

__PACKAGE__->TableSpec_set_conf('column_properties_ordered',

  id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },

	role => {
		header => 'Role',
		width	=> 150,
    allow_edit => \1
	},

	description => {
		header => 'Description',
		width	=> 350,
	},

);

__PACKAGE__->meta->make_immutable;
1;
