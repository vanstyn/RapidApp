package RapidApp::Role::DataStore;
use Moose::Role;

use strict;
use RapidApp::Include qw(sugar perlutil);
use String::Random;

use RapidApp::DataStore;


sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	
#	my $params = {};
#	foreach my $attr ($self->meta->get_all_attributes) {
#		$params->{$attr->name} = $attr->get_value($self);
#	}
#	
#	$self->c->log->debug(BOLD . BLUE . ref($self) . ': ' . Dumper($params) . CLEAR);
	
	print STDERR BOLD . BLUE . ref($self) . ': ' . $self->dump(1) . CLEAR;
	
	
	# Note: DO NOT call apply_init_modules here:
	$self->apply_modules( store => {
		class	=> 'RapidApp::DataStore',
		params	=> {
			#%$params,
			store_read_obj => $self,
			record_pk	=> $self->record_pk,
			item_key		=> $self->record_pk,
			item_keys	=> [$self->record_pk],
			store_autoLoad => $self->store_autoLoad,
			read_records_coderef => sub { return $self->read_records_link; },
			update_records_coderef => sub { return $self->update_records_link; },
		}
	});
	
	# init:
	$self->Module('store')->content;
	
	$self->DataStore($self->Module('store'));
	
	
	$self->apply_store_listeners( load 			=> $self->store_load_listener ) if (defined $self->store_load_listener);
	$self->apply_store_listeners( update 		=> $self->store_update_listener ) if (defined $self->store_update_listener);
	$self->apply_store_listeners( save 			=> $self->store_save_listener ) if (defined $self->store_save_listener);
	$self->apply_store_listeners( add 			=> $self->store_add_listener ) if (defined $self->store_add_listener);
	$self->apply_store_listeners( exception	=> $self->store_exception_listener ) if (defined $self->store_exception_listener);
	

};


after 'ONREQUEST' => sub {
	my $self = shift;
	
	$self->apply_config( columns => $self->column_list ) if ($self->can('apply_config'));

};

has 'DataStore' => (
	is			=> 'rw',
	isa		=> 'RapidApp::DataStore',
	handles => {
		JsonStore					=> 'JsonStore',
		JsonStore_config_apply	=> 'JsonStore_config_apply',
		store_read					=> 'store_read',
		#store_read_raw				=> 'store_read_raw',
		columns						=> 'columns',
		column_order				=> 'column_order',
		include_columns			=> 'include_columns',
		exclude_columns			=> 'exclude_columns',
		include_columns_hash		=> 'include_columns_hash',
		exclude_columns_hash		=> 'exclude_columns_hash',
		apply_columns				=> 'apply_columns',
		column_list					=> 'column_list',
		apply_to_all_columns		=> 'apply_to_all_columns',
		apply_columns_list		=> 'apply_columns_list',
		set_sort						=> 'set_sort',
		batch_apply_opts			=> 'batch_apply_opts',
		set_columns_order			=> 'set_columns_order',
		record_pk					=> 'record_pk',
		getStore						=> 'getStore',
		getStore_code				=> 'getStore_code',
		store_load_code			=> 'store_load_code',
		store_listeners			=> 'listeners',
		apply_store_listeners	=> 'apply_listeners',
		apply_store_config		=> 'apply_config',
		valid_colname				=> 'valid_colname',
		apply_columns_ordered	=> 'apply_columns_ordered',
	
	}
);

sub store_read_raw {
	my $self = shift;
	return $self->Module('store')->store_read_raw(@_);
}


sub read_records_link {
	my $self = shift;
	return $self->read_records if ($self->can('read_records'));
	return $self->read_records_coderef->();
}

sub update_records_link {
	my $self = shift;
	return $self->update_records if ($self->can('update_records'));
	return $self->update_records_coderef->();
}


has 'record_pk' 			=> ( is => 'ro', default => undef );
#sub item_key { (shift)->record_pk(@_) }

has 'store_autoLoad'		=> ( is => 'ro', default => sub {\1} );

has 'store_load_listener' => ( is => 'ro', default => undef );
has 'store_update_listener' => ( is => 'ro', default => undef );
has 'store_save_listener' => ( is => 'ro', default => undef );
has 'store_add_listener' => ( is => 'ro', default => undef );
has 'store_exception_listener' => ( is => 'ro', default => undef );





no Moose;
#__PACKAGE__->meta->make_immutable;
1;