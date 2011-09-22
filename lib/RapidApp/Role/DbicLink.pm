package RapidApp::Role::DbicLink;


use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DbicAppCombo;
use RapidApp::DBIC::RelationTreeSpec;
use RapidApp::DBIC::RelationTreeFlattener;
use Switch;

use Moose::Util::TypeConstraints;

has 'joins' => ( is => 'ro', default => sub {[]} );
has 'group_by' => ( is => 'ro', isa => 'Maybe[Str|ArrayRef]', default => undef );
has 'distinct' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'base_search_set' => ( is => 'ro',	default => undef );
has 'fieldname_transforms' => ( is => 'ro', default => sub {{}});

has 'dbf_virtual_fields'      => ( is => 'ro',	required => 0, 	isa => 'Maybe[HashRef]', default => undef 	);

has 'primary_columns' => ( is => 'rw', default => sub {[]}, isa => 'ArrayRef');

has 'always_fetch_columns' => ( is => 'ro', default => undef );
has 'never_fetch_columns' => ( is => 'ro', default => sub {[]}, isa => 'ArrayRef');

has 'never_fetch_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {} unless (defined $self->never_fetch_columns);
	my $h = {};
	foreach my $col (@{$self->never_fetch_columns}) {
		$h->{$col} = 1;
	}
	return $h;
});

has 'no_search_fields' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	builder => '_build_no_search_fields',
	handles => {
		all_no_search_fields		=> 'uniq',
		add_no_search_fields		=> 'push',
		has_no_no_search_fields 	=> 'is_empty',
	}
);
sub _build_no_search_fields { return [] }


has '_no_search_fields_hash' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef[Bool]',
	handles   => {
		is_no_search_field				=> 'exists',
	},
	lazy => 1,
	builder => '_build__no_search_fields_hash',
);
sub _build__no_search_fields_hash {
	my $self = shift;
	my $h = {};
	my @list = $self->all_no_search_fields;
	push @list, keys %{$self->dbf_virtual_fields} if ($self->dbf_virtual_fields);
	foreach my $col (@list) {
		$h->{$col} = 1;
	}
	return $h;
}




has 'get_ResultSet_Handler' => ( is => 'ro', isa => 'Maybe[RapidApp::Handler]', lazy => 1, default => undef );

has 'literal_dbf_colnames' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );

sub ResultSet {
	my $self = shift;
	return $self->ResultSource->resultset unless ($self->get_ResultSet_Handler);
	return $self->get_ResultSet_Handler->call;
}


has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	
	my $no_search_fields = [ $self->all_no_search_fields ];
	push @$no_search_fields, keys %{$self->dbf_virtual_fields} if ($self->dbf_virtual_fields);
	
	my $cnf = {
		ResultSource				=> $self->ResultSource,
		get_ResultSet_Handler	=> $self->get_ResultSet_Handler,
		ExtNamesToDbFields 		=> $self->fieldname_transforms,
		dbf_virtual_fields		=> $self->dbf_virtual_fields,
		no_search_fields			=> $no_search_fields,
		literal_dbf_colnames		=> $self->literal_dbf_colnames,
		joins 						=> $self->joins,
		distinct						=> $self->distinct,
		#implied_joins			=> 1
		#group_by				=> [ 'me.id' ],
	};
	
	$cnf->{group_by} = $self->group_by if (defined $self->group_by);
	
	$cnf->{base_search_set} = $self->base_search_set if (defined $self->base_search_set);
	
	#$cnf->{columns} = $self->json->decode($self->c->req->params->{columns}) if (
	#	defined $self->c->req->params->{columns}
	#);
	
	return RapidApp::DbicExtQuery->new($cnf);
}


has 'no_rel_combos' => ( is => 'ro', isa => 'Bool', default => 0);

sub apply_primary_columns {
	my $self = shift;
	my @cols = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	
	my %cur = ();
	foreach my $col (@{$self->primary_columns},@cols) {
		$cur{$col}++;
	}
	
	return $self->primary_columns([ keys %cur ]);
}


sub remove_primary_columns {
	my $self = shift;
	my @cols = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	
	my %remove = ();
	foreach my $rem (@cols) {
		$remove{$rem}++;
	}
	
	my %cur = ();
	foreach my $col (@{$self->primary_columns}) {
		next if ($remove{$col});
		$cur{$col}++;
	}
	
	return $self->primary_columns([ keys %cur ]);
}



