package RapidApp::StructuredIO::ReaderNB;
use Moo;
use AnyEvent;
use AnyEvent::Util 'fh_nonblocking';
use Scalar::Util 'weaken';
use RapidApp::Debug 'DEBUG';
use Errno;

extends 'RapidApp::StructuredIO::Reader';

has onData     => ( is => 'rw', trigger => \&_onData_trigger );
has isAEHandle => ( is => 'ro', lazy => 1, default => sub { (shift)->in->can('push_read'); } );

sub BUILD {
	my $self= shift;
	DEBUG(bgtask => "Made it to ReaderNB::Build");
	fh_nonblocking($self->in, 1) unless $self->isAEHandle;
}

my $err_exit= 0;
sub _onData_trigger {
	my ($self, $newVal)= @_;
	weaken( $self );
	my $activate= $newVal && !$self->eof && !$self->err;
	if ($self->isAEHandle) {
		$self->in->on_read($activate? sub { $self->_attemptExtract($self->in->{rbuf}) } : undef);
		$self->in->on_eof($activate? sub { $self->flagEof } : undef);
	}
	elsif ($activate) {
		$self->{_readEvent} ||= AE::io($self->in, 0, sub {
			# The following mess is a workaround for a strange bug where this callback kept occuring (100% cpu)
			# even after I removed the reference to {_readEvent}.  I'm not entirely sure why the bug went away,
			# but I think this helped.  The only line that should be needed here is
			#    $self->_attemptNBRead unless !$self || $self->{eof}
			return unless $self;
			if ($self->{in} && !$self->{err} && !$self->{eof}) {
				$self->_attemptNBRead
			} else {
				%$self= ( err => $self->{err}, eof => 1 );
				undef $self;
			}
		} );
	} else {
		$self->{_readEvent}= undef;
	}
}

sub read {
	die "'read' not available on non-blocking RapidApp::StructuredIO::Reader";
}

sub _readMore {
	die "'_readMore' not available on non-blocking RapidApp::StructuredIO::Reader";
}

sub _readFormat {
	warn "Attempt to read ->format on non-blocking reader when stream has not been started."
		." Returning undef instead of blocking.\n";
	undef;
}

sub flagErr {
	my ($self, $err)= @_;
	undef $self->{_readEvent};
	#my $cv= delete $self->{_readCv};
	#$cv->carp("Error during read: ".$err) if $cv;
	$self->SUPER::flagErr($err);
}

sub flagEof {
	my ($self, $err)= @_;
	undef $self->{_readEvent};
	#my $cv= delete $self->{_readCv};
	#$cv->send(undef) if $cv;
	$self->SUPER::flagEof($err);
}

sub _attemptNBRead {
	my $self= shift;
	exit 1 unless defined $self->in;
	$self->{_readBuf} ||= '';
	my $ofs= length($self->{_readBuf});
	my $got= sysread($self->in, $self->{_readBuf}, 8192, $ofs);
	my $nonfatal= $!{EAGAIN} || $!{EWOULDBLOCK} || $!{EINTR} || $!{WSAEWOULDBLOCK};
	my $err= $!;
	
	#DEBUG(nbstructreader => 'sysread(in, buf, 8192,', $ofs, ') =', $got, ' ($!=',$err,')');
	
	if (defined $got) {
		if ($got > 0) {
			$self->_attemptExtract($self->{_readBuf});
		} else {
			$self->flagEof;
		}
	} elsif (!$nonfatal) {
		$self->flagErr($err);
	}
}

sub _attemptExtract {
	my $self= $_[0];
	return 1 if exists $self->{pendingData}; # already have one extracted
	my ($success, $rec)= $self->extractNextRecord($_[1]);
	if ($success) {
		#if (my $cv= delete $self->{_readCv}) {
		#	$cv->send($rec);
		#} els
		if ($self->{onData}) {
			$self->{onData}->($rec);
		} else {
			$self->{pendingData}= $rec;
		}
	}
	$success;
}

1;