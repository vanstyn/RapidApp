package RapidApp::TableSpec::DbicTableSpec;
use Moose;
extends 'RapidApp::TableSpec';
with 'RapidApp::TableSpec::Role::DBIC';


no Moose;
__PACKAGE__->meta->make_immutable;
1;
