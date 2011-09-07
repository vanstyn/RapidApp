package RapidApp::BgTask::MsgPipe;
use Moo;
use IO::Handle;
use Try::Tiny;
use RapidApp::Debug 'DEBUG';
use RapidApp::StructuredIO::Reader;
use RapidApp::StructuredIO::Writer;
use Scalar::Util 'weaken';

=head1 NAME

RapidApp::BgTask::MsgPipe

=head1 SYNOPSIS

  # basic send/recv
  my $pipe= RapidApp::BgTask::MsgPipe->new( socket => $sock );
  $pipe->sendMessage({ blah => 1, foo => 2 });
  my $hash= $pipe->recvMessage();
  my $ret= $pipe->callRemoteMethod(foo => [1, 2, 3]);
  
  # a simple method server
  my $obj= MyClassWithPublicMethods->new();
  my $pipe2= RapidApp::BgTask::MsgPipe->new( socket => $sock, autoRMI => 1, rmiTargetObj => $obj );
  do { $pipe->recvMessage() } while (!$obj->terminated);

=head1 DESCRIPTION

This class implements a message pipe that can send and receive perl data structures,
and also do some simple remote-method-invocation.

Note that for a real server, you probably want to use the non-blocking version of
this class (RapidApp::BgTask::MsgPipeNB)

=head1 ATTRIBUTES

=head2 socket

The bi-directional socket to use for communication.

=head2 autoPingReply

Whether to automatically send "pong" responses to "ping" messages.
When enabled, ->recvMessage does not return the ping message, and just keeps blocking
until it gets a real message.

=head2 autoRMI

Whether to automatically run remote method requests.
When enabled, RMI requests get handled automatically during recvMessage,
and the caller of recvMessage never sees them.

=head2 rmiTargetObj

The object on which remote method calls will be made.
This is necessary in order for "autoRMI" to be able to handle the requests behind the scenes.

=head2 onEof( callback( $pipe ) )

A callback for when EOF is encountered on the read-end of the socket.

=head2 onErr( callback( $pipe, $message ) )

A callback for when a fatal error occurs on either reading or writing the socket.

=cut

has socket        => ( is => 'ro', required => 1 );

has reader        => ( is => 'ro', builder => '_build_reader', lazy => 1 );
has writer        => ( is => 'ro', builder => '_build_writer', lazy => 1 );

has autoPingReply => ( is => 'rw', default => sub{1;} );
has autoRMI       => ( is => 'rw', default => sub{0;} );
has rmiTargetObj  => ( is => 'rw', default => sub{undef;}, weak_ref => 1 );

sub BUILD {
	DEBUG(foo => "+ $_[0]  -- pid $$");
}

has onEof         => ( is => 'rw' );
has onErr         => ( is => 'rw' );
sub eof           { (shift)->reader->eof }
sub err {
	my $self= shift;
	return $self->reader->err || $self->writer->err;
}

sub recvQueueCount { scalar(@{ (shift)->_recvQueue }) }
has _recvQueue    => ( is => 'rw', default => sub {[]} );

sub _build_reader {
	weaken( my $self= shift );
	return RapidApp::StructuredIO::Reader->new(
		in => $self->socket,
		onErr => sub { $self->flagErr($_[1]) if $self },
		onEof => sub { $self->flagEof() if $self },
	);
}
sub _build_writer {
	weaken( my $self= shift );
	return RapidApp::StructuredIO::Writer->new(
		out => $self->socket,
		onErr => sub { $self->flagErr($_[1]) if $self },
		format => ($ENV{DEBUG_MSGPIPE}? 'json':'storable')
	);
}

=head2 sendMessage( \%message )

Send a message (which must be a hash) to the other end.

=cut
sub sendMessage {
	my ($self, $msg)= @_;
	ref $msg eq 'HASH' or die "All MsgPipe messages must be a hash";
	$self->_send($msg);
}

sub flagErr {
	my ($self, $err)= @_;
	if (my $r= $self->{reader}) { $r->onErr(undef); $r->flagErr($err) unless $r->err }
	if (my $w= $self->{writer}) { $w->onErr(undef); $w->flagErr($err) unless $w->err }
	$self->onErr->($self, $err) if $self->onErr;
}

sub flagEof {
	my $self= shift;
	$self->onEof->($self) if $self->onEof;
}

sub _send {
	my ($self, $msg)= @_;
	DEBUG(msgpipe => "pid", $$, 'send message', $msg);
	$self->writer->write($msg);
}

=head2 recvMessage

Returns the next message received which is not auto-handled.  Returns undef on EOF.

Any messages that are meant to be handled automatically (like ping replies or
RMI requests) will be processed during this method, and only a real message or
EOF will cause it to return.

=cut
sub recvMessage {
	my ($self, $timeout)= @_;
	if ($self->recvQueueCount) {
		# use the next message in the queue, unless we're looking for a response to a specific message
		return shift @{ $self->_recvQueue };
	}
	while (my $msg= $self->reader->read) {
		DEBUG(msgpipe => "pid", $$, 'got message', $msg);
		if (!defined $msg) {
			$self->{eof}= 1;
			return undef;
		}
		return $msg unless $self->_autoHandleMessage($msg);
		# TODO: implement timeout feature
	}
}

