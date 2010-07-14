package RapidApp::AppDataView;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
use RapidApp::AppDataView::Store;

has 'datastore_class' => ( is => 'ro', default => 'RapidApp::AppDataView::Store' );

has 'modules' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		datastore		=> $self->datastore_class,
	};
});

# stub attribute: should be overridden by subclass
has 'read_records_coderef' => ( is => 'ro', default => sub {
	sub {{
		rows		=> [],
		results	=> 0
	}};
});

has 'item_template' => ( is => 'ro', default => '' );

has 'xtemplate' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.XTemplate',
		parm => [
			'<tpl for=".">',
			$self->item_template,
			'</tpl>'
		]
	);
});


has 'dv_id' 				=> ( is => 'ro', lazy => 1, default => sub { 'appdv-' . time } );
has 'dv_itemId' 			=> ( is => 'ro', lazy => 1, default => sub { 'item-' . (shift)->dv_id } );
has 'dv_itemSelector'	=> ( is => 'ro', default => 'div.dv_selector' );
has 'dv_baseconfig'		=> ( is => 'ro', default => sub {{}} );

has 'DataView'  => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $base = $self->dv_baseconfig;
	
	my $config = {
		store				=> $self->Module('datastore')->JsonStore,
		tpl				=> $self->xtemplate,
		autoHeight		=> \1,
		#multiSelect	=> \1,
		singleSelect	=> \1,
		itemSelector	=> $self->dv_itemSelector,
		#emptyText		=> 'No images to display',
		#style				=> 'overflow:auto; background-color: #FFFFFF;'
	};
	
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