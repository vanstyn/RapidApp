package RapidApp::BgTask::Task;

use strict;
use warnings;
require RapidApp::BgTask::TaskPool;
use RapidApp::BgTask::MsgPipe;
use Params::Validate ':all';
use Time::HiRes qw(usleep nanosleep);
use System::Command;
use IO::Handle;
use Scalar::Util 'weaken';
use RapidApp::Debug 'DEBUG';
use Socket qw(AF_UNIX SOCK_STREAM);

=head1 NAME

BgTask, the Background Task System

=head1 DESCRIPTION

This library allows you to conveniently start background jobs, and then check
on them and interact with them later using convenient perl data structures
for communication, all without needing to be a parent or sibling process.

Communication takes place through sockets in /var/run/bgtask/ and permissions
are controlled by file ownership.  Output from the script is held in memory until
something comes and reads it, even after the task terminates or is killed.
(however, if the task supervisor is killed, the output is lost).

=head1 SYNOPSYS

  my $task= RapidApp::BgTask->spawn(
      exec => [ qw( /opt/scripts/foo.pl  -n  -t /tmp/bar.txt ) ],
      env => { DEBUG_STUFF => 1 },
      meta => { name => 'Hello World', myDataStruct => MyObject->new({x =>'y'}) },
      retainOutput => 1000000 # retain up to one MB of output even after it has been read
  );
  
  my @runningTasks= RapidApp::BgTask->search( status => { running => 1 } );

  for my $task (@runningTasks) {
    $task->pause();
    $task->applyMeta('Paused by '.$$);
  }

  my $task= RapidApp::BgTask->new($pid);
  print "Bytes ".$task->stream(1)->start." - ".$task->stream(1)->limit." available on STDOUT\n";
  print "Bytes ".$task->stream(2)->start." - ".$task->stream(2)->limit." available on STDERR\n";
  
  my @datagrams= $task->stream('data')->read; # read all available messages
  my $stdout= $task->stream('stdout')->read;  # read all available bytes
  my $stdoutSegment= $task->stream('stdout')->read(12, 35); # read bytes [12 .. 34] if they are still available
  
  
  #! /usr/bin/perl
  use strict;
  use RapidApp::BgTask;
  my $task= RapidApp::BgTask->new($$);
  $task->applyMeta({ name => 'Hello World', target => $ARGV[0], purpose => 'World Domination' });
  print "Hello World";
  print STDERR, "Hello World";
  my @lines= <>;

=head1 METHODS

=head2 $class->defaultTaskPool

Returns a task pool based on the directory /var/run/bgtask.  This task pool is used
for the methods ->spawn and ->search.  If you want to use a custom task pool, create one,
and then use $pool->spawn and $pool->search

=cut

my $defTaskPool;
sub defaultTaskPool {
	$defTaskPool ||= RapidApp::BgTask::TaskPool->new(path => '/var/run/bgtask');
}

=head2 $class->spawn

Alias for $class->defaultTaskPool->spawn

See RapidApp::BgTask::TaskPool

=cut

sub spawn { (shift)->defaultTaskPool->spawn }

=head2 $class->search

Alias for $class->defaulttaskPool->search

See RapidApp::BgTask::TaskPool

=cut

sub search { (shift)->defaultTaskPool->search }

=head2 $class->new( $pid )

Create a new interface to an existing task.  This doesn't actually do any work, like connecting
to the task supervisor or anything, so creating a Task object is cheap.  In fact, this does little
other than blessing a hash with a pid in it as a BgTask.

If you want to see if you can successfully talk to the supervisor, call 'connect'.
However, keep in mind that the supervisor can be terminated at any moment, and then
whatever method you call next will likely die with an error.  So, you should generally
wrap all your code with try / catch.

=cut

sub new {
	my ($class, $pool, $pid)= @_;
	return bless { taskPool => $pool, pid => $pid }, $class;
}

=head2 $task->pid

The process ID of the supervisor of the task

=cut
sub pid {
	(shift)->{pid};
}

=head2 $task->taskPool

The associated TaskPool object which this job should use various parameters from.

=cut

sub taskPool {
	(shift)->{taskPool};
}

=head2 $bool = $task->connect( \%failReason = undef )

Try connecting to the supervisor of this task.  connect returns true if the supervisor exists
and if it was able to open a socket connection to the supervisor, else dies with an error.

If you don't want it to throw an exception, you can pass the optional hash ref as a parameter,
and the function will return false, with diagnostic information stored into the hash.
( this can help reduce overhead if you want to iterate accross all jobs, trying to connect to each )

=cut

sub connect {
	my ($self, $failReason)= @_;
	return 1 if defined $self->_conn;
	
	my $sock;
	my $path= $self->taskPool->socketPath($self->pid);
	DEBUG(bgtask => "Connecting to $path ...");
	socket($sock, AF_UNIX, SOCK_STREAM, 0) or die $!;
	my $ret= connect($sock, Socket::pack_sockaddr_un($path));
	if ($ret) {
		weaken $self;
		$self->{_conn}= RapidApp::BgTask::MsgPipe->new(socket => $sock);
		#my $resp= $self->_conn->sendMessageAndGetResponse({ protocol => 'storable' });
		#$resp->{protocol} eq 'storable'
		#	or die "Unable to initiate storable protocol with supervisor";
		#$self->_conn->protocol('storable');
	} else {
		defined $failReason or die "Unable to connect to supervisor on $path: $!";
		$failReason->{ok}= 0;
		$failReason->{syserr}= $!;
		$failReason->{msg}= "Unable to connect to supervisor on $path";
		return 0;
	}
}

