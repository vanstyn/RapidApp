package RapidApp::DBIC::ExportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'encode_json';

has 'dest' => ( is => 'rw', isa => 'IO::Handle', required => 1 );

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

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
	
	my $code;
	while (my $row= $rs->next) {
		my $data= ($code= $row->can('get_export_data'))? $row->$code : $self->get_export_data($row);
		# for my $col (@remapFields) {
			# if (defined $data->{$col}) {
				# TODO - here, we also need to record dependencies.... but don't bother for now.
				# $data->{$col}= $self->xlate_auto_id($srcN.'.'.$col, $data->{$col});
			# }
		# }
		$self->export_record(source => $srcN, data => $data);
	}
}

sub get_export_data {
	my ($self, $row)= @_;
	return { $row->get_inflated_columns };
}

sub export_record {
	my $self= shift;
	my %p= validate(@_, { source => {type=>SCALAR}, data => {type=>HASHREF} });
	# if the record(s) we depend on haven't been written yet, we write them first
	$self->dest->print(encode_json(\%p)."\n");
	# TODO - here, we will mark the record's primary key as having been seen.
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;