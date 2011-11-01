package RapidApp::DbicAppGrid3;


use strict;
use Moose;
extends 'RapidApp::AppGrid2';
with 'RapidApp::Role::DbicLink2';

#use RapidApp::MooseX::ClassAttrSugar;
#setup_apply_methods_for('config');
#setup_apply_methods_for('listeners');


#apply_default_config(
#	remote_columns		=> \1,
#	loadMask				=> \1
#
#);

#sub BUILD {
#	my $self = shift;
#	$self->apply_config(
#		remote_columns		=> \1,
#		loadMask				=> \1
#	);
#}

sub BUILD {
	my $self = shift;
	
	if ($self->updatable_colspec) {
		$self->apply_extconfig( xtype => 'appgrid2ed' );
		$self->apply_extconfig( clicksToEdit => 1 );
	}
	
}







#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;