package RapidApp::Role::DbicLink;


use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DbicAppCombo;

use Switch;

use Moose::Util::TypeConstraints;

has 'joins' => ( is => 'ro', default => sub {[]} );

has 'base_search_set' => ( is => 'ro',	default => undef );
has 'fieldname_transforms' => ( is => 'ro', default => sub {{}});
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


has 'get_ResultSet_Handler' => ( is => 'ro', isa => 'Maybe[RapidApp::Handler]', lazy => 1, default => undef );

has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	
	my $cnf = {
		ResultSource				=> $self->ResultSource,
		get_ResultSet_Handler	=> $self->get_ResultSet_Handler,
		ExtNamesToDbFields 		=> $self->fieldname_transforms,
		joins 						=> $self->joins,
		#implied_joins			=> 1
		#group_by				=> [ 'me.id' ],
	};
	
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
	
	return $map;
}

has 'join_col_prefix_map' => (
	is => 'ro',
	isa => 'HashRef',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $map = {};
		foreach my $join (@{$self->joins}) {
			$map->{$self->hashref_concat_recurse($join)} = 1;
		}
		return $map;
	}
);

sub hashref_concat_recurse {
	my ($self, @list) = @_;
	
	my @join_list = ();
	foreach my $ele (@list) {
		if (ref($ele)) {
			die "only hashrefs or strings are supported" unless (ref($ele) eq 'HASH');
			push @join_list, $self->hashref_concat_recurse(%$ele);
		}
		else {
			push @join_list, $ele;
		}
	}
	my $str = join('_',@join_list);
	return $str;
}


has 'limit_dbiclink_columns' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str]',
	default   => sub { [] },
	handles => {
		all_limit_dbiclink_columns		=> 'elements',
		add_limit_dbiclink_columns		=> 'push',
		has_no_limit_dbiclink_columns 	=> 'is_empty',
	}
);

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

sub BUILD {}
around 'BUILD' => sub {
	my $orig = shift;
	my $self = shift;
	
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
	
	my $addColRecurse;
	$addColRecurse = sub {
		my $Source = shift;
		my $rel_name = shift;
		my $prefix = shift;
		
		foreach my $column ($Source->columns) {
			
			#print STDERR '      ' . GREEN . BOLD . ref($self) . ': ' . $column . CLEAR . "\n";
			my $colname = $column;
			$colname = $prefix . '_' . $column if ($prefix);
			
			next unless ($self->has_no_limit_dbiclink_columns or $self->has_limit_dbiclink_column($colname));
			next if ($self->has_exclude_dbiclink_column($colname));
			
			next unless ($self->valid_colname($colname));

			$self->fieldname_transforms->{$colname} = $rel_name . '.' . $column unless ($colname eq $column);
			
			my $opts = { name => $colname };
			my $col_info = $Source->column_info($column);
			my $type = $self->dbic_to_ext_type($col_info->{data_type});
			$opts->{filter}->{type} = $type if ($type);
			
			$self->apply_columns( $colname => $opts );
			
			$self->log->debug_dbiclink(BOLD . ref($self) . ': ' . $colname, $self->log->FLUSH);
			
			# -- Build combos (dropdowns) for every related field (for use in multifilters currently):
			if ($prefix and not ($ENV{NO_REL_COMBOS} or $self->no_rel_combos)) {
				
				
				my $module_name = 'combo_' . $colname;
				$self->apply_modules(
					$module_name => {
						class	=> 'RapidApp::DbicAppCombo',
						params	=> {
							valueField		=> $self->record_pk,
							name				=> $column,
							ResultSource	=> $Source
						}
					}
				) ;
				
				#print STDERR '       ' . CYAN . BOLD . 'apply_columns: ' . $colname . CLEAR . "\n";
				$self->apply_columns(
					$colname => { field_cnf => $self->Module($module_name)->content }
				);
			}
			# --
		}

		foreach my $rel ($Source->relationships) {
			#print STDERR '     ' . RED . 'rel: ' . $rel . '  (' . $Source->source_name . ')' . CLEAR . "\n";
			next unless (defined $self->join_map->{$Source->source_name}->{$rel});
			#print STDERR '     ' . GREEN . 'source: ' . $Source->source_name . CLEAR . "\n";
			my $info = $Source->relationship_info($rel);
			
			#$self->log->debug(YELLOW . BOLD . Dumper($info) . CLEAR);
			
			#next unless ($info->{attrs}->{accessor} eq 'single');

			my $subSource = $Source->schema->source($info->{class});
			my $new_prefix = $rel;
			$new_prefix = $prefix . '_' . $rel if ($prefix);
			
			# only follow prefixes that are defined in the joins:
			#print STDERR '     ' . RED . BOLD . '$addColRecurse: ' . $new_prefix . CLEAR . "\n";
			$addColRecurse->($subSource,$rel,$new_prefix) if ($self->join_col_prefix_map->{$new_prefix});
			
		}
	};
	
	$addColRecurse->($self->ResultSource);
	
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
	my $self = shift;

	my $params = $self->c->req->params;
	
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	if(defined $params->{columns} and not ref($params->{columns})) {
		my $decoded = $self->json->decode($params->{columns});
		$params->{columns} = $decoded;
		
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
	};
	
	my @arg = ( $params );
	push @arg, $self->read_extra_search_set if ($self->can('read_extra_search_set'));
	my $data = $self->DbicExtQuery->data_fetch(@arg);

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



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;