has 'join_map' => ( is => 'rw', lazy => 1, builder => '_build_join_map', isa => 'HashRef' );
sub _build_join_map {
	my $self = shift;
	
	my $map = {};
	my $recurse;
	$recurse = sub {
		my $Source = shift;
		my $join = shift;
		
		if (ref($join)) {
			if (ref($join) eq 'ARRAY') {
				foreach my $sub (@$join) {
					$recurse->($Source,$sub);
				}
			}
			
			if (ref($join) eq 'HASH') {
				foreach my $rel (keys %$join) {
					$map->{$Source->source_name}->{$rel} = 1;
					
					my $info = $Source->relationship_info($rel);
					my $subSource = $Source->schema->source($info->{class});
					$recurse->($subSource,$join->{$rel});
				}
			}
		
		}
		else {
			$map->{$Source->source_name}->{$join} = 1;
		}
	};
	
	$recurse->($self->ResultSource,$self->joins);
	DEBUG('dbiclink', jons => $self->joins, "\n", map => $map, );
	return $map;
}

has 'join_col_prefix_map' => (
	is => 'ro',
	isa => 'HashRef',
	lazy_build => 1 );

sub _build_join_col_prefix_map {
	my $self= shift;
	my $map = {};
	my @todo= ( [ '', $self->joins ] );
	while (my $next= pop @todo) {
		my ($prefix, $node)= @$next;
		if (ref $node eq 'ARRAY') {
			# need to process each element of the array, using the same prefix
			for my $item (@$node) {
				if (!ref $item) {
					$map->{$prefix.$item}= 1;
				} else {
					push @todo, [ $prefix, $item ];
				}
			}
		} elsif (ref $node eq 'HASH') {
			# register each key of the hash
			# then register the value, unless it isn't a scalar, then queue it
			while (my ($key, $val)= each %$node) {
				$map->{$prefix.$key}= 1;
				if (!ref $val) {
					$map->{$prefix.$key.'_'.$val}= 1;
				} else {
					push @todo, [ $prefix.$key.'_', $val ];
				}
			}
		} else { die "Unexpected reftype: ".ref($node); }
	}
	DEBUG('dbiclink', joins => $self->joins, col_prefix_map => $map);
	return $map;
}

has 'limit_dbiclink_columns' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	builder => '_build_limit_dbiclink_columns',
	handles => {
		all_limit_dbiclink_columns		=> 'elements',
		add_limit_dbiclink_columns		=> 'push',
		has_no_limit_dbiclink_columns 	=> 'is_empty',
	}
);
sub _build_limit_dbiclink_columns { return [] }


has '_limit_dbiclink_columns_hash' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef[Bool]',
	handles   => {
		has_limit_dbiclink_column				=> 'exists',
	},
	lazy => 1,
	default => sub {
		my $self = shift;
		my $h = {};
		foreach my $col ($self->all_limit_dbiclink_columns) {
			$h->{$col} = 1;
		}
		return $h;
	}
);


has 'exclude_dbiclink_columns' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	default   => sub { [] },
	handles => {
		all_exclude_dbiclink_columns		=> 'elements',
		add_exclude_dbiclink_columns		=> 'push',
		has_no_exclude_dbiclink_columns 	=> 'is_empty',
	}
);

has '_exclude_dbiclink_columns_hash' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef[Bool]',
	handles   => {
		has_exclude_dbiclink_column				=> 'exists',
	},
	lazy => 1,
	default => sub {
		my $self = shift;
		my $h = {};
		foreach my $col ($self->all_exclude_dbiclink_columns) {
			$h->{$col} = 1;
		}
		return $h;
	}
);

