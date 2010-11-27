package RapidApp::DbicAppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppGrid2';
with 'RapidApp::Role::DbicLink';
#use RapidApp::MooseX::ClassAttrSugar;
#setup_apply_methods_for('config');
#setup_apply_methods_for('listeners');


#apply_default_config(
#	remote_columns		=> \1,
#	loadMask				=> \1
#
#);


sub BUILD {
	my $self = shift;
	$self->apply_config(
		remote_columns		=> \1,
		loadMask				=> \1
	);
}







#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;