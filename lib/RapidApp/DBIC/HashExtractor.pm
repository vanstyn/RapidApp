package RapidApp::DBIC::HashExtractor;

=head1 NAME

RapidApp::DBIC::HashExtractor

=head1 SYNOPSYS

  	my $ex= RapidApp::DBIC::HashExtractor->new(
     source => $db->source('Object'),
     spec => {
       workspace => {},
       user => {
         user_to_reporters_users => {},
       },
     },
  );
  
  my $rs= $db->resultset('Object')->search_rs({ object_id => 31188 });
  print Dumper $ex->process_resultset($rs);
  
  ---------------------
  
  {
    'deleted' => '0',
    'updated_ts' => '2011-06-17 23:37:57',
    'created_ts' => '2011-03-28 00:08:27',
    'parent_workspace_id' => '31180',
    'read_only' => '0',
    'type_id' => '1',
    'user' => {
      'disabled' => '0',
      'user_to_reporters_users' => [
        {
          'reporter_id' => '31185',
          'user_id' => '31188'
        },
        {
          'reporter_id' => '31186',
          'user_id' => '31188'
        }
      ],
      'username' => 'mconrad',
      'password' => 'foo',
      'object_id' => '31188',
      'last_login_ts' => '2011-06-17 23:37:57'
    },
  }

=head1 DESCRIPTION

This module takes a resultsource and a column/relation specification, and builds
an extraction routine that efficiently pulls in the requested data, and returns it as
a hash.

It is very similar to DbicExtQuery, except that it returns a tree of hashes instead of
a flat table, and can "tree up" multi-relations.

The extraction routine can then be used to export any number of resultsets of that
source with minimal overhead.

The current design pulls everything in as one query with potentially many joins.
If several large many-to-many joins are used at once, this will result in a large
cross-product, and will be slow.  If the joined rows are relatively few, the cost
of the cross-product should be outweighed by avoiding the overhead of setting up
lots of tiny sub-queries.

=cut

use Moose;
use RapidApp::Debug 'DEBUG';

has spec   => ( is => 'ro', isa => 'HashRef', required => 1 );
has source => ( is => 'ro', isa => 'DBIx::Class::ResultSource', required => 1 );

sub process_resultset {
	my ($self, $resultset)= @_;
	my $cursor= $resultset->search_rs(undef, {
			columns => $self->query_params->{cols},
			join => $self->query_params->{joins}
		})->cursor;
	my $state= {};
	my @items;
	my $rootHandler= $self->query_params->{rootHandler};
	while (my @row= $cursor->next) {
		my $item= $rootHandler->consume_cursor_row(\@row, $state);
		push @items, $item if $item;
	}
	return @items;
}

has query_params => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
sub _build_query_params {
	my $self= shift;
	my @allCols= ();
	my %joins= ();
	my $relHandler= $self->_build_relation_handler(\@allCols, \%joins, 'me', 0, $self->source->resultset, $self->spec);
	return { cols => \@allCols, joins => \%joins, rootHandler => $relHandler };
}

sub _build_relation_handler {
	my ($self, $allCols, $joins, $relName, $isMulti, $rs, $spec)= @_;
	
	# If they are specified as an array, use those
	# If they are not specified, use all columns
	my @cols= ref $spec->{cols} eq 'ARRAY'? @{ $spec->{cols} } : $rs->result_source->columns;
	
	# if the primary columns weren't selected, we need to add them
	my $firstColOfs= scalar(@$allCols);
	my @pkCols= $rs->result_source->primary_columns;
	my @colsWithPk= @cols;
	my @pkIdx= map { $firstColOfs + _find_idx_in_array_or_add(\@colsWithPk, $_) } @pkCols;
	
	# append these columns to the total selected
	push @$allCols, map { $relName . '.' . $_ } @colsWithPk;
	
	my @handlers;
	# for all other keys in spec, process relations
	for my $key (keys %$spec) {
		next if $key eq 'cols';
		my $val= $spec->{$key};
		my $relInfo= $rs->result_source->relationship_info($key) or die "No such relationship: ".$rs->result_source->source_name."->".$key;
		my $relIsMulti= $relInfo->{attrs}{accessor} eq 'multi';
		push @handlers, $self->_build_relation_handler(
			$allCols,
			($joins->{$key} ||= {}),
			$key,
			$relIsMulti,
			$rs->related_resultset($key),
			$val
		);
	}
	
	return RapidApp::DBIC::HashExtractor::RelationHandler->new(
		relName => $relName,
		isMulti => $isMulti,
		firstColIdx => $firstColOfs,
		cols => \@cols,
		source => $rs->result_source,
		subrels => \@handlers,
		pkIdx => \@pkIdx,
		query_params => {},
	);
}

