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

use RapidApp::Template::Provider;
use RapidApp::Template::Access;

has 'provider_class', is => 'ro', default => 'RapidApp::Template::Provider';
has 'access_class', is => 'ro', default => 'RapidApp::Template::Access';
has 'access_params', is => 'ro', isa => 'HashRef', default => sub {{}};

# If true, mouse-over edit controls will always be available for editable
# templates. Otherwise, query string ?editable=1 is required. Note that
# editable controls are *only* available in the context of an AutoPanel tab
has 'auto_editable', is => 'ro', isa => 'Bool', default => 0;

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

# Checks if the editable toggle/switch is on for this request. Note that
# this has *nothing* to do with actual editability of a given template,
# just whether or not edit controls should be available for templates that
# are allowed to be edited
sub is_editable_request {
  my ($self, $c) = @_;
  
  # check several mechanisms to turn on editing (mouse-over edit controls)
  return (
    $self->auto_editable ||
    $c->req->params->{editable} || 
    $c->req->params->{edit} ||
    $c->stash->{editable}
  );
}

# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  die "Permission denied - template '$template'" 
    unless $self->Access->template_viewable($template);
  
  my $editable = $self->is_editable_request($c);
  
  my ($output,$content_type);
  
  my $ra_req = $c->req->headers->{'x-rapidapp-requestcontenttype'};
  if($ra_req && $ra_req eq 'JSON') {
    # This is a call from within ExtJS, wrap divs to id the templates from javascript
    my $html = $self->_render_template(
      $editable ? 'Template_wrap' : 'Template_raw',
      $template, $c
    );
    
    my $cnf = {
      xtype => 'panel',
      autoScroll => \1,
      
      # try to set the title/icon by finding/parsing <title> in the 'html'
      autopanel_parse_title => \1,
      
      # These will only be the title/icon if there is no parsable <title>
      tabTitle => $template,
      tabIconCls => 'icon-page-white-world',
      
      template_controller_url => '/' . $self->action_namespace($c),
      html => $html
    };
    
    # No reason to load the plugin unless we're editable:
    $cnf->{plugins} = ['template-controller-panel'] if ($editable);
    
    # This is doing the same thing that the overly complex 'Module' controller does:
    $content_type = 'text/javascript; charset=utf-8';
    $output = encode_json_utf8($cnf);
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
  
  $c->response->content_type('text/plain; charset=utf-8');
  $c->response->body($data);
  return $c->detach;
}

# Update raw templates:
sub set :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  $c->response->content_type('text/plain; charset=utf-8');
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


sub create :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  $c->response->content_type('text/plain; charset=utf-8');
  
  die "Create template '$template' - Permission denied" 
    unless $self->Access->template_creatable($template);
  
  my $Provider = $self->get_Provider;
  
  die "Create template '$template' - already exists" 
    if $Provider->template_exists($template);
  
  $Provider->create_template($template)
    or die "Failed to create template '$template'";

  $c->response->body("Created template '$template'");
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