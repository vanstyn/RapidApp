package RapidApp::AppDataView;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
with 'RapidApp::Role::DataStore';
extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use String::Random;

has 'record_pk' => ( is => 'ro', default => 'id' );


has 'item_template' => ( is => 'ro', default => '' );

has 'xtemplate_cnf' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return 
		'<tpl for=".">' .
		$self->item_template .
		'</tpl>';
});

has 'xtemplate' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [ $self->xtemplate_cnf ]
	);
});


has 'dv_id' 				=> ( is => 'ro', lazy => 1, default => sub { 'appdv-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'dv_itemId' 			=> ( is => 'ro', lazy => 1, default => sub { 'item-' . (shift)->dv_id } );
has 'dv_itemSelector'	=> ( is => 'ro', default => 'div.dv_selector' );
has 'dv_baseconfig'		=> ( is => 'ro', default => sub {{}} );

has 'listeners'			=> ( is => 'ro', default => undef );

has 'DataView'  => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $base = $self->dv_baseconfig;
	
	my $config = {
		store				=> $self->JsonStore,
		tpl				=> $self->xtemplate,
		autoHeight		=> \1,
		singleSelect	=> \1,
		itemSelector	=> $self->dv_itemSelector,
	};
	
	$config->{listeners} = $self->listeners if (defined $self->listeners);
	
	foreach my $k (keys %$base) {
		$config->{$k} = $base->{$k};
	}
	
	# we don't allow id and itemId to be overridden with baseconfig:
	$config->{id} 		= $self->dv_id;
	$config->{itemId}	= $self->dv_itemId;
	
	my $DataView = RapidApp::JSONFunc->new( 
		func => 'new Ext.DataView',
		parm => $config
	);
	
	return $DataView;
});


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;