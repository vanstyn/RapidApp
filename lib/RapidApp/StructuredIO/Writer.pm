package RapidApp::StructuredIO::Writer;
use Moo;
use Params::Validate;
use JSON;
use Storable 'freeze';
use IO::Handle;
use Errno;
use Sub::Quote;
use RapidApp::Debug 'DEBUG';

has out        => ( is => 'ro', required => 1 );
has 'format'   => ( is => 'ro', default => sub{'storable'}, trigger => \&_format_trigger );
has onErr      => ( is => 'rw' );
has err        => ( is => 'ro', init_arg => undef );
has _serialize => ( is => 'rw', init_arg => undef, default => sub{ $_[0]->can('_serializeProxyThunk'); } );


sub BUILD {
	my $self= shift;
#	$self->_extract( $self->can('_extractFormatProxyThunk') );
#	$self->_readBuf('');
	DEBUG(foo => "+ $self  -- pid $$");
}

=head1 NAME

RapidApp::StructuredIO::Writer

=head1 SYNOPSIS

  my $writer= Data::StructWriter(out => IO::File->new('> /tmp/foo'), format => json);
  $writer->write( "foo" );
  $writer->write( { a => 1, b => { b_a => 1, b_b => 2 } } );

=head1 DESCRIPTION

StructWriter writes structured data as a discrete sequence.  The point is then
to be able to read back that same sequence without the bother of breaking it
back apart.

StructWriter is slightly better than calling Storable::store_fd in a loop because
you can easily swap it out for a readable format without having to alter your
reader to handle the format change.  Another benefit is that the format used to
encode the records is compatible with non-blocking I/O.  (though to actually do that
you need to make an instance of StructWriter::NonBlockAE or StructReader::NonBlockAE,
which are implementations using AnyEvent)

StructWriter is also extremely extensible.  Just add methods named "_serialize_$format"
and they will be available.  (But when you design new formats, be sure that you can
decode them without a blocking library call...)

The default supported formats are "storable" and "json".

=head1 ATTRIBUTES

=head2 out

The file handle to which serialized data will be written

=head2 format

The format used for serialization.  Default implementation supports 'storable' and 'json',
with 'storable' as the default.

=head1 ATTRIBUTES

=head1 $format= $self->format( $format )

Gets or sets the format for the data stream.  Valid built-in values are 'json' and 'storable'.

If the format is unsupported, you get an exception.  You may set the format as many times
as you like before you begin writing, but once the first record has been written, subsequent
attempts will throw an exception.

=cut
sub _format_trigger {
	my ($self, $newVal)= @_;
	$self->_serialize eq $self->can('_serializeProxyThunk')
		or die "Cannot change the format after records have been written";
	$self->can('_serialize_'.$newVal)
		or die "Unsupported format: ".$newVal;
}

sub serializedStreamHeader {
	my $self= shift;
	return $self->{format}."\n";
}

=head1 $self->write( $data )

Writes a data structure into the stream.  undef is a legal value, and will cause
a reader to read undef.

The first time ->write is called, it will also write out a stream header identifying
the format used.

=cut
sub write {
	my ($self, $data)= @_;
	my $bytes= $self->{_serialize}->($self, $data);
	while (length $bytes) {
		my $wrote= syswrite($self->out, $bytes);
		if (defined $wrote) {
			return 1 if ($wrote eq length $bytes);
			$bytes= substr($bytes, $wrote);
		} else {
			next if $!{EINTR}; # temporary failure
			$self->flagErr("StructWriter: write error: $!");
			die $self->err;
		}
	}
}

sub flagErr {
	my ($self, $err)= @_;
	$self->{err}= $err;
	close delete $self->{out};
	$self->onErr->($self, $err) if $self->onErr;
}

sub _serializeProxyThunk {
	my ($self, $data)= @_;
	$self->{_serialize}= $self->can('_serialize_'.$self->{format});
	return
		$self->serializedStreamHeader # our header
		.$self->{_serialize}->($self, $data);
}

=head1 SERIALIZE FUNCTIONS

This API is dead-simple.  Take a ref to $self, and an arbitrary data structure (possibly undef)
and return a scalar containing bytes (not unicode).

Name the method '_serialize_'.$format

=cut
sub _serialize_json {
	my ($self, $data)= @_;
	my $json= $self->{_json} ||= JSON->new->allow_nonref->utf8;
	return $json->encode($data)."\n";
}

sub _serialize_storable {
	my ($self, $data)= @_;
	my $bytes= freeze(\$data);
	return pack('L', length($bytes)) . $bytes;
}

sub DESTROY {
	DEBUG(foo => "- $_[0]  -- pid $$");
}

1;