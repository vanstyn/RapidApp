package RapidApp::DataStore;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use Term::ANSIColor qw(:constants);

has 'record_pk' 			=> ( is => 'ro', default => undef );
has 'store_fields' 		=> ( is => 'ro', default => undef );
has 'storeId' 				=> ( is => 'ro', default => sub { 'datastore-' . time } );


## Coderefs ##
has 'read_records_coderef' 	=> ( is => 'ro', default => undef );
has 'update_records_coderef'	=> ( is => 'ro', default => undef );
has 'create_records_coderef'	=> ( is => 'ro', default => undef );
has 'delete_records_coderef'	=> ( is => 'ro', default => undef );

has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $actions = {};
	
	$actions->{read}		= sub { $self->read };
	$actions->{update}	= sub { $self->update } if (defined $self->update_records_coderef);
	$actions->{create}	= sub { $self->create } if (defined $self->create_records_coderef);
	$actions->{delete}	= sub { $self->delete } if (defined $self->delete_records_coderef);
	
	return $actions;
});
#############

sub read {
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
sub update {}
sub create {}
sub delete {}



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

has 'store_listeners' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $listeners = {
		load => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(store,records,options) { ' .
				'Ext.log("load event");' . 
				'try {' .
					'var form = Ext.getCmp("' . $self->formpanel_id . '").getForm();' .
					'var Record = records[0];' .
					'if(!Record) return;' . 
					'form.loadRecord(Record);' .
					'store.setBaseParam("orig_params",Ext.util.JSON.encode(Record.data));' .
				'} catch(err) { Ext.log(err); }' .
			'}'
		),
		update => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(store, record, operation) { ' .
				'Ext.log("update event");' . 
				'Ext.log(operation);' . 
				#'record.commit();' .
			'}' 
		),
		save => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(store, batch, data) { ' .
				'Ext.log("save event");' . 
			'}' 
		),
		write => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(store, action, result, res, rs) { ' .
				'Ext.log("write event");' . 
				($self->reload_on_save ? 'store.load();' : '') .
				'store.write_callback.apply(this,arguments);' .
			'}' 
		),
		add => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(store, batch, data) { ' .
				'Ext.log("add event");' . 
			'}' 
		),
		exception => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(DataProxy, type, action, options, response, arg) { ' .
				'Ext.log("exception event -> action: " + action);' .
				'if (action == "update" || action == "create") {' .
					'var store = ' . $self->getStore_code . ';' .
					'store.rejectChanges();' .
					'store.exception_callback.apply(this,arguments);' .
				'}' .
			'}' 
		)
	};

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
	my $self = shift;
	
	my $config = {
		#exception_callback 	=> $self->exception_callback,
		#write_callback 		=> $self->write_callback,
		#create_callback 		=> $self->create_callback,
		storeId 					=> $self->storeId,
		api 						=> $self->store_api,
		baseParams 				=> $self->base_params,
		#listeners				=> $self->listeners,
		
		autoLoad => \1,
		autoSave => \0,
		loadMask => \1,
		autoDestroy => \1,
		
		root => 'rows',
		idProperty => $self->record_pk,
		messageProperty => 'msg',
		successProperty => 'success',
		totalProperty => 'results',
	};
	
	$config->{writer} = $self->store_writer if (defined $self->store_writer);
	
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