=head2 recvRmiResponse( $rmi_instance )

This method is used internally by ->callRemoteMethod.  You probably don't need to use it.

Returns the next message received which is a response to the RMI request with the
given instance ID.  Essentially, this method skips over messages until it finds one
that the caller wanted, and puts any other messages into a hidden queue.

When you call recvMessage next, it will draw messages from the queue first,
then start waiting for new messages.

=cut
sub recvRmiResponse {
	my ($self, $rmi_inst, $timeout)= @_;
	if ($self->recvQueueCount) {
		# scan the list for a response to $rmi_inst.  If found, return it.
		my ($msg)= grep { ($_->{rmi_response}||'') eq $rmi_inst } @{ $self->_recvQueue };
		if ($msg) {
			@{ $self->_recvQueue }= grep { $_ ne $msg } @{ $self->_recvQueue };
			return $msg;
		}
	}
	while (my $msg= $self->reader->read) {
		DEBUG(msgpipe => "pid", $$, 'got message', $msg);
		next if $self->_autoHandleMessage($msg);
		
		return $msg
			if ($msg->{rmi_response}||'') eq $rmi_inst;
		
		push @{ $self->_recvQueue }, $msg;
		# TODO: implement timeout feature
	}
}

sub _autoHandleMessage {
	my ($self, $msg)= @_;
	if ($self->autoPingReply && defined $msg->{ping}) {
		$self->_send({ pong => $msg->{ping} });
		return 1;
	} elsif ($self->autoRMI && defined $msg->{rmi_request}) {
		$self->handleRemoteMethodInvocation($msg);
		return 1;
	}
	return 0;
}

=head2 callRemoteMethod( methodName => \@params )

This builds a RMI message for the given method and parameters, sends the message,
waits for a RMI response message, and then converts that response either into
an exception or a return value.

In a vast majority of cases, it is just like calling the method locally.

=cut
sub callRemoteMethod {
	my ($self, $methodName, $params, $timeout)= @_;
	my $inst= ++$self->{_callInst};
	my $msg= {
		method => $methodName,
		params => $params,
		rmi_request => $inst,
	};
	$self->_send($msg);
	my $resp= $self->recvRmiResponse($inst, $timeout);
	die "Remote end disconnected during remote method invocation" unless $resp;
	
	# deliver remote exceptions as local exceptions
	die "Error from server via MsgPipe RMI:\n".$resp->{err} if !$resp->{ok};
	
	# return the result, with correct regard to call context
	return @{ $resp->{result} } if wantarray;
	return unless defined wantarray;
	die "remote method returned an array, but caller wanted scalar context" unless scalar(@{ $resp->{result} }) eq 1;
	return $resp->{result}[0];
}

=head2 handleRemoteMethodInvocation( \%methodMessage )

Performs the act of invoking the method on $self->rmiTarget, and then
sending a RMI response message.

You only need to use this method if you are not auto-handling the RMI messages.

=cut
sub handleRemoteMethodInvocation {
	my ($self, $methodMsg)= @_;
	try {
		my $response= $self->_execMethodOnTarget($methodMsg, $self->rmiTargetObj);
		$self->_send( $response );
	}
	catch {
		$self->_send({
			rmi_response => ''.$methodMsg->{rmi_request},
			ok => 0,
			err => 'MsgPipe: Unable to serialize remote method result: '.$_
		});
	};
}

=head2 _execMethodOnTarget( \%methodMessage, $targetObjectRef )

Call a method on the target object, and return a RMI response message.

MethodMsg has parameters of

  rmi_request   (used to identify which method call a response belongs to)
  method        name of the method to run
  params        array of the parameters to be passed to the method

The response has parameters of

  rmi_response  identical to input parameter
  method        name of the method that was called
  ok            boolean success flag
  result        an array of the values returned form the function in array context
  err           an error message if the method died

=cut
sub _execMethodOnTarget {
	my ($self, $methodMsg, $target)= @_;
	my ($method, $instance, @p, @result, $response);
	try {
		defined($instance= $methodMsg->{rmi_request}) or die 'Missing "rmi_request"';
		$method= $methodMsg->{method} or die 'Missing "method"';
		# process the request and return the result, like a remote function call
		if (defined $methodMsg->{params}) {
			ref $methodMsg->{params} eq 'ARRAY' or die '"params" must be an array';
			@p= @{ $methodMsg->{params} };
		}
		@result= $target->$method(@p);
		$response= { rmi_response => $instance, method => $method, ok => 1, result => \@result };
	} catch {
		my $errStr;
		try {
			$errStr= ''.$_;
		} catch {
			$errStr= 'MsgPipe: Unable to return error: Cannot stringify '.(ref $_);
		};
		$response= { rmi_response => $instance, method => $method, ok => 0, err => $errStr };
	};
	return $response;
}

sub DESTROY {
	close($_[0]->socket) if $_[0]->socket;
	DEBUG(foo => "- $_[0]  -- pid $$");
}

1;