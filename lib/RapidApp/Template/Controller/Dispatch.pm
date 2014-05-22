package RapidApp::Template::Controller::Dispatch;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

use Moose;
use namespace::autoclean;

# This is the dispatch controller which maps public URL requests
# to the actual Template Controller. It is mounted at the root 
# of the application if the root module isn't, otherwise, it is
# called by the root module via shortcut method
#  $c->template_dispatcher->default($c,@path) where @path is a 
# *public* template path that is mapped into a real template path

BEGIN { extends 'Catalyst::Controller' }

before 'COMPONENT' => sub {
  my $class = shift;
  my $app_class = ref $_[0] || $_[0];
  
  my $cnf = $app_class->config->{'Model::RapidApp'} || {};
  
  # Claim the root namespace if the root module controller has 
  # been setup at a different namespace
  $class->config( namespace => '' ) if (
    $cnf->{module_root_namespace} &&
    $cnf->{module_root_namespace} ne ''
  );

  $class->config( 
    root_template        => $cnf->{root_template} || 'rapidapp/default_root_template.html',
    root_template_prefix => $cnf->{root_template_prefix}
  );
};


sub default :Path {
  my ($self, $c, @args) = @_;

  my $cfg = $self->config;
  
  # root '/' request:
  if(scalar @args == 0) {
    die "root_template not defined" unless ($cfg->{root_template});
    @args = ($cfg->{root_template});
  }
  else {
    die "No root_template_prefix defined" unless ($cfg->{root_template_prefix});
    @args = ($cfg->{root_template_prefix},@args)
  }
  
  $c->stash->{editable} = 1; # <-- Enable template editing (if has perms)
  my $template = join('/',@args);
  $template =~ s/\/+/\//g; #<-- strip any double //
  return $c->template_controller->view($c, $template);
}



1;