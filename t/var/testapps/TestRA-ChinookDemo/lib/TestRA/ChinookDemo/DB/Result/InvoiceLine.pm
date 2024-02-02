use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::InvoiceLine;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("InvoiceLine");
__PACKAGE__->add_columns(
  "invoicelineid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "invoiceid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "trackid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "unitprice",
  { data_type => "numeric", is_nullable => 0, size => [10, 2] },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("invoicelineid");
__PACKAGE__->belongs_to(
  "invoiceid",
  "TestRA::ChinookDemo::DB::Result::Invoice",
  { invoiceid => "invoiceid" },
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
