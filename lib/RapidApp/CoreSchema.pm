package RapidApp::CoreSchema;

# Optional DBIC Schema that provides tables for core/common 
# functions, such as users, roles, navtree, saved searches

use Moose;
use namespace::autoclean;
extends 'DBIx::Class::Schema';

our $VERSION = 1;

__PACKAGE__->load_namespaces;

# You can replace this text with custom code or comments, and it will be preserved on regeneration
#__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
