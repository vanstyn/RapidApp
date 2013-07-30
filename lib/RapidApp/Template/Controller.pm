package RapidApp::Template::Controller;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);
use Try::Tiny;
use Template;
use Module::Runtime;
use Path::Class qw(file dir);
use URI::Escape;

# New unified controller for displaying and editing TT templates on a site-wide
# basis. This is an experiment that breaks with the previous RapidApp 'Module'
# design. It also is breaking away from DataStore2 for editing in order to support
# nested templates (i.e. tree structure instead of table/row structure)

use Moose;
with 'RapidApp::Role::AuthController';
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::Template::Context;
use RapidApp::Template::Provider;
use RapidApp::Template::Access;

has 'context_class', is => 'ro', default => 'RapidApp::Template::Context';
has 'provider_class', is => 'ro', default => 'RapidApp::Template::Provider';
has 'access_class', is => 'ro', default => 'RapidApp::Template::Access';
has 'access_params', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'default_template_extension', is => 'ro', isa => 'Maybe[Str]', default => 'tt';

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
  Module::Runtime::require_module($self->context_class);
  Module::Runtime::require_module($self->provider_class);
  return Template->new({ 
    CONTEXT => $self->context_class->new({
      Controller => $self,
      Access => $self->Access,
      # TODO: turn STRICT back on once I figure out how to make the errors useful:
      #STRICT => 1,
      LOAD_TEMPLATES => [
        $self->provider_class->new({
          Controller => $self,
          Access => $self->Access,
          #INCLUDE_PATH => $self->_app->default_tt_include_path,
          INCLUDE_PATH => [
            dir($self->_app->config->{home},'root/templates')->stringify,
            dir(RapidApp->share_dir,'templates')->stringify
          ],
          CACHE_SIZE => 64,
          %{ $opt || {} }
        })
      ] 
    })
  })
}

# hook for RapidApp::Role::AuthController:
# abort enforce_session for 'external' templates being accessed externally:
around 'enforce_rapidapp_session' => sub {
  my ( $orig, $self, $c, @args ) = @_;
  my $template = join('/',@{$c->req->args});
  return $self->$orig($c,@args) unless (
    ! $c->req->header('X-RapidApp-RequestContentType')
    && $self->is_external_template($c,$template)
  );
};

sub get_Provider {
  my $self = shift;
  return $self->Template_raw->context->{LOAD_TEMPLATES}->[0];
}

# request lifetime cached:
sub _template_exists {
  my ($self, $c, $template) = @_;
  die "missing template arg" unless ($template);
  $c->stash->{_template_exists}{$template} = 
    $self->get_Provider->template_exists($template)
      unless (exists $c->stash->{_template_exists}{$template});
  return $c->stash->{_template_exists}{$template};
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

sub is_iframe_request {
  my ($self, $c) = @_;
  
  return (
    $c->req->params->{iframe} || 
    $c->stash->{iframe}
  );
}

# request lifetime cached:
sub is_external_template {
  my ($self, $c, $template) = @_;
  die "missing template arg" unless ($template);
  
  $c->stash->{is_external_template}{$template} = do {
  # Allow params/stash override:
    return $c->req->params->{external} if (exists $c->req->params->{external});
    return $c->stash->{external} if (exists $c->stash->{external});
    
    my $external = (
      # hard-coded external templates:
      $template =~ /^rapidapp\/public\// ||
      $self->Access->template_external_tpl($template)
    ) ? 1 : 0;

    return (
      $external &&
      # don't treat non-existing templates as external
      $self->_template_exists($c,$template)
    ) ? 1 : 0;
  } unless (exists $c->stash->{is_external_template}{$template});
  
  return $c->stash->{is_external_template}{$template};
}


## -----
## Top level alias URL paths 
#   TODO: add these programatically via config
#   see register_action_methods()
sub tpl :Path('/tpl') {
  my ($self, $c) = @_;
  $c->forward('view');
}

# Edit alias
sub tple :Path('/tple') {
  my ($self, $c) = @_;
  $c->stash->{editable} = 1;
  $c->forward('view');
}
## -----

sub _resolve_template_name {
  my ($self, @args) = @_;
  return undef unless (defined $args[0]);
  my $template = join('/',@args); 
  
  $template .= '.' . $self->default_template_extension if (
    $self->default_template_extension &&
    ! ( $template =~ /\./ ) #<-- doesn't contain a dot '.'
  );
  
  return $template;
}



# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Local {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
    
  local $self->{_current_context} = $c;
  
  $self->Access->template_viewable($template)
    or die "Permission denied - template '$template'";

  my $external = $self->is_external_template($c,$template);
  my $iframe = $external || $self->is_iframe_request($c); # <-- external must use iframe
  my $editable = $self->is_editable_request($c);
  
  my ($output,$content_type);
  
  my $ra_req = $c->req->header('X-RapidApp-RequestContentType');
  if($ra_req && $ra_req eq 'JSON') {
    # This is a call from within ExtJS, wrap divs to id the templates from javascript
    
    my $cnf = {};
    
    if($iframe) {
      # This is an iframe request. Build an iframe panel which will make the request 
      # again but without the X-RapidApp-RequestContentType header which will be 
      # handled as a direct browser request (see logic further down)
      
      my %params = ( %{$c->req->params}, editable => $editable, iframe => 1 );
      my $qs = join('&',map { $_ . '=' . uri_escape($params{$_}) } keys %params);
      my $iframe_src = join('/','',$self->action_namespace($c),'view',$template) . '?' . $qs;

      $cnf = {
        xtype => 'iframepanel',
        plugins => ['ra-link-click-catcher'],
        tabTitle => join('',
          '<span style="color:purple;">',
            '[' . join('/',@args) . ']', #<-- not using $template to preserve the orig req name
          '</span>'
        ),
        tabIconCls => 'ra-icon-page-white',
        style => 'top: 0; left: 0; bottom: 0; right: 0;',
        autoScroll => \1,
        bodyStyle => 'border: 1px solid #D0D0D0;background-color:white;',
        loadMask => \1,
        defaultSrc => $iframe_src
      };
    }
    else {
    
      my $html = $self->_render_template(
        $editable ? 'Template_wrap' : 'Template_raw',
        $template, $c
      );
    
      $cnf = {
        xtype => 'panel',
        autoScroll => \1,
        bodyCssClass => 'ra-scoped-reset',
        
        # try to set the title/icon by finding/parsing <title> in the 'html'
        autopanel_parse_title => \1,
        
        # These will only be the title/icon if there is no parsable <title>
        tabTitle => join('/',@args), #<-- not using $template to preserve the orig req name
        tabIconCls => 'ra-icon-page-white-world',
        
        html => $html
      };
    }
    
    # No reason to load the plugin unless we're editable:
    if ($editable) {
      $cnf->{plugins} ||= [];
      push @{$cnf->{plugins}}, 'template-controller-panel';
      $cnf->{template_controller_url} = '/' . $self->action_namespace($c);
    }
    
    # This is doing the same thing that the overly complex 'Module' controller does:
    $content_type = 'text/javascript; charset=utf-8';
    $output = encode_json_utf8($cnf);
  }
  else {
    # This is a direct browser call:
    
    my $html = $self->_render_template(
      $editable ? 'Template_wrap' : 'Template_raw',
      $template, $c
    );
    
    my @head = ();
    
    # If we're in an iframe tab, we want to make sure we set the base target
    # to prevent the chance of trying to load a link inside the frame (even
    # though local links are already hanlded/converted - we still need to
    # protect against external/global links).
    push @head, '<base target="_blank" />' if $iframe;
    
    if($external) {
      # We still need to include CSS for template edit controls, if we're editable:
      # TODO: basically including everything but ExtJS CSS. This is ugly and should
      # be generalized/available in the Asset system as a simpler function call:
      push @head, (
        $c->controller('Assets::RapidApp::CSS')->html_head_tags,
        $c->controller('Assets::RapidApp::Icons')->html_head_tags,
        $c->controller('Assets::ExtJS')->html_head_tags( js => [
          'adapter/ext/ext-base.js',
          'ext-all-debug.js',
          'src/debug.js'
        ]),
        $c->controller('Assets::RapidApp::JS')->html_head_tags
      ) if $editable;
    }
    else {
      # Include all the ExtJS, RapidApp and local app CSS/JS
      push @head, $c->all_html_head_tags;
    }
    
    # Only include the RapidApp/ExtJS assets and wrap 'ra-scoped-reset' if
    # this is *not* an external template:
    $output = $external ? join("\n",@head,$html) : join("\n",
      '<head>', @head, '</head>',
      '<div class="ra-scoped-reset">', $html, '</div>'
    );
    
    $content_type = 'text/html; charset=utf-8';
  }
  
  return $self->_detach_response($c,200,$output,$content_type);
}


