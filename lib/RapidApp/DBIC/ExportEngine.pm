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

# sub mark_record_as_exported {
	# my ($self, $sourceName, $pk)= @_;
	# ref $pk
		# and $pk= join("\t", @$pk);
	# ($self->exported_set->{$sourceName} ||= {})->{$pk}= undef;
# }

# sub was_record_exported {
	# my ($self, $sourceName, $pk)= @_;
	# ref $pk
		# and $pk= join("\t", @$pk);
	# my $exported= ($self->exported_set->{$sourceName} ||= {});
	# return exists $exported->{$pk};
# }

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
	my ($self, $rs)= @_;
	
	my $rsrc= $rs->result_source;
	my $srcN= $rsrc->source_name;
	my @deps= $self->get_deps_for_source($srcN);
	
	while (my $row= $rs->next) {
		$self->_export_row($srcN, \@deps, $row);
	}
}

sub export_row {
	my ($self, $row)= @_;
	my $srcN= $row->resultset->result_source->source_name;
	my @deps= $self->get_deps_for_source($srcN);
	$self->_export_row($srcN, \@deps, $row);
}

sub _export_row {
	my ($self, $srcN, $depList, $row)= @_;
	
	my $code;
	my $data= ($code= $row->can('get_export_data'))? $row->$code : $self->get_export_data($row);
	for my $dep (@$depList) {
		my $colN= $dep->col;
		if (defined $data->{$colN}) {
			# TODO - here, we need to record dependencies.... but don't bother for now.
		}
	}
	
	$self->create_acn_insert(source => $srcN, data => $data);
}

sub get_export_data {
	my ($self, $row)= @_;
	return { $row->get_inflated_columns };
}

sub create_acn_insert {
	my $self= shift;
	# TODO: record the primary key that we're writing, and then mark that off the dependency list if it was listed
	$self->writer->write_insert(@_);
}

sub create_acn_update {
	my $self= shift;
	$self->writer->write_update(@_);
}

sub create_acn_find {
	my $self= shift;
	# TODO: record the primary key that we're locating, and then mark that off the dependency list if it was listed
	$self->writer->write_find(@_);
}

sub finish {
	my $self= shift;
	# TODO: check for missing dependencies
	$self->writer->finish();
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;