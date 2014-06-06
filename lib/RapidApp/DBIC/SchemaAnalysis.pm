package RapidApp::DBIC::SchemaAnalysis;
use Moose::Role;

use RapidApp::Debug 'DEBUG';
use RapidApp::DBIC::SchemaAnalysis::Dependency;
use RapidApp::DBIC::SchemaAnalysis::SourceAnalysis;
use RapidApp::DBIC::SchemaAnalysis::Constraint;

requires 'schema';

has 'source_analysis' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# map of {srcN} => $rsrc
has 'valid_sources' => (is => 'ro', isa => 'HashRef[DBIx::Class::ResultSource]', lazy_build => 1 );

# map of {colKey}{colKey} => 1
has 'related_columns' => ( is => 'ro', isa => 'HashRef[HashRef]', lazy_build => 1 );

# map of {srcN} => \@deps
has '_deplist_per_source' => ( is => 'ro', isa => 'HashRef[ArrayRef]', lazy_build => 1 );

# map of {colKey} => colKey
has 'related_auto_id_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# map of {srcN} => \@cols
has 'remap_fields_per_source' => ( is => 'ro', isa => 'HashRef[ArrayRef]', lazy_build => 1 );

sub is_auto_id_col {
	my ($self, $colKey)= @_;
	return defined $self->related_auto_id_columns->{$colKey};
}

sub get_deps_for_source {
	my ($self, $srcN)= @_;
	my $deplist= $self->_deplist_per_source->{$srcN};
	return $deplist? @$deplist : ();
}

sub _build_valid_sources {
	my $self= shift;
	my %sources= map { $_ => $self->schema->source($_) } $self->schema->sources;
	return \%sources;
}

sub _build_source_analysis {
	my $self= shift;
	my %analysis= map {
			$_ => RapidApp::DBIC::SchemaAnalysis::SourceAnalysis->new(source => $self->valid_sources->{$_})
		} keys %{$self->valid_sources};
	
	DEBUG([ export => 2, import => 2, schema_analysis => 1 ], "src analysis:\n", map { ''.$_ } values %analysis);
	return \%analysis;
}

sub _build_related_columns {
	my $self= shift;
	my $result= {};
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		my $rsrc= $srcHash->{$srcN};
		for my $relN ($rsrc->relationships) {
			my $relInfo= $rsrc->relationship_info($relN);
			my $foreignSrcN= $rsrc->related_source($relN)->source_name;
			while (my($foreign, $local)= each %{$relInfo->{cond}}) {
				# swap them if they were reversed
				if ($local =~ /^foreign/) { my $tmp= $foreign; $foreign= $local; $local= $tmp; }
				$foreign =~ s/^foreign/$foreignSrcN/ or $foreign= $foreignSrcN.'.'.$foreign;
				$local   =~ s/^self/$srcN/ or $local= $srcN.'.'.$local;
				($result->{$foreign} ||= {})->{$local}= 1;
				($result->{$local} ||= {})->{$foreign}= 1;
				DEBUG('debug', 'related: ', $foreign, $local) if $srcN eq 'Workspace';
			}
		}
	}
	DEBUG([ export => 2, import => 2, schema_analysis => 1 ], 'related columns' => $result);
	return $result;
}

sub _build_keys_per_source {
	my $self= shift;
	# TODO: make this calculate a list of RA::DBIC::Key objects for each source
}

sub _build_key_constraints_per_source {
	my $self= shift;
	# TODO: make this the new name for _build_col_depend_per_source
	# have it calculate RA::DBIC::Key => RA::DBIC::Key
}

sub _build_dependable_keys_per_source {
	my $self= shift;
	# TODO: if we start supporting multiple-column keys, this will list out which ones to test for
}

