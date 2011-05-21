package RapidApp::DBIC::ImportEngine::ItemReader;

use Moose;

use JSON::XS;
use Moose::Util::TypeConstraints;

coerce __PACKAGE__, from "HashRef" => via { __PACKAGE__->factory_create($_) };

has 'source' => ( is => 'rw', isa => 'IO::Handle', required => 1 );
has 'engine' => ( is => 'rw', isa => 'RapidApp::DBIC::ImportEngine', weak_ref => 1 );
has 'itemClassForResultSource' => ( is => 'rw', isa => 'HashRef[String]', default => sub {{}} );

sub factory_create {
	my ($class, $params)= @_;
	my $fmt= delete $params->{format} || 'JSON';
	$fmt= uc(substr $fmt, 0, 1).lc(substr $fmt, 1);
	
	my $code;
	
	my $subclass= $class.'::'.$fmt;
	$subclass->can("new") or die "No such format reader: $subclass";
	
	if (($code= $subclass->can('factory_create')) ne \&factory_create) {
		return $subclass->$code();
	}
	
	my $fname= delete $params->{fileName};
	if ($fname) {
		$params->{source}= IO::File->new($params->{fileName}, 'r') or die $!;
	}
	
	return $subclass->new($params);
}

=head2 $self->next

This method reads the next item object, or returns undef if no more exist in the stream.

On error, it calls die.

=cut
sub next {
	die "abstract method";
}

=head2 $self->inflate( \%itemHash )

This method creates an appropriate item object from the given item hash

=cut
sub inflate {
	my ($self, $itemHash)= @_;
	my $cls= delete $itemHash->{class}
		|| $self->classForDbicSource($itemHash->{source});
	if ($cls->can('createFromHash')) {
		return $cls->createFromHash(engine => $self->engine, hash => $itemHash->{data});
	} else {
		$itemHash->{engine}= $self->engine;
		return $cls->new($itemHash);
	}
}

sub classForDbicSource {
	my ($self, $srcN)= @_;
	return $self->itemClassForResultSource->{$srcN} ||= 'RapidApp::DBIC::ImportEngine::Item';
}

__PACKAGE__->meta->make_immutable;

package RapidApp::DBIC::ImportEngine::ItemReader::Storable;

use Moose;
extends 'RapidApp::DBIC::ImportEngine::ItemReader';

use Storable 'fd_retrieve';

sub BUILD {
	my $self= shift;
	binmode($self->source);
}

sub next {
	my $self= shift;
	my $src= $self->source;
	$src->eof and return undef;
	
	my $itemHash= fd_retrieve($src);
	# we have the option to write an end-of-file record in the storable stream,
	#   so that multiple things could be stored in the same file
	return undef if ($itemHash eq 'EOF');
	
	return $self->inflate($itemHash);
}

__PACKAGE__->meta->make_immutable;

package RapidApp::DBIC::ImportEngine::ItemReader::Json;

use Moose;
extends 'RapidApp::DBIC::ImportEngine::ItemReader';

use JSON::XS;
my $json= JSON::XS->new();

sub BUILD {
	my $self= shift;
	binmode($self->source, ':utf8');
}

sub next {
	my $self= shift;
	my $src= $self->source;
	$src->eof and return undef;
	
	my $line= $src->getline;
	defined($line) or return undef;
	
	chomp $line;
	my $itemHash= $json->decode($line);
	defined $itemHash or die "Error decoding line: \"$line\"";
	
	return $self->inflate($itemHash);
}

__PACKAGE__->meta->make_immutable;

1;