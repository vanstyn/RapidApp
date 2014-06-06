use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Artist;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Artist");
__PACKAGE__->add_columns(
  "artistid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "nvarchar", is_nullable => 1, size => 120 },
);
__PACKAGE__->set_primary_key("artistid");
__PACKAGE__->has_many(
  "albums",
  "TestRA::ChinookDemo::DB::Result::Album",
  { "foreign.artistid" => "self.artistid" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;
1;
