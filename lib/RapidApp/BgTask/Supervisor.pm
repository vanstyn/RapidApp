package RapidApp::BgTask::Supervisor;
use Moo;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Util 'fh_nonblocking';
use IO::Handle;
use System::Command;
use Storable qw(freeze thaw);
use Socket qw(AF_UNIX SOCK_STREAM);
use RapidApp::BgTask::Task;
use RapidApp::BgTask::TaskPool;
use RapidApp::BgTask::MsgPipeNB;
use Data::Dumper;
use Try::Tiny;
use Hash::Merge 'merge';
use Scalar::Util 'weaken';
use Params::Validate ':all';
use RapidApp::Debug 'DEBUG';
eval "use RapidApp::TraceCapture"; # optional

=head1 NAME

BgTask Supervisor

=head1 SYNOPSIS

  # supervisor is created behind the scenes
  $taskPool->spawn(cmd => 'while sleep 1; do date; done');
  
  # to write your own supervisor
  use strict;
  use warnings;
  use RapidApp::BgTask::Supervisor;
  RapidApp::BgTask::Supervisor->script_main

=head1 DESCRIPTION

This is the main object implementing a job supervisor for the BgTask system.

Supervisor has a delicate startup sequence, whereby the parent process tries to wait
until it is fairly sure that the supervisor has started successfully before fully
detaching.  To make life easy, use "script_main" to perform this sequence.

Supervisor uses the RMI feature of BgTask::MsgPipe to let clients call methods on
the supervisor object.  This is very much a security concern, so use appropriate
filesystem permissions to keep untrusted clients from connecting to the socket.

Supervisor has a number of methods intended to be called by clients.  It also has
lots of other methods which probably shouldn't be called by the client.  It would
perhaps have been a good idea to separate out the public methods into a new package,
and proxy them back to the Supervisor object.

I didn't do this yet, so here is a list:
  terminate
  getInfo
  applyMeta
  kill
  restart
  getStreamInfo
  readStream
  writeStream
  closeStream

You will find these nicely wrapped up by the BgTask::Task class.  Use that when
possible.

=head1 HOW TO DEBUG

Debugging can be difficult, since this runs as a background job disconnected from
the terminal.  Use the -f option, and encode your parameters into Storable format
on stdin, and then you can run it in the foreground:

  perl -e 'use Storable "freeze"; print freeze { exec => [ "/usr/bin/cat" ], meta => { name => "Hello World" } };' > foo
  
  perl -e 'use RapidApp::BgTask::Supervisor; RapidApp::BgTask::Supervisor->script_main' -- -f < foo

If you aren't sure what your parameters need to be, set the DEBUG_BGTASK environment
variable and then call BgTask::TaskPool->spawn() with appropriate official parameters,
and it will write out /tmp/bgtask_serialized_params.sto for you.  Then use that.

You can also enable DEBUG_SUPERVISOR for lots of diagnostic info.

=cut

sub trace {
	DEBUG(supervisor => caller);
	DEBUG([supervisor => 1], caller(1));
	DEBUG([supervisor => 2], caller(2));
}

sub script_main {
	my $class= shift;
	
	# optional support for capturing errors with RapidApp::TraceCapture
	my $tcap_coderef= RapidApp::TraceCapture->can("captureTrace");
	local $SIG{__DIE__}= $tcap_coderef if $tcap_coderef;
	
	# Params come in serialized on STDIN.
	# We don't use STDOUT, and STDERR is used to report back to the caller.
	# Once we report our success, we redirect STDOUT and STDERR to a file.
	
	my $serializedParams;
	{ local $/= undef;
	  $serializedParams= <STDIN>;
	  close STDIN;
	}
	
	my $taskPool= $ENV{BGTASK_TASKPOOL_PATH}? RapidApp::BgTask::TaskPool->new(path => $ENV{BGTASK_TASKPOOL_PATH}) : RapidApp::BgTask->defaultTaskPool();
	
	defined $serializedParams && length $serializedParams or die "No child process arguments defined";
	my $p= thaw $serializedParams;
	
	if ($p->{lockfile}) {
		take_lockfile($p->{lockfile}) or die "Failed to acquire lockfile \"$p->{lockfile}\"";
	}
	
	if (!(@ARGV and $ARGV[0] eq '-f')) {
		my $outfname= $taskPool->outputPath($$);
		open(STDOUT, '> '.$outfname) or die "Failed to redirect stdout to $outfname";
		
		setpgrp(0,0); # become our own process group
	}
	
	# this must be called before fork, for reliable child watching
	AnyEvent::detect();
	
	my $supervisor= $class->new(
		taskPool => $taskPool,
		childCmd => $p->{exec},
		childEnv => $p->{env},
		childMeta => $p->{meta} || {},
		maxReadBufSize => $p->{maxReadBufSize},
	);
	
	# At this point, it is safe to assume we succeeded.  So, we write "OK" to stderr
	#   to let the caller know we're running.
	print STDERR RapidApp::BgTask::TaskPool->SUCCESS_RESPONSE;
	open STDERR, ">&STDOUT";
	
	warn "Testing";
	
	my $sigint=  AE::signal INT  => sub { $supervisor->terminate };
	my $sigterm= AE::signal TERM => sub { $supervisor->terminate };
	my $sighup=  AE::signal HUP  => sub { $supervisor->terminate };
	$supervisor->runTilDone;
	$supervisor->_cleanupFinal;
}

