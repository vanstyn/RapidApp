package RapidApp::DBIC::SchemaAnalysis;
use Moose::Role;

use RapidApp::Debug 'DEBUG';

requires 'schema';

# map of {srcN} => $rsrc
has 'valid_sources' => (is => 'ro', isa => 'HashRef[DBIx::Class::ResultSource]', lazy_build => 1 );

# map of {colKey}{colKey} => 1
has 'related_columns' => ( is => 'ro', isa => 'HashRef[HashRef]', lazy_build => 1 );

# map of {srcN} => [ $colN, ... ]
has 'auto_id_columns_per_source' => ( is => 'ro', isa => 'HashRef[ArrayRef]', lazy_build => 1 );

# map of {colKey} => colKey
has 'related_auto_id_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# map of {srcN} => \@cols
has 'remap_fields_per_source' => ( is => 'ro', isa => 'HashRef[ArrayRef]', lazy_build => 1 );

sub is_auto_id_col {
	my ($self, $colKey)= @_;
	return defined $self->related_auto_id_columns->{$colKey};
}

sub _build_valid_sources {
	my $self= shift;
	my %sources= map { $_ => $self->schema->source($_) }
		grep { !$self->schema->resultset($_)->result_class->can('CONSTANT_VALUES') }
			$self->schema->sources;
	DEBUG('export', 'valid sources: ' => keys %sources);
	return \%sources;
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
				$foreign =~ s/^foreign/$foreignSrcN/;
				$local   =~ s/^self/$srcN/;
				($result->{$foreign} ||= {})->{$local}= 1;
				($result->{$local} ||= {})->{$foreign}= 1;
			}
		}
	}
	DEBUG('export', 'related columns' => $result);
	return $result;
}

sub _build_key_constraints_per_source {
	my $self= shift;
	
}

sub _build_dependable_keys_per_source {
	my $self= shift;
	
}

sub _build_auto_id_columns_per_source {
	my $self= shift;
	
	my $result= {};
	# for each source...
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		my $rsrc= $srcHash->{$srcN};
		$result->{$srcN}= [ grep { $rsrc->column_info($_)->{is_auto_increment} } $rsrc->columns ];
	}
	DEBUG('export', 'auto id columns' => $result);
	return $result;
}

sub _build_related_auto_id_columns {
	my $self= shift;
	
	my $result= {};
	# for all sources...
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		for my $colN (@{$self->auto_id_columns_per_source->{$srcN}}) {
			my $colKey= $srcN.'.'.$colN;
			
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
	DEBUG('export', 'all auto id col refs' => $result);
	return $result;
}

sub _build_remap_fields_per_source {
	my $self= shift;
	my $result= {};
	my $srcHash= $self->valid_sources;
	for my $srcN (keys %$srcHash) {
		$result->{$srcN}= [ grep { $self->is_auto_id_col($srcN.'.'.$_) } $srcHash->{$srcN}->columns ];
	}
	
	DEBUG('export', 'fields which need remapped' => $result);
	return $result;
}

1;
