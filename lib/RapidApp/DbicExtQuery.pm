package RapidApp::DbicExtQuery;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS connector object for DBIC
#
#
# 2010-06-15:	Version 0.1 (HV)
#	Initial development


### DEPRECATED - WILL BE REMOVED ###


use strict;
use Moose;

use Clone;


our $VERSION = '0.1';

use DateTime::Format::Flexible;
use DateTime;

use RapidApp::Debug 'DEBUG';
use RapidApp::Include qw(sugar perlutil);


#### --------------------- ####

# The root ResultSource of the query.
# All joins and unqualified columns are relative to this.
has 'ResultSource'            => ( is => 'ro',	required => 1, 	isa => 'DBIx::Class::ResultSource' );

# Some Ext components require a single primary key column.
# If your table doens't have a single column pk, you need to fake it.
has 'record_pk'               => ( is => 'ro',  required => 1,  isa => 'Str' );

# Specify this to use a specialized ResultSet for the query.
# If not specified, ResultSource->resultset will be used.
has 'get_ResultSet_Handler'   => ( is => 'ro',  isa => 'Maybe[RapidApp::Handler]', default => undef );

# TODO: document this...
has 'dbf_virtual_fields'      => ( is => 'ro',	required => 0, 	isa => 'Maybe[HashRef]', default => undef 	);

# This is an input parameter only.  Changing it after the constructor has no effect.
# Any field listed here will be used literally in the query without translation.
# These get translated into entries in ExtNamedToDbFields.
has 'literal_dbf_colnames'    => ( is => 'ro',  required => 0,  isa => 'ArrayRef[Str]' );

# These fields will be removed from search requests.
has 'no_search_fields'        => ( is => 'ro',  required => 0,  isa => 'ArrayRef[Str]', default => sub { [] } );

# This maps Ext column names to dotted "relation.relation.col" names
# This is an input parameter used to build or augment ExtNamesToDbFields.
# ExtNamesToDbFields is the final authority.
has 'extColMap'               => ( is => 'rw',  required => 0,  isa => 'RapidApp::DBIC::RelationTreeFlattener' );

# This maps Ext named columns to "RelName.ColName" format used by DBIC.
# This map can be populated by the caller, but it will be augmented with
# dbf_virtual_fields and extColMap.
has 'ExtNamesToDbFields'      => ( is => 'rw',	required => 0, 	isa => 'HashRef', default => sub{ {} } 	);

# 'joins' is the total list of possible joins for the query.
# Joins may be eliminated based on whether they are needed.
# You may specify joins to the constructor, but they will be merged with any
# found in extColMap, so you only need to specify this if you are doing
# something special.
has 'joins'                   => ( is => 'rw',  required => 0,  isa => 'ArrayRef', default => sub {[]} );

# These should probably just be applied to the ResultSet in get_ResultSet_Handler
has 'group_by'                => ( is => 'ro',	default => undef	);
has 'distinct'                => ( is => 'ro',	default => 0 );
has 'prefetch'                => ( is => 'ro',	default => undef	);

# TODO: document me
has 'base_search_set'         => ( is => 'ro',	default => undef );


###########################################################################################

sub c { RapidApp->active_request_context }

sub BUILD {
	my $self = shift;
	
	# merge everything into ExtNamesToDbFields
	if ($self->dbf_virtual_fields) {
		foreach my $col (keys %{ $self->dbf_virtual_fields }) {
			$self->ExtNamesToDbFields->{$col}= $col;
		}
	}
	if ($self->literal_dbf_colnames) {
		foreach my $col (@{ $self->literal_dbf_colnames }) {
			$self->ExtNamesToDbFields->{$col}= $col;
		}
	}
	if ($self->extColMap) {
		for my $extCol ($self->extColMap->getAllFlatKeys) {
			my $colPath= $self->extColMap->flatKeyToCol($extCol);
			my $dbicName= (scalar(@$colPath) > 1)?
				  $colPath->[-2].'.'.$colPath->[-1]
				: 'me.'.$colPath->[0]; # <-- http://www.mail-archive.com/dbix-class@lists.scsys.co.uk/msg02386.html
			$self->ExtNamesToDbFields->{$extCol}= $dbicName;
		}
	}
	
	# Make sure the record_pk is included somewhere.
	croak "record_pk '".$self->record_pk."' was not included in extColMap or dbf_virtual_fields or literal_dbf_colnames!"
		unless $self->ExtNamesToDbFields->{$self->record_pk};
	
	# Now merge and simplify all the joins we know about
	my $mergedJoins= {};
	$self->simplify_joins($mergedJoins, $self->extColMap->spec->relTree, undef) if $self->extColMap;
	$self->simplify_joins($mergedJoins, $self->joins, undef) if $self->joins;
	$self->joins([ $mergedJoins ]);
	
	DEBUG( dbicextquery => 'Ext2DB =>', $self->ExtNamesToDbFields, 'joins =>', $self->joins );
}