has relationTreeSpec => ( is => 'ro', isa => 'RapidApp::DBIC::RelationTreeSpec', lazy_build => 1 );
sub _build_relationTreeSpec {
	my $self= shift;
	
	# DbicLink has all its configuration parameters defined in terms of the concatenated name.
	# In retrospect, it would have been more convenient to configure it in terms of the DBIC name,
	#  and hopefully the API can move in that direction now that we have this object to play with.
	# Here, we try to convert those concatenated names back to the DBIC name.
	
	my @spec;
	my @worklist= ( [ $self->ResultSource, [] ] );
	while (@worklist) {
		my ($source, $path)= @{ pop @worklist };
		my $srcN= $source->source_name;
		
		for my $colN ($source->columns) {
			my $concatName= join('_', @$path, $colN);
			next unless ($self->has_no_limit_dbiclink_columns or $self->has_limit_dbiclink_column($concatName));
			next if ($self->has_exclude_dbiclink_column($concatName));
			next unless ($self->valid_colname($concatName));
			
			push @spec, join('.', @$path, $colN); # use it
		}
		
		for my $relN ($source->relationships) {
			# only follow prefixes that are defined in the joins:
			next unless (defined $self->join_map->{$srcN}->{$relN});
			my $prefix= join('_', @$path, $relN);
			next unless $self->join_col_prefix_map->{$prefix};
			
			push @worklist, [ $source->related_source($relN), [ @$path, $relN ] ];
		}
	}
	
	return RapidApp::DBIC::RelationTreeSpec->new(source => $self->ResultSource, colSpec => \@spec);
}

has relationTreeFlattener => ( is => 'ro', isa => 'RapidApp::DBIC::RelationTreeFlattener', lazy_build => 1 );
sub _build_relationTreeFlattener {
	RapidApp::DBIC::RelationTreeFlattener->new(spec => $_[0]->relationTreeSpec);
}


# -- vv -- 2011-09-22 by HV -- New update support

has 'dbiclink_updatable' => ( is => 'ro', isa => 'Bool', default => 0 );

# dbiclink_updatable_relationships:
# Should be a list of relationship/join names that will be updated along with 
# the base row. 
# For multi-level relationships, separate with '.' 
# for example:
# If these joins were defined: [ 'owner', { 'project' => 'status' } ]
# To set them as writable set dbiclink_updatable_relationships to: [ 'owner', 'project.status' ]
has 'dbiclink_updatable_relationships' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );

has 'relationTreeFlattenerPruned' => ( is => 'ro', isa => 'RapidApp::DBIC::RelationTreeFlattener', lazy_build => 1 );
sub _build_relationTreeFlattenerPruned {
	my $self = shift;
	
	my @exps = ( '/^[^.]+$/' );
	foreach my $rel (@{$self->dbiclink_updatable_relationships}) {
		push @exps, '/^' . quotemeta($rel . '.') . '[^.]+$/';
	}
	
	my $grepEval = 'grep { ' . join(' or ',@exps) . ' } @{$self->relationTreeSpec->allCols}';
	
	my $objCols = [ eval $grepEval ];
	
	return RapidApp::DBIC::RelationTreeFlattener->new(
		spec => RapidApp::DBIC::RelationTreeSpec->new(
			colSpec => $objCols, 
			source => $self->ResultSource
		)
	);
}

# Accepts a hash of flattened record data as sent from the ExtJS Store client
# and unflattens it back into a tree hash, pruning/excluding columns from 
# joins/rels that are not in dbiclink_updatable_relationships
sub unflatten_prune_update_packet {
	my $self = shift;
	my $data = shift;
	
	my $tree = $self->relationTreeFlattenerPruned->restore($data);
	
	return $tree;
}

sub Row_tree_update_recursive {
	my $self = shift;
	my $Row = shift;
	my $tree = shift;
	
	my $base = {};
	my $rels = {};
	
	foreach my $k (keys %$tree) {
		if (ref($tree->{$k}) eq 'HASH') {
			$rels->{$k} = $tree->{$k};
			next;
		}
		$base->{$k} = $tree->{$k};
	}
	
	$Row->update($base);
	
	foreach my $rel (keys %$rels) {
		$Row->can($rel) 
			or die '"' . $rel . '" is not an accessor method of Row object; Row_tree_update_recursive failed.';
		
		my $Related = $Row->$rel;
		
		$Related->isa('DBIx::Class::Row') 
			or die '"' . $rel . '" (' . ref($Related) . ') is not a DBIx::Class::Row object; Row_tree_update_recursive failed.';
		
		$self->Row_tree_update_recursive($Related,$rels->{$rel});
	}
}

