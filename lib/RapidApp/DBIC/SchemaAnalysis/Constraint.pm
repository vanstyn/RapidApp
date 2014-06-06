package RapidApp::DBIC::SchemaAnalysis::Constraint;

use Moose;

# the columns of the local table which make up the key
has 'local_key'   => ( is => 'ro', isa => 'RapidApp::DBIC::Key' );

# the columns in the remote table which we match against
has 'foreign_key' => ( is => 'ro', isa => 'RapidApp::DBIC::Key' );

# the table which defined whether or not the key exists, i.e. if
#  A.id has a FK of B.id, and B.id has a FK of C.id, A.id's origin is C.id
has 'origin_key'  => ( is => 'ro', isa => 'RapidApp::DBIC::Key' );

__PACKAGE__->meta->make_immutable;
1;