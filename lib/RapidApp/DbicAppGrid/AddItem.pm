package RapidApp::DbicAppGrid::AddItem;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppGrid::AddItem';



################################################################
################################################################

has 'tbar_icon' => ( is => 'ro', default => '/assets/rapidapp/images/static/table_sql_create_32x32.png' );
has 'tbar_title' => ( is => 'ro', lazy_build => 1 );
sub _build_tbar_title {
	my $self = shift;
	return 'Add new row (' . $self->parent_module->db_name . '/' . $self->parent_module->table . ')';
}


1;
