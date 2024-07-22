package RapidApp::Plack::Middleware::ThreadedSocketWatch;
use parent 'Plack::Middleware';

use strict;
use warnings;

# ABSTRACT: Inline C threaded client socket watcher

use RapidApp::Util qw(:all);

use Inline C => <<'END_C';
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
void watch_socket(int sock, int sig) {
  int err;
  struct control_msg msg;
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
}
void terminate_watcher() {
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
}
END_C

use POSIX ':signal_h';
use PadWalker 'peek_sub';


sub stop_watch_socket { watch_socket(-1, 0) }

sub call {
  my ($self, $env) = @_;
  
  my $socket;
  if (ref (my $handle = $env->{"psgix.io"})) {
    $socket = fileno($handle);
  } elsif ($env->{'psgix.informational'}) {
    my $conn_ref = peek_sub($env->{'psgix.informational'})->{'$conn'};
    $socket = $$conn_ref if $conn_ref;
  }
  
  scream($env);
  
  unless($socket) {
    warn "ThreadedSocketWatch: cannot start - psgix.io socket handle not available in psgi env";
    return $self->app->($env);
  }
  
  my $watch_started = 0;
  
  try {
    watch_socket($socket, SIGUSR1);
    $watch_started = 1;
  }
  catch {
    my $err = shift;
    warn "ThreadedSocketWatch: exception - $err";
    $watch_started = 0;
    stop_watch_socket(); # for good measure
  };
  
  my $return;
  
  if($watch_started) {
    $return = sub {
      my $responder = shift;
      
      local $SIG{USR1} = sub { 
        die "ThreadedSocketWatch: client aborted/disconnected.\n"; 
      };
      
      my $response = $self->app->($env);
      
      # Because we get back a CodeRef, we have to wrap it and call it ourselves
      # in our own CodeRef so that our localized USR1 signal handler is in scope
      # when Catalyst Code is actually ran
      my $ret = ref $response eq 'CODE'
        ? $response->($responder)
        : $responder->($response);
      
      stop_watch_socket();
      
    };
  }
  else {
    return $self->app->($env);
  }
  
  return $return;
}


1;