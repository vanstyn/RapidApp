package RapidApp::Util::PSGI::ThreadedSocketWatch;
use strict;
use warnings;

# ABSTRACT: Inline C socket thread watcher

use Moo;
use Types::Standard qw(:all);
use Scalar::Util qw/blessed/;

use RapidApp::Util qw(:all);

use Socket ':all';
use POSIX ':signal_h';
use PadWalker 'peek_sub';

use Inline C => <<'END_C';
#include <sys/stat.h>
#define CONTROL_CANCEL    -1
#define CONTROL_TERMINATE -2
static pthread_t watch_thread;
static int control_pipe[2]= { -1, -1 };
struct control_msg {
  int fd,
      sig;
};
void* watch_main(void* unused) {
  sigset_t sset;
  pid_t self_pid= getpid();
  fd_set rd_fds, er_fds;
  struct timeval timeout;
  char buffer[64];
  int sig= 0, watch_fd= -1, n_ready, max_fd, read_q_len= 0;
  // Make sure we don't catch any of the main thread's signals
  sigfillset(&sset);
  pthread_sigmask(SIG_BLOCK, &sset, NULL);
  while (1) {
    FD_ZERO(&rd_fds);
    FD_ZERO(&er_fds);
    // Always listen for the control pipe
    FD_SET(control_pipe[0], &rd_fds);
    max_fd= control_pipe[0];
    // Listen to the socket if the watch is enabled
    if (sig && watch_fd >= 0) {
      // only keep watching for data if we don't already know it has data
      if (read_q_len <= 0)
        FD_SET(watch_fd, &rd_fds);
      // always watch for errors
      FD_SET(watch_fd, &er_fds);
      // keep track, for select() call
      if (watch_fd > max_fd)
        max_fd= watch_fd;
    }
    // If there's a socket, need to poll it for write status occasionally
    // because there's no way to select on that.
    timeout.tv_sec= sig && watch_fd >= 0? 0 : 1000000;
    timeout.tv_usec= 500000;
    // wait for file handles to be readable, or error out
    n_ready= select(max_fd+1, &rd_fds, NULL, &er_fds, &timeout);
    if (n_ready > 0) { // triggered by events on files
      // New control message
      if (FD_ISSET(control_pipe[0], &rd_fds)) {
        struct control_msg msg;
        if (read(control_pipe[0], &msg, sizeof(msg)) == sizeof(msg)) {
          write(2, buffer, snprintf(buffer, sizeof(buffer), "watch request: fd=%d sig=%d\n", msg.fd, msg.sig));
          if (msg.fd == -2) // end thread
            break;
          // change what we're watching and/or what signal gets sent
          watch_fd= msg.fd;
          sig= msg.sig;
          read_q_len= 0;
          // instructions have changed, do another loop before maybe sending signal
          continue;
        }
      }
    } else if (n_ready < 0) {
      perror("select failed"); // something unexpected went wrong
      break;
    }
    // If watch is armed, check socket status
    if (sig && watch_fd >= 0) {
      bool read_closed= false, write_closed= false;
      if (FD_ISSET(watch_fd, &er_fds)) { // error flag on socket
        read_closed= true;
        write_closed= true;
      }
      else if (FD_ISSET(watch_fd, &rd_fds)) {
        // Try peeking into socket read queue.  If it returns 0, that indicates EOF.
        read_q_len= recv(watch_fd, buffer, sizeof(buffer), MSG_DONTWAIT|MSG_PEEK);
//        write(2, buffer, snprintf(buffer, sizeof(buffer), "recv: %d, errno=%d\n", read_q_len, errno));
        if (read_q_len == 0)
          read_closed= true;
      }
      // Now check for shutdown write-channel of socket.
      // This seems like it ought to be true any time the socket gets closed,
      // but many times it does not.
      if (send(watch_fd, "", 0, MSG_DONTWAIT|MSG_NOSIGNAL) < 0 && errno == EPIPE)
        write_closed= true; // Writes are disabled on socket
      // Send signal?
      write(2, buffer, snprintf(buffer, sizeof(buffer), "watch %d (sig %d): read_closed=%d write_closed=%d%s\n",
        watch_fd, sig, read_closed? 1 : 0, write_closed? 1 : 0,
        (read_closed||write_closed)? ", sending signal" : ""));
      if (read_closed || write_closed) {
        kill(self_pid, sig);
        // stop watching
        sig= 0;
        watch_fd= -1;
      }
    }
  }
  return NULL;
}
int watch_socket(int sock, int sig) {
  int err;
  struct control_msg msg;

  // If not -1, verify sock is actually a socket
  if (sock >= 0) {
    struct stat statbuf;
    if (fstat(sock, &statbuf) < 0) croak("fstat failed %d", errno);
    if (!S_ISSOCK(statbuf.st_mode)) croak("Descriptor %d is not a socket", sock);
  }

  if (control_pipe[1] == -1) {
    if (pipe(control_pipe) != 0)
      croak("pipe: %d", errno);
    err= pthread_create(&watch_thread, NULL, watch_main, NULL);
    if (err != 0) {
      close(control_pipe[0]);
      close(control_pipe[1]);
      control_pipe[0]= control_pipe[1]= -1;
      croak("pthread_create: %d", err);
    }
  }
  msg.fd= sock;
  msg.sig= sig;
  if (write(control_pipe[1], &msg, sizeof(msg)) != sizeof(msg))
    croak("write failed on control pipe");
  return 1;
}
int terminate_watcher() {
  struct control_msg msg;
  if (control_pipe[1] >= 0) {
    msg.fd= CONTROL_TERMINATE;
    msg.sig= 0;
    if (write(control_pipe[1], &msg, sizeof(msg)) != sizeof(msg))
      croak("write failed on control pipe");
    pthread_join(watch_thread, NULL);
    close(control_pipe[1]);
    close(control_pipe[0]);
    control_pipe[1]= control_pipe[0]= -1;
  }
  return 1;
}
END_C

sub stop_watch_socket { watch_socket(-1, 0) }


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
  
  fileno($self->socket) or return join (" ",
    "Invalid psgix.io socket - not a file handle" 
  );
  
  return undef;
}


sub start {
  my $self = shift;
  
  if(my $reason = $self->not_startable_reason) {
    die $reason;
  }
  
  if(watch_socket($self->socket, eval $self->signal)) {
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