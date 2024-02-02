use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Genre;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Genre");
__PACKAGE__->add_columns(
  "genreid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "nvarchar", is_nullable => 1, size => 120 },
);
__PACKAGE__->set_primary_key("genreid");
__PACKAGE__->has_many(
  "tracks",
  "TestRA::ChinookDemo::DB::Result::Track",
  { "foreign.genreid" => "self.genreid" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;
1;
