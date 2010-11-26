package RapidApp::Role::DataStore;
use Moose::Role;

use strict;

use String::Random;

use Term::ANSIColor qw(:constants);

sub BUILD {}
after 'BUILD' => sub {
	my $self = shift;
	
	$self->apply_actions( read		=> 'store_read' );
	$self->apply_actions( update	=> 'store_update' ) if (defined $self->update_records_coderef);
	$self->apply_actions( create	=> 'store_create' ) if (defined $self->create_records_coderef);
	$self->apply_actions( destroy	=> 'store_destroy' ) if (defined $self->destroy_records_coderef);
};


before 'ONREQUEST' => sub {
	my $self = shift;
	
	$self->apply_store_listeners( load 			=> $self->store_load_listener ) if (defined $self->store_load_listener);
	$self->apply_store_listeners( update 		=> $self->store_update_listener ) if (defined $self->store_update_listener);
	$self->apply_store_listeners( save 			=> $self->store_save_listener ) if (defined $self->store_save_listener);
	
	$self->apply_store_listeners( add 			=> $self->store_add_listener ) if (defined $self->store_add_listener);
	$self->apply_store_listeners( exception	=> $self->store_exception_listener ) if (defined $self->store_exception_listener);
	
	$self->apply_store_listeners( write => RapidApp::JSONFunc->new( raw => 1, func => 
		'function(store, action, result, res, rs) { ' .
			'Ext.log("write event");' . 
			($self->reload_on_save ? 'store.load();' : '') .
		'}'
	));
	
};

has 'store_listeners' => ( is => 'ro', default => sub {{}}, isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );

has 'store_load_listener' => ( is => 'ro', default => undef );
has 'store_update_listener' => ( is => 'ro', default => undef );
has 'store_save_listener' => ( is => 'ro', default => undef );
has 'store_add_listener' => ( is => 'ro', default => undef );
has 'store_exception_listener' => ( is => 'ro', default => undef );

has 'record_pk' 			=> ( is => 'ro', default => undef );
has 'store_fields' 		=> ( is => 'ro', default => undef );
has 'storeId' 				=> ( is => 'ro', default => sub { 'datastore-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'store_use_xtype'	=> ( is => 'ro', default => 0 );
has 'store_autoLoad'		=> ( is => 'ro', default => sub {\1} );
has 'reload_on_save' 		=> ( is => 'ro', default => 1 );


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
		elsif ($opt eq 'filterdata') {		$self->apply_store_config($opt => $opts{$opt});		}
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


#has 'base_params' => ( is => 'ro', lazy => 1, default => sub {
#	my $self = shift;
#	return $self->parent_module->base_params;
#});

has 'store_config' => ( is => 'ro', default => sub {{}}, isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );

# Merge/overwrite store_config hash
sub apply_store_config {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%{ $self->store_config } = (
		%{ $self->store_config },
		%new
	);
}


# Merge in only hash keys that do not already exist:
sub applyIf_store_config {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %new) {
		next if (defined $self->store_config->{$opt});
		$self->store_config->{$opt} = $new{$opt};
	}
}


## Coderefs ##
has 'read_records_coderef' 	=> ( is => 'rw', default => undef );
has 'update_records_coderef'	=> ( is => 'rw', default => undef );
has 'create_records_coderef'	=> ( is => 'rw', default => undef );
has 'destroy_records_coderef'	=> ( is => 'rw', default => undef );


#############

sub store_read {
	my $self = shift;
	my $data = $self->store_read_raw;
	return $self->store_meta_json_packet($data);
}

sub store_read_raw {
	my $self = shift;
	
	if (defined $self->read_records_coderef or $self->can('read_records')) {
		
		my $data;
		if ($self->can('read_records')) {
			$data = $self->read_records;
		}
		else {
			$data = $self->read_records_coderef->() or die "Failed to read records with read_records_coderef";
		}
		
		die "unexpected data returned in store_read_raw" unless (
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


sub store_meta_json_packet {
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


sub store_update {
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
	
	my $result = $self->update_records_coderef->($rows,$params);
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

# not implemented yet:
sub store_create {}
sub store_destroy {}


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
	
	$api->{read}		= $self->suburl('/read')		if (defined $self->actions->{read});
	$api->{update}		= $self->suburl('/update')		if (defined $self->actions->{update});
	$api->{create}		= $self->suburl('/create')		if (defined $self->actions->{create});
	$api->{destroy}	= $self->suburl('/destroy')	if (defined $self->actions->{destroy});
	
	return $api;
});


# Merge/overwrite store_listeners hash
sub apply_store_listeners {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%{ $self->store_listeners } = (
		%{ $self->store_listeners },
		%new
	);
}

# Merge in only hash keys that do not already exist:
sub applyIf_store_listeners {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %new) {
		next if (defined $self->store_listeners->{$opt});
		$self->store_listeners->{$opt} = $new{$opt};
	}
}


has 'store_writer' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	return undef unless (
		defined $self->actions->{update} or 
		defined $self->actions->{create} or
		defined $self->actions->{destroy}
	);
	
	my $writer = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonWriter',
		parm => {
			encode => \1,
			writeAllFields => \1
	});
	
	return $writer;
});


sub JsonStore_config_apply {
	my $self = shift;
	
	return $self->apply_store_config(
		storeId 					=> $self->storeId,
		api 						=> $self->store_api,
		baseParams 				=> $self->base_params,
		listeners				=> $self->store_listeners,
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



#sub JsonStore {
has 'JsonStore' => ( is => 'ro', lazy => 1, predicate => 'has_JsonStore', default => sub {
	my $self = shift;
	
	$self->JsonStore_config_apply;
	
	my $config = $self->store_config;
	
	foreach my $k (keys %$config) {
		delete $config->{$k} unless (defined $config->{$k});
	}
	
	if ($self->store_use_xtype) {
		$config->{xtype} = 'jsonstore';
		return $config;
	}
	
	my $JsonStore = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $config
	);
	
	return $JsonStore;
#}
});





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;