=head2 take_lockfile( $fname, \$result_existing_pid )

This function opens the named lockfile, marks it close-on-exec,
and then acquires a write-lock on it.

It also writes its pid to this file in case others are interested.

The file is not closed for the duration of the script, nor is
the file ever unlinked.  This makes a very secure way to ensure
only one copy of a service is running.

If the file cannot be locked, this returns false, and places the pid
of the process holding the lock into the optional $$result_existing_pid

=cut
sub take_lockfile {
	use Fcntl qw( :DEFAULT :flock :seek F_GETFL );
	my ($fname, $existing_pid_ref)= @_;
	sysopen(LOCKFILE, $fname, O_RDWR|O_CREAT|O_EXCL, 0644)
		or sysopen(LOCKFILE, $fname, O_RDWR)
		or die "Unable to create or open $fname\n";
	fcntl(LOCKFILE, F_SETFD, FD_CLOEXEC) or die "Failed to set close-on-exec for $fname";
	my $lockStruct= pack('sslll', F_WRLCK, SEEK_SET, 0, 0, $$);
	if (fcntl(LOCKFILE, F_SETLK, $lockStruct)) {
		my $data= "$$";
		syswrite(LOCKFILE, $data, length($data)) or die "Failed to write pid to $fname";
		truncate(LOCKFILE, length($data)) or die "Failed to resize $fname";
		# we do not close the file, so that we maintain the lock.
		return 1;
	}
	else {
		if ($existing_pid_ref) {
			sysread(LOCKFILE, $$existing_pid_ref, 1024);
		}
		close(LOCKFILE);
		return 0;
	}
}

has taskPool    => ( is => 'ro', required => 1 );
has childCmd    => ( is => 'rw' );
has childEnv    => ( is => 'rw' );
has childPid    => ( is => 'rw' );
has childExitStatus => ( is => 'rw' );
sub childExitStatusHash {
	trace();
	my $st= (shift)->childExitStatus;
	defined $st or return { exit => undef, signal => undef, core => undef };
	return { exit => $st >> 8, signal => $st & 127, core => $st &128 };
}

has childExitEvent => ( is => 'rw' );
has childMeta    => ( is => 'rw', default => sub{{}} );
has childStream  => ( is => 'rw', default => sub{{}} );

has listenSocket => ( is => 'rw' );
has listenEvent  => ( is => 'rw' );
has clients      => ( is => 'rw', default => sub { {} } );

has endEvent     => ( is => 'rw', default => sub { AE::cv } );

has maxReadBufSize => ( is => 'rw' );

=head2 $supervisor->terminate [PUBLIC]

Terminates the supervisor, killing the child proc and losing all in/out data

=cut
sub terminate {
	my $self= shift;
	trace();
	$self->{_cleanAggressive}= AE::timer 1.5, 0, sub { $self->_cleanupAggressive };
	$self->{_cleanFinal}= AE::timer 3, 0, sub { $self->endEvent->send; };
	$self->_cleanupNice;
	1;
}

sub runTilDone {
	my $self= shift;
	trace();
	$self->endEvent->recv;
}

sub _cleanupNice {
	my $self= shift;
	trace();
	kill 'INT', $self->childPid if $self->childPid;
}

sub _cleanupAggressive {
	my $self= shift;
	trace();
	kill 'TERM', $self->childPid if $self->childPid;
	for my $streamId (keys %{$self->childStream}) {
		try {
			if ($self->childStream->{$streamId}->{handle}) {
				print "Supervisor $$: closing child stream $streamId\n";
				$self->closeStream(streamId => $streamId);
			}
		}
		catch { print "Error closing stream $streamId: $_\n"; };
	}
	for my $client (values %{$self->clients}) {
		try {
			close $client->socket;
		};
	}
}

