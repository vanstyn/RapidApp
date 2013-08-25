package RapidApp::CoreSchema::Result::User;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->table('user');

__PACKAGE__->add_columns(
   "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "full_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_login_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "disabled",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "disabled_ts",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("username", ["username"]);

__PACKAGE__->has_many(
  "user_to_roles",
  "RapidApp::CoreSchema::Result::UserToRole",
  { "foreign.username" => "self.username" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "saved_states",
  "RapidApp::CoreSchema::Result::SavedState",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "sessions",
  "RapidApp::CoreSchema::Result::Session",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->TableSpec_m2m( roles => "user_to_roles", 'role');

# ----
# TODO/FIXME: This is ugly/global, but works. This virtual column
# provides a column-based interface to set the password, optionally
# passing it through a custom password hasher function. The ugly
# part is that the password hasher is set on the class...
# This is being set by Catalyst::Plugin::RapidApp::AuthCore
__PACKAGE__->mk_classdata( 'password_hasher' );
__PACKAGE__->password_hasher( sub { (shift) } ); # 'clear'
__PACKAGE__->add_virtual_columns( set_pw => {
	data_type => "varchar", 
	is_nullable => 1, 
	sql => "SELECT NULL",
  set_function => sub {
    my ($self,$pw) = @_;
    if($pw && $pw ne '') {
      my $pass = $self->password_hasher->($pw) || $pw;
      $self->set_column( password => $pass );
      $self->update;
    }
  }
});
# ----

__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'User',
	title_multi => 'Users',
	#iconCls => 'ra-icon-user',
	#multiIconCls => 'ra-icon-group',
	display_column => 'username',
  priority_rel_columns => 1,
  columns => {
    id            => { width => 40,   profiles => ['noedit'] },
    username      => { width => 90,    },
    password      => { width => 70, profiles => ['noedit']   },
    full_name     => { width => 120, hidden => \1   },
    
    last_login_ts => { 
      hidden => \1, # temp: hide only so it doesn't show between password and set_pw
      width => 120,  allow_edit => \0, allow_add => \0  
    },
    
    disabled      => { 
      width => 60,  profiles => ['bool'], hidden => \1,
      # Not implemented yet
      no_column => \1, no_quick_search => \1, no_multifilter => \1
    },
    
    disabled_ts   => { 
      width => 120, hidden => \1,
      # Not implemented yet   
      no_column => \1, no_quick_search => \1, no_multifilter => \1
    },
    
    set_pw        => { width => 130,    },
  }
);


__PACKAGE__->meta->make_immutable;
1;
