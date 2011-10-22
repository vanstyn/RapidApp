package RapidApp::Role::DbicLink2;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::Role::DBIC;
use Clone qw(clone);



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











# Colspec attrs can be specified as simple arrayrefs
has 'include_colspec' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );
has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );

has 'dbiclink_updatable' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'ResultSource' => (
	is => 'ro',
	isa => 'DBIx::Class::ResultSource',
	required => 1
);


has 'ResultClass' => ( is => 'ro', lazy_build => 1 );
sub _build_ResultClass {
	my $self = shift;
	my $source_name = $self->ResultSource->source_name;
	return $self->ResultSource->schema->class($source_name);
}

has 'TableSpec' => ( is => 'ro', isa => 'RapidApp::TableSpec', lazy_build => 1 );
sub _build_TableSpec {
	my $self = shift;
	my $TableSpec = RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(
		name => $self->ResultClass->table,
		relation_sep => $self->relation_sep,
		ResultClass => $self->ResultClass,
		include_colspec => $self->include_colspec
	);
	
	$TableSpec->add_all_related_TableSpecs_recursive;
	
	# Set the column order based on the include_colspec list order:
	$TableSpec->reorder_by_colspec_list($self->include_colspec);
	
	# Prevent the dummy record_pk from showing up
	$self->apply_columns( $self->record_pk => { 
		no_column => \1, 
		no_multifilter => \1, 
		no_quick_search => \1 
	});
	
	return $TableSpec;
}

has 'record_pk' => ( is => 'ro', isa => 'Str', default => '___record_pk' );
has 'primary_columns_sep' => ( is => 'ro', isa => 'Str', default => '~$~' );
has 'primary_columns' => ( is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
	my $self = shift;
	
	# If the db has no primary columns, then we have to use ALL the columns:
	unless ($self->ResultSource->primary_columns > 0) {
		my $class = $self->ResultSource->schema->class($self->ResultSource->source_name);
		$class->set_primary_key( $self->ResultSource->columns );
		$self->ResultSource->set_primary_key( $self->ResultSource->columns );
	}
	
	my @cols = $self->ResultSource->primary_columns;
	
	$self->apply_extconfig( primary_columns => [ $self->record_pk, @cols ] );

	return \@cols;
});


sub generate_record_pk_value {
	my $self = shift;
	my $data = shift;
	die "generate_record_pk_value(): expected hashref arg" unless (ref($data) eq 'HASH');
	return join(
		$self->primary_columns_sep, 
		map { defined $data->{$_} ? "'" . $data->{$_} . "'" : 'undef' } @{$self->primary_columns}
	);
}

# reverse generate_record_pk_value:
sub record_pk_cond {
	my $self = shift;
	my $value = shift;
	
	my $sep = quotemeta $self->primary_columns_sep;
	my @parts = split(/${sep}/,$value);
	
	my %cond = ();
	foreach my $col (@{$self->primary_columns}) {
		my $val = shift @parts;
		if ($val eq 'undef') {
			$val = undef;
		}
		else {
			$val =~ s/^\'//;
			$val =~ s/\'$//;
		}
		$cond{$col} = $val;
	}

	return \%cond;
}




sub BUILD {}
around 'BUILD' => sub { &DbicLink_around_BUILD(@_) };
sub DbicLink_around_BUILD {
	my $orig = shift;
	my $self = shift;
	
	die "FATAL: DbicLink and DbicLink2 cannot both be loaded" if ($self->does('RapidApp::Role::DbicLink'));
	
	$self->$orig(@_);
	
	# init primary columns:
	$self->primary_columns;
	
	# TODO: find out why this option doesn't work when applied via other, newer config mechanisms:
	$self->apply_store_config(
		remoteSort => \1
	);
	
	$self->apply_extconfig(
		remote_columns		=> \1,
		loadMask				=> \1
	);
}



sub _ResultSet {
	my $self = shift;
	my $Rs = $self->ResultSource->resultset;
	$Rs = $self->ResultSet($Rs) if ($self->can('ResultSet'));
	return $Rs;
}


sub read_records {
	my $self = shift;
	my $params = shift || $self->c->req->params;
	
	my $Rs = $self->_ResultSet;
	
	# Apply base Attrs:
	$Rs = $self->chain_Rs_req_base_Attr($Rs,$params);
	
	# Apply id_in search:
	$Rs = $self->chain_Rs_req_id_in($Rs,$params);
	
	# Apply explicit resultset:
	$Rs = $self->chain_Rs_req_explicit_resultset($Rs,$params);
	
	# Apply quicksearch:
	$Rs = $self->chain_Rs_req_quicksearch($Rs,$params);
	
	# Apply multifilter:
	$Rs = $self->chain_Rs_req_multifilter($Rs,$params);
	
	# don't use Row objects
	$Rs = $Rs->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' });
	
	my $rows = [ $Rs->all ];
	
	#Hard coded munger for record_pk:
	foreach my $row (@$rows) {
		$row->{$self->record_pk} = $self->generate_record_pk_value($row);
	}

	return {
		rows    => $rows,
		results => $Rs->pager->total_entries,
	};
}




