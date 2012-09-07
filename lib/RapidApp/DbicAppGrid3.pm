package RapidApp::DbicAppGrid3;
use strict;
use Moose;
extends 'RapidApp::AppGrid2';
with 'RapidApp::Role::DbicLink2';

use RapidApp::Include qw(sugar perlutil);

sub BUILD {
	my $self = shift;
	
	if ($self->updatable_colspec) {
		$self->apply_extconfig( 
			xtype => 'appgrid2ed',
			clicksToEdit => 1,
		);
	}
	
	$self->apply_extconfig( setup_bbar_store_buttons => \1 );
	
	# New AppGrid2 nav feature. Need to always fetch the column to use for grid nav (open)
	push @{$self->always_fetch_columns}, $self->open_record_rest_key
		if ($self->open_record_rest_key);
	
	# Defaults: only applicable items will actually be added:
	#$self->apply_extconfig( store_buttons => [ 'add', 'delete', 'reload', 'save', 'undo' ]);
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;