sub ResultSet {
	my $self = shift;
	return $self->get_ResultSet_Handler->call if (defined $self->get_ResultSet_Handler);
	return $self->ResultSource->resultset;
}

# TODO: document me
has 'base_search_set_list' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return undef unless (defined $self->base_search_set and $self->base_search_set ne '');
	return $self->base_search_set if (
		ref($self->base_search_set) eq 'ARRAY' and 
		scalar @{$self->base_search_set} > 0
	);
	return [ $self->base_search_set ];
});

# Build a map from the array we were given in the constructor
has '_forbidden_search_fields' => ( is => 'ro', lazy => 1, default => sub{
	my $self= shift;
	return { map { $_ => 1 } @{ $self->no_search_fields } }
});

# When deciding if a field is searchable, check both the Ext and Dbic names.
sub search_permitted {
	my ($self, $fieldName)= @_;
	return 0 if $self->_forbidden_search_fields->{$fieldName};
	return 0 if $self->_forbidden_search_fields->{$self->ExtNamesToDbFields->{$fieldName} || ''};
	return 1;
}

sub build_data_fetch_resultset {
	my $self = shift;
	my $params = shift or return undef;
	my $extra_search = shift;
	
	# Treat zero length string as if it wasn't defined at all:
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	# We can't limit the fields if there is a query (because it needs to be able to search 
	# in all fields and all relationships:
	#delete $params->{columns} if (defined $params->{query});

	#Add all the fields (assciated with string search/query) This replaces the above delete $params->{columns} 
	push @{$params->{columns}},@{RapidApp::JSON::MixedEncoder::decode_json($params->{fields})} if (defined $params->{query} and defined $params->{fields});

	# If there is a filter, we need to make sure that column is included if we have a 
	# limited set of columns:
	if($params->{columns} and $params->{filter}) {
		my $filters = $params->{filter};
		$filters = RapidApp::JSON::MixedEncoder::decode_json($params->{filter}) unless (ref($filters));
		foreach my $filter (@$filters) {
			push @{$params->{columns}}, $filter->{field} if ($filter->{field});
		}
	}
	
	# vv ---
	# Add composit_fields from dbf_virtual_fields to the column list:
	if($params->{columns} and $self->dbf_virtual_fields) {
		my %add = ();
		foreach my $col (@{$params->{columns}}) {
			delete $add{$col} if ($add{$col}); # <-- no need to add if its already in the column list
			next unless (
				ref($self->dbf_virtual_fields->{$col}) eq 'HASH' and
				ref($self->dbf_virtual_fields->{$col}->{composit_fields}) eq 'ARRAY'
			);
			foreach my $composit (@{$self->dbf_virtual_fields->{$col}->{composit_fields}}) {
				$add{$composit}++;
			}
		}
		push @{$params->{columns}},keys %add;
	}
	# ^^ ---

	# Attr and Search can be overridden via $params.
	# else we calculate them.
	my $Attr   = $params->{Attr_spec} || $self->Attr_spec($params);
	my $Search = $params->{Search_spec} || $self->Search_spec($params,$extra_search);
	
	return $self->ResultSet->search($Search,$Attr);
}

sub data_fetch {
	my $self= shift;
	my $Rs= $self->build_data_fetch_resultset(@_);
	return {
		rows			=> [ $Rs->all ],
		totalCount	=> $Rs->pager->total_entries,
	};
}