sub _cleanupFinal {
	my $self= shift;
	trace();
	kill 'KILL', $self->childPid if $self->childPid;
	for (values %{$self->childStream}) { try { %$_= () }; }
	for (values %{$self->clients}) { try { %$_= () }; }
	$self->childStream({});
	$self->clients({});
}

=head2 $supervisor->getInfo [PUBLIC]

Returns a hash of information about the task.

=cut
sub getInfo {
	my $self= shift;
	trace();
	return {
		meta         => $self->childMeta,
		command      => $self->childCmd,
		pid          => $self->childPid,
		exitStatus   => $self->childExitStatusHash,
		clientCount  => scalar keys %{ $self->clients },
		streams      => { map { $_ => $self->getStreamInfo($_) } keys %{ $self->childStream } },
	};
}

=head2 $supervisor->applyMeta( \%newHashData -or- key => $value, ... )

Merges new hash data with the existing meta hash.

=cut
sub applyMeta {
	trace();
	my $self= shift;
	return unless scalar(@_);
	ref($_[0]) eq 'HASH' or (scalar(@_) & 1) == 0 or die "applyMeta requires either a hashref or even number of arguments\n";
	my $hash= (ref($_[0]) eq 'HASH')? $_[0] : { @_ };
	$self->childMeta( merge($hash, $self->childMeta || {}) );
}

sub _startListen {
	trace();
	weaken( my $self= shift );
	my $path= $self->taskPool->socketPath($$);
	my $sock;
	socket($sock, AF_UNIX, SOCK_STREAM, 0) or die $!;
	print "Listening on $path ...\n";
	bind($sock, Socket::pack_sockaddr_un($path)) or die "Unable to listen on $path: $!";
	fh_nonblocking($sock, 1);
	listen($sock, 10) or die $!;
	
	$self->listenSocket($sock);
	$self->listenEvent( AE::io($sock, 0, sub { $self->_acceptConnection }) );
}

sub _acceptConnection {
	trace();
	weaken( my $self= shift );
	my $clientSock;
	while ($self->listenSocket && accept($clientSock, $self->listenSocket)) {
		my $client;
		$client= RapidApp::BgTask::MsgPipeNB->new(
			socket => $clientSock,
			autoRMI => 1,
			rmiTargetObj => $self,
			onMessage => sub {
				# we don't care about any messages except RMI
				print "Supervisor $$: ignoring stray message\n";
			},
			onErr => sub { $self->closeClient($_[0]) if $self },
			onEof => sub { $self->closeClient($_[0]) if $self },
		);
		$self->clients->{$client}= $client;
	}
}

sub closeClient {
	my ($self, $msgPipe)= @_;
	DEBUG(supervisor => "Closing client $msgPipe");
	delete $self->clients->{$msgPipe};
}

sub BUILD {
	trace();
	my $self= shift;
	weaken($self);
	$self->_startListen;
	$self->_launchChild($self->childCmd, $self->childEnv);
	
	# this detects closed connections
	$self->{pingTimer}= AE::timer 10, 10, sub { $self->distributeEvent({ event => 'ping' }) };
}

=head2 $supervisor->restart() [PUBLIC]

If the child process is not running, start it again using the same paramteters as the first time.

=cut
sub restart {
	trace();
	my $self= shift;
	return 0 if ($self->childPid);
	$self->_launchChild($self->childCmd, $self->childEnv);
	return 1;
}

sub _launchChild {
	trace();
	my ($self, $exec, $env)= @_;
	
	$self->childPid(undef);
	$self->childExitStatus(undef);
	my ($pid, $childIn, $childOut, $childErr)=
		System::Command->spawn(@$exec, { env => { %{$env||{}}, BGTASK_SUPERVISOR_PID => $$ } });
	
	$self->childPid($pid);
	$self->childExitEvent( AE::child( $pid, sub { my ($pid, $status)= @_; $self->_childExit(@_); } ) );
	$self->childStream->{0}= $self->_createStreamWatcher('r', 0, $childIn,  $self->childStream->{0}? $self->childStream->{0}->{readPos} : 0);
	$self->childStream->{1}= $self->_createStreamWatcher('w', 1, $childOut, $self->childStream->{1}? $self->childStream->{1}->{readPos} : 0);
	$self->childStream->{2}= $self->_createStreamWatcher('w', 2, $childErr, $self->childStream->{2}? $self->childStream->{2}->{readPos} : 0);
}

