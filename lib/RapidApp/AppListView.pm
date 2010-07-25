package RapidApp::AppListView;


use strict;
use Moose;
with 'RapidApp::Role::DataStore';
extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
use String::Random;


has 'lv_id' 				=> ( is => 'ro', lazy => 1, default => sub { 'applv-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'lv_itemId' 			=> ( is => 'ro', lazy => 1, default => sub { 'item-' . (shift)->lv_id } );
has 'lv_itemSelector'	=> ( is => 'ro', default => 'div.lv_selector' );
has 'lv_baseconfig'		=> ( is => 'ro', default => sub {{}} );


has 'listview_columns' => ( is => 'ro', default => sub {[]} );


has 'ListView'  => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $base = $self->lv_baseconfig;
	
	my $config = {
		store				=> $self->JsonStore,
		columns			=> $self->listview_columns,
		autoHeight		=> \1,
		#multiSelect	=> \1,
		singleSelect	=> \1,
		#itemSelector	=> $self->lv_itemSelector,
		emptyText		=> 'No items to display',
		#style				=> 'overflow:auto; background-color: #FFFFFF;'
	};
	
	foreach my $k (keys %$base) {
		$config->{$k} = $base->{$k};
	}
	
	# we don't allow id and itemId to be overridden with baseconfig:
	$config->{id} 		= $self->lv_id;
	$config->{itemId}	= $self->lv_itemId;
	
	my $ListView = RapidApp::JSONFunc->new( 
		func => 'new Ext.ListView',
		parm => $config
	);
	
	return $ListView;
});


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;