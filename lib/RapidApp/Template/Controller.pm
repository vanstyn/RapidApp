package RapidApp::Template::Controller;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);
use Try::Tiny;
use Template;
use Module::Runtime;

# New unified controller for displaying and editing TT templates on a site-wide
# basis. This is an experiment that breaks with the previous RapidApp 'Module'
# design. It also is breaking away from DataStore2 for editing in order to support
# nested templates (i.e. tree structure instead of table/row structure)

use Moose;
with 'RapidApp::Role::AuthController';
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

has 'provider_class', is => 'ro', default => 'RapidApp::Template::Provider';
has 'access_class', is => 'ro', default => 'RapidApp::Template::Access';
has 'access_params', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'Access', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  Module::Runtime::require_module($self->access_class);
  return $self->access_class->new({ 
    %{ $self->access_params },
    Controller => $self 
  });
}, isa => 'RapidApp::Template::Access';


# Maintain two separate Template instances - one that wraps divs and one that
# doesn't. Can't use the same one because compiled templates are cached
has 'Template_raw', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->_new_Template({ div_wrap => 0 });
}, isa => 'Template';

has 'Template_wrap', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return $self->_new_Template({ div_wrap => 1 });
}, isa => 'Template';

sub _new_Template {
  my ($self,$opt) = @_;
  Module::Runtime::require_module($self->provider_class);
  return Template->new({ 
    LOAD_TEMPLATES => [
      $self->provider_class->new({
        Controller => $self,
        INCLUDE_PATH => $self->_app->default_tt_include_path,
        CACHE_SIZE => 64,
        %{ $opt || {} }
      })
    ] 
  });
}

sub get_Provider {
  my $self = shift;
  return $self->Template_raw->context->{LOAD_TEMPLATES}->[0];
}

# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  die "Permission denied - template '$template'" 
    unless $self->Access->template_readable($template);
  
  my ($output,$content_type);
  
  my $ra_req = $c->req->headers->{'x-rapidapp-requestcontenttype'};
  if($ra_req && $ra_req eq 'JSON') {
    # This is a call from within ExtJS, wrap divs to id the templates from javascript
    my $html = $self->_render_template('Template_wrap',$template,$c);
    
    # This is doing the same thing that the overly complex 'Module' controller does:
    $content_type = 'text/javascript; charset=utf-8';
    $output = encode_json_utf8({
      xtype => 'panel',
      autoScroll => \1,
      autopanel_parse_title => \1,
      plugins => ['template-controller-panel'],
      template_controller_url => '/' . $self->action_namespace($c),
      html => $html
    });
  }
  else {
    # This is a direct browser call, need to include js/css
    my $text = join("\n",
      '<head>[% c.all_html_head_tags %]</head>',
      '[% INCLUDE ' . $template . ' %]',
    );
    $content_type = 'text/html; charset=utf-8';
    $output = $self->_render_template('Template_raw',\$text,$c);
  }
  
  $c->response->content_type($content_type);
  $c->response->body($output);
  return $c->detach;
}


# Read (not compiled/rendered) raw templates:
sub get :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  die "Permission denied - template '$template'" 
    unless $self->Access->template_readable($template);
  
  my ($data, $error) = $self->get_Provider->load($template);
  
  $c->response->content_type('text/plain charset=utf-8');
  $c->response->body($data);
  return $c->detach;
}

# Update raw templates:
sub set :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  $c->response->content_type('text/plain charset=utf-8');
  my $content = $c->req->params->{content};
  
  # TODO: handle invalid template exceptions differently than 
  # permission/general exceptions:
  try {
    die "Modify template '$template' - Permission denied" 
      unless $self->Access->template_writable($template);
    
    # Test that the template is valid:
    $self->_render_template('Template_raw',\$content,$c);
    
    # Update the template (note that this is beyond the normal Template::Provider API)
    $self->get_Provider->update_template($template,$content);
  }
  catch {
    # Send back the template error:
    $c->response->status(500);
    $c->response->body("$_");
    return $c->detach;
  };
  
  $c->response->body('Updated');
  return $c->detach;
}



sub _render_template {
  my ($self, $meth, $template, $c) = @_;
  
  my $TT = $self->$meth;
  my $vars = { c => $c };
  
  my $output;
  $TT->process( $template, $vars, \$output )
    or die $TT->error;

  return $output;
}


1;