sub _createStreamWatcher {
	trace();
	my ($self, $mode, $streamId, $handle, $initialReadPos)= @_;
	weaken($self);
	my $w= {
		streamId  => $streamId,
		direction => $mode,
		handle    => AnyEvent::Handle->new(
			fh => $handle,
			on_read  => ($mode eq 'w' || $mode eq 'rw')? sub { $self->_childStreamRead($streamId); } : undef,
			on_error => sub { my ($hdl, $fatal, $msg)= @_; $self->_childStreamError($streamId, $fatal, $msg); },
			on_eof   => sub { my ($hdl)= @_; $self->_childStreamEof($streamId); },
		),
		rbuf      => '',
		readPos   => $initialReadPos,
		writePos  => 0,
		error     => 0,
		eof       => 0,
	};
	return $w;
}

=head2 $supervisor->getStreamInfo( $streamId ) [PUBLIC]

Like getInfo, but only data for one stream.

StreamId should be a numeric file descriptor number of the child process.

=cut
sub getStreamInfo {
	trace();
	my ($self, $streamIdOrWatcher)= @_;
	my $w= (ref $streamIdOrWatcher)? $streamIdOrWatcher : $self->childStream->{$streamIdOrWatcher};
	defined $w or die "No such stream";
	
	my $unwritten= length( $w->{handle}{wbuf} || '' );
	my $unread= length( $w->{rbuf} );
	return {
		direction    => $w->{direction},
		readPos      => $w->{readPos},
		readAvail    => $unread,
		writePos     => $w->{writePos} - $unwritten,
		writePending => $unwritten,
		error        => $w->{error},
		errMsg       => $w->{errMsg},
		eof          => $w->{eof},
	};
}

sub applyBounds {
	my ($min, $val, $max)= @_;
	return $val < $min? $min : $val > $max? $max : $val;
}

=head2 $supervisor->readStream( streamId => $streamId, ofs => $offset, count => $byteCount, peek => $bool, discard => $bool )  [PUBLIC]

$streamId is a numeric file descriptor number of the child.  Call getInfo for a list of streams. (which are always [0, 1, 2] for now)
And in fact, only 1 and 2 are ever readable.

$offset is a byte offset from the first byte read form the stream.
Not all bytes might be available.  Call getStreamInfo to find the minimum $offset allowed.
However, setting $offset to too small of a number will still return a result with "ofs" set
to the earliest offset currently available. (so an $offset of 0 will always return a packet
of the earliest data)

$count is the number of bytes to retrieve.  If fewer are available, fewer will be returned.

If 'peek' is set, no data is removed from the buffer.  If ppek is not set, all read bytes will
be removed and no longer available.

If 'discard' is set, the data will be removed from the buffer, but not returned.  Use this if
you want to remove data from the buffer but don't want to waste the time to have it sent to you.

=cut
sub readStream {
	trace();
	my $self= shift;
	my %p= validate(@_, { streamId => 1, ofs => 0, count => 0, peek => 0, discard => 0 });
	my $w= $self->childStream->{$p{streamId}};
	defined $w or die "No such stream $p{streamId}";
	my $minOfs= $w->{readPos};
	my $maxCount= length($w->{rbuf});
	$p{ofs}= applyBounds($minOfs, $p{ofs}||$minOfs, $minOfs+$maxCount);
	$p{count}= $maxCount unless defined $p{count};
	
	my $data= substr($w->{rbuf}, $p{ofs}-$minOfs, $p{count});
	
	# if we're not using "peek" mode, we discard the data now that it has been read
	if (!$p{peek}) {
		my $discardPos= $p{ofs}-$minOfs + length($data);
		$w->{rbuf}= substr($w->{rbuf}, $discardPos);
		$w->{readPos} += $discardPos;
	}
	
	return {
		ofs => $p{ofs},
		($p{discard}? () : (data => $data)),
		info => $self->getStreamInfo($p{streamId}),
	};
}

=head2 $supervisor->writeStream( streamId => $streamId, data => $data )  [PUBLIC]

Write a scalar of bytes to the specified stream.

StreamId currently must be 0 (STDIN is the only writeable stream)

=cut
sub writeStream {
	trace();
	my $self= shift;
	my %p= validate(@_, { streamId => 1, data => 1 });
	my $w= $self->childStream->{$p{streamId}};
	defined $w or die "No such stream $p{streamId}";
	$w->{handle}->destroyed and die "Stream is closed";
	
	$w->{writePos}+= length($p{data});
	$w->{handle}->push_write($p{data});
	
	return {
		info => $self->getStreamInfo($p{streamId})
	};
}

