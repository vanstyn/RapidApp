package RapidApp::Role::DataStore;


use strict;
use Moose::Role;
#with 'RapidApp::Role::Controller';
#extends 'RapidApp::AppBase';

use String::Random;

use Term::ANSIColor qw(:constants);

has 'record_pk' 			=> ( is => 'ro', default => undef );
has 'store_fields' 		=> ( is => 'ro', default => undef );
has 'storeId' 				=> ( is => 'ro', default => sub { 'datastore-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );

has 'store_autoLoad'		=> ( is => 'ro', default => sub {\1} );

#has 'base_params' => ( is => 'ro', lazy => 1, default => sub {
#	my $self = shift;
#	return $self->parent_module->base_params;
#});


## Coderefs ##
has 'read_records_coderef' 	=> ( is => 'ro', default => undef );
has 'update_records_coderef'	=> ( is => 'ro', default => undef );
has 'create_records_coderef'	=> ( is => 'ro', default => undef );
has 'delete_records_coderef'	=> ( is => 'ro', default => undef );

has 'actions' => ( is => 'ro', lazy => 1, default => sub {{}} ); # Dummy placeholder
around 'actions' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $actions = $self->$orig(@_);
	
	$actions->{read}		= sub { $self->store_read };
	$actions->{update}	= sub { $self->store_update } if (defined $self->update_records_coderef);
	$actions->{create}	= sub { $self->store_create } if (defined $self->create_records_coderef);
	$actions->{delete}	= sub { $self->store_delete } if (defined $self->delete_records_coderef);
	
	return $actions;
};
#############

sub store_read {
	my $self = shift;
	
	my $results = 0;
	my $fields = [];
	$fields = $self->store_fields if (defined $self->store_fields);
	my $rows = [];

	if (defined $self->read_records_coderef) {
		my $data = $self->read_records_coderef->() or die "Failed to read records with read_records_coderef";
		$rows			= $data->{rows};
		$fields 		= $self->store_fields_from_rows($rows) unless (defined $self->store_fields);
		$results 	= $data->{results};
	}
	# If there is no read_data_coderef this will be an add-only StoreForm and we'll
	# return a store with no records.

	return {
		metaData => {
			fields => $fields,
			root => 'rows',
			idProperty => $self->record_pk,
			messageProperty => 'msg',
			successProperty => 'success',
			totalProperty => 'results',
		},
		success => \1,
		results => $results,
		rows => $rows
	};
}

sub store_fields_from_rows {
	my $self = shift;
	my $rows = shift;
	
	# for performance we'll assume that the first row contains all the field types:
	my $row = $rows->[0];
	
	my $fields = [];
	foreach my $k (keys %$row) {
		push @$fields, { name => $k };
	}
	return $fields;
}





# not implemented yet:
sub store_update {}
sub store_create {}
sub store_delete {}



has 'getStore_code' => ( is => 'ro', lazy_build => 1 );
sub _build_getStore_code {
	my $self = shift;
	return 'Ext.StoreMgr.lookup("' . $self->storeId . '")';
}

has 'store_load_code' => ( is => 'ro', lazy_build => 1 );
sub _build_store_load_code {
	my $self = shift;
	return $self->getStore_code . '.load()';
}

has 'store_api' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $api = {};
	
	$api->{read}	= $self->suburl('/read')		if (defined $self->actions->{read});
	$api->{update}	= $self->suburl('/update')		if (defined $self->actions->{update});
	$api->{create}	= $self->suburl('/create')		if (defined $self->actions->{create});
	$api->{delete}	= $self->suburl('/delete')		if (defined $self->actions->{delete});
	
	return $api;
});


has 'store_load_listener' => ( is => 'ro', default => undef );
has 'store_update_listener' => ( is => 'ro', default => undef );
has 'store_save_listener' => ( is => 'ro', default => undef );
has 'store_write_listener' => ( is => 'ro', default => undef );
has 'store_add_listener' => ( is => 'ro', default => undef );
has 'store_exception_listener' => ( is => 'ro', default => undef );

has 'store_listeners' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $listeners;
	
	$listeners->{load} 		= $self->store_load_listener if (defined $self->store_load_listener);
	$listeners->{update}		= $self->store_update_listener if (defined $self->store_update_listener);
	$listeners->{save} 		= $self->store_save_listener if (defined $self->store_save_listener);
	$listeners->{write} 		= $self->store_write_listener if (defined $self->store_write_listener);
	$listeners->{add} 		= $self->store_add_listener if (defined $self->store_add_listener);
	$listeners->{exception} = $self->store_exception_listener if (defined $self->store_exception_listener);

	return $listeners;
});

has 'store_writer' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	return undef unless (
		defined $self->actions->{update} or 
		defined $self->actions->{create} or
		defined $self->actions->{delete}
	);
	
	my $writer = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonWriter',
		parm => {
			encode => \1,
			writeAllFields => \1
	});
	
	return $writer;
});

sub JsonStore {
#has 'JsonStore' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $config = {
		#exception_callback 	=> $self->exception_callback,
		#write_callback 		=> $self->write_callback,
		#create_callback 		=> $self->create_callback,
		storeId 					=> $self->storeId,
		api 						=> $self->store_api,
		baseParams 				=> $self->base_params,
		listeners				=> $self->store_listeners,
		writer					=> $self->store_writer,
		
		#autoLoad => \1,
		autoLoad => $self->store_autoLoad,
		autoSave => \0,
		loadMask => \1,
		autoDestroy => \1,
		
		root => 'rows',
		idProperty => $self->record_pk,
		messageProperty => 'msg',
		successProperty => 'success',
		totalProperty => 'results',
	};
	
	foreach my $k (keys %$config) {
		delete $config->{$k} unless (defined $config->{$k});
	}
	
	my $JsonStore = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $config
	);
	
	return $JsonStore;
}







#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;