sub _build__deplist_per_source {
	my $self= shift;
	
	my $result= {};
	my $srcHash= $self->valid_sources;
	
	# for each source ...
	for my $srcN (keys %$srcHash) {
		my @deps= ();
		
		# Add any dependencies
		# TODO: we should process constraints here, not just auti-id columns.
		# TODO: we can support multi-column constraints by adding a method which stringifies a
		#    list of columns, and a list of values in a canonical maanner.
		my $rsrc= $srcHash->{$srcN};
		for my $colN ($rsrc->columns) {
			my $colKey= RapidApp::DBIC::Key->new_from_array($srcN, $colN).'';
			my $originColKey= $self->related_auto_id_columns->{$colKey};
			$originColKey && $originColKey ne $colKey
				and push @deps, RapidApp::DBIC::SchemaAnalysis::Dependency->new( source => $srcN, col => $colN, origin_colKey => $originColKey );
		}
		
		$result->{$srcN}= \@deps;
	}
	DEBUG([ export => 2, import => 2, schema_analysis => 1 ], 'all column dependencies' => $result);
	return $result;
}

sub _build_related_auto_id_columns {
	my $self= shift;
	
	my $result= {};
	# for all sources...
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		for my $colN ($self->source_analysis->{$srcN}->autogen_cols) {
			my $colKey= RapidApp::DBIC::Key->new_from_array($srcN, $colN).'';
			
			# this column depends on itself
			$result->{$colKey}= $colKey;
			
			# now, for any chain of relations, mark those columns as auto_id dependent on this column.
			# (use a worklist algorithm, rather than recursion)
			my @toCheck= keys %{$self->related_columns->{$colKey}};
			my %seen= map { $_ => 1 } @toCheck;
			while (my $relCol= pop @toCheck) {
				$result->{$relCol}= $colKey;
				push @toCheck, grep { $seen{$_}++ == 0 } keys %{$self->related_columns->{$relCol}};
			}
		}
	}
	
	DEBUG([ export => 2, import => 2, schema_analysis => 1 ], 'all auto id col refs' => $result);
	return $result;
}

sub _build_remap_fields_per_source {
	my $self= shift;
	my $result= {};
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		$result->{$srcN}= [ grep { $self->is_auto_id_col($srcN.'.'.$_) } $srcHash->{$srcN}->columns ];
	}
	
	DEBUG([ export => 2, import => 2, schema_analysis => 1 ], 'fields which need remapped' => $result);
	return $result;
}

=pod

The following were replaced with RapidApp::DBIC::Key and RapidApp::DBIC::KeyVal utility methods

sub get_primary_key_string {
	my ($self, $rsrc, $rec)= @_;
	my @pkvals;
	for my $colN ($rsrc->primary_columns) {
		defined $rec->{$colN} or return '';  # primary key wasn't given.  Hopefully it gets autogenerated during insert.
		push @pkvals, $rec->{$colN};
	}
	return stringify_pk(@pkvals);
}

# For purposes of hash keys, we want to come up with a string that
#    uniquely represents a key on a table.
# A key may have multiple columns.
# We use a string of the form TABLE.COL1+COL2+COL3...
# We ignore the possibility of a column having a "+" in its name and colliding
#    with another key on the same table with similar names.
sub stringify_colkey {
	my ($self, $table, @cols)= @_;
	return $table.'.'.join('+', sort @cols);
}

# get the values of a key from a hash, by colKey
sub get_key_val {
	my ($self, $colKey, $rowHash)= @_;
	my ($table, $colList)= split(/[.]/, $colKey);
	my @cols= split(/[+]/, $colList);
	return map { $rowHash->{$_} } @cols;
}

# This method stringifies a value for a key.
# For all single-column keys, we just use the value.
# For multiple-column keys, we join the values with the length of that value
# i.e.   LEN "~" VALUE LEN "~" VALUE ...
# (which is a quick and easy way to ensure that unique values get unique
#   strings without having to escape anything.  This trick is borrowed
#   from C++ name mangling)
sub stringify_key_val {
	my ($self, @vals)= @_;
	scalar(@vals) eq 1 && !(ref $vals[0]) and return $vals[0];
	scalar(@vals) eq 1 && ref $vals[0] eq 'ARRAY' and return @vals= @{$vals[0]};
	return join '', map { length($_).'~'.$_ } @vals;
}
=cut
1;
