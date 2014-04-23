use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::MediaType;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("MediaType");
__PACKAGE__->add_columns(
  "mediatypeid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "nvarchar", is_nullable => 1, size => 120 },
);
__PACKAGE__->set_primary_key("mediatypeid");
__PACKAGE__->has_many(
  "tracks",
  "TestRA::ChinookDemo::DB::Result::Track",
  { "foreign.mediatypeid" => "self.mediatypeid" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->meta->make_immutable;
1;
