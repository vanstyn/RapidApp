package RapidApp::StructuredIO::WriterNB;
use Moo;
use AnyEvent;
use AnyEvent::Util 'fh_nonblocking';
use Scalar::Util 'weaken';
use Errno;
use Sub::Quote;
use RapidApp::Debug 'DEBUG';

extends 'RapidApp::StructuredIO::Writer';

sub isAEHandle {
	(shift)->out->can('push_write');
}

sub BUILD {
	my $self= shift;
	DEBUG(bgtask => "Made it to WriterNB::Build");
	if ($self->isAEHandle) {
		$self->{_write}= $self->can('_write_anyEventHandle');
	} else {
		$self->{_write}= $self->can('_write_anyEvent');
		fh_nonblocking($self->out, 1);
	}
}

sub write {
	my ($self, $data)= @_;
	die "Stream is closed from error: ".$self->err if $self->err;
	$self->pushWrite($data);
	$self->waitForComplete();
}

sub pushWrite {
	my ($self, $data)= @_;
	if (!$self->{_write}) { &BUILD($self) } # WTF is causing BUILD not to run on its own???
	$self->{_write}->($self, $self->{_serialize}->($self, $data));
}

sub _write_anyEventHandle {
	my ($self, $bytes)= @_;
	$self->out->push_write($bytes);
	1;
}

sub _write_anyEvent {
	my ($self, $bytes)= @_;
	
	# append data
	$self->{_writeBuf} ||= '';
	$self->{_writeBuf} .= $bytes;
	
	$self->_attemptNBWrite;
	1;
}

sub flagErr {
	my ($self, $err)= @_;
	my $drainCv= delete $self->{_drainEvent};
	$drainCv->carp("Error during write: ".$err) if $drainCv;
	$self->SUPER::flagErr($err);
}

sub _attemptNBWrite {
	my $self= shift;
	my $data= $self->{_writeBuf};
	if (length($data)) {
		my $wrote= syswrite($self->out, $data);
		my $nonfatal= $!{EAGAIN} || $!{EWOULDBLOCK} || $!{EINTR} || $!{WSAEWOULDBLOCK};
		my $err= $!;
		
		#DEBUG(nbstructwriter => 'syswrite(out, data, '.length($data).') =', $wrote, ' ($!=',$err,')');

		if (defined $wrote) {
			$self->{_writeBuf}= $data= substr($data, $wrote);
		} elsif (!$nonfatal) {
			$self->flagErr("WriterNB: stream error with ".length($data)." bytes unsent: $err");
			$self->{_writeBuf}= $data= '';
		}
	}
	# see if we still need a write event or not
	if (length($data) && !$self->err) {
		if (!$self->{_writeEvent}) {
			DEBUG(nbstructwriter => 'starting write-listen');
			weaken(my $wself= $self);
			$self->{_writeEvent}= AE::io($self->out, 1, sub { $wself->_attemptNBWrite } );
		}
	} else {
		delete $self->{_writeEvent};
		my $drainCv= delete $self->{_drainEvent};
		$drainCv->send if $drainCv;
	}
	
	if ($self->err) {
		$self->onErr($self->err);
	}
}

sub waitForComplete {
	my $self= shift;
	if ($self->out->can('push_write')) {
		die "Use methods of AnyEvent::Handle instead of WriterNB->waitForComplete\n";
	}
	
	if (length($self->{_writeBuf})) {
		my $cv= $self->{_drainEvent}= AE::cv;
		$self->_attemptNBWrite unless $self->{_writeEvent};  # shouldn't be necessary, but play it safe
		$cv->recv;
	}
	1;
}

sub DESTROY {
	my $self= shift;
	if (length($self->{_writeBuf} || '')) {
		warn "WriterNB was destroyed before all data was written!  See ->waitForComplete\n";
	}
	$self->SUPER::DESTROY();
	1;
}

1;