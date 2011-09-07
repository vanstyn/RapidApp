package RapidApp::BgTask::MsgPipeNB;
use Moo;
use IO::Handle;
use Try::Tiny;
use RapidApp::Debug 'DEBUG';
use RapidApp::StructuredIO::ReaderNB;
use RapidApp::StructuredIO::WriterNB;
use Scalar::Util 'weaken';
use AnyEvent;
use Sub::Quote;

=head1 NAME

RapidApp::BgTask::MsgPipeNB

=head1 SYNOPSIS

  sub runServer {
    my $self= shift;
    my $pipe= RapidApp::BgTask::MsgPipeNB->new( socket => $sock, autoRMI => 1, rmiTargetObj => $self );
    my $exit= AE::cv;
    $pipe->onMessage( sub {
      my ($pipe, $msg)= @_;
      return $exit->send if $msg->{exit};
      $msg->{got_it}= 1;
      $pipe->pushMessage($msg);
    } );
    $exit->recv;
  }

=head1 DESCRIPTION

This is a version of MsgPipe that can work with non-blocking event-driven IO.

Instead of recvMessage, use a callback handler in onMessage.

Instead of sendMessage, use pushMessage.

Instead of callRemoteMethod, use pushMethodCall.

=cut

extends 'RapidApp::BgTask::MsgPipe';

has onMessage       => ( is => 'rw', trigger => \&_onMessage_trigger );
has _methodHandlers => ( is => 'ro', default => sub {[]} );

sub _onMessage_trigger {
	my ($self, $newVal)= @_;
	if ($newVal) {
		$self->_pumpRecvQueue if $self->recvQueueCount;
		weaken( my $wself= $self );
		$self->reader->onData( sub { $wself->_onRead(@_) } );
	} else {
		$self->reader->onData(undef);
	}
}

sub recvMessage { die "recvMessage unavailable in non-blocking mode"; }
sub recvRmiResponse { die "recvRmiResponse unavailable in non-blocking mode"; }
sub callRemoteMethod { die "callRemoteMethod unavailable in non-blocking mode"; }

sub _build_reader {
	weaken( my $self= shift );
	return RapidApp::StructuredIO::ReaderNB->new(
		in => $self->socket,
		onErr => sub { $self->flagErr($_[0]) if $self },
		onEof => sub { $self->flagEof() if $self },
	);
}
sub _build_writer {
	weaken( my $self= shift );
	return RapidApp::StructuredIO::WriterNB->new(
		out => $self->socket,
		onErr => sub { $self->flagErr($_[0]) if $self },
		format => ($ENV{DEBUG_MSGPIPE}? 'json':'storable')
	);
}

=head2 pushMessage( \%message )

Adds a message to the queue.

Note that there is no guarantee that the message actually got sent by the copletion of this call.

=cut
sub pushMessage {
	my ($self, $msg)= @_;
	ref $msg eq 'HASH' or die "All MsgPipe messages must be a hash";
	$self->_send($msg);
}

=head2 pushMethodCall( methodName => \@params, $unsupported_timeout, $callback )

Push a method call onto the send queue, and register a callback which will run when
a response (either success or failure) is received.

Note that the third parameter (timeout) is not yet supported.

On success, the callback will be called as
  callback( $msgPipe, 1, \@result )

On failure, the callback will be called as
  callback( $msgPipe, 0, $errMsg )

=cut
sub pushMethodCall {
	my ($self, $methodName, $params, $timeout, $callback)= @_;
	die "Require 4 params to pushMethodCall" unless scalar(@_) == 5;
	die "Write error ".$self->writer->err if $self->writer->err;
	my $inst= ++$self->{_callInst};
	my $msg= {
		method => $methodName,
		params => $params,
		rmi_instance => $inst,
	};
	$self->{_methodHandlers}{$inst}= $callback;
	$self->_send($msg);
}

sub _send {
	my ($self, $msg)= @_;
	DEBUG(msgpipe => "pid", $$, 'queued message', $msg);
	$self->writer->pushWrite($msg);
}

sub _onRead {
	my ($self, $msg)= @_;
	DEBUG(msgpipe => "pid", $$, 'received message', $msg);
	$self->_autoHandleMessage($msg);
}

sub _pumpRecvQueue {
	my $self= shift;
	defined $self->onMessage or die "BUG: can't pump recv queue if onMessage isn't set";
	while (my $msg= shift @{ $self->_recvQueue }) {
		if (!$self->_autoHandleMessage($msg)) {
			warn "Queued a message because onMessage was not set";
			push @{ $self->_recvQueue }, $msg;
		}
	}
}

sub _autoHandleMessage {
	my ($self, $msg)= @_;
	return 1 if $self->SUPER::_autoHandleMessage($msg);
	
	my $inst= $msg->{rmi_response};
	if (defined $inst && defined $self->_methodHandlers->{$inst}) {
		my $callback= delete $self->_methodHandlers->{$inst};
		DEBUG(msgpipe => 'executing callback for RMI method', $msg->{method});
		$callback->($self, $msg->{ok}? 1 : 0, $msg->{ok}? $msg->{result} : $msg->{err});
		return 1;
	}
	elsif ($self->onMessage) {
		$self->onMessage->($self, $msg);
		return 1;
	}
	
	return 0;
}

sub DESTROY {
	my $self= shift;
	$self->reader->onData(undef) if $self->{reader};

}

1;