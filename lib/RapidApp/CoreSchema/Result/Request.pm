package RapidApp::CoreSchema::Result::Request;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table('request');

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "user_id" =>  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "timestamp" => {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "client_ip",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "client_hostname",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "uri",
  { data_type => "varchar", is_nullable => 0, size => 512 },
  "method",
  { data_type => "varchar", is_nullable => 0, size => 8 },
  "user_agent",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "referer",
  { data_type => "varchar", is_nullable => 1, size => 512 },
  "serialized_request",
  { data_type => "text", is_nullable => 1 },
    
);
__PACKAGE__->set_primary_key("id");

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


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');

## This is MySQL-specific
#__PACKAGE__->add_virtual_columns(
#	display => {
#		data_type => "varchar", 
#		is_nullable => 0, 
#		size => 255,
#		sql => 'SELECT CONCAT(self.id,' .
#			'CONCAT(" - ",' .
#				'CONCAT(self.client_ip,' .
#					'CONCAT(" [",' .
#						'CONCAT(self.timestamp,"]")' .
#					')' .
#				')' .
#			')' .
#		')'
#	}
#);

__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'HTTP Request',
	title_multi => 'HTTP Requests',
	#iconCls => 'ra-icon-world-go',
	#multiIconCls => 'ra-icon-world-gos',
	display_column => 'timestamp',
	priority_rel_columns => 1,
);

__PACKAGE__->meta->make_immutable;
1;
