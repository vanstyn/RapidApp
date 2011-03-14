package RapidApp::DBIC::ImportEngine;
use Moose;

use Params::Validate ':all';
use IO::Handle;
use RapidApp::Debug 'DEBUG';
use RapidApp::JSON::MixedEncoder 'encode_json';

has 'src' => ( is => 'rw', isa => 'IO::Handle', required => 1 );

has 'schema' => ( is => 'ro', isa => 'DBIx::Class::Schema', required => 1 );

with 'RapidApp::DBIC::SchemaAnalysis';

has 'auto_id_map' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

sub import_records {
	my $self= shift;
	my $data;
	$self->schema->txn_do( sub {
		while (($data= $self->read_record)) {
			$self->import_record($data);
		}
	});
}

sub read_record {
	my $self= shift;
	my $line= $self->src->getline;
	defined($line) or return undef;
	chomp $line;
	return decode_json($line);
}

sub import_record {
	my $self= shift;
	my %p= validate(@_, { src => {type=>SCALAR}, data => {type=>HASHREF} });
	my $rsrc= $self->schema->source($p{src});
	my $rs= $rsrc->resultset;
	my $code;
	if (($code= $rs->can('import_create'))) {
		$rs->$code($data);
	} else {
		$self->resolve_relations($rsrc, $data);
		$rs->create($data);
	}
}

sub resolve_relations {
	my ($self, $rsrc, $data)= @_;
	my $srcN= $rsrc->source_name;
	for my $colN ($self->remap_fields_per_source->{$srcN}) {
		if (defined $data->{$colN}) {
			my $importId= $data->{$colN};
			my $localId= $self->auto_id_map->{$srcN.'.'.$colN}->{$data->{$colN}};
			defined $localId or die "Unable to resolve local-database ID for import ID of $importId";
			$data->{$colN}= $localId;
		}
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;