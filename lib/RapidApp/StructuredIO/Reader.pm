package RapidApp::StructuredIO::Reader;
use Moo;
use Params::Validate;
use JSON;
use Storable 'thaw';
use IO::Handle;
use Errno;
use Sub::Quote;
use RapidApp::Debug 'DEBUG';

has in       => ( is => 'ro' );
has 'format' => ( is => 'ro', lazy => 1, builder => '_readFormat' );
has onErr    => ( is => 'rw' );
has onEof    => ( is => 'rw' );
has eof      => ( is => 'ro', init_arg => undef );
has err      => ( is => 'ro', init_arg => undef );
has _extract => ( is => 'rw', init_arg => undef );
has _readBuf => ( is => 'rw', init_arg => undef );

sub BUILD {
	my $self= shift;
	$self->_extract( $self->can('_extractFormatProxyThunk') );
	$self->_readBuf('');
	DEBUG(foo => "+ $self  -- pid $$");
}

=head1 ATTRIBUTES

=head2 $self->format

Returns the format used on the stream.  Built-in formats are 'json' or 'storable'

=head1 METHODS

=head2 $data= $self->read

Returns one data record, or () at end of stream.  This method can block, so don't use it
if you wanted the nonblocking API.  Note that undef could be encoded on the stream, making
the return value slightly vague.  Call it in array context if you want to see the difference
between reading undef and EOF.  However, keep in mind that undef makes a nice terminator
between segments of data, so it is still good style to do:

  while ($rec= $stream->read()) {
  }

Read throws an exception if a partial record exists at the end of the stream.

=cut
sub read {
	my $self= shift;
	do {
		my ($success, $rec)= $self->extractNextRecord($self->{_readBuf});
		return $rec if $success;
	} while ($self->_readMore);
	length($self->{_readBuf}) eq 0
		or die "StructReader: Partial record found on stream";
	return;
}

=head2 (success, $data)= $self->extractNextRecord( $buffer )

This method is lower level than read().  It attempts to extract bytes out of the
passed argument (which should be a scalar) and returns a success flag, and the
data if it succeeds.  As such, this should always be called in array context.

Note that there is no need to use the read buffer of this object; you are free
to use whatever buffer you like.  However, it also means you must grow your scalar
large enough to hold an entire data record before this function will succeed.

The first time this method succeeds, it will have silently detected the format
of the stream.  You may then call ->format without fear of blocking.

=cut
sub extractNextRecord {
	my $self= shift; # second parameter is the input buffer, which we modify in place
	wantarray or die "extractNextRecord should be called in array context";
	
	# we call the extraction function in-place, and check for success/failure by whether it returns anything.
	my ($data, $remainder)= $self->{_extract}->($self, $_[0]);
	return 0 unless defined $remainder;
	
	$_[0]= $remainder; # alter the input buffer to contain the remainder
	return (1, $data);
}

sub flagErr {
	my ($self, $err)= @_;
	return if $self->err;
	$self->{err}= $err;
	close delete $self->{in};
	$self->onErr->($self, $err) if $self->onErr;
	$self->flagEof;
}

sub flagEof {
	my $self= shift;
	return if $self->{eof};
	$self->{eof}= 1;
	$self->onEof->($self) if $self->onEof;
}

sub _readMore {
	my $self= shift;
	my $got= sysread( $self->in, $self->{_readBuf}, 8192, length($self->{_readBuf}) );
	if (defined $got) {
		return 1 if $got > 0; # success
		$self->flagEof;
		return 0; # EOF
	} else {
		return -1 if $!{EINTR}; # temporary failure
		$self->flagErr("StructReader: read error: $!");
		die $self->err;
	}
}

sub _readFormat {
	my $self= shift;
	while (!$self->_extractFormat($self->{_readBuf})) {
		$self->_readMore();
		if ($self->_readMore == 0) { # fatal error, EOF
			die "Stream ended before format discovered";
		}
	}
	$self->{format};
}

sub _extractFormat {
	my $self= shift;
	my $nlPos= index($_[0], "\n");
	return 0 unless $nlPos >= 0;
	($self->{format}, $_[0])= ( substr($_[0], 0, $nlPos), substr($_[0], $nlPos+1) );
	$self->{_extract}= $self->can("_extract_".$self->{format}) or die "Unsupported format: ".$self->{format};
	return 1;
}

# Passes through to the extraction function after detecting the format
# We use this as the initial value of $self->{_extract}
sub _extractFormatProxyThunk {
	my $self= shift;
	return $self->_extractFormat($_[0])? $self->{_extract}->($self, $_[0]) : ();
}

=head1 EXTRACTION FUNCTIONS

The API for an extraction function is
  my ($dataStruct, $remainder)= $self->_extract_$FORMAT( $buffer );

This makes an extraction function very easy to write.
  - name the method "_extract_" . $format
  - return () if there is not enough data.
  - return ($dataStruct, $remainder) if the buffer contained a complete record.
  - die if there is enough data but the bytes can't be decoded.
  - $remainder should be an empty scalar if the entire buffer was used;  NOT undef.
  - $data is allowed to be undef, if that's what the user originally wrote.

=cut

sub _extract_json {
	my ($self, $buf)= @_;
	my $nlPos= index $buf, "\n";
	return unless $nlPos >= 0;
	my ($recBytes, $remainder)= (substr($buf, 0, $nlPos), substr($buf, $nlPos+1));
	my $json= $self->{_json} ||= JSON->new->allow_nonref->utf8;
	return $json->decode($recBytes), $remainder;
}

sub _extract_storable {
	my ($self, $buf)= @_;
	# need the first 4 bytes to know how long the message is
	return unless length($buf) >= 4;
	my $byteLen= unpack("L",substr($buf, 0, 4));
	# do we have a complete message?
	return unless length($buf) >= 4 + $byteLen;
	my ($recBytes, $remainder)= (substr($buf, 4, $byteLen), substr($buf, 4+$byteLen));
	# split the buffer
	return ${ thaw($recBytes) }, $remainder;
}

sub DESTROY {
	DEBUG(foo => "- $_[0]  -- pid $$");
}

1;