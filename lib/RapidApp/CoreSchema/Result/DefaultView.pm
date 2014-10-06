package RapidApp::CoreSchema::Result::DefaultView;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';

__PACKAGE__->table("default_view");

__PACKAGE__->add_columns(
  "source_model" => { 
    data_type => "varchar", 
    is_nullable => 0, 
    size => 255 
  },
  "view_id" =>  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key("source_model");


__PACKAGE__->belongs_to(
  "view",
  "RapidApp::CoreSchema::Result::SavedState",
  { id => "view_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


__PACKAGE__->load_components('+RapidApp::DBIC::Component::TableSpec');
__PACKAGE__->apply_TableSpec;

__PACKAGE__->TableSpec_set_conf( 
	title => 'Source Default View',
	title_multi => 'Source Default Views',
	iconCls => 'ra-icon-data-preferences',
	multiIconCls => 'ra-icon-data-preferences',
	display_column => 'source_model'
);

__PACKAGE__->TableSpec_set_conf('column_properties_ordered', 

  view_id => { no_column => \1, no_multifilter => \1, no_quick_search => \1 },

	source_model => {
		header => 'Source/Model',
		width	=> 250,
    allow_add => \0,
    allow_edit => \0
	},
	
	view => {
		header => 'View',
		width	=> 225,
    allow_add => \0,
	}
	
);


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
