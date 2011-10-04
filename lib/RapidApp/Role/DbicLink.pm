package RapidApp::Role::DbicLink;


use strict;
use Moose::Role;
use Hash::Merge;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::Debug 'DEBUG';
use RapidApp::DbicAppCombo;
use RapidApp::DbicExtQuery;
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

# These two parameters affect the results returned from read_records.
has 'always_fetch_columns' => ( is => 'ro', default => sub {[]}, isa => 'ArrayRef');
has 'never_fetch_columns' => ( is => 'ro', default => sub {[]}, isa => 'ArrayRef');

has 'never_fetch_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {} unless (defined $self->never_fetch_columns);
	return { map { $_ => 1 } @{$self->never_fetch_columns} };
});


# Columns that need other columns to automatically be fetched when they are fetched
has 'column_required_fetch_columns' => (
	is => 'ro',
	isa => 'HashRef[ArrayRef[Str]]',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $hash = {};
		
		foreach my $col (keys %{ $self->columns }) {
			my $list = $self->columns->{$col}->required_fetch_columns or next;
			next unless (
				ref($list) eq 'ARRAY' and
				scalar @$list > 0
			);
			$hash->{$col} = $list;
		}
		return $hash;
	}
);




has 'no_search_fields' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	builder => '_build_no_search_fields',
	handles => {
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
		is_no_search_field   => 'exists',
		all_no_search_fields => 'keys',
	},
	lazy => 1,
	builder => '_build__no_search_fields_hash',
);
sub _build__no_search_fields_hash {
	my $self = shift;
	return {
		map { $_ => 1 } @{$self->no_search_fields}, keys %{$self->dbf_virtual_fields || {}}
	};
}

has 'get_ResultSet_Handler' => ( is => 'ro', isa => 'Maybe[RapidApp::Handler]', lazy => 1, default => sub {
	my $self = shift;
	return undef unless ($self->can('get_ResultSet'));
	return RapidApp::Handler->new(
		scope	=> $self,
		method	=> 'get_ResultSet'
	);
});

has 'literal_dbf_colnames' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );

sub ResultSet {
	my $self = shift;
	return $self->ResultSource->resultset unless ($self->get_ResultSet_Handler);
	return $self->get_ResultSet_Handler->call;
}


has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	DEBUG(dbiclink => 'building DbicExtQuery.  flattener=>', $self->dbiclink_columns_flattener);
	my $cnf = {
		ResultSource            => $self->ResultSource,
		get_ResultSet_Handler   => $self->get_ResultSet_Handler,
		record_pk               => $self->record_pk,
		ExtNamesToDbFields      => $self->fieldname_transforms,
		dbf_virtual_fields      => $self->dbf_virtual_fields,
		no_search_fields        => [ $self->all_no_search_fields ],
		literal_dbf_colnames    => $self->literal_dbf_colnames,
		joins                   => $self->joins,
		extColMap               => $self->dbiclink_columns_flattener,
		distinct                => $self->distinct,
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
	DEBUG('dbiclink', joins => $self->joins, "\n", join_map => $map, );
	return $map;
}

has 'join_col_prefix_map' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
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
after add_limit_dbiclink_columns => sub { (shift)->regen_limit_exclude_dbiclink_columns };


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
after add_exclude_dbiclink_columns => sub { (shift)->regen_limit_exclude_dbiclink_columns };

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

sub regen_limit_exclude_dbiclink_columns {
	my $self = shift;
	my $attr = $self->meta->find_attribute_by_name('_exclude_dbiclink_columns_hash') or die "no _exclude_dbiclink_columns_hash attr";
	$attr->clear_value($self);
	$self->_exclude_dbiclink_columns_hash;
	
	$attr = $self->meta->find_attribute_by_name('_limit_dbiclink_columns_hash') or die "no _limit_dbiclink_columns_hash";
	$attr->clear_value($self); 
	$self->_limit_dbiclink_columns_hash;
}