sub data_fetch_as_hashes {
	my $self= shift;
	my $rs= $self->build_data_fetch_resultset(@_)->search_rs(undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' });
	return {
		rows       => [ $rs->all ],
		totalCount => $rs->pager->total_entries,
	}
}

sub Attr_spec {
	my $self = shift;
	my $params = shift;

	my $sort = 'id';
	my $dir = 'asc';
	my $start = 0;
	my $count = 1000000;
	
	my @cols;
	push @cols, @{$params->{columns}} if (ref($params->{columns}) eq 'ARRAY');
	
	# -- Extract cols from multifilters:
	# Most of this logic is duplicated in the Search_spec method. Would be nice to find a 
	# better way to handle this:
	if($params->{multifilter}) {
		my $multifilter = RapidApp::JSON::MixedEncoder::decode_json($params->{multifilter});

		my $multi_dbfnames;
		$multi_dbfnames = sub {
			my $multi = shift;
			if(ref($multi) eq 'HASH') {
				return $multi_dbfnames->($multi->{'-and'}) if (defined $multi->{'-and'});
				return $multi_dbfnames->($multi->{'-or'}) if (defined $multi->{'-or'});
				
				foreach my $f (keys %$multi) {
					push @cols, $f
				}
			}
			elsif(ref($multi) eq 'ARRAY') {
				foreach my $item (@$multi) {
					$multi_dbfnames->($item);
				}
			}
		};
		$multi_dbfnames->($multifilter);
	}
	# --
	
	# Remove duplicates:
	my %Seen = ();
	my $columns = [ grep { ! $Seen{$_}++ } @cols ];
	
	if (defined $params->{start} and defined $params->{limit}) {
		$start = $params->{start};
		$count = $params->{limit};
	}
	
	my $page = int($start/$count) + 1;
	
	my $attr = {
		page		=> $page,
		rows		=> $count
	};
	
	if (defined $params->{sort} and defined $params->{dir}) {
		# optionally convert table column name to db field name
		my $dbfName= $self->ExtNamesToDbFields->{$params->{sort}};
		if (defined $dbfName) {
			if (lc($params->{dir}) eq 'desc') {
				$attr->{order_by} = { -desc => $dbfName };
			}
			elsif (lc($params->{dir}) eq 'asc') {
				$attr->{order_by} = { -asc => $dbfName };
			}
		} else {
			$self->c->log->error('Client supplied unknown sort-by field "'.$params->{sort}.'" in Ext Query!  Not sorting.');
		}
	}
	
	# Start with all joins.  Reduce them as needed, below.
	if (scalar @{$self->joins}) {
		$attr->{join}= $self->joins;
	}
	
	# optional add to prefetch:
	#$attr->{prefetch} = [];
	#foreach my $rel (@{$attr->{join}}) {		push @{$attr->{prefetch}}, $rel;	}
	
	# Either the user specifies a list of columns, or we use all columns.
	if (scalar @$columns) {
		$attr->{'select'} = [];
		$attr->{'as'} = [];
		my $in_use = {};
		for my $extName (@$columns) {
			my $dbfName = $self->ExtNamesToDbFields->{$extName};
			if (defined $dbfName) {
				my ($relationship,$ffield) = split(/\./,$dbfName);
				$in_use->{$relationship} = 1 unless $relationship eq 'me';
				push @{$attr->{'select'}}, $self->transform_select_item($dbfName);
				push @{$attr->{'as'}}, $extName;
			}
			else {
				$self->c->log->error('Client requested an unknown column "'.$extName.'" in Ext Query!  Ignoring it.');
			}
		}
		
		# Delete unused joins/relationships for performance.
		my $newJoins= {};
		$self->simplify_joins($newJoins, $attr->{join}, $in_use);
		$attr->{join}= $newJoins;
	}
	else {
		$attr->{'+select'} = [];
		$attr->{'+as'} = [];
		
		foreach my $k (sort keys %{$self->ExtNamesToDbFields}) {
			my $t = $self->ExtNamesToDbFields->{$k};
			push @{$attr->{'+select'}}, $self->transform_select_item($t);
			push @{$attr->{'+as'}}, $k;
		}
	}
	# --
	$attr->{prefetch} = $self->prefetch if (defined $self->prefetch);
	$attr->{group_by} = $self->group_by if (defined $self->group_by);
	$attr->{distinct} = 1 if $self->distinct;
	
	return $attr;
}

=head2 $self->simplify_joins( \%simplifiedResult, $joinSpec, \%requiredSetOfRelations || undef);

Take all data in $joinSpec (which can be anything DBIC will accept, which
includes hashes and arrays) and eliminate any relation not mentioned in
\%requiredSetOfRelations.  If %requiredSetOfRelations is undef, no relations
are eliminated.

This function converts things like

  [ { a => b },
    { a => { b => c } },
    a,
    a => [ d, f ],
  ]
  
into

  { a => { b => { c => {}, }, d => {}, f => {} } }
  
resulting in a minimum of joined tables.

This routine would be a little nicer if the output were

  { a => [ { b => c }, d, f ] }

but that would be a lot of work, and nothing to gain.

Note that for DBIC, regardless of nesting, the relations must each have unique
names, which is why %requiredSetOfRelations is a one-level hash rather than
a tree of hashes.  However, the joins must be specified to DBIC as a tree.

=cut
sub simplify_joins {
	my ($self, $simplifiedNode, $joins, $neededSet)= @_;
	return 0 unless defined $joins;
	
	if (!ref $joins) {
		return 0 unless (!defined $neededSet || $neededSet->{$joins});
		$simplifiedNode->{$joins}= {};
		return 1;
	}
	
	if (ref $joins eq 'HASH') {
		my $used= 0;
		while (my ($k, $v)= each %$joins) {
			my $inner= $simplifiedNode->{$k} || {};
			if ($self->simplify_joins($inner, $v, $neededSet) || (!defined $neededSet || $neededSet->{$k})) {
				$simplifiedNode->{$k}= $inner;
				$used= 1;
			}
		}
		return $used;
	}
	
	if (ref $joins eq 'ARRAY') {
		my $used= 0;
		for (@$joins) {
			$used += $self->simplify_joins($simplifiedNode, $_, $neededSet);
		}
		return $used > 0;
	}
}


sub Search_spec {
	my $self = shift;
	my $params = shift;
	my $extra_search = shift;

	my $filter_search = [];
	#my $set_filters = {};
	if (defined $params->{filter}) {
		my $filters = $params->{filter};
		$filters = RapidApp::JSON::MixedEncoder::decode_json($params->{filter}) unless (ref($filters) eq 'ARRAY');
		if (defined $filters and ref($filters) eq 'ARRAY') {
			foreach my $filter (@$filters) {
				my $field = $filter->{field};
				next unless $self->search_permitted($field);
				
				# convert table column name to db field name
				my $dbfName= $self->ExtNamesToDbFields->{$field};
				if (!defined $dbfName) {
					$self->c->log->warn("Client supplied Unknown filter-field '$field' in Ext Query!");
					next;
				}
				
				##
				## String type filter:
				##
				if ($filter->{type} eq 'string') {
					push @$filter_search, { $dbfName => { like =>  '%' . $filter->{value} . '%' } };
				}
				##
				## Date type filter:
				##
				elsif ($filter->{type} eq 'date') {
					my $dt = DateTime::Format::Flexible->parse_datetime($filter->{value}) or next;
					my $new_dt = DateTime->new(
						year		=> $dt->year,
						month		=> $dt->month,
						day		=> $dt->day,
						hour		=> 00,
						minute	=> 00,
						second	=> 00
					);
					if ($filter->{comparison} eq 'eq') {
						my $start_str = $new_dt->ymd . ' ' . $new_dt->hms;
						$new_dt->add({ days => 1 });
						my $end_str = $new_dt->ymd . ' ' . $new_dt->hms;
						push @$filter_search, {$dbfName => { '>' =>  $start_str, '<' => $end_str } };
					}
					elsif ($filter->{comparison} eq 'gt') {
						my $str = $new_dt->ymd . ' ' . $new_dt->hms;
						push @$filter_search, {$dbfName => { '>' =>  $str } };
					}
					elsif ($filter->{comparison} eq 'lt') {
						$new_dt->add({ days => 1 });
						my $str = $new_dt->ymd . ' ' . $new_dt->hms;
						push @$filter_search, {$dbfName => { '<' =>  $str } };
					}
				}
				##
				## Numeric type filter
				##
				elsif ($filter->{type} eq 'numeric') {
					if ($filter->{comparison} eq 'eq') {
						push @$filter_search, {$dbfName => { '=' =>  $filter->{value} } };
					}
					elsif ($filter->{comparison} eq 'gt') {
						push @$filter_search, {$dbfName => { '>' =>  $filter->{value} } };
					}
					elsif ($filter->{comparison} eq 'lt') {
						push @$filter_search, {$dbfName => { '<' =>  $filter->{value} } };
					}
				}
				##
				## List type filter (aka 'enum')
				##
				elsif ($filter->{type} eq 'list') {
					my @enum_or = ();
					foreach my $val (@{$filter->{value}}) {
						push @enum_or, {$dbfName => { '=' =>  $val } };
					}
					push @$filter_search, { -or => \@enum_or };
				}
				##
				##
				##
			}
		}
	}
	
	my $search = [];
	if (defined $params->{fields} and defined $params->{query} and $params->{query} ne '') {
		my $fields = RapidApp::JSON::MixedEncoder::decode_json($params->{fields});
		if (defined $fields and ref($fields) eq 'ARRAY') {
			foreach my $field (@$fields) {
				next unless $self->search_permitted($field);
				
				# convert table column name to db field name
				my $dbfName= $self->ExtNamesToDbFields->{$field};
				if (!defined $dbfName) {
					$self->c->log->warn("Client supplied Unknown filter-field '$field' in Ext Query!");
					next;
				}
				
				#next if ($set_filters->{$field});
				push @$search, { $dbfName => { like =>  '%' . $params->{query} . '%' } };
			}
		}
	}

	my $Search;
	
	if($params->{multifilter}) {
		my $multifilter = RapidApp::JSON::MixedEncoder::decode_json($params->{multifilter});
	
		my $map_dbfnames;
		$map_dbfnames = sub {
			my $multi = shift;
			if(ref($multi) eq 'HASH') {
				return $map_dbfnames->($multi->{'-and'}) if (defined $multi->{'-and'});
				return $map_dbfnames->($multi->{'-or'}) if (defined $multi->{'-or'});
				
				foreach my $f (keys %$multi) {
					# Not sure why this is commented out.
					# next unless $self->search_permitted($f);
					
					# convert table column name to db field name
					my $dbfName = $self->ExtNamesToDbFields->{$f};
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
					# ---
					
					# -- Add '%' characters to "like" searches: (disabled in favor of special content conditions above)
					#if (defined $multi->{$dbfName}->{like} and not $multi->{$dbfName}->{like} =~ /\%/) {
					#	$multi->{$dbfName}->{like} = '%' . $multi->{$dbfName}->{like} . '%';
					#}
					# --

				}
			}
			elsif(ref($multi) eq 'ARRAY') {
				foreach my $item (@$multi) {
					$map_dbfnames->($item);
				}
			}
		};
		
		$map_dbfnames->($multifilter);
	
	
		# Recursive sub to make all lists explicitly '-and' lists:
		my $add_ands;
		$add_ands = sub {
			my $multi = shift;
			return $multi unless (ref($multi) eq 'ARRAY');
			
			foreach my $item (@$multi) {
				$item = $add_ands->($item);
			}
			return { '-and' => $multi };
		};
		
		push @$filter_search, $add_ands->($multifilter);
	}
	
	push @$filter_search, @{ $self->base_search_set_list } if (defined $self->base_search_set_list);
	push @$filter_search, @{ $extra_search } if (defined $extra_search);
	
	# -- vv -- support for id_in:
	if ($params->{id_in}) {
		my $in;
		$in = $params->{id_in} if (ref($params->{id_in}) eq 'ARRAY');
		$in = $self->json->decode($params->{id_in}) unless ($in);
		my $id_col= $self->ExtNamesToDbFields->{$self->record_pk};
		push @$filter_search, { $id_col => { '-in' => $in } };
	}
	# -- ^^ --
	
	if (scalar @$filter_search > 0) {
		#unshift @$search, { -and => $filter_search };
		$Search = { -and => [{ -or => $search },{ -and => $filter_search }] };
	}
	else {
		$Search = $search;
	}
	
	return $Search;
}



sub safe_create_row {
	my $self = shift;
	my $params = shift;
 
	my $safe_params = {};
	foreach my $col ($self->ResultSource->columns) {
		$safe_params->{$col} = $params->{$col} if (defined $params->{$col});
	}
 
	return $self->ResultSet->create($safe_params);
}


sub transform_select_item {
	my $self = shift;
	my $col = shift;
	return $col unless (
		defined $self->dbf_virtual_fields and
		defined $self->dbf_virtual_fields->{$col}
	);
	
	my $virt = $self->dbf_virtual_fields->{$col};
	# the database function can either be specified as the value directly, 
	# or as a subkey 'function' within the value (if its a HashRef):
	return $virt->{function} if (ref($virt) eq 'HASH' and defined $virt->{function});
	return $virt;
	
	#return $self->dbf_virtual_fields->{$col} ? $self->dbf_virtual_fields->{$col} : $col;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;