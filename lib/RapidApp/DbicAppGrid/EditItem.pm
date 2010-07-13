package RapidApp::DbicAppGrid::EditItem;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppGrid::EditItem';



################################################################
################################################################

has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_tbar {
	my $self = shift;
	return [
		'<div style="font-weight: bolder;">' .
			'Edit row (' . $self->parent_module->db_name . '/' . $self->parent_module->table . ')' .
		'</div>',
		'->',
		$self->reload_button, 
		$self->save_button
	];
}



1;