=head2 $supervisor->closeStream( streamId => $streamId, immediate => $bool )  [PUBLIC]

This closes a stream.  If immediate is set, it will close the stream before making
sure that previous writes are complete.  Otherwise, it waits for all data to be
consumed by the child, then closes the stream.

Streams will always be closed immediately if they have not been written to.

=cut
sub closeStream {
	trace();
	my $self= shift;
	my %p= validate(@_, { streamId => 1, immediate => 0 });
	my $w= $self->childStream->{$p{streamId}};
	defined $w or die "No such stream $p{streamId}";
	defined $p{close} or $p{close}= 1;
	
	return 0 unless !$w->{handle}->destroyed;
	
	weaken($w);
	my $close_proc= sub {
		my $ret= close($w->{handle}{fh});
		$w->{handle}->destroy;
		#$w->{handle}= undef;
		$w->{direction}= 0;
		$w->{eof}= 1;
		$w->{error}= $ret? 0 : $!;
	};
	
	if ($p{close}) {
		# don't close until all data has been written... unless they requested to close it immediately
		if (!$p{immediate} && $w->{handle} && $w->{handle}{wbuf} && length($w->{handle}{wbuf})) {
			$w->{handle}->{low_water_mark}= 0;
			$w->{handle}->on_drain($close_proc);
			return 1;
		} else {
			$close_proc->();
			$w->{error} and die $w->{error};
			return 1;
		}
	}
}

=head2 $supervisor->kill( $sigName )  [PUBLIC]

Send the specified signal to the child process.

=cut
sub kill {
	trace();
	my ($self, $sigName)= @_;
	kill $sigName, $self->childPid;
}

sub _childStreamRead {
	trace();
	my ($self, $streamId)= @_;
	my $watcher= $self->childStream->{$streamId};
	
	$watcher->{rbuf} .= $watcher->{handle}{rbuf};
	$watcher->{handle}{rbuf}= '';
	
	# Truncate buffer to N bytes if that option has been configured
	if ($self->maxReadBufSize) {
		my $surplus= length($watcher->{rbuf} || '') - $self->maxReadBufSize;
		if ($surplus > 0) {
			$watcher->{rbuf}= substr($watcher->{rbuf}, $surplus);
			$watcher->{readPos} += $surplus;
		}
	}
	
	my $event= {
		event => 'streamDataAvail',
		streamId => $streamId,
		streamInfo => $self->getStreamInfo($watcher)
	};
	
	$self->distributeEvent($event);
}

sub _childStreamError {
	trace();
	my ($self, $streamId, $fatal, $msg)= @_;
	my $watcher= $self->childStream->{$streamId};
	$watcher->{error}= 1;
	$watcher->{errMsg}= $msg;
	if ($fatal) {
		close($watcher->{handle}{fh});
		$watcher->{handle}->destroy;
		#$watcher->{handle}= undef;
		$watcher->{eof}= 1;
	}
	
	my $event= {
		event => 'streamError',
		streamId => $streamId,
		streamInfo => $self->getStreamInfo($watcher),
		fatal => $fatal,
		msg => $msg,
	};
	
	$self->distributeEvent($event);
}

sub _childStreamEof {
	trace();
	my ($self, $streamId)= @_;
	my $watcher= $self->childStream->{$streamId};
	$watcher->{handle}->destroy;
	#$watcher->{handle}= undef;
	$watcher->{eof}= 1;
	
	my $event= {
		event => 'streamEof',
		streamid => $streamId,
		streamInfo => $self->getStreamInfo($watcher),
	};
}

sub _childExit {
	trace();
	my ($self, $pid, $status)= @_;
	if ($pid eq $self->childPid) {
		$self->childPid(undef);
		$self->childExitStatus($status);
		$self->childExitEvent(undef);
		$self->distributeEvent({ event => 'childExit', status => $status });
	} else {
		warn "Received exit event for wrong child! ($pid != ".$self->childPid.")";
	}
}

sub DESTROY {
	trace();
	my $self= shift;
	unlink $self->socketPath;
}

=head2 $supervisor->distributeEvent( \%event )

Supervisor sends out event messages to all clients about activity on streams or the child exiting.

This method sends those events to all clients.

This also helps to determine when a client has closed its handle.  The onErr of the MsgPipe will
clean up the socket and remove the client form the list.  (this is why we make a copy of the
client list first)

=cut
sub distributeEvent {
	my ($self, $event)= @_;
	my @clients= values %{ $self->clients };
	for my $client (@clients) {
		$client->sendMessage($event);
	}
}

#__PACKAGE__->meta->make_immutable;
1;