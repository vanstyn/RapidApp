package RapidApp::DBIC::ExportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'encode_json';
use RapidApp::DBIC::ImportEngine::ItemWriter;

extends 'RapidApp::DBIC::EngineBase';

has 'writer' => ( is => 'rw', isa => 'RapidApp::DBIC::ImportEngine::ItemWriter', coerce => 1 );

#has 'exported_set' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has '_required_pk' => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );
has '_seen_pk'     => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );

sub BUILD {
	my $self= shift;
	# mark all records built-in to the schema as "seen".
	for my $sa (values %{$self->source_analysis}) {
		$self->mark_pkVal_seen($_->{pkVal}) for $sa->schema_defined_rows;
	}
}

sub mark_pkVal_required {
	my ($self, $pkVal)= @_;
	return if $self->seen_pkVal($pkVal);
	($self->_required_pk->{$pkVal->key} ||= {})->{$pkVal}= $pkVal;
}

sub mark_pkVal_seen {
	my ($self, $pkVal)= @_;
	($self->_seen_pk->{$pkVal->key} ||= {})->{$pkVal}= $pkVal;
	my $hash= $self->_required_pk->{$pkVal->key};
	delete $hash->{$pkVal} if $hash;
}

sub seen_pkVal {
	my ($self, $pkVal)= @_;
	my $hash= $self->_seen_pk->{$pkVal->key};
	return $hash && $hash->{$pkVal};
}

sub get_missing_deps {
	my ($self)= @_;
	return map { values %{$_} } values %{$self->_required_pk};
}

=pod

For each record in the resultset
  Get the fields
  For each field which is an auto-increment,
    record that we exported that key
  For each field which references a foreign key,
    If we want to 'inline' that relation,
      follow the relation and get its data too
      insert that data under the relation name of this data
    else if we are also saving the related object,
      Tell the exporter that we depend on it
    else build a search so that we can join up to it if the IDs of the new DB are different
=cut
sub export_resultset {
	my ($self, $rs, $srcN, $depList)= @_;
	
	$srcN ||= $rs->result_source->source_name;
	$depList ||= [ $self->get_deps_for_source($srcN) ];
	
	while (my $row= $rs->next) {
		$self->export_row($row, $srcN, $depList);
	}
}

sub export_item {
	my ($self, $item)= @_;
	$self->writer->write_insert(source => undef, class => ref $item, data => $item->toHash());
}

sub export_row {
	my ($self, $row, $srcN, $depList)= @_;
	$srcN ||= $row->result_source->source_name;
	$depList ||= [ $self->get_deps_for_source($srcN) ];
	$self->export_rowHash($self->get_export_data($row), $srcN, $depList);
}

sub export_rowHash {
	my ($self, $rowHash, $srcN, $depList)= @_;
	
	$self->create_acn_insert(source => $srcN, data => $rowHash, depList => $depList);
}

sub get_export_data {
	my ($self, $row)= @_;
	return { $row->get_inflated_columns };
}

sub create_acn_insert {
	my $self= shift;
	my %p= validate(@_, { source => 1, class => 0, data => 1, depList => 0, pk => 0, pkVal => 0 });
	
	# check whether we've done this row already
	my $sa= $self->source_analysis->{$p{source}};
	$p{pk}    ||= $sa->pk;
	$p{pkVal} ||= $p{pk}->val_from_hash_if_exists($p{data});
	if ($p{pkVal} && $self->seen_pkVal($p{pkVal})) {
		DEBUG('export', $p{pkVal}, "has been exported already, skipping");
		return;
	}
	
	# find foreign key values and list them as required
	for my $fkc ($sa->fk_constraints) {
		my $lkVal= $fkc->local_key->val_from_hash_if_exists($p{data});
		if ($lkVal) {
			# The foreign key and local key in a constraint are guaranteed
			#   to have their columns in matching sequence
			my $fkVal= $fkc->foreign_key->val_from_array($lkVal->values);
			$self->mark_pkVal_required($fkVal);
		}
	}
	
	# record the primary key that we're writing
	$self->mark_pkVal_seen($p{pkVal}) if $p{pkVal};
	
	# emit a record
	$self->writer->write_insert(map { $_ => $p{$_} } qw(source class data));
}

sub create_acn_update {
	my $self= shift;
	my %p= validate(@_, { source => 1, search => 1, data => 1, depList => 0 });
	$self->writer->write_update(map { $_ => $p{$_} } qw(source search data));
}

sub create_acn_find {
	my $self= shift;
	my %p= validate(@_, { source => 1, search => 1, data => 1, depList => 0, pk => 0 });
	
	# record the primary key that we're locating
	$p{pk} ||= $self->source_analysis->{$p{source}}->pk;
	# This line forces {data} to contain the primary key, which is something we wanted to validate
	my $pkVal= $p{pk}->val_from_hash($p{data});
	if ($self->seen_pkVal($pkVal)) {
		DEBUG('export', $pkVal, "has been exported already, skipping");
		return;
	}
	$self->mark_pkVal_seen($pkVal);
	
	$self->writer->write_find(map { $_ => $p{$_} } qw(source search data));
}

sub finish {
	my $self= shift;
	# TODO: check for missing dependencies
	$self->writer->finish();
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;