package RapidApp::AppDataView;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
with 'RapidApp::Role::DataStore';
extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use String::Random;

has 'no_persist'				=> ( is => 'rw',	default => 1 );

has 'record_pk' => ( is => 'ro', default => 'id' );


has 'item_template' => ( is => 'ro', default => '' );

has 'dv_itemSelectorTag' => ( is => 'ro', default => 'div' );
has 'dv_itemSelectorClass' => ( is => 'ro', default => 'dv_selector' );

has 'xtemplate_cnf' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return 
		'<tpl for=".">' .
			#'<' . $self->dv_itemSelectorTag . ' id="dv-' . $self->instance_id . '-{' . $self->record_pk . '}" class="' . $self->dv_itemSelectorClass . '">' .
			'<' . $self->dv_itemSelectorTag . ' class="' . $self->dv_itemSelectorClass . '">' .
				$self->item_template .
			'</' . $self->dv_itemSelectorTag . '>' .
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
has 'dv_baseconfig'		=> ( is => 'ro', default => sub {{}} );

has 'listeners'			=> ( is => 'ro', default => undef );


#has 'DataView'  => ( is => 'ro', lazy => 1, default => sub {
sub DataView {
	my $self = shift;
	
	my $base = $self->dv_baseconfig;
	
	my $config = {
		store				=> $self->JsonStore,
		tpl				=> $self->xtemplate,
		autoHeight		=> \1,
		singleSelect	=> \1,
		itemSelector	=> $self->dv_itemSelectorTag . '.' . $self->dv_itemSelectorClass,
	};
	
	$config->{listeners} = $self->listeners if (defined $self->listeners);
	
	foreach my $k (keys %$base) {
		$config->{$k} = $base->{$k};
	}
	
	# we don't allow id and itemId to be overridden with baseconfig:
	#$config->{id} 		= $self->dv_id;
	
	
	$config->{id} = 'appdv-' . String::Random->new->randregex('[a-z0-9A-Z]{5}');
	
	$config->{itemId}	= $self->dv_itemId;
	
	my $DataView = RapidApp::JSONFunc->new( 
		func => 'new Ext.DataView',
		parm => $config
	);
	
	return $DataView;
}	
#});


sub content {
	my $self = shift;
	return $self->DataView;
}




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;