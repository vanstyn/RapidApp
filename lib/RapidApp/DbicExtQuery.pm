package RapidApp::DbicExtQuery;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS connector object for DBIC
#
#
# 2010-06-15:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

use Clone;


our $VERSION = '0.1';

use DateTime::Format::Flexible;
use DateTime;


use Term::ANSIColor qw(:constants);

#### --------------------- ####

has 'ResultSource'				=> ( is => 'ro',	required => 1, 	isa => 'DBIx::Class::ResultSource'			);
has 'ExtNamesToDbFields'      => ( is => 'rw',	required => 0, 	isa => 'HashRef', default => sub{ {} } 	);
has 'columns'                 => ( is => 'rw',  required => 0,    isa => 'ArrayRef', default => sub{ [] }   );

# be careful! joins can slow queries considerably
has 'joins'    					=> ( is => 'rw',	required => 0, 	isa => 'ArrayRef', default => sub{ [] } 	);
has 'implied_joins'				=> ( is => 'rw',  required => 0,    isa => 'Bool',     default => 0 );

has 'group_by'    				=> ( is => 'ro',	default => undef	);
has 'prefetch'    				=> ( is => 'ro',	default => undef	);

has 'base_search_set'    		=> ( is => 'ro',	default => undef );

###########################################################################################


has 'base_search_set_list' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return undef unless (defined $self->base_search_set and $self->base_search_set ne '');
	return $self->base_search_set if (
		ref($self->base_search_set) eq 'ARRAY' and 
		scalar @{$self->base_search_set} > 0
	);
	return [ $self->base_search_set ];
});



sub data_fetch {
	my $self = shift;
	my $params = shift or return undef;
	
	# Treat zero length string as if it wasn't defined at all:
	delete $params->{query} if (defined $params->{query} and $params->{query} eq '');
	
	# We can't limit the fields if there is a query (because it needs to be able to search 
	# in all fields and all relationships:
	delete $params->{columns} if (defined $params->{query});


	# If there is a filter, we need to make sure that column is included if we have a 
	# limited set of columns:
	if($params->{columns} and $params->{filter}) {
		my $filters = $params->{filter};
		$filters = JSON::PP::decode_json($params->{filter}) unless (ref($filters));
		foreach my $filter (@$filters) {
			push @{$params->{columns}}, $filter->{field} if ($filter->{field});
		}
	}



	my $Attr		= $params->{Attr_spec};		# <-- Optional custom Attr_spec override
	my $Search	= $params->{Search_spec};	# <-- Optional custom Search_spec override
	
	$Attr 		= $self->Attr_spec($params) unless (defined $Attr);
	$Search 		= $self->Search_spec($params) unless (defined $Search);
	
	#use Data::Dumper;
	#print STDERR BOLD .GREEN . Dumper($Attr) . CLEAR;
	
	my @rows = $self->ResultSource->resultset->search($Search,$Attr)->all;
	
	
	#my $rs = $self->ResultSource->resultset->search($Search,$Attr);
	
	my $count_Attr = Clone::clone($Attr);
	delete $count_Attr->{page} if (defined $count_Attr->{page}); # <-- ##  need to delete page and rows attrs to prevent the
	delete $count_Attr->{rows} if (defined $count_Attr->{rows}); # <-- ##  totalCount from including only the current page
	
	return {
		totalCount	=> $self->ResultSource->resultset->search($Search,$count_Attr)->count,
		rows			=> \@rows
		#totalCount => $rs->count,
		#rs => $rs
	};
}