# dbiclink_colspec is a user-friendly configuration parameter of a list of
# DBIC column names, in "relation.relation.col" notation.
# It is used to builc dbiclink_columns_spec and dbiclink_columns_flattener on demand.
# Those are in turn used for calculating dbiclink_columns_updatable from dbiclink_colspec_updatable
has dbiclink_colspec => ( 
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	lazy_build => 1,
	handles => {
		dbiclink_colspec_list => 'elements',
		apply_dbiclink_colspec => 'push',
		dbiclink_colspec_count => 'count',
	}
);
sub _build_dbiclink_colspec {
	return [];
}

# dbiclink_updatable_relationships:
# Should be a list of relationship/join names that will be updated along with 
# the base row. 
# For multi-level relationships, separate with '.' 
# for example:
# If these joins were defined: [ 'owner', { 'project' => 'status' } ]
# To set them as writable set dbiclink_updatable_relationships to: [ 'owner', 'project.status' ]

# dbiclink_colspec_updatable is a user-friendly configuration parameter of a list of
# DBIC column names, in "relation.relation.col" notation.
#
# NOTE: A column must be listed in dbiclink_colspec to be considered.
#       The updatable list is only a mask which gets applied to that other list.
# NOTE2: Nothing actually becomes updatable unless "dbiclink_updateable" is set to
#        true before BUILD.
#has dbiclink_colspec_updatable => ( 
#	is => 'ro',
#	traits => [ 'Array' ],
#	isa => 'ArrayRef[Str]',
#	lazy_build => 1,
#	handles => {
#		dbiclink_colspec_updatable_list => 'elements',
#		apply_dbiclink_colspec_updatable => 'push',
#		dbiclink_colspec_updatable_count => 'count',
#	}
#);
#sub _build_dbiclink_colspec_updatable {
#	return [];
#}

has 'dbiclink_colspec_updatable' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub {
	my $self = shift;
	my @list = ( '*' );
	foreach my $rel (@{ $self->dbiclink_updatable_relationships }) {
		push @list, $rel . '.*';
	}
	return \@list;
});

has 'dbiclink_updatable_relationships' => ( is => 'ro', isa => 'ArrayRef[Str]', lazy_build => 1 );
sub _build_dbiclink_updatable_relationships {[]}



# dbiclink_col_naming_convention is a configuration parameter for how column names will be generated.
# It can only be changed before dbiclink_columns_flattener has been created.
has dbiclink_col_naming_convention => ( is => 'rw', isa => 'Str', default => 'concat_' );

# dbiclink_columns_spec is dbiclink_colspec in object form, and fully resolved against the ResultSource.
sub dbiclink_columns_spec { $_[0]->dbiclink_columns_flattener->spec }

