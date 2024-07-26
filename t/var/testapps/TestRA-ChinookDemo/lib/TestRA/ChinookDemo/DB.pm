use utf8;
package # hide from PAUSE
     TestRA::ChinookDemo::DB;

use Moose;

extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
