package RapidApp::DataStore2;
use Moose;
extends 'RapidApp::AppCmp';

use strict;
use RapidApp::Include qw(sugar perlutil);
use String::Random;
use RapidApp::Column;

use Text::Glob qw( match_glob );

has 'create_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'read_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'update_handler'		=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );
has 'destroy_handler'	=> ( is => 'ro', default => undef,	isa => 'Maybe[RapidApp::Handler]' );

# global variable/flag (set/localized in RapidApp::Role::DataStore2)
our $BATCH_UPDATE_IN_PROGRESS = 0;

has 'record_pk' 			=> ( is => 'ro', default => undef );
has 'store_fields' 		=> ( is => 'ro', default => undef );
has 'storeId' 				=> ( is => 'ro', default => sub { 'datastore-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'store_use_xtype'	=> ( is => 'ro', default => 0 );
has 'store_autoLoad'		=> ( is => 'rw', default => sub {\0} );
has 'reload_on_save' 	=> ( is => 'ro', default => 1 );

has 'max_pagesize'		=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );


has 'onrequest_columns_mungers' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_onrequest_columns_mungers		=> 'uniq',
		add_onrequest_columns_mungers		=> 'push',
		insert_onrequest_columns_mungers	=> 'unshift',
		has_no_onrequest_columns_mungers => 'is_empty',
	}
);

has 'read_raw_mungers' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_read_raw_mungers		=> 'uniq',
		add_read_raw_mungers		=> 'push',
		insert_read_raw_mungers	=> 'unshift',
		has_no_read_raw_mungers => 'is_empty',
	}
);


has 'update_mungers' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_update_mungers		=> 'uniq',
		add_update_mungers		=> 'push',
		insert_update_mungers	=> 'unshift',
		has_no_update_mungers 	=> 'is_empty',
	}
);



has 'base_params_mungers' => (
	traits    => [ 'Array', 'RapidApp::Role::PerRequestBuildDefReset' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_base_params_mungers		=> 'uniq',
		add_base_params_mungers		=> 'push',
		has_no_base_params_mungers => 'is_empty',
	}
);

has 'base_keys' => (
	traits    => [	'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef',
	default   => sub { [] },
	handles => {
		add_base_keys	=> 'push',
		base_keys_list	=> 'uniq'
	}
);

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
	
	$self->add_listener( write => RapidApp::JSONFunc->new( raw => 1, func => 
		'function(store, action, result, res, rs) { store.reload(); }' 
	)) if ($self->reload_on_save);
	
	
	$self->add_base_keys($self->record_pk);
	
	# If this isn't in late we get a deep recursion error:
	$self->add_ONREQUEST_calls('store_init_onrequest');
};


sub store_init_onrequest {
	my $self = shift;
	
	unless ($self->has_no_onrequest_columns_mungers) {
		foreach my $Handler ($self->all_onrequest_columns_mungers) {
			$Handler->call($self->columns);
		}
	}
	
	$self->apply_extconfig( baseParams => $self->base_params ) if (
		defined $self->base_params and
		scalar keys %{ $self->base_params } > 0
	);
	
	$self->apply_extconfig(
		storeId 					=> $self->storeId,
		api 						=> $self->store_api,
		#baseParams 				=> $self->base_params,
		writer					=> $self->store_writer,
		#autoLoad 				=> $self->store_autoLoad,
		autoSave 				=> \0,
		loadMask 				=> \1,
		autoDestroy 			=> \1,
		root 						=> 'rows',
		idProperty 				=> $self->record_pk,
		messageProperty 		=> 'msg',
		successProperty 		=> 'success',
		totalProperty 			=> 'results',
		#columns 					=> $self->column_list
	);
	
	# Set this to an object so that it can be modified in javascript
	# *after* the store has been constructed:
	$self->apply_extconfig( store_autoLoad => { params => {
		start => 0,
		limit => $self->max_pagesize ? $self->max_pagesize : 400
	}}) if (jstrue $self->store_autoLoad); 
	
	# If there is no Catalyst request, we can't get the base params:
	if (defined $self->c) {
		my $params = $self->get_store_base_params;
		$self->apply_extconfig( baseParams => $params ) if (defined $params);
	}
	
}