# Gets programatically added as a method named 'update_records' (see BUILD modifier method below)
sub _dbiclink_update_records {
	my $self = shift;
	my $params = shift;
	
	my $arr = $params;
	$arr = [ $params ] if (ref($params) eq 'HASH');
	
	my $Rs = $self->ResultSource->resultset;
	
	try {
		$self->ResultSource->schema->txn_do(sub {
			foreach my $data (@$arr) {
				my $Row = $Rs->find($data->{$self->record_pk}) or die usererr "Failed to find row.";
				my $tree = $self->unflatten_prune_update_packet($data);
				$self->Row_tree_update_recursive($Row,$tree);
			}
		});
	}
	catch {
		my $err = shift;
		die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
	};
	
	# TODO: return the new state of the updated rows instead of just true:
	return 1;
}
# -- ^^ --





sub BUILD {}
around 'BUILD' => sub {
	my $orig = shift;
	my $self = shift;
	
	# -- vv -- Introspective code:
	# Dynamically toggle the addition of an 'update_records' method
	# The existence of this method is part of the DataStore2 API
	$self->meta->add_method('update_records',$self->meta->get_method('_dbiclink_update_records')) if (
		$self->dbiclink_updatable and 
		not $self->can('update_records')
	);
	# -- ^^ --
	
	$self->apply_extconfig( no_multifilter_fields => $self->_no_search_fields_hash );

	role_type('RapidApp::Role::DataStore2')->assert_valid($self);
	# We can't 'require' this method, because intermediate subclasses like DbicAppGrid2 don't have it defined, though the final one should.
	# What Moose really needs is an "use Moose::Abstract" for intermediate base classes, which would delay the 'requires' checks.
	$self->can('ResultSource') or die "Role ".__PACKAGE__." requires method ".'ResultSource';
	
	$self->$orig(@_);
	
	$self->apply_primary_columns($self->record_pk); # <-- should be redundant
	$self->apply_primary_columns($self->ResultSource->primary_columns);
	
	$self->apply_config(primary_columns => $self->primary_columns);
	
	$self->apply_store_config(
		remoteSort => \1
	);
	
	# TODO, fieldname_transforms needs calculated elsewhere
	
	my $addColRecurse;
	$addColRecurse = sub {
		my ($path, $relTreeSpec, $rs)= @_;
		
		for my $key (keys %$relTreeSpec) {
			if (ref $relTreeSpec->{$key}) { # if it is a relation...
				my $relName= $key;
				my $subSource= $rs->related_source($relName);
				$addColRecurse->([ @$path, $relName ], $relTreeSpec->{$key}, $subSource);
			}
			else { # else if it is a column...
				my $colName= $key;
				my $flatName= $self->relationTreeFlattener->colToFlatKey(@$path, $key);
				if (@$path) {
					$self->fieldname_transforms->{$flatName} = $path->[-1] . '.' . $colName;
				}
				
				my $opts = { name => $flatName };
				
				my $type = $self->dbic_to_ext_type($rs->column_info($colName)->{data_type});
				$opts->{filter}{type} = $type if ($type);
				
				# -- Build combos (dropdowns) for every related field (for use in multifilters currently):
				if (scalar(@$path) and not ($ENV{NO_REL_COMBOS} or $self->no_rel_combos)) {
					
					my $module_name = 'combo_' . $flatName;
					$self->apply_modules(
						$module_name => {
							class	=> 'RapidApp::DbicAppCombo',
							params	=> {
								#valueField		=> $self->record_pk,
								valueField    => ($rs->primary_columns)[0],
								name          => $colName,
								ResultSource  => $rs,
							}
						}
					);
					
					$opts->{rel_combo_field_cnf}= $self->Module($module_name)->content;
				}
				
				$self->apply_columns( $flatName => $opts );
			}
		}
	};
	
	$addColRecurse->([], $self->relationTreeSpec->relationTree, $self->ResultSource);
	
	$self->add_ONREQUEST_calls('check_can_delete_rows');
};



sub check_can_delete_rows {
	my $self = shift;
	$self->applyIf_module_options( delete_records => 1 ) if($self->can('delete_rows'));
}


sub action_delete_records {
	my $self = shift;
	
	die "delete_rows method does not exist" unless ($self->can('delete_rows'));
	
	my $recs = $self->json->decode($self->c->req->params->{rows});
	
	my @Rows = ();
	foreach my $rec (@$recs) {
		my $search = {};
		foreach my $col (@{$self->primary_columns}) {
			$search->{$col} = $rec->{$col} if (defined $rec->{$col});
		}
		push @Rows, $self->ResultSource->resultset->single($search);
	}
	
	my $result = $self->delete_rows(@Rows);
	
	return {
		success => \1,
		msg => 'success'
	};
}



