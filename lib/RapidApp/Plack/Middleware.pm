package RapidApp::Plack::Middleware;
use parent 'Plack::Middleware';

use strict;
use warnings;

# ABSTRACT: Default Middleware for RapidApp

use RapidApp::Util qw(:all);

sub call {
  my ($self, $env) = @_;

  # RapidApp currently doesn't like PATH_INFO of ""
  $env->{PATH_INFO} ||= '/';

  # --- GitHub Issue #153
  # New: handing for magic path keyword '_ra-rel-mnt_' ("RapidApp Relative Mount")
  #
  # If the now reserved keyword/string '/_ra-rel-mnt_/' appears anyplace
  # in the path, we munge it and strip everything in the path *up to
  # that point*. The reason this is being done is to provide an
  # efficient mechanism for generated markups such as <img> 'src', css
  # urls, <link> tags, etc, to reference paths (such as simplecas and
  # asset urls) w/o needing to know the current mount_url and, more
  # importantly, be able to remain valid if the mount_url is changed
  # after the fact. This is essentially a means to supply an absolute
  # url path but the form of a *relative* url path from the perspective
  # of the browser. This is a better way to handle this case than from
  # within the module dispatch because it avoids the associated
  # unnecessary overhead (which can vary from module to module) and is
  # also even more flexible, to also work via locally-defined controller
  # actions which internally re-dispatch to modules.
  my $keyword = '_ra-rel-mnt_';
  if($env->{PATH_INFO} =~ /\/\Q${keyword}\E\//) {
    my @parts = split(/\/\Q${keyword}\E\//,$env->{PATH_INFO});
    $env->{PATH_INFO} = '/' . pop(@parts);
  }
  # ---

  # FIXME: RapidApp applies logic based on uri in places,
  # so we need it to match PATH_INFO
  $env->{REQUEST_URI} = $env->{PATH_INFO};

  $self->app->($env)
}


1;
