package RapidApp::Util::PSGI::ThreadSocketWatch;
use strict;
use warnings;

# ABSTRACT: Inline C socket thread watcher

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw/blessed/;

use RapidApp::Util qw(:all);

use Socket ':all';
use POSIX ':signal_h';

use Inline C => <<'END_C';
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
struct socket_watch {
  pthread_t main, thread;
  int sock;
  int sig;
  int disarm_fd[2];
  float timeout_sec;
  int exitcode;
};
void* socket_watch(struct socket_watch *args) {
  int n_ready, read_q_len= 0,
    max_fd= args->disarm_fd[0] > args->sock? args->disarm_fd[0] : args->sock;
  double deadline, tdiff;
  fd_set rd, er;
  char buffer[256];
  struct timeval timeout;
  struct timespec cur_tm;
  // Read current monotonic time
  if (clock_gettime(CLOCK_MONOTONIC, &cur_tm) < 0) {
    perror("clock_gettime MONOTONIC failed");
    args->exitcode= 3;
    return args;
  }
  // Add the timeout to it.
  deadline= (double)cur_tm.tv_sec + .000000001 * cur_tm.tv_nsec;
  deadline += args->timeout_sec;
  while (1) {
    FD_ZERO(&rd);
    FD_ZERO(&er);
    if (read_q_len <= 0)
      FD_SET(args->sock, &rd);     // wake on readable socket, unless has data penidng
    FD_SET(args->disarm_fd[0], &rd); // wake on main thread asking us to stop
    FD_SET(args->sock, &er);         // wake on error-condition on socket
    // read current time
    if (clock_gettime(CLOCK_MONOTONIC, &cur_tm) < 0) {
      perror("clock_gettime MONOTONIC failed");
      args->exitcode= 3;
      return args;
    }
    // compare to deadline
    tdiff= deadline - ((double)cur_tm.tv_sec + .000000001 * cur_tm.tv_nsec);
    write(2, buffer, snprintf(buffer, sizeof(buffer), "Thread loop, %.2lf seconds remaining\n", tdiff));
    if (tdiff < 0)
      break;
    // wait half a second, unless timeout is sooner
    timeout.tv_sec= 0;
    timeout.tv_usec= tdiff < .5? (long)(tdiff * 1000000) : 500000;
    // wait for file handles to be readable, or error out
    n_ready= select(max_fd+1, &rd, NULL, &er, &timeout);
    write(2, buffer, snprintf(buffer, sizeof(buffer), "select()=%d, rd[disarm]=%d, rd[sock]=%d, er[sock]=%d\n",
      n_ready, FD_ISSET(args->disarm_fd[0], &rd), FD_ISSET(args->sock, &rd), FD_ISSET(args->sock, &er)
    ));
    if (n_ready > 0) { // triggered by events on files
      if (FD_ISSET(args->disarm_fd[0], &rd)) {
        // graceful cancel, exit thread
        args->exitcode= 1;
        return args;
      }
      if (FD_ISSET(args->sock, &er)) // error flag on socket
        break;
      if (FD_ISSET(args->sock, &rd)) {
        // Try peeking into socket read queue.  If it returns 0, that indicates EOF.
        read_q_len= recv(args->sock, buffer, sizeof(buffer), MSG_DONTWAIT|MSG_PEEK);
        write(2, buffer, snprintf(buffer, sizeof(buffer), "recv: %d, errno=%d\n", read_q_len, errno));
        if (read_q_len == 0)
          break; // Zero-length read pending on socket
      }
    } else if (n_ready < 0) {
      perror("select failed"); // something unexpected went wrong
      args->exitcode= 4;
      return args;
    }
    // Now check for shutdown write-channel of socket.
    // This seems like it ought to be true any time the socket gets closed,
    // but many times it does not.
    if (send(args->sock, "", 0, MSG_DONTWAIT|MSG_NOSIGNAL) < 0 && errno == EPIPE)
      break; // Writes are disabled on socket
  }
  // If we get here, it means send the signal.
  write(2, buffer, snprintf(buffer, sizeof(buffer), "Sending signal %d\n", args->sig));
  pthread_kill(args->main, args->sig);
  args->exitcode= 0;
  return args;
}
UV create_watch(int sock, double timeout_sec, int sig) {
  struct socket_watch *args;
  Newxz(args, 1, struct socket_watch);
  if (pipe(args->disarm_fd) != 0
    || pthread_create(&args->thread, NULL, (void*(*)(void*)) socket_watch, args) != 0
  ) {
    Safefree(args);
    croak("failed to start watcher");
  }
  args->timeout_sec= timeout_sec;
  args->sig= sig;
  args->sock= sock;
  args->main= pthread_self();
  return (IV) args;
}
void cancel_watch(UV args_ptr) {
  struct socket_watch *args= (struct socket_watch*) args_ptr;
  write(args->disarm_fd[1], "x", 1);
  pthread_join(args->thread, NULL);
  close(args->disarm_fd[0]);
  close(args->disarm_fd[1]);
  Safefree(args);
}
END_C

has 'psgi_env', is => 'ro', isa => HashRef, required => 1;      
has 'signal',         is => 'ro', isa => Str, default => sub { 'SIGUSR1' };
has 'kill_timeout',   is => 'ro', isa => Maybe[Int], default => sub { 3600 };

has 'watcher', is => 'rw', default => sub { undef }, init_arg => undef;
has '_started', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;
has '_started_and_stopped', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;

sub socket { (shift)->psgi_env->{'psgix.io'} }


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


sub is_startable {
  my $self = shift;
  
  $self->not_startable_reason ? 0 : 1
}

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
  
  ! exists $self->psgi_env->{'psgix.io'} and return join(" ",
    "The supplied PSGI env HashRef does not contain 'psgix.io' socket/handle",
    "which is required for this module to work. Make sure you're using a server",
    "which supports PSGI Streaming"
  );
  
  defined $self->socket or return "'psgix.io' is undef";
  
  #(blessed($self->socket) and $self->socket->isa('IO::Handle')) or return join(" ",
  #  "The 'psgix.io' in the supplied PSGI env HashRef is not a valid socket/filehandle object"
  #);
  
  # TODO: add check to see if the socket is in the correct state, open, etc, whatever that is

  return undef;
}


sub start {
  my $self = shift;
  
  if(my $reason = $self->not_startable_reason) {
    die $reason;
  }
  
  $self->watcher( create_watch(fileno($self->socket), $self->kill_timeout, eval $self->signal) )
    or die "Unknown error starting socker watcher thread";
  
  $self->_started(1);
}

sub stop {
  my $self = shift;
  $self->_started or die "not started";
  $self->watcher or die "stop(): unknown error - watcher previously started, but reference to watcher not available";
  cancel_watch( $self->watcher );
  $self->watcher( undef );
  $self->_started(0);
  $self->_started_and_stopped(1);
}

sub DESTROY {
  my $self = shift;
  try { $self->stop; } if $self->_started;
}


1;