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
        Access => $self->Access,
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
  
  $self->Access->template_viewable($template)
    or die "Permission denied - template '$template'";
  #  or return $self->_detach_response($c,403,"Permission denied - template '$template'");
  
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
  
  return $self->_detach_response($c,200,$output,$content_type);
}


# Read (not compiled/rendered) raw templates:
sub get :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_readable($template)
    or return $self->_detach_response($c,403,"Permission denied - template '$template'");
  
  my ($data, $error) = $self->get_Provider->load($template);
  
  return $self->_detach_response($c,200,$data);
}

# Update raw templates:
sub set :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  exists $c->req->params->{content}
    or return $self->_detach_response($c,400,"Template 'content' required");
  
  $self->Access->template_writable($template)
    or return $self->_detach_response($c,403,"Modify template '$template' - Permission denied");
  
  my $content = $c->req->params->{content};
  
  # Special status 418 means the supplied content is a bad template
  unless ($c->req->params->{skip_validate}) {
    my $err = $self->_get_template_error('Template_raw',\$content,$c);
    return $self->_detach_response($c,418,$err) if ($err);
  }
  
  $self->get_Provider->update_template($template,$content);
  
  return $self->_detach_response($c,200,'Template Updated');
}

sub create :Local {
  my ($self, $c, @args) = @_;
  my $template = join('/',@args);
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_creatable($template)
    or return $self->_detach_response($c,403,"Create template '$template' - Permission denied");
  
  my $Provider = $self->get_Provider;
  
  die "Create template '$template' - already exists" 
    if $Provider->template_exists($template);
  
  $Provider->create_template($template)
    or die "Failed to create template '$template'";

  return $self->_detach_response($c,200,"Created template '$template'");
}

sub _detach_response {
  my ($self, $c, $status, $body, $content_type) = @_;
  $content_type ||= 'text/plain; charset=utf-8';
  $c->response->content_type($content_type);
  $c->response->status($status);
  $c->response->body($body);
  return $c->detach;
}

sub _get_template_vars {
  my ($self, $c) = @_;
  return { c => $c }
}

sub _render_template {
  my ($self, $meth, $template, $c) = @_;
  
  my $TT = $self->$meth;
  my $vars = $self->_get_template_vars($c);
  my $output;
  
  # If there are errors in the template, it might be caused by
  # errors within a sub template rather than the top-level
  # template. In this case, we want to find the actual offender
  # and render it inline. Normally the Provider has no idea if
  # a template has errors or not, however, the machinery for
  # wrapping/replacing templates is located within the extended
  # Provider class. Also, we don't want to have the Provider
  # compile/check the template automatically because, besides the
  # deep recursion issue, this would be a big performance hit
  # because every template would always have to be compiled twice...
  #
  # To reconcile this, what we do here is first try to process the
  # template normally, and *if* (and only if) it fails do we turn
  # on the "pre_validate" functionality within the Provider by
  # localizing a hash key (template_pre_validate) that the Provider
  # looks for and uses to pre_validate the template. This enables
  # the Provider to replace only the template(s) with errors with
  # a pretty message, and not have the expense of the extra 
  # validation when it's not needed (the case most of the time).
  unless ( $TT->process($template,$vars,\$output) ) {
    die $TT->error if ($self->{template_pre_validate});
    local $self->{template_pre_validate} = sub {
      my $tpl = shift;
      return $self->_get_template_error($meth,$tpl,$c);
    };
    return $self->_render_template($meth,$template,$c);
  }
  
  return $output;
}

# Returns undef if the template is valid or the error
sub _get_template_error {
  my ($self, $meth, $template, $c) = @_;
  my $TT = $self->$meth;
  my $vars = $self->_get_template_vars($c);
  my $output;
  return $TT->process( $template, $vars, \$output ) ? undef : $TT->error;
}


1;