# Applies base request attrs to ResultSet:
sub chain_Rs_req_base_Attr {
	my $self = shift;
	my $Rs = shift || $self->_ResultSet;
	my $params = shift || $self->c->req->params;
	
	$params = {
		start => 0,
		limit => 100000,
		dir => 'asc',
		%$params
	};
	
	my $attr = {
		'+select' => [],
		'+as' => [],
		join => {},
		page => int($params->{start}/$params->{limit}) + 1,
		rows => $params->{limit}
	};
	
	$attr->{order_by} = {
		'-' . $params->{dir} => lc($self->TableSpec->resolve_dbic_colname($params->{sort},$attr->{join}))
	} if (defined $params->{sort} and defined $params->{dir});
	
	my $columns = $self->param_decodeIf($params->{columns},[]);
	
	
	
	# Exclude the dummy record_pk:
	@$columns = grep { $_ ne $self->record_pk && $_ ne 'loadContentCnf' } @$columns;
	
	#Must include primary columns:
	#@$columns = ($self->ResultSource->primary_columns,@$columns);
	
	# Remove duplicates:
	uniq($columns);
	#my %Seen = ();
	#@$columns = grep { ! $Seen{$_}++ } @$columns;
	
	for my $col (@$columns) {
		my $dbic_name = $self->TableSpec->resolve_dbic_colname($col,$attr->{join});
		push @{$attr->{'+select'}}, $dbic_name;
		push @{$attr->{'+as'}}, $col;
	}
	
	# This makes it look prettier, but is probably not needed:
	#$attr->{join} = $self->TableSpec->hash_with_undef_values_to_array_deep($attr->{join});
	
	return $Rs->search_rs({},$attr);
}

# Applies id_in filter to ResultSet:
sub chain_Rs_req_id_in {
	my $self = shift;
	my $Rs = shift || $self->_ResultSet;
	my $params = shift || $self->c->req->params;
	
	my $id_in = $self->param_decodeIf($params->{id_in}) or return $Rs;
	return $Rs if (ref $id_in and ! ref($id_in) eq 'ARRAY');
	$id_in = [ $id_in ] unless (ref $id_in);
	
	# If there is more than one primary column, we have to construct the condition completely 
	# different:
	return $Rs->search_rs({ '-or' => [ map { $self->record_pk_cond($_) } @$id_in ] })
		if (@{$self->primary_columns} > 1);
		
	# If there is really only one primary column we can use '-in' :
	my $col = $self->TableSpec->resolve_dbic_colname($self->primary_columns->[0]);
	return $Rs->search_rs({ $col => { '-in' => $id_in } });
}


# Applies additional explicit resultset cond/attr to ResultSet:
sub chain_Rs_req_explicit_resultset {
	my $self = shift;
	my $Rs = shift || $self->_ResultSet;
	my $params = shift || $self->c->req->params;
	
	my $cond = $self->param_decodeIf($params->{resultset_condition},{});
	my $attr = $self->param_decodeIf($params->{resultset_attr},{});
	
	return $Rs->search_rs($cond,$attr);
}


# Applies multifilter search to ResultSet:
sub chain_Rs_req_quicksearch {
	my $self = shift;
	my $Rs = shift || $self->_ResultSet;
	my $params = shift || $self->c->req->params;
	
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	my $query = $params->{query} or return $Rs;
	
	my $fields = $self->param_decodeIf($params->{fields},[]);
	return $Rs unless (@$fields > 0);
	
	my $attr = { join => {} };
	
	my @search = ();
	push @search, { 
		$self->TableSpec->resolve_dbic_colname($_,$attr->{join}) => 
		{ like =>  '%' . $query . '%' } 
	} for (@$fields);
	
	return $Rs->search_rs({ '-or' => \@search },$attr);
}


# Applies multifilter search to ResultSet:
sub chain_Rs_req_multifilter {
	my $self = shift;
	my $Rs = shift || $self->_ResultSet;
	my $params = shift || $self->c->req->params;
	
	my $multifilter = $self->param_decodeIf($params->{multifilter}) or return $Rs;
	
	my $attr = { join => {} };
	my $cond = $self->multifilter_to_dbf($multifilter,$attr->{join});

	return $Rs->search_rs($cond,$attr);
}

