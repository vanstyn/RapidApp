package RapidApp::AppGridSelector;
use strict;
use Moose;
extends 'RapidApp::AppGrid2';

use RapidApp::Include qw(sugar perlutil);


sub content {
	my $self = shift;	
	my $gridcnf = $self->SUPER::content;
	
	my $grid = RapidApp::JSONFunc->new( func => 'Ext.ComponentMgr.create', parm => $gridcnf );
	
	return {
		xtype	=> 'appgridselector',
		grid	=> $grid
	};
}





#no Moose;
#__PACKAGE__->meta->make_immutable;
1;