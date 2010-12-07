package RapidApp::DataStore2;
use Moose;
extends 'RapidApp::AppCmp';

use strict;
use RapidApp::Include qw(sugar perlutil);
use String::Random;


has 'create_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'read_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'update_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'destroy_handler'	=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );


has 'record_pk' 			=> ( is => 'ro', default => undef );
has 'store_fields' 		=> ( is => 'ro', default => undef );
has 'storeId' 				=> ( is => 'ro', default => sub { 'datastore-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'store_use_xtype'	=> ( is => 'ro', default => 0 );
has 'store_autoLoad'		=> ( is => 'ro', default => sub {\0} );
has 'reload_on_save' 	=> ( is => 'ro', default => 1 );


sub BUILD {
	my $self = shift;
	
	$self->apply_actions( read		=> 'read' );
	$self->apply_actions( update	=> 'update' ) if (defined $self->update_handler);
	$self->apply_actions( create	=> 'create' ) if (defined $self->create_handler);
	$self->apply_actions( destroy	=> 'destroy' ) if (defined $self->destroy_handler);
	
	$self->add_listener( exception => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(DataProxy, type, action, options, response, arg) { ' .
				'if (action == "update" || action == "create") {' .
					'var store = ' . $self->getStore_code . ';' .
					'store.rejectChanges();' .
				'}' .
			'}' 
		)
	);
	
	$self->add_ONREQUEST_calls_late('store_init_onrequest');
};


sub store_init_onrequest {
	my $self = shift;

	$self->add_event_handlers([ 
		'write', 
		RapidApp::JSONFunc->new( raw => 1, func => 'function(store, action, result, res, rs) { store.load(); }' )
	]) if ($self->reload_on_save);
	
	$self->apply_extconfig( baseParams => $self->base_params ) if (
		defined $self->base_params and
		scalar keys %{ $self->base_params } > 0
	);
	
	$self->apply_extconfig(
		storeId 					=> $self->storeId,
		api 						=> $self->store_api,
		#baseParams 				=> $self->base_params,
		writer					=> $self->store_writer,
		autoLoad 				=> $self->store_autoLoad,
		autoSave 				=> \0,
		loadMask 				=> \1,
		autoDestroy 			=> \1,
		root 						=> 'rows',
		idProperty 				=> $self->record_pk,
		messageProperty 		=> 'msg',
		successProperty 		=> 'success',
		totalProperty 			=> 'results',
	);
}


sub JsonStore {
	my $self = shift;
	return RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $self->content
	);
}





# -- Moved from AppGrid2:
has 'columns' => ( is => 'rw', default => sub {{}}, isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );
has 'column_order' => ( is => 'rw', default => sub {[]}, isa => 'ArrayRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );

has 'include_columns' => ( is => 'ro', default => sub {[]} );
has 'exclude_columns' => ( is => 'ro', default => sub {[]} );

has 'include_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->include_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});

has 'exclude_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->exclude_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});


# Does the same thing as apply_columns, but the order is also set 
# (offset should be the first arg). Unlike apply_columns, column data
# must be passed as a normal Hash (not Hashref). This is required 
# because the order cannot be known
sub apply_columns_ordered {
	my $self = shift;
	my $offset = shift;
	
	die "invalid options passed to apply_columns_ordered" if (
		ref($offset) or
		ref($_[0])
	);
	
	my %columns = @_;
	
	# Get even indexed items from array (i.e. hash keys)
	my @col_names = @_[map { $_ * 2 } 0 .. int($#_ / 2)];
	
	$self->apply_columns(%columns);
	return $self->set_columns_order($offset,@col_names);
}

sub apply_columns {
	my $self = shift;
	my %column = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $name (keys %column) {
	
		next unless ($self->valid_colname($name));
	
		unless (defined $self->columns->{$name}) {
			$self->columns->{$name} = RapidApp::Column->new( name => $name );
			push @{ $self->column_order }, $name;
		}
		
		$self->columns->{$name}->apply_attributes(%{$column{$name}});
	}
	
	return $self->apply_config(columns => $self->column_list);
}


sub column_list {
	my $self = shift;
	
	my @list = ();
	foreach my $name (@{ $self->column_order }) {
		push @list, $self->columns->{$name}->get_grid_config;
	}
	
	return \@list;
}


sub apply_to_all_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $column (keys %{ $self->columns } ) {
		$self->columns->{$column}->apply_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}

sub apply_columns_list {
	my $self = shift;
	my $cols = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	die "type of arg 1 must be ArrayRef" unless (ref($cols) eq 'ARRAY');
	
	foreach my $column (@$cols) {
		$self->columns->{$column}->apply_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}


sub set_sort {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	return $self->apply_config( sort => { %opt } );
}


sub batch_apply_opts {
	my $self = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %opts) {
		if ($opt eq 'columns' and ref($opts{$opt}) eq 'HASH') {				$self->apply_columns($opts{$opt});				}
		elsif ($opt eq 'column_order') {		$self->set_columns_order(0,$opts{$opt});		}
		elsif ($opt eq 'sort') {				$self->set_sort($opts{$opt});						}
		elsif ($opt eq 'filterdata') {		$self->apply_config($opt => $opts{$opt});		}
		else { die "invalid option '$opt' passed to batch_apply_opts";							}
	}
}


sub valid_colname {
	my $self = shift;
	my $name = shift;
	
	if (scalar @{$self->exclude_columns} > 0) {
		return 0 if (defined $self->exclude_columns_hash->{$name});
	}
	
	if (scalar @{$self->include_columns} > 0) {
		return 0 unless (defined $self->include_columns_hash->{$name});
	}
	
	return 1;
}

sub set_columns_order {
	my $self = shift;
	my $offset = shift;
	my @cols = (ref($_[0]) eq 'ARRAY' and not defined $_[1]) ? @{ $_[0] } : @_; # <-- arg as list or arrayref
	
	my %cols_hash = ();
	foreach my $col (@cols) {
		die $col . " specified more than once" if ($cols_hash{$col}++);
	}
	
	my @pruned = ();
	foreach my $col (@{ $self->column_order }) {
		if ($cols_hash{$col}) {
			delete $cols_hash{$col};
		}
		else {
			push @pruned, $col;
		}
	}
	
	my @remaining = keys %cols_hash;
	if(@remaining > 0) {
		die "can't set the order of columns that do not already exist (" . join(',',@remaining) . ')';
	}
	
	splice(@pruned,$offset,0,@cols);
	
	@{ $self->column_order } = @pruned;
	
	return $self->apply_config(columns => $self->column_list);
}

# --



#############


sub read {
	my $self = shift;

	my $data = $self->read_raw;
	return $self->meta_json_packet($data);
}



sub read_raw {
	my $self = shift;
	
	if (defined $self->read_handler and $self->has_flag('can_read')) {
		
		my $params = $self->c->req->params;
		$params = $self->json->decode($self->c->req->params->{orig_params}) if (defined $self->c->req->params->{orig_params});
		
		my $data = $self->read_handler->call($params);
		
		die "unexpected data returned in read_raw" unless (
			ref($data) eq 'HASH' and 
			defined $data->{results} and
			ref($data->{rows}) eq 'ARRAY'
		);
		
		# data should be a hash with rows (arrayref) and results (number):
		return $data;
	}
	
	# empty set of data:
	return {
		results	=> 0,
		rows		=> []
	};
}


sub meta_json_packet {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# this "metaData" packet allows the store to be "reconfigured" on
	# any request. Uuseful for things such as changing the fields, which
	# we compute dynamically here from the first row of the data that was
	# returned (see store_fields_from_rows)
	return {
		metaData	=> {
			root => 'rows',
			idProperty => $self->record_pk,
			messageProperty => 'msg',
			successProperty => 'success',
			totalProperty => 'results',
			fields => defined $self->store_fields ? $self->store_fields : $self->store_fields_from_rows($opt{rows})
		},
		success	=> \1,
		%opt
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


sub update {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
	
	if (defined $params->{orig_params}) {
		my $orig_params = $self->json->decode($params->{orig_params});
		delete $params->{orig_params};
		
		# merge orig_params, preserving real params that are set:
		foreach my $k (keys %$orig_params) {
			next if (defined $params->{$k});
			$params->{$k} = $orig_params->{$k};
		}
	}
	
	#my $result = $self->update_records_coderef->($rows,$params);
	my $result = $self->update_handler->call($rows,$params);
	return $result if (
		ref($result) eq 'HASH' and
		defined $result->{success}
	);
	
	return {
		success => \1,
		msg => 'Update Succeeded'
	} if ($result);
	
	return {
		success => \0,
		msg => 'Update Failed'
	};
}




sub create {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
		
	my $result = $self->create_handler->call($rows);
	
	# we don't actually care about the new record, so we simply give the store back
	# the row it gave to us. We have to make sure that pk (primary key) is set to 
	# something or else it will throw an error
	$rows->{$self->record_pk} = 'dummy-key';
	
	# If the id of the new record was provided in the response, we'll use it:
	$rows = $result->{rows} if (ref($result) and defined $result->{rows} and defined $result->{rows}->{$self->record_pk});
	
	
	if (ref($result) and defined $result->{success} and defined $result->{msg}) {
		$result->{rows} = $rows;
		if ($result->{success}) {
			$result->{success} = \1;
		}
		else {
			$result->{success} = \0;
		}
		return $result;
	}
	
	
	if ($result and not (ref($result) and $result->{success} == 0 )) {
		return {
			success => \1,
			msg => 'Create Succeeded',
			rows => $rows
		}
	}
	
	if(ref($result) eq 'HASH') {
		$result->{success} = \0;
		$result->{msg} = 'Create Failed' unless (defined $result->{msg});
		return $result;
	}
	
	return {
		success => \0,
		msg => 'Create Failed'
	};
}




# not implemented yet:
sub destroy {}


has 'getStore' => ( is => 'ro', lazy => 1, default => sub { 
	my $self = shift;
	return $self->JsonStore unless ($self->has_JsonStore); # Return the JsonStore constructor if it hasn't been called yet
	return RapidApp::JSONFunc->new( 
		raw => 1, 
		func => $self->getStore_code
	);
});


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
	
	$api->{read}		= $self->suburl('/read')		if (defined $self->read_handler);
	$api->{update}		= $self->suburl('/update')		if (defined $self->update_handler);
	$api->{create}		= $self->suburl('/create')		if (defined $self->create_handler);
	$api->{destroy}	= $self->suburl('/destroy')	if (defined $self->destroy_handler);
	
	return $api;
});



has 'store_writer' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	return undef unless (
		defined $self->update_handler or 
		defined $self->create_handler or
		defined $self->destroy_handler
	);
	
	my $writer = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonWriter',
		parm => {
			encode => \1,
			writeAllFields => \1
	});
	
	return $writer;
});






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;