use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::PlaylistTrack;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("PlaylistTrack");
__PACKAGE__->add_columns(
  "playlistid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "trackid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("playlistid", "trackid");
__PACKAGE__->belongs_to(
  "playlistid",
  "TestRA::ChinookDemo::DB::Result::Playlist",
  { playlistid => "playlistid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "trackid",
  "TestRA::ChinookDemo::DB::Result::Track",
  { trackid => "trackid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

__PACKAGE__->meta->make_immutable;
1;
