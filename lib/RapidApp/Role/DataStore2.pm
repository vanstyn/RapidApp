package RapidApp::Role::DataStore2;
use Moose::Role;

use strict;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DataStore2;

has 'record_pk'			=> ( is => 'ro', default => 'id' );
has 'DataStore_class'	=> ( is => 'ro', default => 'RapidApp::DataStore2' );


sub BUILD {}
before 'BUILD' => sub {
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
	
	if ($self->can('destroy_records')) {
		$self->apply_flags( can_destroy => 1 ) unless ($self->flag_defined('can_destroy'));
		$store_params->{destroy_handler}	= RapidApp::Handler->new( scope => $self, method => 'destroy_records' ) if ($self->has_flag('can_destroy'));
	}
	
	$self->apply_modules( store => {
		class		=> $self->DataStore_class,
		params	=> $store_params
	});
	
	#init the store with all of our flags:
	$self->Module('store',1)->apply_flags($self->all_flags);
	
	$self->add_ONREQUEST_calls('store_init_onrequest');
};


sub store_init_onrequest {
	my $self = shift;
	my $params = $self->get_store_base_params;
	$self->Module('store',1)->apply_extconfig( baseParams => $params ) if (defined $params);
	$self->apply_extconfig( store => $self->Module('store')->JsonStore );
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
	
	return undef unless (scalar keys %$params > 0);
	return $params;
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;