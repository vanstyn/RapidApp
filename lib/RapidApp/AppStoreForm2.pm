package RapidApp::AppStoreForm2;
use Moose;
extends 'RapidApp::AppCmp';

use strict;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DataStore2;

has 'reload_on_save' 	=> ( is => 'ro', default => 0 );
has 'record_pk'			=> ( is => 'ro', default => 'id' );
has 'DataStore_class'	=> ( is => 'ro', default => 'RapidApp::DataStore2' );


sub BUILD {
	my $self = shift;
	
	my $store_params = { record_pk => $self->record_pk };
	
	if ($self->can('create_records')) {
		$self->apply_flags( can_create => 1 ) unless ($self->flag_defined('can_create'));
		$store_params->{create_handler}	= RapidApp::Handler->new( scope => $self, method => 'create_records' ) if ($self->has_flag('can_create'));
	}
	
	if ($self->can('read_records')) {
		$self->apply_flags( can_read => 1 ) unless ($self->flag_defined('can_read'));
		$store_params->{read_handler}	= RapidApp::Handler->new( scope => $self, method => 'read_records' ) if ($self->has_flag('can_read'));
	}
	
	if ($self->can('update_records')) {
		$self->apply_flags( can_update => 1 ) unless ($self->flag_defined('can_update'));
		$store_params->{update_handler}	= RapidApp::Handler->new( scope => $self, method => 'update_records' ) if ($self->has_flag('can_update'));
	}
	
#	if ($self->can('destroy_records')) {
#		$self->apply_flags( can_destroy => 1 ) unless ($self->flag_defined('can_destroy'));
#		$store_params->{destroy_handler}	= RapidApp::Handler->new( scope => $self, method => 'destroy_records' ) if ($self->has_flag('can_destroy'));
#	}
	
	$self->apply_modules( store => {
		class		=> $self->DataStore_class,
		params	=> $store_params
	});
	
	#init the store with all of our flags:
	$self->Module('store',1)->apply_flags($self->all_flags);
	
	$self->Module('store',1)->add_listener( load => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.store_load_handler' ));	
	$self->Module('store',1)->add_listener( write => RapidApp::JSONFunc->new( raw => 1, func =>  'function(store) { store.load(); }' )) if ($self->reload_on_save); 

	
#	$self->Module('store',1)->apply_listeners(
#
#		load => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.store_load_handler' ),
#
#		write => RapidApp::JSONFunc->new( raw => 1, func => 
#			'function(store, action, result, res, rs) { ' .
#				'console.log("write event");' . 
#				($self->reload_on_save ? 'store.load();' : '') .
#			'}' 
#		)
#	);


	$self->apply_extconfig(
		xtype		=> 'appstoreform2',
		trackResetOnLoad => \1
	);

	$self->add_listener( clientvalidation	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.clientvalidation_handler' ) );
	$self->add_listener( afterrender			=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.afterrender_handler' ) );

#	$self->apply_listeners(
#		clientvalidation	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.clientvalidation_handler' ),
#		afterrender			=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.afterrender_handler' )
#	);
	
	$self->add_ONREQUEST_calls('init_onrequest');
}


sub init_onrequest {
	my $self = shift;
	$self->Module('store',1)->apply_extconfig( baseParams => $self->get_store_base_params );
	$self->apply_extconfig( 
		id 		=> $self->instance_id,
		tbar 		=> $self->formpanel_tbar,
		items 	=> $self->formpanel_items,
		store		=> $self->Module('store')->JsonStore,
	);
}



sub get_store_base_params {
	my $self = shift;
	
	my $params = {};

	my $encoded = $self->c->req->params->{base_params};
	if (defined $encoded) {
		my $decoded = $self->json->decode($encoded) or die "Failed to decode base_params JSON";
		foreach my $k (keys %$decoded) {
			$params->{$k} = $decoded->{$k};
		}
	}
	
	my $keys = [];
#	if (ref($self->item_keys) eq 'ARRAY') {
#		$keys = $self->item_keys;
#	}
#	else {
#		push @$keys, $self->item_keys;
#	}
	
	push @$keys, $self->record_pk;
	
	my $orig_params = {};
	my $orig_params_enc = $self->c->req->params->{orig_params};
	$orig_params = $self->json->decode($orig_params_enc) if (defined $orig_params_enc);
	
	foreach my $key (@$keys) {
		$params->{$key} = $orig_params->{$key} if (defined $orig_params->{$key});
		$params->{$key} = $self->c->req->params->{$key} if (defined $self->c->req->params->{$key});
	}
	
	return $params;
}




############# Buttons #################
has 'button_text_cls' => ( is => 'ro', default => 'tbar-button-medium' );
has 'button_scale' => ( is => 'ro',	default => 'medium'	);

has 'reload_button_text' => ( is => 'ro',	default => ' Reload '	);
has 'reload_button_iconCls' => ( is => 'ro',	default => 'icon-refresh-24x24'	);
has 'reload_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->reload_button_text . '</div>',
			iconCls	=> $self->reload_button_iconCls,
			itemId	=> 'reload-btn',
			scale		=> $self->button_scale,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.reload_handler' ) 
	});
}

has 'save_button_text' => ( is => 'ro',	default => ' Save '	);
has 'save_button_iconCls' => ( is => 'ro',	default => 'icon-save-24x24'	);
has 'save_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->save_button_text . '</div>',
			iconCls	=> $self->save_button_iconCls,
			itemId	=> 'save-btn',
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.save_handler' ) 
	});
}


has 'add_button_text' => ( is => 'ro',	default => ' Add '	);
has 'add_button_iconCls' => ( is => 'ro',	default => 'icon-add-24x24'	);
has 'add_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_add_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->add_button_text . '</div>',
			iconCls	=> $self->add_button_iconCls,
			itemId	=> 'add-btn',
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.add_handler' ) 
	});
}
###############################################




has 'tbar_icon' => ( is => 'ro', default => undef );
#has 'tbar_title' => ( is => 'ro', default => undef );
has 'formpanel_items' => ( is => 'ro', default => sub {[]} );


has 'tbar_title_text_cls' => ( is => 'ro', default => 'tbar-title-medium' );
#has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
#sub _build_formpanel_tbar {
sub formpanel_tbar {

	my $self = shift;
	
	my $Store = $self->Module('store',1);
	
	my $items = [];
		
	push @$items, '<img src="' . $self->tbar_icon . '">' if (defined $self->tbar_icon);
	push @$items, '<div class="' . $self->tbar_title_text_cls . '">' . $self->tbar_title . '</div>' if (defined $self->tbar_title);
	
	push @$items, '->';
	
	push @$items, $self->add_button if (defined $Store->create_handler and $Store->has_flag('can_create'));
	push @$items, $self->reload_button if (defined $Store->read_handler and not $Store->has_flag('can_create') and $Store->has_flag('can_read'));
	push @$items, '-' if (defined $Store->read_handler and defined $Store->update_handler and $Store->has_flag('can_read') and $Store->has_flag('can_update'));
	push @$items, $self->save_button if (defined $Store->update_handler and $Store->has_flag('can_update'));
	
	return {
		items => $items
	};
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;