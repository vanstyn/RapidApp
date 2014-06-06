package RapidApp::DBIC::ImportEngine::ItemWriter;

use Moose;

use JSON::XS;
use Moose::Util::TypeConstraints;
use Params::Validate ':all';


coerce __PACKAGE__, from "HashRef" => via { __PACKAGE__->factory_create($_) };

has 'dest' => ( is => 'rw', isa => 'IO::Handle', required => 1 );

sub factory_create {
	my ($class, $params)= @_;
	my $fmt= delete $params->{format} || 'JSON';
	$fmt= uc(substr $fmt, 0, 1).lc(substr $fmt, 1);
	
	my $code;
	
	my $subclass= $class.'::'.$fmt;
	$subclass->can('new') or die "No such format writer: $subclass";
	
	if (($code= $subclass->can('factory_create')) ne \&factory_create) {
		return $subclass->$code($params);
	}
	
	my $fname= delete $params->{fileName};
	if ($fname) {
		$params->{dest}= IO::File->new($params->{fileName}, 'w') or die $!;
	}
	
	return $subclass->new($params);
}

sub write_insert {
	my $self= shift;
	my %p= validate(@_, { source => 1, class => 0, data => {type=>HASHREF} });
	$self->_writeHash(\%p);
}

sub write_find {
	my $self= shift;
	my %p= validate(@_, { source => {type=>SCALAR}, search => {type=>HASHREF}, data => {type=>HASHREF} });
	$p{action}= 'find';
	$self->_writeHash(\%p);
}

sub write_update {
	my $self= shift;
	my %p= validate(@_, { source => {type=>SCALAR}, search => {type=>HASHREF}, data => {type=>HASHREF} });
	$p{action}= 'update';
	$self->_writeHash(\%p);
}

=head2 $self->_writeHash

This method writes a hash to the stream.  It is intended to be called from the other methods which
build hashes for various types of import items.

On error, it calls die.

=cut
sub _writeHash {
	die "abstract method";
}

__PACKAGE__->meta->make_immutable;

#=============================================================================
package RapidApp::DBIC::ImportEngine::ItemWriter::Storable;

use Moose;
extends 'RapidApp::DBIC::ImportEngine::ItemWriter';

use Storable 'nstore_fd';

sub BUILD {
	my $self= shift;
	binmode($self->dest);
}

sub _writeHash {
	my ($self, $hash)= @_;
	
	nstore_fd($hash, $self->dest);
}

sub finish {
	my $self= shift;
	fd_nstore("EOF", $self->dest);
}

__PACKAGE__->meta->make_immutable;

#=============================================================================
package RapidApp::DBIC::ImportEngine::ItemWriter::Json;

use Moose;
extends 'RapidApp::DBIC::ImportEngine::ItemWriter';

use JSON::XS;
my $json= JSON::XS->new();

sub BUILD {
	my $self= shift;
	binmode($self->dest, ':utf8');
}

sub _writeHash {
	my ($self, $hash)= @_;
	$self->dest->print($json->encode($hash)."\n");
}

__PACKAGE__->meta->make_immutable;

1;