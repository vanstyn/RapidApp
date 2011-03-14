package RapidApp::DBIC::SchemaAnalysis;
use Moose::Role;

requires 'schema';

has 'related_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
has 'auto_id_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
has 'remap_fields_per_source' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

sub is_auto_id_col {
	my ($self, $colKey)= @_;
	return defined (shift)->auto_id_columns->{$colKey};
}

sub _build_related_columns {
	my $self= shift;
	my $result= {};
	for my $srcN ($self->schema->sources) {
		my $rsrc= $self->schema->source($srcN);
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
	DEBUG('export', related_columns => $result);
	return $result;
}

sub _build_auto_id_columns {
	my $self= shift;
	
	my $result= {};
	# for all sources...
	for my $srcN ($self->schema->sources) {
		my $rsrc= $self->schema->source($srcN);
		
		# For all auto_increment columns of this source...
		for my $colN (grep { $rsrc->column_info($_)->{is_auto_increment} } $rsrc->columns) {
			my $colKey= $srcN.'.'.$colN;
			
			# mark this column as a auti_id column
			$result->{$colKey}= $colKey;
			
			# now, for any chain of relations, mark those columns as auti_id dependent on this column.
			# (use a worklist algorithm, rather than recursion)
			my @toCheck= keys %{$self->related_columns->{$colKey}};
			my %seen= map { $_ => 1 } @toCheck;
			while (scalar(@toCheck)) {
				my $relCol= pop @toCheck;
				$result->{$relCol}= $colKey;
				push @toCheck, grep { $seen{$_}++ == 0 } keys %{$self->related_columns->{$relCol}};
			}
		}
	}
	DEBUG('export', auto_id_columns => $result);
	return $result;
}

sub _build_remap_fields_per_source {
	my $self= shift;
	my $result= {};
	for my $srcN ($self->schema->sources) {
		$result->{$srcN}=
			grep { $self->is_auto_id_col($srcN.'.'.$_) }
				$self->schema->source($srcN)->columns;
	}
	
	return $result;
}

1;
