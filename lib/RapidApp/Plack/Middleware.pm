package RapidApp::Plack::Middleware;
use parent 'Plack::Middleware';

use strict;
use warnings;

# ABSTRACT: Default Middleware for RapidApp

use RapidApp::Include qw(sugar perlutil);

sub call {
  my ($self, $env) = @_;
  
  # RapidApp currently doesn't like PATH_INFO of ""
  $env->{PATH_INFO} ||= '/';
  
  # FIXME: RapidApp applies logic based on uri in places, 
  # so we need it to match PATH_INFO
  $env->{REQUEST_URI} = $env->{PATH_INFO};
  
  $self->app->($env)
}


1;