sub _find_idx_in_array_or_add {
	my ($ary, $val)= @_;
	for (my $i=0; $i < scalar(@$ary); $i++) {
		return $i if $ary->[$i] eq $val;
	}
	push @$ary, $val;
	return scalar($#$ary);
}

no Moose;
__PACKAGE__->meta->make_immutable;

package RapidApp::DBIC::HashExtractor::RelationHandler;
use Moose;
use RapidApp::Debug 'DEBUG';

has relName      => ( is => 'ro', isa => 'Str', required => 1 );
has isMulti      => ( is => 'ro', isa => 'Str', required => 1 );
has firstColIdx  => ( is => 'ro', isa => 'Int', required => 1 );
has cols         => ( is => 'ro', isa => 'ArrayRef', auto_deref => 1, required => 1 );
has source       => ( is => 'rw', required => 1 );
has subrels      => ( is => 'ro', isa => 'ArrayRef[RapidApp::DBIC::HashExtractor::RelationHandler]', auto_deref => 1, required => 1 );
has pkIdx        => ( is => 'ro', isa => 'ArrayRef[Int]', auto_deref => 1, required => 1 );
has query_params => ( is => 'ro', isa => 'Maybe[HashRef]' );

# returns undef if the pk has not changed since last time
# else returns the pk in the current row
sub get_pk {
	my ($self, $cursorRow)= @_;
	my $curPk= [ map { $cursorRow->[$_] } $self->pkIdx ];
	# if no key fields are set, we assume there is no record either
	return undef unless grep { defined $_ } @$curPk;
	#return undef if $lastPkVals && _array_equals($curPk, $lastPkVals);
	return ($curPk, _stringify_pk(@$curPk));
}
sub _array_equals {
	my ($a, $b)= @_;
	return 0 unless scalar(@$a) == scalar(@$b);
	no warnings 'uninitialized'; # because we might compare undef values
	for (my $i=0; $i < @$a; $i++) {
		return 0 unless $a->[$i] eq $b->[$i]
	}
	return 1;
}
sub _stringify_pk {
	my @pkVals= @_;
	scalar(@pkVals) eq 1 && return ''.$pkVals[0];
	return join '+', map { length($_).'_'.$_ } @pkVals;
}

sub get_col_hash {
	my ($self, $cursorRow)= @_;
	
	my $result= {};
	my $i= $self->firstColIdx;
	for ($self->cols) {
		my $val= $cursorRow->[$i++];
		$result->{$_}= $val if defined $val;
	}
	return $result;
}

sub consume_cursor_row {
	my ($self, $cursorRow, $state)= @_;
	my ($pk, $pkStr)= $self->get_pk($cursorRow);
	# only continue if this record is defined
	return undef unless $pk;
	
	my $rec;
	my $emit= 0;
	
	if (!defined $state->{seen}{$pkStr}) {
		$emit= 1;
		$rec= $self->get_col_hash($cursorRow);
		$state->{seen}{$pkStr}= $rec;
		%{ $state->{rels} }= ();
	} else {
		$rec= $state->{seen}{$pkStr};
	}
	
	for my $relHandler ($self->subrels) {
		my $relN= $relHandler->relName;
		my $relState= ($state->{rels}{$relN} ||= {});
		if ($relHandler->isMulti) {
			if (my $item= $relHandler->consume_cursor_row($cursorRow, $relState)) {
				# the relation is multi, so it generates an array of items
				my $ary= ($rec->{$relN} ||= []);
				push @$ary, $item;
			}
		} else {
			if (my $item= $relHandler->consume_cursor_row($cursorRow, $relState)) {
				$rec->{$relN}= $item;
			}
		}
	}
	
	return $emit? $rec : undef;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;