sub Attr_spec {
	my $self = shift;
	my $params = shift;

	my $sort = 'id';
	my $dir = 'asc';
	my $start = 0;
	my $count = 1000000;
	
	my @cols = ();
	push @cols, @{$params->{columns}} if (ref($params->{columns}) eq 'ARRAY');
	push @cols, @{$self->columns} if (scalar(@{$self->columns}));
	
	
	# -- Extract cols from multifilters:
	# Most of this logic is duplicated in the Search_spec method. Would be nice to find a 
	# better way to handle this:
	if($params->{multifilter}) {
		my $multifilter = JSON::PP::decode_json($params->{multifilter});

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
	
	
	
	my $columns = [];
	# Remove duplicates:
	my %Seen = ();
   foreach my $col (@cols) {
		next if $Seen{$col}++;
		push @$columns, $col;
   }
	
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
		defined $dbfName or $dbfName= $params->{sort};
		
		if (lc($params->{dir}) eq 'desc') {
			$attr->{order_by} = { -desc => $dbfName };
		}
		elsif (lc($params->{dir}) eq 'asc') {
			$attr->{order_by} = { -asc => $dbfName };
		}
	}
	
	# --
	# Join attr support:
	if (scalar(@{$self->joins})) {
		$attr->{join}= $self->joins;
	}
	# implied joins with either use all defined values in the name-hash, or just those associated with desired 'columns'
	elsif ($self->implied_joins) {
		my $dbfNames= ();
		if (scalar(@{$columns})) {
			foreach my $colName (@{$columns}) {
				my $dbfName= $self->ExtNamesToDbFields->{$colName};
				push @$dbfNames, defined $dbfName? $dbfName : $colName;
			}
		}
		else {
			$dbfNames= [ values %{$self->ExtNamesToDbFields} ]; 
		}
		$attr->{join}= $self->_find_implied_joins($dbfNames);
	}
	
	# optional add to prefetch:
	#$attr->{prefetch} = [];
	#foreach my $rel (@{$attr->{join}}) {		push @{$attr->{prefetch}}, $rel;	}
	if (scalar(@{$columns})) {
		$attr->{'select'} = [];
		$attr->{'as'} = [];
		my $in_use = {};
		foreach my $extName (@{$columns}) {
			my $dbfName = $self->ExtNamesToDbFields->{$extName};
			if (defined $dbfName) {
				my ($relationship,$ffield) = split(/\./,$dbfName);
				$in_use->{$relationship} = 1;
			}
			else {
				$dbfName = $extName;
			}
			
			#Set the relationship to "me" if none is specified:
			$dbfName = 'me.' . $dbfName unless ($dbfName =~ /\./);
			
			push @{$attr->{'select'}}, $dbfName;
			push @{$attr->{'as'}}, $extName;
		}
		
		# Delete unused joins/relationships for performance:
		my @newjoins = ();
		foreach my $relation (@{$attr->{join}}) {
			foreach my $needed (keys %$in_use) {
				if ($self->multiCheck($needed,$relation)) {
					push @newjoins, $relation;
					last;
				}
			}
		}
		$attr->{join} = \@newjoins;
		
	}
	else {
		$attr->{'+select'} = [];
		$attr->{'+as'} = [];
		
		foreach my $k (keys %{$self->ExtNamesToDbFields}) {
			#my @trans = reverse split(/\./,$self->ExtNamesToDbFields->{$k});
			#my $t = shift @trans;
			#$t = shift(@trans) . '.' . $t if (scalar @trans > 0);
			
			my $t = $self->ExtNamesToDbFields->{$k};
			
			#if ($self->implied_joins) { 
			#	my $j = $self->hash_to_join($t) or next;
			#	push @{$attr->{join}}, $j;
			#}
			push @{$attr->{'+select'}}, $t;
			push @{$attr->{'+as'}}, $k;
		}
	}
	# --
	$attr->{prefetch} = $self->prefetch if (defined $self->prefetch);
	$attr->{group_by} = $self->group_by if (defined $self->group_by);
	
	return $attr;
}

sub _find_implied_joins {
	my $self= shift;
	my $dbfNames= shift;
	
	my $joinTree= {};
	foreach my $dbfName (@$dbfNames) {
		my @parts = split(/\./, $dbfName);
		my $curHash= $joinTree;
		for (my $i=0; $i<$#parts; $i++) { # skip the last part
			defined $curHash->{$parts[$i]} or $curHash->{$parts[$i]}= {};
			$curHash= $curHash->{$parts[$i]};
		}
	}
	
	return $self->_build_join_for_hash($joinTree);
}

