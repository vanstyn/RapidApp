package RapidApp::Controller::DirectCmp;

use strict;
use warnings;

use Moose;
BEGIN { extends 'Catalyst::Controller'; }
use namespace::autoclean;

use RapidApp::Util qw(:all);

# This is a special controller designed to render a single RapidApp 
# Module in its own Viewport (i.e. in an iFrame)

sub default :Path {
  my ($self, $c, @args) = @_;
  # Fallback to 'direct'
  return $self->direct($c,@args);
}

sub direct :Local {
  my ($self, $c, @args) = @_;

  $c->req->params->{__no_hashnav_redirect} = 1;
  $c->stash->{render_viewport} = 1;

  return $c->redispatch_public_path(@args);
}

sub printview :Local {
  my ($self, $c, @args) = @_;

  $c->req->params->{__no_hashnav_redirect} = 1;
  $c->stash->{render_viewport} = 'printview';

  return $c->redispatch_public_path(@args);
}

sub navable :Local {
  my ($self, $c, @args) = @_;
  
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


no Moose;
__PACKAGE__->meta->make_immutable;
1;
