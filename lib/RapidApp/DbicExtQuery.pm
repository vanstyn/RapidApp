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



our $VERSION = '0.1';

use DateTime::Format::Flexible;
use DateTime;


use Term::ANSIColor qw(:constants);

#### --------------------- ####

has 'ResultSource'				=> ( is => 'ro',	required => 1, 	isa => 'DBIx::Class::ResultSource'							);



###########################################################################################


sub data_fetch {
	my $self = shift;
	my $params = shift or return undef;

	my $Attr 	= $self->Attr_spec($params);
	my $Search 	= $self->Search_spec($params);
	
	my @rows = $self->ResultSource->resultset->search($Search,$Attr)->all;
	
	return {
		totalCount	=> $self->ResultSource->resultset->search($Search)->count,
		rows			=> \@rows
	};
}

sub Attr_spec {
	my $self = shift;
	my $params = shift;

	my $sort = 'id';
	my $dir = 'asc';
	my $start = 0;
	my $count = 10000;
	
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
		if (lc($params->{dir}) eq 'desc') {
			$attr->{order_by} = { -desc => $params->{sort} };
		}
		elsif (lc($params->{dir}) eq 'asc') {
			$attr->{order_by} = { -asc => $params->{sort} };
		}
	}

	return $attr;
}



sub Search_spec {
	my $self = shift;
	my $params = shift;

	my $filter_search = [];
	#my $set_filters = {};
	if (defined $params->{filter}) {
		my $filters = JSON::decode_json($params->{filter});
		if (defined $filters and ref($filters) eq 'ARRAY') {
			foreach my $filter (@$filters) {
			
				##
				## String type filter:
				##
				if ($filter->{type} eq 'string') {
					push @$filter_search, { $filter->{field} => { like =>  '%' . $filter->{value} . '%' } };
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
						push @$filter_search, {$filter->{field} => { '>' =>  $start_str, '<' => $end_str } };
					}
					elsif ($filter->{comparison} eq 'gt') {
						my $str = $new_dt->ymd . ' ' . $new_dt->hms;
						push @$filter_search, {$filter->{field} => { '>' =>  $str } };
					}
					elsif ($filter->{comparison} eq 'lt') {
						$new_dt->add({ days => 1 });
						my $str = $new_dt->ymd . ' ' . $new_dt->hms;
						push @$filter_search, {$filter->{field} => { '<' =>  $str } };
					}
				}
				##
				## Numeric type filter
				##
				elsif ($filter->{type} eq 'numeric') {
					if ($filter->{comparison} eq 'eq') {
						push @$filter_search, {$filter->{field} => { '=' =>  $filter->{value} } };
					}
					elsif ($filter->{comparison} eq 'gt') {
						push @$filter_search, {$filter->{field} => { '>' =>  $filter->{value} } };
					}
					elsif ($filter->{comparison} eq 'lt') {
						push @$filter_search, {$filter->{field} => { '<' =>  $filter->{value} } };
					}
				}
				##
				## List type filter (aka 'enum')
				##
				elsif ($filter->{type} eq 'list') {
					my @enum_or = ();
					foreach my $val (@{$filter->{value}}) {
						push @enum_or, {$filter->{field} => { '=' =>  $val } };
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
		my $fields = JSON::decode_json($params->{fields});
		if (defined $fields and ref($fields) eq 'ARRAY') {
			foreach my $field (@$fields) {
				#next if ($set_filters->{$field});
				push @$search, { $field => { like =>  '%' . $params->{query} . '%' } };
			}
		}
	}

	my $Search;
	if (scalar @$filter_search > 0) {
		#unshift @$search, { -and => $filter_search };
		$Search = { -and => [{ -or => $search },{ -and => $filter_search }] };
	}
	else {
		$Search = $search;
	}
	
	return $Search;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;