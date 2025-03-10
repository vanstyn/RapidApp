use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB::Result::Customer;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("Customer");
__PACKAGE__->add_columns(
  "customerid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "firstname",
  { data_type => "nvarchar", is_nullable => 0, size => 40 },
  "lastname",
  { data_type => "nvarchar", is_nullable => 0, size => 20 },
  "company",
  { data_type => "nvarchar", is_nullable => 1, size => 80 },
  "address",
  { data_type => "nvarchar", is_nullable => 1, size => 70 },
  "city",
  { data_type => "nvarchar", is_nullable => 1, size => 40 },
  "state",
  { data_type => "nvarchar", is_nullable => 1, size => 40 },
  "country",
  { data_type => "nvarchar", is_nullable => 1, size => 40 },
  "postalcode",
  { data_type => "nvarchar", is_nullable => 1, size => 10 },
  "phone",
  { data_type => "nvarchar", is_nullable => 1, size => 24 },
  "fax",
  { data_type => "nvarchar", is_nullable => 1, size => 24 },
  "email",
  { data_type => "nvarchar", is_nullable => 0, size => 60 },
  "supportrepid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("customerid");
__PACKAGE__->has_many(
  "invoices",
  "TestRA::ChinookDemo::DB::Result::Invoice",
  { "foreign.customerid" => "self.customerid" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->belongs_to(
  "supportrepid",
  "TestRA::ChinookDemo::DB::Result::Employee",
  { employeeid => "supportrepid" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

__PACKAGE__->meta->make_immutable;
1;
