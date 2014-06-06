package RapidApp::CoreSchema::Result::DeployInfo;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table("deploy_info");

__PACKAGE__->add_columns(
  md5 => { 
    data_type => "char", 
    is_nullable => 0, 
    size => 32 
  },
  schema_class => { 
    data_type => "varchar", 
    is_nullable => 0, 
    size => 128 
  },
  schema_version => { 
    data_type => "varchar", 
    is_nullable => 0, 
    size => 16 
  },
  comment => { 
    data_type => "varchar", 
    is_nullable => 0, 
    size => 255 
  },
  deployed_ddl => {
    data_type	=> 'mediumtext',
    is_nullable	=> 0
  },
  deployed_ts	=> { 
    data_type => "datetime", 
    datetime_undef_if_invalid => 1, 
    is_nullable => 0 
  },
);
__PACKAGE__->set_primary_key("md5");


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

# quick set all columns
use Clone qw(clone);
my $col_props = { map { $_ => clone({
  allow_add => \0, allow_edit => \0
}) } __PACKAGE__->columns };
$col_props->{deployed_ddl}->{hidden} = \1;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Deploy Info',
	title_multi => 'Deploy Info',
	#iconCls => 'ra-icon-data-view',
	#multiIconCls => 'ra-icon-data-views',
	display_column => 'md5',
  columns => $col_props
);



# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
