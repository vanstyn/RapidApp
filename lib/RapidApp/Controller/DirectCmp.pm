package RapidApp::Controller::DirectCmp;

use strict;
use warnings;

use Moose;
BEGIN { extends 'Catalyst::Controller'; }
use namespace::autoclean;

use RapidApp::Util qw(:all);

sub base :Chained :PathPrefix :CaptureArgs(0) {}

# This is a special controller designed to render a single RapidApp 
# Module in its own Viewport (i.e. in an iFrame)

sub default :Chained('base') :PathPart('') :Args {
  my ($self, $c, @args) = @_;
  # Fallback to 'direct'
  return $self->direct($c,@args);
}

sub direct :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  $c->stash->{render_viewport} = 1;
  $self->_redispatch_viewport($c,@args)
}

sub printview :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  $c->stash->{render_viewport} = 'printview';
  $self->_redispatch_viewport($c,@args)
}

sub navable :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  $c->stash->{render_viewport} = 'navable';
  $self->_redispatch_viewport($c,@args)
}

sub _redispatch_viewport {
  my ($self, $c, @args) = @_;

  $c->stash->{config_url}    = join('/','',@args);
  $c->stash->{config_params} = { %{$c->req->params} };

  $c->req->params->{__no_hashnav_redirect} = 1;
  
  return $c->redispatch_public_path(@args);
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;