sub dbic_to_ext_type {
	my $self = shift;
	my $type = shift;
	
	$type = lc($type);
	
	switch ($type) {
		case (/int/ or /float/) {
			return 'number';
		}
		case ('datetime' or 'timestamp') {
			return 'date';
		}
	}
	return undef;
}








sub read_records {
	my ($self, $params)= @_;
	
	# only touch request if params were not supplied
	$params ||= $self->c->req->params;
	
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	if (defined $params->{columns}) {
		if (!ref $params->{columns}) {
			my $decoded = $self->json->decode($params->{columns});
			$params->{columns} = $decoded;
		}
		
		# If custom columns have been provided, we have to make sure that the record_pk is among them.
		# This is required to properly support the "item" page which is opened by double-clicking
		# a grid row. The id field must be loaded in the Ext Record because this is used by the
		# item page to query the database for the given id:
		push @{$params->{columns}}, $self->record_pk if (defined $self->record_pk);
		
		push @{$params->{columns}}, @{$self->always_fetch_columns} if (defined $self->always_fetch_columns);
		
		
		my %seen = ();
		my $newcols = [];
		foreach my $col (@{$params->{columns}}) {
			next if ($seen{$col}++);
			next if ($self->never_fetch_columns_hash->{$col});
			push @$newcols, $col;
		}
		
		$params->{columns} = $newcols;
	}
	
	my @arg = ( $params );
	push @arg, $self->read_extra_search_set if ($self->can('read_extra_search_set'));

	#my $data = $self->DbicExtQuery->data_fetch(@arg);


  my $Rs = $self->DbicExtQuery->build_data_fetch_resultset(@arg);
  
  # -- vv -- support for id_in:
  if ($params->{id_in}) {
    my $in;
    $in = $params->{id_in} if (ref($params->{id_in}) eq 'ARRAY');
    $in = $self->json->decode($params->{id_in}) unless ($in);
	  $Rs = $Rs->search({ 'me.' . $self->record_pk => { '-in' => $in }});
  }
  # -- ^^ --

  my $data = {
		rows			=> [ $Rs->all ],
		totalCount	=> $Rs->pager->total_entries,
	};
	
  # TODO: stop doing this...
  # don't iterate rows calling get_columns!! Use something like HashRefInflator!!
	my $rows = [];
	foreach my $row (@{$data->{rows}}) {
		my $hash = { $row->get_columns };
		push @$rows, $hash;
	}
	
	my $result = {
		results		=> $data->{totalCount},
		rows		=> $rows
	};

	return $result;
}




sub get_row_related_columns_flattened {
	my $self = shift;
	my $Row = shift;
	
	my $data = { $Row->get_columns };
	foreach my $rel ( $Row->relationships ) {
		next unless ( defined $Row->$rel and $Row->$rel->can('get_columns') );
		my $reldata = { $Row->$rel->get_columns };
		foreach my $col ( keys %$reldata ) {
			$data->{$rel . '_' . $col} = $reldata->{$col};
		}
	}
	
	return $data;
	
}


sub update_Row_and_compare_deep {
	my $self = shift;
	my $Row = shift;
	my $update = shift;
	
	my $orig_data = $self->get_row_related_columns_flattened($Row);
	$Row->update($update);
	my $new_data = $self->get_row_related_columns_flattened($Row->get_from_storage);
	
	my @changes = ();
			
	foreach my $k (sort keys %$orig_data) {
		next if ($orig_data->{$k} eq $new_data->{$k});
		push @changes, [ $k, $orig_data->{$k}, $new_data->{$k} ];
	}
	
	return \@changes;
}




sub make_dbic_exception_friendly {
	my $self = shift;
	my $exception = shift;
	my $msg = "" . $exception . "";
	
	my @parts = split(/DBD\:\:mysql\:\:st execute failed\:\s*/,$msg);
	return $exception unless (scalar @parts > 1);
	
	$msg = $parts[1];
	
	@parts = split(/\s*\[/,$msg);

	return '<center><pre>' . $parts[0] . "</pre></center>";
	return $parts[0];
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;