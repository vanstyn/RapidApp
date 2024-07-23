package RapidApp::Util::PSGI::InlineCSocketWatch;
use strict;
use warnings;

# ABSTRACT: Inline C socket thread watcher

use base 'Exporter';
our @EXPORT_OK = qw(start_watch_socket stop_watch_socket socket_from_psgi_env);

use PadWalker 'peek_sub';

sub stop_watch_socket  { watch_socket(-1, 0, -1, undef) }
sub start_watch_socket { watch_socket($_[0], $_[1], $_[2]//-1, $_[3])    }

sub socket_from_psgi_env {
  my $env = shift;
  
  my $socket = undef;
  if (ref (my $handle = $env->{"psgix.io"})) {
    $socket = fileno($handle);
  } elsif ($env->{'psgix.informational'}) {
    my $conn_ref = peek_sub($env->{'psgix.informational'})->{'$conn'};
    $socket = $$conn_ref if $conn_ref;
  }
  
  $socket
}

our $dir;

BEGIN {
  use File::Spec;
  $dir = File::Spec->catfile(File::Spec->tmpdir, 'RapidApp_InlineC_dir');
  -d $dir or mkdir $dir;
};

use Inline (C => Config =>
    name => 'RapidApp::Util::PSGI::InlineCSocketWatch',
    directory => "$dir"
);

use Inline C => <<'END_C';
#include <sys/stat.h>
#include <sys/socket.h>
#include <pthread.h>

#define CONTROL_TERMINATE 0
#define CONTROL_CHANGE_FD 1
struct control_msg { int act; };

static pthread_t watch_thread;
static int control_pipe[2]= { -1, -1 };

struct action_data {
  int watch_fd;
  int mysql_sock;
  int signal;
  #define MAX_EXEC_ARGC 64
  int exec_argc;
  char *exec_argv[MAX_EXEC_ARGC + 1]; // argv ends with extra NULL pointer
  char exec_buffer[512];
};

pthread_mutex_t action_data_mutex= PTHREAD_MUTEX_INITIALIZER;
static volatile struct action_data action_data;

int is_socket(int socket) {
  struct stat statbuf;
  if (fstat(socket, &statbuf) < 0) {
    perror("fstat");
    return 0;
  }
  return S_ISSOCK(statbuf.st_mode);
}

void* watch_main(void* unused) {
  sigset_t sset;
  pid_t self_pid= getpid();
  fd_set rd_fds, er_fds;
  struct timeval timeout;
  char buffer[64];
  int watch_fd= -1, n_ready, max_fd, read_q_len= 0;
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
    if (watch_fd >= 0) {
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
    timeout.tv_sec= watch_fd >= 0? 0 : 1000000;
    timeout.tv_usec= 500000;
    // wait for file handles to be readable, or error out
    n_ready= select(max_fd+1, &rd_fds, NULL, &er_fds, &timeout);
    if (n_ready > 0) { // triggered by events on files
      // New control message
      if (FD_ISSET(control_pipe[0], &rd_fds)) {
        struct control_msg msg;
        if (read(control_pipe[0], &msg, sizeof(msg)) == sizeof(msg)) {
          if (msg.act == CONTROL_TERMINATE) { // end thread
            write(2, buffer, snprintf(buffer, sizeof(buffer), "watch request: TERMINATE\n"));
            break;
          }
          // change what we're watching and/or what signal gets sent
          if (pthread_mutex_lock(&action_data_mutex) != 0)
            perror("pthread_mutex_lock");
          else {
            watch_fd= action_data.watch_fd;
            pthread_mutex_unlock(&action_data_mutex);
            write(2, buffer, snprintf(buffer, sizeof(buffer), "watch request: watch_fd=%d\n", watch_fd));
            read_q_len= 0;
          }
          // instructions have changed, do another loop before maybe sending signal
          continue;
        }
      }
    } else if (n_ready < 0) {
      perror("select failed"); // something unexpected went wrong
      break;
    }
    // If watch is armed, check socket status
    if (watch_fd >= 0) {
      bool read_closed= false, write_closed= false;
      if (FD_ISSET(watch_fd, &er_fds)) { // error flag on socket
        if (is_socket(watch_fd)) { // socket still exists
          read_closed= true;
          write_closed= true;
        } else {                   // socket was closed on our side
          write(2, buffer, snprintf(buffer, sizeof(buffer), "Socket %d appears to be closed, cancelling watch\n", watch_fd));
          watch_fd= -1;
          continue;
        }
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

      write(2, buffer, snprintf(buffer, sizeof(buffer), "watch %d: read_closed=%d write_closed=%d%s\n",
        watch_fd, read_closed? 1 : 0, write_closed? 1 : 0));
      // Send signal, etc?
      if (read_closed || write_closed) {
        if (pthread_mutex_lock(&action_data_mutex) != 0) {
          perror("pthread_mutex_lock");
        }
        else {
          struct action_data tmp;
          memcpy(&tmp, &action_data, sizeof(action_data));
          action_data.signal= -1;  // after we close it, it won't be valid
          action_data.exec_argc= 0; // assume should only run once
          pthread_mutex_unlock(&action_data_mutex);

          // Avoid race condition - verify these actions are for the same fd we watched
          if (watch_fd != tmp.watch_fd) {
            write(2, buffer, snprintf(buffer, sizeof(buffer), "The requested watch_fd has changed (%d->%d), returning to watch\n", watch_fd, tmp.watch_fd));
            watch_fd= tmp.watch_fd;
            continue;
          }
          watch_fd= -1; // stop listening

          if (tmp.signal > 0) {
            write(2, buffer, snprintf(buffer, sizeof(buffer), "  sending signal %d\n", tmp.signal));
            kill(self_pid, tmp.signal);
          }

          if (tmp.mysql_sock >= 0) {
            write(2, buffer, snprintf(buffer, sizeof(buffer), "  closing mysql fd %d\n", tmp.mysql_sock));
            if (shutdown(tmp.mysql_sock, SHUT_RDWR) != 0) perror("shutdown(mysql)");
          }

          if (tmp.exec_argc > 0) {
            write(2, buffer, snprintf(buffer, sizeof(buffer), "  launching %s\n", tmp.exec_argv[0]));
            // double-fork, so that parent can reap child, and grandchild gets cleaned up by init()
            pid_t child, gchild;
            if ((child= fork()) < 0)         // fork failure
              perror("fork");
            else if (child > 0) {            // parent - wait for immediate child to return
              int status= -1;
              waitpid(child, &status, 0);
              if (status != 0)
                perror("waitpid");  // not accurate, but probably not going to happen
            }
            else if ((gchild= fork()) <= 0) { // second fork
              if (gchild < 0) perror("fork");
              _exit(gchild < 0? 1 : 0);       // immediately exit
            }
            else {                            // grandchild, perform exec of desired prog
              close(0);
              open("/dev/null", O_RDONLY);
              execvp(tmp.exec_argv[0], tmp.exec_argv);
              perror("exec"); // if we got here, it failed.  Log the error.
              _exit(1); // make sure we don't continue this thread.
            }
          }
        }
      }
    }
  }
  return NULL;
}

int watch_socket(int watch_fd, int sig, int mysql_sock, SV *argv_sv) {
  int err;
  struct control_msg msg;
  struct action_data tmp;
  AV *argv= SvOK(argv_sv) && SvROK(argv_sv) && SvTYPE(SvRV(argv_sv)) == SVt_PVAV? (AV*)SvRV(argv_sv) : NULL;
  memset(&tmp, 0, sizeof(tmp));

  // If not -1, verify sock is actually a socket
  if (watch_fd >= 0 && !is_socket(watch_fd))
    croak("Descriptor %d is not a socket", watch_fd);
  tmp.watch_fd= watch_fd;

  if (mysql_sock >= 0 && !is_socket(mysql_sock))
    croak("Descriptor %d is not a socket", mysql_sock);
  tmp.mysql_sock= mysql_sock;

  tmp.signal= sig;

  if (argv) {
    int i, argc= av_len(argv)+1;
    char *str, *bufpos= tmp.exec_buffer, *buflim= bufpos + sizeof(tmp.exec_buffer);
    SV **el;
    STRLEN len;
    
    // The total number of arguments is limited
    if (argc > MAX_EXEC_ARGC)
      croak("Too many arguments for exec array");

    // Stringify and copy each argument into the buffer
    for (i= 0; i < argc; i++) {
      el= av_fetch(argv, i, 0);
      if (!el || !SvOK(*el))
        croak("exec array[%d] is not defined", (int)i);
      // The total string length of the arguments is also limited
      str= SvPV((*el), len);
      if (len+1 > buflim - bufpos)
        croak("argv list exceeds %d characters", (int)sizeof(tmp.exec_buffer));
      tmp.exec_argv[i]= bufpos;
      memcpy(bufpos, str, len);
      bufpos += len;
      *bufpos++ = '\0';
    }
    tmp.exec_argc= argc;
    tmp.exec_argv[argc]= NULL;
  } else {
    tmp.exec_argc= 0;
  }

  // now overwrite the global, guarded by a mutex
  if (pthread_mutex_lock(&action_data_mutex) != 0)
    croak("pthread_mutex_lock failed");
  memcpy(&action_data, &tmp, sizeof(tmp));
  pthread_mutex_unlock(&action_data_mutex);

  // start the thread if it doesn't exist
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

  // Send a message to tell it to reload watch_fd
  msg.act= CONTROL_CHANGE_FD;
  if (write(control_pipe[1], &msg, sizeof(msg)) != sizeof(msg))
    croak("write failed on control pipe");
  return 1;
}

int terminate_watcher() {
  struct control_msg msg;
  if (control_pipe[1] >= 0) {
    msg.act= CONTROL_TERMINATE;
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


1;
