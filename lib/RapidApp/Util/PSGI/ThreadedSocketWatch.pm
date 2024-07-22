package RapidApp::Util::PSGI::ThreadedSocketWatch;
use strict;
use warnings;

# ABSTRACT: Manager object for Inline C threaded client socket watcher

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw/blessed/;

use RapidApp::Util qw(:all);

use RapidApp::Util::PSGI::InlineCSocketWatch qw(start_watch_socket stop_watch_socket);

use POSIX ':signal_h';
use PadWalker 'peek_sub';

use Socket ':all';
use POSIX ':signal_h';
use PadWalker 'peek_sub';

has 'psgi_env', is => 'ro', isa => HashRef, required => 1;      
has 'signal',         is => 'ro', isa => Str, default => sub { 'SIGUSR1' };

has '_started', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;
has '_started_and_stopped', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;

has 'socket', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $env = $self->psgi_env;
  
  my $socket = undef;
  if (ref (my $handle = $env->{"psgix.io"})) {
    $socket = fileno($handle);
  } elsif ($env->{'psgix.informational'}) {
    my $conn_ref = peek_sub($env->{'psgix.informational'})->{'$conn'};
    $socket = $$conn_ref if $conn_ref;
  }
  
  $socket
};


sub BUILD {
  my $self = shift;
  
  try {
    # use POSIX ':signal_h' exports signal keywords, so if this 
    # fails, it must be a bad signal keyword
    eval $self->signal; 
  }
  catch {
    my $err = shift;
    die join('', 'Bad signal value "',$self->signal,'" - did not evaluate as POSIX signal keyword. Caught: ',$err);
  };
  
}

sub is_startable { (shift)->not_startable_reason ? 0 : 1 }

sub not_startable_reason {
  my $self = shift;

  $self->_started and return "already started";
  
  $self->_started_and_stopped and return join(" ",
    "The socket watcher has already been started and was subsequently stopped.",
    "This Object class should only ever be used once - create a new watcher object if",
    "you need to start a new watcher thread"
  );
  
  ! $self->psgi_env->{'psgi.streaming'} and return join(" ",
    "'psgi.streaming' is not set in the supplied PSGI env HashRef",
    "which is required for this module to work. Make sure you're using a server",
    "which supports PSGI Streaming"
  );
  
  defined $self->socket or return join (" ",
    "Unable to access the 'psgix.io' socket via the supplied PSGI env through either",
    "direct inclusion in the env, nor from indirect access via 'psgix.informational'.",
    "Access to this raw client socket is required for this module to work. Make sure you",
    "are using a PSGI server which supports streaming and psgix I/O extensions."  
  );
  
  my $fd_number = ref $self->socket ? fileno($self->socket) : $self->socket;
  ($fd_number =~ /^[0-9]+$/) or return join (" ",
    "Invalid psgix.io socket - not a file handle ref or a file descriptor number" 
  );
  
  return undef;
}


sub start {
  my $self = shift;
  
  if(my $reason = $self->not_startable_reason) {
    die $reason;
  }
  
  if(start_watch_socket($self->socket, eval $self->signal)) {
    $self->_started(1);
  }
  else {
    stop_watch_socket();
    die "Unknown error assigning socket to watcher thread";
  }
}

sub stop {
  my $self = shift;
  
  # Because the thread is always running, we still call stop for good measure,
  # even when the stop call is invalid (such as not yet started)
  stop_watch_socket();
 
  $self->_started or die "not started";
  $self->_started(0);
  $self->_started_and_stopped(1);
}

sub DESTROY {
  my $self = shift;
  
  # We always make the call to stop watching because the background thread
  # survives the life of the object; once it is started for the first time,
  # It's thread will run for the entire lifertime of the worker. So we want
  # to error on the side of stopping it from watching sockets. This is a
  # no-op if it isn't already watching a socket.
  stop_watch_socket();
}


1;
