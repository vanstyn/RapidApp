use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Track;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Track");
__PACKAGE__->add_columns(
  "trackid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "nvarchar", is_nullable => 0, size => 200 },
  "albumid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "mediatypeid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "genreid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "composer",
  { data_type => "nvarchar", is_nullable => 1, size => 220 },
  "milliseconds",
  { data_type => "integer", is_nullable => 0 },
  "bytes",
  { data_type => "integer", is_nullable => 1 },
  "unitprice",
  { data_type => "numeric", is_nullable => 0, size => [10, 2] },
);
__PACKAGE__->set_primary_key("trackid");
__PACKAGE__->belongs_to(
  "albumid",
  "TestRA::ChinookDemo::DB::Result::Album",
  { albumid => "albumid" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "genreid",
  "TestRA::ChinookDemo::DB::Result::Genre",
  { genreid => "genreid" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "invoice_lines",
  "TestRA::ChinookDemo::DB::Result::InvoiceLine",
  { "foreign.trackid" => "self.trackid" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "mediatypeid",
  "TestRA::ChinookDemo::DB::Result::MediaType",
  { mediatypeid => "mediatypeid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "playlist_tracks",
  "TestRA::ChinookDemo::DB::Result::PlaylistTrack",
  { "foreign.trackid" => "self.trackid" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many("playlistids", "playlist_tracks", "playlistid");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-09-12 15:36:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LL9b6tXK9jLBIgjhimty4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
