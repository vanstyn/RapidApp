package RapidApp::Template::Controller;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

# New unified controller for displaying and editing TT templates on a site-wide
# basis. This is an experiment that breaks with the previous RapidApp 'Module'
# design. It also is breaking away from DataStore2 for editing nested templates

use Moose;
use namespace::autoclean;

use Template;
use RapidApp::Template::Provider;

BEGIN { extends 'Catalyst::Controller' }

has 'Provider', is => 'ro', isa => 'Template::Provider', lazy => 1, default => sub {
  my $self = shift;
  my $c = $self->_app;
  return RapidApp::Template::Provider->new({
    INCLUDE_PATH => $c->default_tt_include_path,
    CACHE_SIZE => 64,
  });
};

has 'Template', is => 'ro', isa => 'Template', lazy => 1, default => sub {
  my $self = shift;
  return Template->new({ LOAD_TEMPLATES => [$self->Provider] });
};

# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Local {
  my ($self, $c, @args) = @_;
  
  my $template = join('/',@args);
  my $vars = { c => $c };
  my $output = $self->_render_template($template,$vars);
  
  $c->response->content_type('text/html; charset=utf-8');
  $c->response->body($output);

  return $c->detach;
}


sub _render_template {
  my ($self, $template, $vars, $opts) = @_;
  $opts ||= {};
  
  my $output;
  $self->Template->process( $template, $vars, \$output )
    or die $self->Template->error;

  return $output;
}

1;