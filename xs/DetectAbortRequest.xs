#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>

static pthread_t watch_thread;
static int watch_fd;
static int watch_signal;
static int stop_watching = 0;

void* watch_for_disconnect_io(void* arg) {
    char buf;
    while (!stop_watching) {
        if (read(watch_fd, &buf, 1) <= 0) {
            kill(getpid(), watch_signal);
            break;
        }
    }
    return NULL;
}

void* watch_for_disconnect_timer(void* arg) {
    while (!stop_watching) {
        sleep(1);
        // Dummy write to trigger disconnect detection
        if (write(STDOUT_FILENO, "", 0) == -1) {
            kill(getpid(), watch_signal);
            break;
        }
    }
    return NULL;
}

void start_disconnect_watcher_io(int fd, int signal) {
    watch_fd = fd;
    watch_signal = signal;
    stop_watching = 0;
    pthread_create(&watch_thread, NULL, watch_for_disconnect_io, NULL);
}

void stop_disconnect_watcher_io() {
    stop_watching = 1;
    pthread_join(watch_thread, NULL);
}

void start_disconnect_watcher_timer(int signal) {
    watch_signal = signal;
    stop_watching = 0;
    pthread_create(&watch_thread, NULL, watch_for_disconnect_timer, NULL);
}

void stop_disconnect_watcher_timer() {
    stop_watching = 1;
    pthread_join(watch_thread, NULL);
}

MODULE = RapidApp::Util::XS::DetectAbortReqest  PACKAGE = RapidApp::Util::XS::DetectAbortReqest

void
start_disconnect_watcher_io(fd, signal)
    int fd
    int signal
  CODE:
    start_disconnect_watcher_io(fd, signal);

void
stop_disconnect_watcher_io()
  CODE:
    stop_disconnect_watcher_io();

void
start_disconnect_watcher_timer(signal)
    int signal
  CODE:
    start_disconnect_watcher_timer(signal);

void
stop_disconnect_watcher_timer()
  CODE:
    stop_disconnect_watcher_timer();
