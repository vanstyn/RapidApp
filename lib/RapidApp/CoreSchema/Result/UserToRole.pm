package RapidApp::CoreSchema::Result::UserToRole;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table('user_to_role');

__PACKAGE__->add_columns(
  "username",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "role",
  { data_type => "varchar", is_nullable => 0, size => 64 },
);
__PACKAGE__->set_primary_key("username", "role");

__PACKAGE__->belongs_to(
  "username",
  "RapidApp::CoreSchema::Result::User",
  { username => "username" },
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
	title => 'UserToRole',
	title_multi => 'UserToRoles',
	#iconCls => 'icon-node',
	#multiIconCls => 'icon-user1-preferences-many',
	display_column => 'role',
  priority_rel_columns => 1
);

__PACKAGE__->meta->make_immutable;
1;
