package RapidApp::CoreSchema::Result::User;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

use DBIx::Class::PassphraseColumn 0.02;

__PACKAGE__->load_components("InflateColumn::DateTime","PassphraseColumn");

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
  #"password",
  #{ data_type => "varchar", is_nullable => 1, size => 255 },
  
  password => {
    is_serializable => 1,
    data_type => 'varchar',
    is_nullable => 1,
    size => 'max',
    passphrase => 'rfc2307',
    passphrase_class => 'BlowfishCrypt',
    passphrase_args => {
      cost        => 9,
      salt_random => 1,
    },
    passphrase_check_method => 'check_password',
  },
  
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
# passing it through a custom Authen::Passphrase class. The ugly
# part is that the Authen::Passphrase class setting is set on the class...
# This is being set by Catalyst::Plugin::RapidApp::AuthCore
__PACKAGE__->mk_classdata( 'authen_passphrase_class' );
__PACKAGE__->mk_classdata( 'authen_passphrase_params' );
__PACKAGE__->add_virtual_columns( set_pw => {
	data_type => "varchar", 
	is_nullable => 1, 
	sql => "SELECT NULL",
  set_function => sub {
    my ($self,$pw) = @_;
    if($pw && $pw ne '') {
      if($self->authen_passphrase_class) {
        my %params = (
          %{ $self->authen_passphrase_params || {} },
          passphrase => $pw
        );
        
        $pw = $self->authen_passphrase_class->new(%params);
        
        # TODO/FIXME: I thought I could pass an Authen::Passphrase object
        # to the PassphraseColumn, but it seemed to always only create the
        # default set in passphrase_class, so I am just doing it manually
        my $pf = $pw->can('as_rfc2307') 
          ? $pw->as_rfc2307 : join('','{CRYPT}',$pw->as_crypt);
        
        $self->store_column( password => $pf );
        $self->make_column_dirty('password');
      }
      else {
        $self->password($pw);
      }
      $self->update;
    }
  }
});
# ----

__PACKAGE__->apply_TableSpec;


# Always returns undef unless 'linked_user_model' is configured
sub linkedRow {
  my $self = shift;
  $self->{_linkedRow} //= do {
    my $Row = undef;
    if($self->can('_find_linkedRow')) {
      $Row = $self->_find_linkedRow || $self->_create_linkedRow;
    }
    $Row
  }
}


__PACKAGE__->TableSpec_set_conf( 
	title => 'User',
	title_multi => 'Users',
	iconCls => 'ra-icon-businessman',
	multiIconCls => 'ra-icon-businessmen',
	display_column => 'username',
  priority_rel_columns => 1,
  columns => {
    id            => { width => 40,  header => 'Id',   profiles => ['noedit'] },
    username      => { width => 90,  header => 'Username'  },
    password      => { width => 120, header => 'Password (hashed)',  profiles => ['noedit'] },
    full_name     => { width => 120, header => 'Full Name', hidden => \1   },
    
    last_login_ts => { 
      hidden => \1, # temp: hide only so it doesn't show between password and set_pw
      header => 'Last Login',
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
    
    
    
    roles         => { width => 220,  header => 'Roles'  },
    sessions      => { width => 120,  header => 'Sessions'  },
    saved_states  => { width => 130,  header => 'Saved Views' },
    user_to_roles => { width => 130, header => 'User to Roles', hidden => \1   },
    
    set_pw => { 
      header => 'Set Password*', 
      width => 130,    
      editor => { xtype => 'ra-change-password-field' },
      renderer => 'Ext.ux.RapidApp.renderSetPwValue'
    },
    
  }
);


__PACKAGE__->meta->make_immutable;
1;