# dbiclink_columns_flattener maps DBIC column names to Ext names and back.
has dbiclink_columns_flattener => ( is => 'ro', isa => 'RapidApp::DBIC::RelationTreeFlattener', lazy_build => 1 );
sub _build_dbiclink_columns_flattener {
	my $self= shift;
	# if the user is using the "colSpec" interface, we create the flattener directly.
	# Else, we try to build the spec from the previous "dbiclink_columns" API.
	if ($self->dbiclink_colspec_count) {
		my $relSpec= RapidApp::DBIC::RelationTreeSpec->new(source => $self->ResultSource, colSpec => $self->dbiclink_colspec);
		return RapidApp::DBIC::RelationTreeFlattener->new(spec => $relSpec, namingConvention => $self->dbiclink_col_naming_convention);
	} else {
		
		# DbicLink has all its configuration parameters defined in terms of the concatenated name.
		# In retrospect, it would have been more convenient to configure it in terms of the DBIC name,
		#  and hopefully the API can move in that direction now that we have this object to play with.
		# Here, we try to convert those concatenated names back to the DBIC name.
		
		my @spec;
		my @worklist= ( [ $self->ResultSource, [] ] );
		while (@worklist) {
			my ($source, $path)= @{ pop @worklist };
			my $srcN= $source->source_name;
			
			DEBUG(dbiclink => ref($self), ' - including', $srcN, '(', $source->columns, ')');
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
		
		# We also have logic to handle and attempt to automatically resolve name conflicts.
		# With the simple concatenation with "_", columns like project.status_id and project.status.id
		# can end up with the same mapped name.  We work around it by adding excludes to the colSpec
		# until we can successfully create a mapper.
		
		my $relSpec= RapidApp::DBIC::RelationTreeSpec->new(source => $self->ResultSource, colSpec => \@spec);
		my $flattener= RapidApp::DBIC::RelationTreeFlattener->new(
			spec => $relSpec,
			namingConvention => $self->dbiclink_col_naming_convention,
			conflictResolver => sub {
				my ($col1, $col2)= @_;
				# exclude the deeper column, because in most cases it is an Enum table which we don't want to modify.
				my $keep= scalar(@$col1) < scalar(@$col2)? $col1 : $col2;
				my $exclude= scalar(@$col1) >= scalar(@$col2)? $col1 : $col2;
				my $cls= ref $self;
				warn "Conflicting columns in $cls: '$col1', '$col2'.  Automatically excluding '$exclude'\n";
				return $keep;
			}
		);
		DEBUG(dbiclink => 'colSpec =>', \@spec, 'spec =>', { %$relSpec, source => '...' }, 'flattener =>', { %$flattener, spec => '...' } );
		return $flattener;
	}
}

has 'dbiclink_updatable' => ( is => 'ro', isa => 'Bool', default => 0 );

has dbiclink_updatable_flattener => ( is => 'ro', isa => 'RapidApp::DBIC::RelationTreeFlattener', lazy_build => 1 );
sub _build_dbiclink_updatable_flattener {
	my $self = shift;
	return $self->dbiclink_columns_flattener->subset( $self->dbiclink_colspec_updatable );
}

# Accepts a hash of flattened record data as sent from the ExtJS Store client
# and unflattens it back into a tree hash, pruning/excluding columns from 
# joins/rels that are not in dbiclink_colspec_updatable
sub unflatten_prune_update_packet {
	my $self = shift;
	my $data = shift;
	
	my $tree = $self->dbiclink_updatable_flattener->restore($data);
	
	return $tree;
}


## -- vv -- TableSpec Support
has 'ignore_Result_TableSpec' => ( is => 'ro', isa => 'Bool', default => 0 );

# Need to do this with an around istead of normal sub to make sure
# we take over the sub from DataStore2. Not sure why since this gets
# loaded *after* DataStore2
around '_build_TableSpec' => sub {
	my $orig = shift;
	my $self = shift;
	return undef if ($self->ignore_Result_TableSpec);
	return $self->get_Result_class_TableSpec;
};

sub get_Result_class_TableSpec {
	my $self = shift;
	my $name = $self->ResultSource->source_name;
	my $Class = $self->ResultSource->schema->class($name);
	return undef unless ($Class->can('TableSpec'));
	
	# -- vvv -- One possible way of addressing this problem --
	# Here we are initializing the DbicLink columns earlier than normal (because this
	# gets called from within DataStore2) so we can have them and limit our columns
	# to them to prevent the TableSpec from adding columns that do not exist for this
	# context (because we probably haven't joined on all possible rels defined in the
	# TableSpec). We do also add the bare rel names so they get added by TableSpec if
	# it has relationship columns.
	# (Note that this doesn't yet work except for 1st level joins -- or does it?)
	$self->init_apply_columns;
	$self->add_limit_dbiclink_columns(keys %{ $self->columns });
	# All of the defined "relationship columns" from TableSpec will have names matching
	# the keys in join_col_prefix_map because the same name algorithm/process is applied
	# to naming the relationship columns (same name as the relationship) and then pulling
	# related relationship columns from related TableSpecs, relname_colname, where colname
	# is actually a relname itself
	$self->add_limit_dbiclink_columns(keys %{ $self->join_col_prefix_map });
	# -- ^^^ --
	
	my $TableSpec = $Class->TableSpec;
	# -- vvv -- Another possible way of addressing the problem (above) --
	# -- Exclude columns from relationships we aren't joining on:
	# TODO: make this work for multiple levels deep:
	#my $joins = { map {$_ => 1} @{ $self->joins } };
	#foreach my $rel ( keys %{ $Class->TableSpec_rel_columns } ) {
	#	$self->add_exclude_dbiclink_columns(@{ $Class->TableSpec_rel_columns->{$rel} }) unless ($joins->{$rel})
	#}
	# -- ^^^ --
	
	# copy limit/exclude columns in both directions:
	
	# from TableSpec:
	$self->add_limit_dbiclink_columns(@{ $TableSpec->limit_columns }) if (defined $TableSpec->limit_columns);
	$self->add_exclude_dbiclink_columns(@{ $TableSpec->exclude_columns }) if (defined $TableSpec->exclude_columns);
	
	# To TableSpec:
	return $TableSpec->copy( 
		limit_columns => $self->limit_dbiclink_columns,
		exclude_columns => $self->exclude_dbiclink_columns,
	);
}
# -- ^^ --


before DataStore2_BUILD => sub {
	my $self= shift;
	# Dynamically toggle the addition of an 'update_records' method
	# The existence of this method is part of the DataStore2 API
	$self->meta->add_method('update_records', $self->meta->find_method_by_name('_dbiclink_update_records')) if (
		$self->dbiclink_updatable and 
		not $self->can('update_records')
	);
};

sub BUILD {}
around 'BUILD' => sub { &DbicLink_around_BUILD(@_) };
sub DbicLink_around_BUILD {
	my $orig = shift;
	my $self = shift;
	
	$self->apply_extconfig( no_multifilter_fields => $self->_no_search_fields_hash );

	role_type('RapidApp::Role::DataStore2')->assert_valid($self);
	# We can't 'require' this method, because intermediate subclasses like DbicAppGrid2 don't have it defined, though the final one should.
	# What Moose really needs is an "use Moose::Abstract" for intermediate base classes, which would delay the 'requires' checks.
	$self->can('ResultSource') or die "Role ".__PACKAGE__." requires method ".'ResultSource';
	
	$self->$orig(@_);
	
	$self->init_apply_columns;

	
	$self->add_ONREQUEST_calls('check_can_delete_rows');
}


has '_init_apply_columns_applied' => ( is => 'rw', isa => 'Bool', default => 0 );
sub init_apply_columns {
	my $self = shift;
	return if ($self->_init_apply_columns_applied);

	$self->apply_primary_columns($self->record_pk); # <-- should be redundant
	
	# currently this is needed for "delete_row" support -- different from "destroy" and will
	# probably be removed at which point this should also be removed (maybe)
	$self->apply_primary_columns($self->ResultSource->primary_columns);
	
	$self->apply_config(primary_columns => $self->primary_columns);
	
	$self->apply_store_config(
		remoteSort => \1
	);
	
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
				my $flatName= $self->dbiclink_columns_flattener->colToFlatKey(@$path, $key);
				#if (@$path) {
				#	$self->fieldname_transforms->{$flatName} = $path->[-1] . '.' . $colName;
				#}
				
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
	
	$addColRecurse->([], $self->dbiclink_columns_spec->colTree, $self->ResultSource);
	
	#init column_required_fetch_columns
	$self->column_required_fetch_columns;
	$self->_init_apply_columns_applied(1);
}

#after BUILD => sub {
#	my $self= shift;
#	$self->DbicExtQuery; # make sure this gets built now, and not on each request
#};


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


# This is the meat of serving data requests.
#   * calculate a list of columns which should be selected,
#   * call DbicExtQuery to get the ResultSet,
#   * build hashes form the result
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
		
		$self->prepare_req_columns($params->{columns});
		

	}
	
	my @arg = ( $params );
	push @arg, $self->read_extra_search_set if ($self->can('read_extra_search_set'));

	# Build the query
	my $Rs = $self->DbicExtQuery->build_data_fetch_resultset(@arg);
	
	# don't use Row objects
	$Rs= $Rs->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' });
	
	return {
		rows    => [ $Rs->all ],
		results => $Rs->pager->total_entries,
	};
}