sub JsonStore {
	my $self = shift;
	
	return {
		%{ $self->content },
		xtype => 'jsonstore'
	} if ($self->store_use_xtype);
	
	return RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $self->content
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
	
	#push @$keys, $self->record_pk;
	
	my $orig_params = {};
	my $orig_params_enc = $self->c->req->params->{orig_params};
	$orig_params = $self->json->decode($orig_params_enc) if (defined $orig_params_enc);
	
	#foreach my $key (@$keys) {
	foreach my $key ($self->base_keys_list) {
		$params->{$key} = $orig_params->{$key} if (defined $orig_params->{$key});
		$params->{$key} = $self->c->req->params->{$key} if (defined $self->c->req->params->{$key});
	}
	
	unless ($self->has_no_base_params_mungers) {
		foreach my $Handler ($self->all_base_params_mungers) {
			$Handler->call($params);
		}
	}
	
	return undef unless (scalar keys %$params > 0);
	
	return $params;
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

sub has_column {
	my $self = shift;
	my $col = shift;
	return 0 if ($self->deleted_column_names->{$col});
	return 1 if (exists $self->columns->{$col}); 
	return 0;
}

sub get_column {
	my $self = shift;
	my $col = shift;
	return undef unless ($self->has_column($col));
	return $self->columns->{$col};
}


has 'deleted_column_names', is => 'ro', isa => 'HashRef', default => sub {{}}, traits => ['RapidApp::Role::PerRequestBuildDefReset'];
sub delete_columns {
	my $self = shift;
	my @columns = @_;
	my %indx = map {$_=>1} @columns;
	
	# Besides deleting the column, add it to deleted_column_names to prevent
	# it from being added back with apply_columns. This is just to prevent
	# columns previously deleted from coming back which is probably not
	# expected for desired. (although this could be considered breaking the API)
	# This also means that columns can be deleted proactively (before they are added)
	# -- This may be redundant to exclude_columns, need to look into combining these --
	$self->deleted_column_names->{$_} = 1 for (@columns);
	
	# vvv -- deleted columns are now filtered out in column_list instead of using the below code -- vvv
	
	## Delete by filtering out supplied column names:
	#%{$self->columns} = map { $_ => $self->columns->{$_} } grep { !$indx{$_} } keys %{$self->columns};
	#@{$self->column_order} = uniq(grep { !$indx{$_} } @{$self->column_order});
	#
	##TODO: what happens if removed column had a read_raw_mungers/update_mungers?
	#
	#return $self->apply_columns;
}


sub get_columns_wildcards {
	my $self = shift;
	my @globspecs = @_;
	my %cols = ();
	
	foreach my $gl (@globspecs) {
		match_glob($gl,$_) and $cols{$_} = 1 for ($self->column_name_list);
	}
	
	return keys %cols;
}


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
	
	# Filter out previously deleted column names:
	#%columns = map {$_=>$columns{$_}} grep { !$self->deleted_column_names->{$_} } keys %columns;
	
	# Get even indexed items from array (i.e. hash keys)
	my @col_names = @_[map { $_ * 2 } 0 .. int($#_ / 2)];
	
	$self->apply_columns(%columns);
	return $self->set_columns_order($offset,@col_names);
}

sub apply_columns {
	my $self = shift;
	my %columns = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	# Filter out previously deleted column names:
	#%columns = map {$_=>$columns{$_}} grep { !$self->deleted_column_names->{$_} } keys %columns;
	
	foreach my $name (keys %columns) {
	
		next unless ($self->valid_colname($name));
	
		unless (defined $self->columns->{$name}) {
			$self->columns->{$name} = RapidApp::Column->new( name => $name );
			push @{ $self->column_order }, $name;
		}
		
		$self->columns->{$name}->apply_attributes(%{$columns{$name}});
		
		$self->add_read_raw_mungers($self->columns->{$name}->read_raw_munger) if ($self->columns->{$name}->read_raw_munger);
		$self->add_update_mungers($self->columns->{$name}->update_munger) if ($self->columns->{$name}->update_munger);
	}
	
	return $self->apply_config(columns => $self->column_list);
}

sub column_name_list {
	my $self = shift;
	return grep { !$self->deleted_column_names->{$_} } @{$self->column_order};
}

sub column_list {
	my $self = shift;
	
	# new, safer way to way to handle deleted columns
	my @colnames = $self->column_name_list;
	
	my @list = ();
	foreach my $name (@colnames) {
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

sub applyIf_to_all_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $column (keys %{ $self->columns } ) {
		$self->columns->{$column}->applyIf_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}

sub apply_columns_list {
	my $self = shift;
	my $cols = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	die "type of arg 1 must be ArrayRef" unless (ref($cols) eq 'ARRAY');
	
	foreach my $column (@$cols) {
		croak "Can't apply_attributes because column '$column' is not defined\n" unless (defined $self->columns->{$column});
		$self->columns->{$column}->apply_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}

# Pass a coderef and opts hash to apply columns. Coderef is called for each existing,
# non-deleted column. Column name is supplied to the coderef as $_ (and the first arg)
# For columns where the coderef returns true, the opts are applied.
sub apply_coderef_columns {
	my $self = shift;
	my $coderef = shift;
	
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$coderef->($_) and $self->columns->{$_}->apply_attributes(%opt) 
		for ($self->column_name_list);
	
	return $self->apply_config(columns => $self->column_list);
}

sub set_sort {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	return $self->apply_config( sort_spec => { %opt } );
}

# batch_apply_opts_existing():
# Same as batch_apply_opts except columns that do not already exist
# are pruned out of columns and column_order
sub batch_apply_opts_existing {
	my $self = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %opts) {
		if ($opt eq 'columns' and ref($opts{$opt}) eq 'HASH') {		
			foreach my $col (keys %{$opts{$opt}}) {
				delete $opts{$opt}->{$col} unless (defined $self->columns->{$col});
			}				
		}
		elsif ($opt eq 'column_order') {
			my @new_list = ();
			foreach my $col (@{$opts{$opt}}) {
				next unless (defined $self->columns->{$col});
				push @new_list, $col;
			}
			@{$opts{$opt}} = @new_list;
		}				
	}
	
	return $self->batch_apply_opts(\%opts);
}

sub batch_apply_opts {
	my $self = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %opts) {
		if ($opt eq 'columns' and ref($opts{$opt}) eq 'HASH') {				$self->apply_columns($opts{$opt});				}
		elsif ($opt eq 'column_order') {		$self->set_columns_order(0,$opts{$opt});		}
		elsif ($opt eq 'sort') {				$self->set_sort($opts{$opt});						}
		else { 
			$self->apply_extconfig( $opt => $opts{$opt} );
		}
		#elsif ($opt eq 'filterdata') {		$self->apply_config($opt => $opts{$opt});		}
		#elsif ($opt eq 'pageSize') {		$self->apply_config($opt => $opts{$opt});		}
		#else { die "invalid option '$opt' passed to batch_apply_opts";							}
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
	
	my $last_indx = (scalar @pruned);
	$offset = $last_indx if ($offset > $last_indx);
	
	splice(@pruned,$offset,0,@cols);
	
	@{ $self->column_order } = @pruned;
	
	return $self->apply_config(columns => $self->column_list);
}

# --



#############

sub params_from_request {
	my $self= shift;
	
	my $params= $self->c->req->params;
	if (defined $params->{orig_params}) {
		$params= $self->json->decode($params->{orig_params});
	}
	
	return $params;
}

sub read {
	# params is optional
	my ($self, $params)= @_;
	
	# only touch request if params were not supplied
	$params ||= $self->params_from_request;
	$self->enforce_max_pagesize($params);
	
	my $data = $self->read_raw($params);
	
	return $self->meta_json_packet($data);
}

sub enforce_max_pagesize {
	my ($self, $params)= @_;
	
	return if !$self->max_pagesize || $params->{ignore_page_size};
	return unless
		not defined $params->{limit} or 
		$params->{limit} > $self->max_pagesize or
		not defined $params->{start};
	
	my $new_params = {};
	$new_params->{start} = 0 unless (defined $params->{start});
	$new_params->{limit} = $self->max_pagesize if (
		not defined $params->{limit} or 
		$params->{limit} > $self->max_pagesize
	);
	
	%$params = (
		%$params,
		%$new_params
	);
	
	$self->c->log->info(ref($self) . '->enforce_max_pagesize: request params modified: ' . Dumper($new_params)); 
}

sub read_raw {
	# params is optional
	my ($self, $params)= @_;
	
	my $data;
	if (defined $self->read_handler and $self->has_flag('can_read')) {
		$params ||= $self->params_from_request;
		
		$data = $self->read_handler->call($params);
		
		# data should be a hash with rows (arrayref) and results (number):
		die "unexpected data returned in read_raw" unless (
			ref($data) eq 'HASH' and 
			defined $data->{results} and
			ref($data->{rows}) eq 'ARRAY'
		);
	} else {
		# empty set of data:
		$data= { results => 0, rows => [] }
	}
	
	unless ($self->has_no_read_raw_mungers) {
		foreach my $Handler ($self->all_read_raw_mungers) {
			$Handler->call($data);
		}
	}
	
	return $data;
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
			fields => defined $self->store_fields ? $self->store_fields : $self->store_fields_from_rows($opt{rows}),
			loaded_columns => try{[ keys %{$opt{rows}->[0]} ]}
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
	
	# -- Set the $BATCH_UPDATE_IN_PROGRESS flag if the client says this is a
	# batch update. This codepath is followed for "local" batch updates. See
	# also the 'batch_update' method/action in RapidApp::Role::DataStore2
	local $BATCH_UPDATE_IN_PROGRESS = $BATCH_UPDATE_IN_PROGRESS;
	$BATCH_UPDATE_IN_PROGRESS = 1 if ($params->{batch_update});
	# --
	
	if (defined $params->{orig_params}) {
		my $orig_params = $self->json->decode($params->{orig_params});
		delete $params->{orig_params};
		
		# merge orig_params, preserving real params that are set:
		foreach my $k (keys %$orig_params) {
			next if (defined $params->{$k});
			$params->{$k} = $orig_params->{$k};
		}
	}
	
	unless ($self->has_no_update_mungers) {
		foreach my $Handler ($self->all_update_mungers) {
			$Handler->call($rows);
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
	
	die "Update Failed";
}




sub create {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
		
	my $result = $self->create_handler->call($rows);
	
	#scream_color(RED,$result);
	# TODO: get rid of this crap into DbicLink2
	return $result if (delete $result->{use_this}); #<-- temp hack
	
	# we don't actually care about the new record, so we simply give the store back
	# the row it gave to us. We have to make sure that pk (primary key) is set to 
	# something or else it will throw an error (update: bypass this failsafe if more
	# than one row was provided in the request, that is, if its an array instead of
	# a hash)
	$rows->{$self->record_pk} = 'dummy-key' if (ref($rows) eq 'HASH');
	
	# If the id of the new record was provided in the response, we'll use it:
	$rows = $result->{rows} if (ref($result) and defined $result->{rows} and defined $result->{rows}->{$self->record_pk});
	
	# Use the provided rows if its an array. Assume the record_pk is provided in each row:
	$rows = $result->{rows} if (ref($result) and ref($result->{rows}) eq 'ARRAY');
	
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
		die $result->{msg};
	}
	
	die 'Create Failed';
}



sub destroy {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
		
	my $result = $self->destroy_handler->call($rows) or return {
		success => \0,
		msg => 'destroy failed'
	};
	
	return $result if (ref($result) eq 'HASH' and $result->{success});
	
	return {
		success => \1,
		msg => 'destroy success'
	};
}


has 'getStore' => ( is => 'ro', lazy => 1, default => sub { 
	my $self = shift;
	return $self->JsonStore;
});

has 'getStore_code' => ( is => 'ro', lazy_build => 1 );
sub _build_getStore_code {
	my $self = shift;
	return 'Ext.StoreMgr.lookup("' . $self->storeId . '")';
}

has 'getStore_func' => ( is => 'ro', lazy_build => 1 );
sub _build_getStore_func {
	my $self = shift;
	return RapidApp::JSONFunc->new( 
		raw => 1, 
		func => $self->getStore_code
	);
}

has 'store_load_code' => ( is => 'ro', lazy_build => 1 );
sub _build_store_load_code {
	my $self = shift;
	return $self->getStore_code . '.load()';
}

# TODO: get a more reliable way to access the store - use local references and scope
# instead of relying on a global ID:
has 'store_load_fn' => ( is => 'ro', isa => 'RapidApp::JSONFunc', lazy => 1, default => sub {
	my $self = shift;
	return RapidApp::JSONFunc->new( raw => 1, func =>
		'function() {' .
			'var storeId = "' . $self->storeId . '";' .
			'var storeByLookup = Ext.StoreMgr.lookup(storeId);' .
			'if(storeByLookup) { storeByLookup.load(); }' .
		'}'
	);
});


has 'store_api' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $api = {};
	
	$api->{read}		= $self->suburl('/read');
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
			#writeAllFields => \1
	});
	
	return $writer;
});






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;