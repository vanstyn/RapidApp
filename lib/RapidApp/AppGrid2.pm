package RapidApp::AppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppCnt';
with 'RapidApp::Role::DataStore';


use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);

use RapidApp::MooseX::ClassAttrSugar;
setup_add_methods_for('config');
setup_add_methods_for('listeners');


add_default_config(
	xtype		'gridpanel',
	

);


before 'content' => sub {
	my $self = shift;
	
	$self->add_config(
		store		=> $self->JsonStore
	);

};




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;