sub prepare_req_columns {
	my $self = shift;
	my $columns = shift;
	
	# If custom columns have been provided, we have to make sure that the record_pk is among them.
	# This is required to properly support the "item" page which is opened by double-clicking
	# a grid row. The id field must be loaded in the Ext Record because this is used by the
	# item page to query the database for the given id:
	push @$columns, $self->record_pk if (defined $self->record_pk);
	
	push @$columns, @{$self->always_fetch_columns} if (defined $self->always_fetch_columns);
	
	foreach my $col (@$columns) {
		my $add = $self->column_required_fetch_columns->{$col} or next;
		push @$columns, @$add;
	}
	
	my %seen = ();
	my @newcols = ();
	foreach my $col (@$columns) {
		next if ($seen{$col}++);
		next if ($self->never_fetch_columns_hash->{$col});
		push @newcols, $col;
	}
	
	@$columns = @newcols;
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
		
		my $Related = $Row->$rel or next;
		
		$Related->isa('DBIx::Class::Row') 
			or die '"' . $rel . '" (' . ref($Related) . ') is not a DBIx::Class::Row object; Row_tree_update_recursive failed.';
		
		$self->Row_tree_update_recursive($Related,$rels->{$rel});
	}
}

# Gets programatically added as a method named 'update_records' (see BUILD modifier method above)
# 
# This first runs updates on each supplied (and allowed) relation.
# It then re-runs a read_records to tell the client what the new values are.
#
sub _dbiclink_update_records {
	my $self = shift;
	my $params = shift;
	
	my $arr = $params;
	$arr = [ $params ] if (ref($params) eq 'HASH');
	
	my $Rs = $self->ResultSource->resultset;
	
	try {
		$self->ResultSource->schema->txn_do(sub {
			foreach my $data (@$arr) {
				my $pkVal= $data->{$self->record_pk};
				defined $pkVal or die ref($self)."->update_records: Record is missing primary key '".$self->record_pk."'";
				my $Row = $Rs->search({ $self->record_pk => $pkVal })->next or die usererr "Failed to find row.";
				my $tree = $self->unflatten_prune_update_packet($data);
				$self->Row_tree_update_recursive($Row,$tree);
			}
		});
	}
	catch {
		my $err = shift;
		die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
	};
	
	# Find out what columns we need, and get the key of each record
	my $readParams= { columns => [], id_in => [] };
	my %cols= ();
	my @ids= ();
	foreach my $data (@$arr) {
		$cols{$_}= 1 for keys %$data;
		push @ids, $data->{$self->record_pk};
	}
	
	#for my $trace (RapidApp::TraceCapture::collectTraces()) { RapidApp::TraceCapture::writeQuickTrace($trace) }
	#RapidApp::TraceCapture::writeFullTrace;
	
	# Return the new state of the updated rows.
	#my $dataResult= $self->read_records({ columns => [ keys %cols ], id_in => \@ids });
	#my $dataResult= $self->DataStore->read({ columns => [ keys %cols ], id_in => \@ids });
	
	#my $dataResult= $self->DataStore->read({ columns => [ keys %cols ], id_in => \@ids });
	
	my $dataResult= $self->DataStore->read({ columns => [ keys %{ $arr->[0] } ], id_in => \@ids });
	
	return {
		%$dataResult,
		success => \1,
		msg => 'Update Succeeded'
	}
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

# This function performs an update on a row, then builds a hash of new and old values,
# (using flattened names) and makes a list of changes,
#
# Unfortunately, there is no guarantee that the row is of the ResultSource we're
# configured for, so we can't use dbiclink_columns_flattener.
#
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