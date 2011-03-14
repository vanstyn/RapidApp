package RapidApp::DBIC::ExportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'encode_json';

has 'dest' => ( is => 'rw', isa => 'IO::Handle', required => 1 );

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

has 'related_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
has 'auto_id_columns' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

has 'auto_id_map' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
has 'auto_id_count' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has 'exported_set' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );


sub is_auto_id_col {
	my ($self, $colKey)= @_;
	return (shift)->auto_id_columns->{$colKey};
}

sub xlate_auto_id {
	my ($self, $colKey, $id)= @_;
	my $officialCol= $self->auto_id_columns->{$colKey} || die "Cannot translate auto-ids for $colKey";
	my $id_map= ( $self->auto_id_map->{$officialCol} ||= {} );
	return $id_map->{$id} ||= ++$self->auto_id_count->{$officialCol};
}

sub mark_record_as_exported {
	my ($self, $sourceName, $pk)= @_;
	ref $pk
		and $pk= join("\t", @$pk);
	($self->exported_set->{$sourceName} ||= {})->{$pk}= undef;
}

sub was_record_exported {
	my ($self, $sourceName, $pk)= @_;
	ref $pk
		and $pk= join("\t", @$pk);
	my $exported= ($self->exported_set->{$sourceName} ||= {});
	return exists $exported->{$pk};
}

=pod

For each record in the resultset
  Get the fields
  For each field which is an auto-increment,
    re-map that field to a fresh integer sequence
    record which old ID is mapped to which new ID.
  For each field which references a foreign key,
    If we want to 'inline' that relation,
      follow the relation and get its data too
      insert that data under the relation name of this data
    else if we are also saving the related object,
      Tell the exporter that we depend on it
    If that relation refers to an auto_increment field,
      Tell the exporter that we depend on the related object
      Convert the ID as we save
=cut
sub export_resultset {
	my ($self, $rs)= @_;
	
	my $rsrc= $rs->result_source;
	my $srcN= $rsrc->source_name;
	my @remapFields= grep { $self->is_auto_id_col($srcN.'.'.$_) } $rsrc->columns;
	
	my $code;
	while (my $row= $rs->next) {
		my $data= ($code= $row->can('get_export_data'))? $row->$code : { $row->get_inflated_columns };
		for my $col (@remapFields) {
			if (defined $data->{$col}) {
				# TODO - here, we also need to record dependencies.... but don't bother for now.
				$data->{$col}= $self->xlate_auto_id($srcN.'.'.$col, $data->{$col});
			}
		}
		$self->export_record(src => $srcN, data => $data);
	}
}

sub export_record {
	my $self= shift;
	my %p= validate(@_, { src => {type=>SCALAR}, data => {type=>HASHREF} });
	# if the record(s) we depend on haven't been written yet, we write them first
	$self->dest->print(encode_json(\%p)."\n");
	# TODO - here, we will mark the record's primary key as having been seen.
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

no Moose;
__PACKAGE__->meta->make_immutable;
1;