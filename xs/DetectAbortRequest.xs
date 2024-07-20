#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>

typedef struct {
    int fd;
    int signal;
    int stop_watching;
    pthread_t watch_thread;
} WatchArgs;

void* watch_for_disconnect_io(void* arg) {
    WatchArgs* args = (WatchArgs*) arg;
    char buf;
    while (!args->stop_watching) {
        if (read(args->fd, &buf, 1) <= 0) {
            kill(getpid(), args->signal);
            break;
        }
    }
    return NULL;
}

void* watch_for_disconnect_timer(void* arg) {
    WatchArgs* args = (WatchArgs*) arg;
    while (!args->stop_watching) {
        sleep(1);
        // Dummy write to trigger disconnect detection
        if (write(STDOUT_FILENO, "", 0) == -1) {
            kill(getpid(), args->signal);
            break;
        }
    }
    return NULL;
}

void start_disconnect_watcher_io(int fd, int signal) {
    WatchArgs* args = malloc(sizeof(WatchArgs));
    args->fd = fd;
    args->signal = signal;
    args->stop_watching = 0;
    if (pthread_create(&args->watch_thread, NULL, watch_for_disconnect_io, args) != 0) {
        free(args);
        Perl_warn("pthread_create() failed");
    }
}

void stop_disconnect_watcher_io() {
    extern WatchArgs* args;
    args->stop_watching = 1;
    if (pthread_join(args->watch_thread, NULL) != 0) {
        Perl_warn("pthread_join() failed");
    }
    free(args);
}

void start_disconnect_watcher_timer(int signal) {
    WatchArgs* args = malloc(sizeof(WatchArgs));
    args->signal = signal;
    args->stop_watching = 0;
    if (pthread_create(&args->watch_thread, NULL, watch_for_disconnect_timer, args) != 0) {
        free(args);
        Perl_warn("pthread_create() failed");
    }
}

void stop_disconnect_watcher_timer() {
    extern WatchArgs* args;
    args->stop_watching = 1;
    if (pthread_join(args->watch_thread, NULL) != 0) {
        Perl_warn("pthread_join() failed");
    }
    free(args);
}

MODULE = RapidApp::Util::XS::DetectAbortRequest  PACKAGE = RapidApp::Util::XS::DetectAbortRequest

void
start_disconnect_watcher_io(fd, signal)
    int fd
    int signal
  PROTOTYPE: $$
  CODE:
    start_disconnect_watcher_io(fd, signal);

void
stop_disconnect_watcher_io()
  PROTOTYPE: $
  CODE:
    stop_disconnect_watcher_io();

void
start_disconnect_watcher_timer(signal)
    int signal
  PROTOTYPE: $
  CODE:
    start_disconnect_watcher_timer(signal);

void
stop_disconnect_watcher_timer()
  PROTOTYPE: $
  CODE:
    stop_disconnect_watcher_timer();