sub multifilter_to_dbf {
	my $self = shift;
	my $multi = clone(shift);
	my $join = shift || {};
	
	return $self->multifilter_to_dbf({ '-and' => $multi },$join) if (ref($multi) eq 'ARRAY');
	
	die 'Invalid multifilter' unless (ref($multi) eq 'HASH');
	
	foreach my $f (keys %$multi) {
		if($f eq '-and' or $f eq '-or') {
			die "-and/-or must reference an ARRAY/LIST" unless (ref($multi->{$f}) eq 'ARRAY');
			my $new = [];
			push @$new, $self->multifilter_to_dbf($_,$join) for (@{$multi->{$f}});
			$multi->{$f} = $new;
			next;
		}
		
		my $dbfName = $self->TableSpec->resolve_dbic_colname($f,$join);
			
		if (!defined $dbfName) {
			$self->c->log->error("Client supplied Unknown multifilter-field '$f' in Ext Query!");
			next;
		}
		
		$multi->{$dbfName} = $multi->{$f};
		delete $multi->{$f};
		
		# --- translate special content conditions to "LIKE" conditions
		if (defined $multi->{$dbfName}->{contains}) {
			$multi->{$dbfName}->{like} = '%' . $multi->{$dbfName}->{contains} . '%';
			delete $multi->{$dbfName}->{contains};
		}
		
		if (defined $multi->{$dbfName}->{starts_with}) {
			$multi->{$dbfName}->{like} = $multi->{$dbfName}->{starts_with} . '%';
			delete $multi->{$dbfName}->{starts_with};
		}
		
		if (defined $multi->{$dbfName}->{ends_with}) {
			$multi->{$dbfName}->{like} = '%' . $multi->{$dbfName}->{ends_with};
			delete $multi->{$dbfName}->{ends_with};
		}
		
		if (defined $multi->{$dbfName}->{not_contain}) {
			$multi->{$dbfName}->{'not like'} = '%' . $multi->{$dbfName}->{not_contain} . '%';
			delete $multi->{$dbfName}->{not_contain};
		}
	}
	
	return $multi;
}



sub param_decodeIf {
	my $self = shift;
	my $param = shift;
	my $default = shift || undef;
	
	return $default unless (defined $param);
	
	return $param if (ref $param);
	return $self->json->decode($param);
}

has 'DataStore_build_params' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
before DataStore2_BUILD => sub {
	my $self= shift;
	
	# merge this way to make sure the opts get set, but yet still allow
	# the opts to be specifically overridden DataStore_build_params attr
	# is defined but with different params
	%{ $self->DataStore_build_params } = (
		#store_autoLoad => 1,
		reload_on_save => 0,
		remoteSort => \1,
		%{ $self->DataStore_build_params }
	);
	
	# Dynamically toggle the addition of an 'update_records' method
	# The existence of this method is part of the DataStore2 API
	$self->meta->add_method('update_records', $self->meta->find_method_by_name('_dbiclink_update_records')) if (
		$self->dbiclink_updatable and 
		not $self->can('update_records')
	);
};

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
	
	my @updated_keyvals = ();
	
	try {
		$self->ResultSource->schema->txn_do(sub {
			foreach my $data (@$arr) {
				my $pkVal= $data->{$self->record_pk};
				defined $pkVal or die ref($self)."->update_records: Record is missing primary key '".$self->record_pk."'";
				my $BaseRow = $Rs->search($self->record_pk_cond($pkVal))->next or die usererr "Failed to find row.";
				
				my @columns = grep { $_ ne $self->record_pk && $_ ne 'loadContentCnf' } keys %$data;
				
				my $relspecs = $self->TableSpec->columns_to_relspec_map(@columns);
				my %rows_relspecs = map { $_ => $self->TableSpec->related_Row_from_relspec($BaseRow,$_) } keys %$relspecs;
				
				# Update all the individual Row objects, including the base row (last)
				foreach my $relspec (reverse sort keys %rows_relspecs) {
					my $Row = $rows_relspecs{$relspec};
					my %update = map { $_->{local_colname} => $data->{$_->{orig_colname}} } @{$relspecs->{$relspec}};
					$Row->update(\%update);
				}
				
				# Get the new record_pk for the row (it probably hasn't changed, but it could have):
				push @updated_keyvals, $self->generate_record_pk_value({ $BaseRow->get_columns });
			}
		});
	}
	catch {
		my $err = shift;
		die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
	};
	
	# Perform a fresh lookup of all the records we just updated and send them back to the client:
	my $newdata = $self->DataStore->read({ columns => [ keys %{ $arr->[0] } ], id_in => \@updated_keyvals });
	
	return {
		%$newdata,
		success => \1,
		msg => 'Update Succeeded'
	};
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


1;