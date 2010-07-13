package RapidApp::DbicAppGrid::AddItem;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppGrid::AddItem';



################################################################
################################################################

has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_tbar {
	my $self = shift;
	return [
		'<div style="font-weight: bolder;">' .
			'Add new row (' . $self->parent_module->db_name . '/' . $self->parent_module->table . ')' .
		'</div>',
		'->',
		$self->add_button
	];
}



1;