sub _build_join_for_hash {
	my $self= shift;
	my $joinTree= shift;
	my @result= ();
	while (my ($reln,$subjoin) = each %$joinTree) {
		my $subCnt= scalar(keys(%$subjoin));
		if ($subCnt == 0) {
			push @result, $reln;
		}
		else {
			push @result, { $reln => $self->_build_join_for_hash($subjoin) };
		}
	}
	return $result[0] if scalar(@result) == 1;
	return \@result;
}


sub multiCheck {
	my $self = shift;
	my $string = shift;
	my $test = shift;
	
	unless (ref($test)) {
		return 1 if ($string eq $test);
		return 0;
	}
	
	if (ref($test) eq 'HASH') {
		foreach my $i (keys %$test, values %$test) {
			return 1 if ($self->multiCheck($string,$i));
		}
		return 0;
	}
	
	if (ref($test) eq 'ARRAY') {
		foreach my $i (@$test) {
			return 1 if ($self->multiCheck($string,$i));
		}
		return 0;
	}
	
	return 0;
}




=pod
sub addToFlatHashref {
	my $self = shift;
	my $hash = shift;
	my $item = shift;
	
	unless (ref($item)) {
		$hash->{$item} = 1;
		return $hash;
	}
	
	if (ref($item) eq 'HASH') {
		foreach my $i (keys %$item, values %$item) {
			$self->addToFlatHashref($hash,$i);
		}
		return $hash;
	}
	
	if (ref($item) eq 'ARRAY') {
		foreach my $i (@$item) {
			$self->addToFlatHashref($hash,$i);
		}
		return $hash;
	}
	
	return $hash;
}
=cut



sub Search_spec {
	my $self = shift;
	my $params = shift;

	my $filter_search = [];
	#my $set_filters = {};
	if (defined $params->{filter}) {
		my $filters = $params->{filter};
		$filters = JSON::PP::decode_json($params->{filter}) unless (ref($filters) eq 'ARRAY');
		if (defined $filters and ref($filters) eq 'ARRAY') {
			foreach my $filter (@$filters) {
				my $field = $filter->{field};
				# optionally convert table column name to db field name
				my $dbfName= $self->ExtNamesToDbFields->{$filter->{field}};
				$field = 'me.' . $field; # <-- http://www.mail-archive.com/dbix-class@lists.scsys.co.uk/msg02386.html
				defined $dbfName or $dbfName= $field;
				
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
		my $fields = JSON::PP::decode_json($params->{fields});
		if (defined $fields and ref($fields) eq 'ARRAY') {
			foreach my $field (@$fields) {
				# optionally convert table column name to db field name
				my $dbfName= $self->ExtNamesToDbFields->{$field};
				$field = 'me.' . $field; # <-- http://www.mail-archive.com/dbix-class@lists.scsys.co.uk/msg02386.html
				defined $dbfName or $dbfName= $field;
				
				#next if ($set_filters->{$field});
				push @$search, { $dbfName => { like =>  '%' . $params->{query} . '%' } };
			}
		}
	}

	my $Search;
	
	if($params->{multifilter}) {
		my $multifilter = JSON::PP::decode_json($params->{multifilter});
	
		my $map_dbfnames;
		$map_dbfnames = sub {
			my $multi = shift;
			if(ref($multi) eq 'HASH') {
				return $map_dbfnames->($multi->{'-and'}) if (defined $multi->{'-and'});
				return $map_dbfnames->($multi->{'-or'}) if (defined $multi->{'-or'});
				
				foreach my $f (keys %$multi) {
					# optionally convert table column name to db field name
					my $dbfName = $self->ExtNamesToDbFields->{$f};
					my $field = 'me.' . $f; # <-- http://www.mail-archive.com/dbix-class@lists.scsys.co.uk/msg02386.html
					defined $dbfName or $dbfName = $field;
					$multi->{$dbfName} = $multi->{$f};
					delete $multi->{$f};
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
 
	return $self->ResultSource->resultset->create($safe_params);
}





no Moose;
__PACKAGE__->meta->make_immutable;
1;