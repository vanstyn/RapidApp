package RapidApp::DBIC::ExportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'encode_json';
use RapidApp::DBIC::ImportEngine::ItemWriter;

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

has 'writer' => ( is => 'rw', isa => 'RapidApp::DBIC::ImportEngine::ItemWriter', coerce => 1 );

with 'RapidApp::DBIC::SchemaAnalysis';

has 'exported_set' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

has 'required_pk' => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );
has 'seen_pk'     => ( is => 'ro', isa => 'HashRef[HashRef]', default => sub {{}} );

sub mark_pkVal_required {
	my ($self, $pkVal)= @_;
	($self->required_pk->{$pkVal->key} ||= {})->{$pkVal}= 1;
}

sub mark_pkVal_seen {
	my ($self, $pkVal)= @_;
	($self->seen_pk->{$pkVal->key} ||= {})->{$pkVal}= 1;
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

sub export_row {
	my ($self, $row, $srcN, $depList)= @_;
	$srcN ||= $row->resultset->result_source->source_name;
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
	my %p= validate(@_, { source => 1, data => 1, depList => 0, pk => 0, pkVal => 0 });
	
	# TODO - here, we need to record dependencies.... but don't bother for now.
	
	# record the primary key that we're writing
	$p{pk}    ||= $self->source_analysis->{$p{source}}->pk;
	$p{pkVal} ||= $p{pk}->val_from_hash($p{data});
	$self->mark_pkVal_seen($p{pkVal});
	
	$self->writer->write_insert(map { $_ => $p{$_} } qw(source data));
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