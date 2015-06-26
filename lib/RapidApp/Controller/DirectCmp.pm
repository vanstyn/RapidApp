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

  $c->req->params->{__no_hashnav_redirect} = 1;
  $c->stash->{render_viewport} = 1;

  return $c->redispatch_public_path(@args);
}

sub printview :Chained('base') :Args {
  my ($self, $c, @args) = @_;

  $c->req->params->{__no_hashnav_redirect} = 1;
  $c->stash->{render_viewport} = 'printview';

  return $c->redispatch_public_path(@args);
}

sub navable :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  
  # Render a tabpanel *only* if the path end-point is a module:
  if( try{$c->rapidApp->rootModule->get_Module(join('/',@args))} ) {
    # Return a one-off AppTab with a tab pointing to the supplied module 
    # url/path. This will allow any hashnav links inside the module's
    # content to function as expected, loading as additional tabs
    $c->stash->{panel_cfg} = {
      xtype => 'apptabpanel',
      id => 'main-load-target',
      initLoadTabs => [{
        closable => \0,
        autoLoad => {
          url => join('/','',@args),
          params => $c->req->params
        }
      }]
    };
    return $c->detach( $c->view('RapidApp::Viewport') );
  }
  else {
    # The path isn't a module end-point, but still redirect into the dispatcher from
    # here so that sub-path actions and special relative urls (like assets, etc) 
    # still work as expected, in the same manner as 'direct' above:
    return $c->redispatch_public_path(@args);
  }
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