=head1 $task->disconnect



=cut

sub disconnect {
	my $self= shift;
	
	$self->{_conn}= undef;
}

=head2 $task->applyMeta( %metaAttributes )

This method merges a hash of key/values into the hash of metadata associated with the process.

=cut

sub applyMeta {
	my $self= shift;
	$self->callRemoteMethod(applyMeta => [ @_ ]);
	1;
}

=head2 $task->info( $getFreshCopy=0 )

This method returns the "info hash" of the task.  The info hash has lots of useful information,
including a key "meta" which contains the metadata hash.

This method fetches the info the first time, and returns the cached info afterward.  If you
pass a true value for the optional $getFreshCopy, it will discard any cache and pull the info
from the supervisor again.

=cut

sub info {
	my ($self, $getFreshCopy)= @_;
	delete $self->{info} if $getFreshCopy;
	return ($self->{info} ||= $self->callRemoteMethod(getInfo => []));
}

=head2 $task->stream( $indexOrName )

This method returns a L<RapidApp::BgTask::Stream> which you can use to query or read or write to one
of the task's file descriptors.  The parameter can either be a numeric file descriptor,
or one of 'stdin', 'stdout', 'stderr'.

=cut

sub stream {
	my ($self, $streamName)= @_;
	return ($self->{_streams}->{$streamName} ||= RapidApp::BgTask::Stream->new( $self, $streamName ));
}

=head2 $task->kill( $signal='KILL' )

This method tells the supervisor to send a signal to the task.  Note that this is much
preferrable to trying to find the pid of the supervisor's child and trying to send the
signal yourself.

The signal name strings are the same as those for perl's kill() function.

=cut

sub kill {
	my ($self, $sigName)= @_;
	$self->callRemoteMethod(kill => [$sigName]);
	return 1;
}

=head2 $task->pause( $bool=true )

Alias for ->kill(SIGSTOP), or ->kill(SIGCONT) if the parameter is specified false.

=cut

sub pause {
	my ($self, $pause)= @_;
	defined $pause or $pause= 1;
	$self->kill($pause? 'STOP' : 'CONT');
}

=head2 $task->resume

Alias for ->kill(SIGCONT)

=cut

sub resume {
	(shift)->kill('CONT');
}

=head2 $task->restart

Re-execute a terminated task.  Has no effect if the job is still running.
This does not restart a supervisor; it tells a live supervisor to restart the child process.

=cut

sub restart {
	(shift)->callRemoteMethod(restart => []);
}

=head2 $task->delete

Tell the supervisor to terminate, killing its job, collecting any remaining output,
and removing its files and disappearing from existance.

=cut
sub terminate_supervisor {
	(shift)->callRemoteMethod(terminate => []);
}

=head2 $task->_conn

The connection to the supervisor, if one has been made.  undef if not connected.

=cut
sub _conn {
	(shift)->{_conn};
}

=head2 $task->callRemoteMethod

Run a remote method, checking the connection, getting a response, and checking the
response for errors.

=cut
sub callRemoteMethod {
	my $self= shift;
	defined $self->{_conn} or $self->connect;
	
	return $self->{_conn}->callRemoteMethod(@_);
}

package RapidApp::BgTask::Stream;
use strict;
use warnings;
use Scalar::Util 'weaken';

sub new {
	my ($class, $owner, $streamId)= @_;
	defined $owner->info->{streams}->{$streamId}
		or defined $owner->info(1)->{streams}->{$streamId}
			or die "stream $streamId does not exist";
	my $ret= bless { owner => $owner, streamId => $streamId }, $class;
	weaken($ret->{owner});
	return $ret;
}

sub owner { (shift)->{owner} }
sub streamId { (shift)->{streamId} }

sub info {
	my $self= shift;
	return $self->owner->callRemoteMethod(getStreamInfo => [$self->streamId]);
}

sub start {
	(shift)->info->{start};
}

sub limit {
	(shift)->info->{limit};
}

sub read {
	my ($self, $ofs, $count)= @_;
	return $self->owner->callRemoteMethod(readStream => [{ streamId => $self->streamId, ofs => $ofs, count => $count }]);
}

sub peek {
	my ($self, $ofs, $count)= @_;
	return $self->owner->callRemoteMethod(readStream => [{ streamId => $self->streamId, ofs => $ofs, count => $count, peek => 1 }]);
}

sub discard {
	my ($self, $ofs)= @_;
	return $self->owner->callRemoteMethod(readStream => [{ streamId => $self->streamId, ofs => $ofs, count => 0, discard => 1 }]);
}

sub write {
	my ($self, $data)= @_;
	return $self->owner->callRemoteMethod(writeStream => [{ streamId => $self->streamId, data => $data }]);
}

sub close {
	my ($self, $immediate)= @_;
	return $self->owner->callRemoteMethod(closeStream => [{ streamId => $self->streamId, immediate => $immediate }]);
}

1;