package RapidApp::CoreSchema::Result::Session;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table('session');

__PACKAGE__->add_columns(
   "id" => {
    data_type => "varchar",
    is_nullable => 0,
  },
  "session_data" => {
    data_type => "text",
    is_nullable => 1,
  },
  "expires" => {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "expires_ts" => {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "user_id" =>  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
);

__PACKAGE__->set_primary_key('id');

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

use DateTime;
use MIME::Base64;
use Storable;
use Try::Tiny;

sub insert {
  my $self = shift;
  $self->_set_extra_columns(@_);
  return $self->next::method;
}

sub update {
  my $self = shift;
  $self->_set_extra_columns(@_);
  return $self->next::method;
}

sub _set_extra_columns {
  my $self = shift;
  my $columns = shift;
	$self->set_inflated_columns($columns) if $columns;
  
  my $expires = $self->get_column('expires');
  $self->set_column( expires_ts => DateTime->from_epoch(
    epoch => $expires,
    time_zone => 'local'
  ) ) if ($expires);
  
  my $data = $self->decoded_session_data;
  if($data) {
    my $user_id = try{$data->{__user}{id}};
    $self->set_column( user_id => $user_id );
  }
}

sub decoded_session_data {
  my $self = shift;
  my $value = $self->get_column('session_data') or return undef;
  return try{ Storable::thaw(MIME::Base64::decode($value)) };
}

__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->add_virtual_columns(
  expires_in => {
    data_type => "integer", 
    is_nullable => 1, 
    sql => q|SELECT (self.expires - strftime('%s','now'))|
  },
);
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
  title => 'Session',
  title_multi => 'Sessions',
  display_column => 'id',
  priority_rel_columns => 1,
  columns => {
    id => { 
      width => 300,
      allow_add => \0, allow_edit => \0,
    },
    session_data => {
      hidden => \1,
      renderer => 'Ext.ux.RapidApp.renderBase64'
    },
    user_id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },
    expires => {
      width => 100, hidden => \1,
      allow_add => \0, allow_edit => \0,
    },
    expires_ts => { 
      allow_add => \0, allow_edit => \0, 
      width => 130
    },
    expires_in => {
      width => 100,
      renderer => 'Ext.ux.RapidApp.renderSecondsElapsed'
    },
    user => { allow_add => \0, allow_edit => \0 },
  }
);

__PACKAGE__->meta->make_immutable;
1;