# Read (not compiled/rendered) raw templates:
sub get :Local {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_readable($template)
    or return $self->_detach_response($c,403,"Permission denied - template '$template'");
  
  my ($data, $error) = $self->get_Provider->load($template);
  
  return $self->_detach_response($c,200,$data);
}

# Update raw templates:
sub set :Local {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
  
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
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_creatable($template)
    or return $self->_detach_response($c,403,"Create template '$template' - Permission denied");
  
  die "Create template '$template' - already exists" 
    if $self->_template_exists($c,$template);
  
  $self->get_Provider->create_template($template)
    or die "Failed to create template '$template'";

  return $self->_detach_response($c,200,"Created template '$template'");
}

sub delete :Local {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_deletable($template)
    or return $self->_detach_response($c,403,"Delete template '$template' - Permission denied");
  
  die "Delete template '$template' - doesn't exists" 
    unless $self->_template_exists($c,$template);;
  
  $self->get_Provider->delete_template($template)
    or die "Failed to delete template '$template'";

  return $self->_detach_response($c,200,"Deleted template '$template'");
}

sub _detach_response {
  my ($self, $c, $status, $body, $content_type) = @_;
  $content_type ||= 'text/plain; charset=utf-8';
  $c->response->content_type($content_type);
  $c->response->status($status);
  $c->response->body($body);
  return $c->detach;
}

sub _render_template {
  my ($self, $meth, $template, $c) = @_;
  
  my $TT = $self->$meth;
  local $self->{_current_context} = $c;
  local $self->{_div_wrap} = 1 if ($meth eq 'Template_wrap');
  my $vars = $self->Access->get_template_vars($template);
  my $output;
  
  # TODO/FIXME: this is duplicate logic that has to be handled for the
  # top-level template which doesn't seem to go through process() in Context:
  $output = $self->Template_raw->context->_template_error_content(
    $template, $TT->error, (
      $self->is_editable_request($c) &&
      $self->Access->template_writable($template)
    )
  ) unless $TT->process( $template, $vars, \$output );
  
  return $output;
}

# Returns undef if the template is valid or the error
sub _get_template_error {
  my ($self, $meth, $template, $c) = @_;
  my $TT = $self->$meth;
  local $self->{_current_context} = $c;
  local $self->{_div_wrap} = 1 if ($meth eq 'Template_wrap');
  my $vars = $self->Access->get_template_vars($template);
  my $output;
  return $TT->process( $template, $vars, \$output ) ? undef : $TT->error;
}


1;