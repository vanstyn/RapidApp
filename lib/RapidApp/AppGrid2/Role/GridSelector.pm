package RapidApp::AppGrid2::Role::GridSelector;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

has 'add_record_class'	=> ( is => 'ro', default => undef );
has 'open_record_class'	=> ( is => 'ro', default => undef );

around 'content' => sub {
	my ($orig, $self, @args) = @_;
	
	my $gridcnf = $self->$orig(@args);
	
	my $grid = RapidApp::JSONFunc->new( func => 'Ext.ComponentMgr.create', parm => $gridcnf );
	
	return {
		xtype	=> 'appgridselector',
		grid	=> $grid
	};
};





#no Moose;
#__PACKAGE__->meta->make_immutable;
1;