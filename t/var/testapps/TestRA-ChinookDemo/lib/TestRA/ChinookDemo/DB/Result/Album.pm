use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Album;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Album");
__PACKAGE__->add_columns(
  "albumid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "nvarchar", is_nullable => 0, size => 160 },
  "artistid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("albumid");
__PACKAGE__->belongs_to(
  "artistid",
  "TestRA::ChinookDemo::DB::Result::Artist",
  { artistid => "artistid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "tracks",
  "TestRA::ChinookDemo::DB::Result::Track",
  { "foreign.albumid" => "self.albumid" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;
1;
