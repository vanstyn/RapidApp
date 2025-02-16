use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Playlist;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Playlist");
__PACKAGE__->add_columns(
  "playlistid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "nvarchar", is_nullable => 1, size => 120 },
);
__PACKAGE__->set_primary_key("playlistid");
__PACKAGE__->has_many(
  "playlist_tracks",
  "TestRA::ChinookDemo::DB::Result::PlaylistTrack",
  { "foreign.playlistid" => "self.playlistid" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("trackids", "playlist_tracks", "trackid");

__PACKAGE__->meta->make_immutable;
1;
