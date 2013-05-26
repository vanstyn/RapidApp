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
  }
);

__PACKAGE__->set_primary_key('id');

use DateTime;

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
}

__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Session',
	title_multi => 'Sessions',
	#iconCls => 'icon-user',
	#multiIconCls => 'icon-group',
	display_column => 'id',
  priority_rel_columns => 1,
);

__PACKAGE__->meta->make_immutable;
1;
