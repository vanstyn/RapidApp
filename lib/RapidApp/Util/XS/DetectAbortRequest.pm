package RapidApp::Util::XS::DetectAbortReqest;
use strict;
use warnings;

# ABSTRACT: XS wrapper for thread to trigger signal for Aborted Request

use Moo;
use Types::Standard qw(:all);

our $VERSION = '0.01';

use XSLoader;

XSLoader::load('RapidApp::Util::XS::DetectAbortReqest', $RapidApp::Util::XS::DetectAbortReqest::VERSION);

has 'fh',             is => 'ro', isa => Maybe[InstanceOf['IO::Handle']], default => sub { undef };
has 'signal',         is => 'ro', isa => Str, default => sub { 'USR1' };
has 'watch_interval', is => 'ro', isa => Maybe[Int], default => sub { 1 };

has '_started', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;

sub BUILD {
  my $self = shift;
  
  die "fh and watch_interval cannpt both be set - it is one or the other" if (
    $self->fh && $self->watch_interval
  );
  
  die "Must set either fh or watch_interval" unless (
    $self->fh || $self->watch_interval
  );
  
  if (my $int = $self->watch_interval) {
    $int > 0 or die "watch_interval (seconds) must be an integer greater than zero";
  }
}


sub start {
  my $self = shift;
  $self->_started and die "already started";
  
  if(my $int = $self->watch_interval) {
    start_disconnect_watcher_timer($self->signal, $int);
  }
  else {
    start_disconnect_watcher_io($self->fh, $self->signal);
  }
  $self->_started(1);
}

sub stop {
  my $self = shift;
  $self->_started or die "not started";
  stop_disconnect_watcher();
  $self->_started(0);
  1
}

sub DESTROY {
  my $self = shift;
  $self->stop if $self->_started;
}


1;