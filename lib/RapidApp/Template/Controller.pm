package RapidApp::Template::Controller;
use strict;
use warnings;

use RapidApp::Util qw(:all);
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

## -----
## Setup Top-level alias URL paths:
has 'read_alias_path', is => 'ro', default => '/tpl';
has 'edit_alias_path', is => 'ro', default => '/tple';

sub BUILD {
  my $self = shift;
  
  my $c = $self->_app;
  my $ns = $self->action_namespace($c);
  
  if($self->read_alias_path) {
    my $path = $self->read_alias_path;
    $path =~ s/^\///;

    $c->dispatcher->register( $c => Catalyst::Action->new({
      name      => 'tpl',
      code      => $self->can('tpl'),
      class     => $self->meta->name,
      namespace => $ns,
      reverse   => join('/',$ns,'tpl'),
      attributes => {
        Chained    => ['/'],
        PathPrefix => [''],
      }
    }));
  }
  
  if($self->edit_alias_path) {
    my $path = $self->edit_alias_path;
    $path =~ s/^\///;
    $c->dispatcher->register( $c => Catalyst::Action->new({
      name      => 'tple',
      code      => $self->can('tple'),
      class     => $self->meta->name,
      namespace => $ns,
      reverse   => join('/',$ns,'tple'),
      attributes => {
        Chained    => ['/'],
        PathPrefix => [''],
      }
    }));
  }
}



sub tpl_path {
  my $self = shift;
  # Return the edit alias patgh first or fall back to the read alias:
  return $self->edit_alias_path || $self->read_alias_path;
}
## -----


has 'context_class', is => 'ro', default => 'RapidApp::Template::Context';
has 'provider_class', is => 'ro', default => 'RapidApp::Template::Provider';
has 'access_class', is => 'ro', default => 'RapidApp::Template::Access';
has 'access_params', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'include_paths', is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]};
has 'store_class', is => 'ro',  default => sub {undef}; # Will be 'RapidApp::Template::Store' if undef
has 'store_params', is => 'ro', default => sub {undef};


# -- 
# Only these TT plugins and filters will be allowed in Templates
# This is *very* important for security if non-admin users will
# have access to modify templates. These templates and filters
# are from the built-in list and are known to be safe. Examples
# of unsafe plugins are things like 'Datafile' and 'DBI', and
# examples of unsafe filters are things like 'eval', 'redirect', etc.
# It is critical that these types of things are never exposed
# to web interfaces. It is also important to note that TT was
# not originally designed with "limited" access in mind - it was
# only meant to be used by the programmer, not users. In hindsight,
# it might have been better to go with Text::Xslate for this reason
#
# (note: these get accessed/used within RapidApp::Template::Context)
has 'allowed_plugins', is => 'ro', default => sub {[qw(
  Assert Date Dumper Format HTML Iterator 
  Scalar String Table URL Wrap
)]}, isa => 'ArrayRef';

has 'allowed_filters', is => 'ro', default => sub {[qw(
  format upper lower ucfirst lcfirst trim collapse 
  html html_entity xml html_para html_break 
  html_para_break html_line_break uri url indent 
  truncate repeat remove replace null
)]}, isa => 'ArrayRef';
# --

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
          store_class  => $self->store_class,
          store_params => $self->store_params,
          #INCLUDE_PATH => $self->_app->default_tt_include_path,
          INCLUDE_PATH => [
            map { dir($_)->stringify } @{ $self->include_paths },
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
  
  # Never editable externally, unless this is an iframe request
  return 0 unless (
    $c->req->header('X-RapidApp-RequestContentType') ||
    (exists $c->req->params->{iframe} && $c->req->params->{iframe} eq 'request')
  );
  
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

sub base :Chained :PathPrefix :CaptureArgs(0) {}

# -------
# direct/navable dispatch to match the same pattern as Module DirectCmp
#
# We now have 'direct' and 'navable' controller actions to that the following
# URL paths will behave is a consistent manner:
#
#  /rapidapp/module/direct/<module_path>
#  /rapidapp/template/direct/tple/<template_path>
#
# We are simulating module viewport content with a simple autopanel cfg so
# that a template can be rendered full-screen with the same functionality
# as it has when rendered in a TabGui tab
sub _validate_args_template_viewable {
  my ($self, @args) = @_;
  my $template = $self->_resolve_template_name(@args);
  $self->get_Provider->template_exists($template)
}

sub _validate_enforce_arguments_path {
  my ($self, $c, @args) = @_;
  
  shift @args if ($args[0] eq 'tpl' || $args[0] eq 'tple');
  return 1 if ($self->_validate_args_template_viewable(@args));
  
  my @pre_args = ();
  while(scalar(@args) > 1) {
    
    push @pre_args, shift @args;
    
    # Special handling for relative requests to special/reserved controller paths.
    # this is based on the same logic/rules as in RapidApp::Module
    $c->redispatch_public_path($c->mount_url,@args) && $c->detach if (
      $self->_validate_args_template_viewable(@pre_args) && (
           $args[0] eq 'simplecas'
        || $args[0] eq 'assets'
        || $args[0] eq 'rapidapp'
      )
    );
  }
  
  $c->stash->{template} = 'rapidapp/http-404.html';
  $c->stash->{current_view} = 'RapidApp::Template';
  $c->res->status(404);
  return $c->detach;
}

sub direct :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  
  $self->_validate_enforce_arguments_path($c,@args);
  
  $c->stash->{panel_cfg} = {
    xtype => 'autopanel',
    layout => 'fit',
    autoLoad => {
      url => join('/','',@args),
      params => $c->req->params
    }
  };
  
  return $c->detach( $c->view('RapidApp::Viewport') );
}

sub navable :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  $self->_validate_enforce_arguments_path($c,@args);
  return $c->controller('RapidApp::Module')->navable($c,@args);
}
# --------

sub tpl :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  $self->view($c,@args)
}

# Edit alias
sub tple :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  
  $c->stash->{editable} = 1;
  $self->view($c,@args)
}

# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
    
  local $self->Access->{_local_cache} = {};
    
  if(my $psgi_response = $self->Access->template_psgi_response($template,$c)) {
    $c->res->from_psgi_response( $psgi_response );
    return $c->detach;
  }

  my $ra_client = $c->is_ra_ajax_req;

  # Honor the existing status, if set, except for Ajax requests
  my $status = $c->res->status || 200;
  $status = 200 if ($ra_client);

  local $self->{_current_context} = $c;
  
  # Track the top-level template that is being viewed, in case the Access class
  # wants to treat top-level templates differently from nested templates
  #   -- see currently_viewing_template() in RapidApp::Template::Access
  local $self->{_viewing_template} = $template;
  
  $self->Access->template_viewable($template)
    or die "Permission denied - template '$template'";

  my $external = $self->is_external_template($c,$template);
  my $editable = $self->is_editable_request($c);
 
  # ---
  # New: for non-external templates which are being accessed externally, 
  # (i.e. directly from browser) redirect to internal hashnav path:
  unless ($external || $ra_client) {
    return $c->auto_hashnav_redirect_current;
  }
  #---
  
  my $iframe = $external || $self->is_iframe_request($c); # <-- external must use iframe
  my ($output,$content_type);
  
  $content_type = $self->Access->template_content_type($template);
  
  my @cls = ('ra-scoped-reset');
  my $tpl_cls = $self->Access->template_css_class($template);
  push @cls, $tpl_cls if ($tpl_cls);
  
  if($ra_client) {
    # This is a call from within ExtJS, wrap divs to id the templates from javascript
    
    my $cnf = {};
    
    if($iframe) {
      # This is an iframe request. Build an iframe panel which will make the request 
      # again but without the X-RapidApp-RequestContentType header which will be 
      # handled as a direct browser request (see logic further down)
      
      my %params = ( %{$c->req->params}, editable => $editable, iframe => 'request' );
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
        bodyCssClass => join(' ',@cls),
        
        # try to set the title/icon by finding/parsing <title> in the 'html'
        autopanel_parse_title => \1,
        
        # These will only be the title/icon if there is no parsable <title>
        tabTitle => join('/',@args), #<-- not using $template to preserve the orig req name
        tabIconCls => 'ra-icon-page-white-world',
        
        html => $html,
        
        # Load any extra, template-specific configs from the Access class:
        %{ $self->Access->template_autopanel_cnf($template) || {} }
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
    push @head, '<base target="_blank" />' if (
      exists $c->req->params->{iframe} &&
      $c->req->params->{iframe} eq 'request'
    );
    
    if($external) {
      
      # Ask the Access class for custom headers for this external template, and
      # if it has them, set them in the response object now. And pull out $content_type
      # if this operation set it (i.e. the template provides its own Content-Type)
      # NEW: the template can also now provide its content type via ->template_content_type
      #  which takes priority and is the preferred API
      my $headers  = $external ? $self->Access->get_external_tpl_headers($template) : undef;
      if($headers) {
        $c->res->header( $_ => $headers->{$_} ) for (keys %$headers);
        $content_type ||= $c->res->content_type;
      }
    
      # If this external template provides its own headers, including Content-Type, and that is
      # *not* text/html, don't populate @head, even if it is $editable (which is rare - or maybe 
      # even impossible - here anyway)
      unless($content_type && ! ($content_type =~ /^text\/html/)){
        # If we're editable and external we need to include CSS for template edit controls:
        # TODO: basically including everything but ExtJS CSS. This is ugly and should
        # be generalized/available in the Asset system as a simpler function call:
        push @head, (
          $c->favicon_head_tag||'',
          $c->controller('Assets::RapidApp::CSS')->html_head_tags,
          $c->controller('Assets::RapidApp::Icons')->html_head_tags,
          $c->controller('Assets::ExtJS')->html_head_tags( js => [
            'adapter/ext/ext-base.js',
            'ext-all-debug.js',
            'src/debug.js'
          ]),
          $c->controller('Assets::RapidApp::JS')->html_head_tags
        ) if $editable; # $editable is rarely true here, so @header will be empty here anyway
      }
    }
    else {
      # Include all the ExtJS, RapidApp and local app CSS/JS
      push @head, $c->all_html_head_tags;
    }
    
    # Only include the RapidApp/ExtJS assets and wrap 'ra-scoped-reset' if
    # this is *not* an external template. If it is an external template,
    # ignore @head entirely if its empty:
    $output = $external 
      ? ( scalar(@head) == 0 ? $html : join("\n",@head,$html) ) 
      : join("\n",
          '<head>', @head, '</head>',
          '<div class="' . join(' ',@cls) . '">', $html, '</div>'
        )
    ;
    
  }

  return $self->_detach_response($c,$status,$output,$content_type);
}


# Read (not compiled/rendered) raw templates:
sub get :Chained('base') :Args {
  my ($self, $c, @args) = @_;
  my $template = $self->_resolve_template_name(@args)
    or die "No template specified";
  
  local $self->{_current_context} = $c;
  
  $self->Access->template_readable($template)
    or return $self->_detach_response($c,403,"Permission denied - template '$template'");
  
  my ($data, $error) = $self->get_Provider->load($template);
  
  return $self->_detach_response($c,400,"Failed to get template '$template'")
    unless (defined $data);
  
  # Decode as UTF-8 for user consumption:
  utf8::decode($data); 
  
  return $self->_detach_response($c,200,$data);
}

# Update raw templates:
sub set :Chained('base') :Args {
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
  
  # Encode the template content in UTF-8
  utf8::encode($content);
  
  $self->get_Provider->update_template($template,$content);
  
  return $self->_detach_response($c,200,'Template Updated');
}

sub create :Chained('base') :Args {
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

sub delete :Chained('base') :Args {
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
  #$content_type ||= 'text/plain; charset=utf-8';
  $c->response->content_type($content_type) if ($content_type);
  $c->response->status($status);
  $c->response->body($body);
  return $c->detach;
}

sub _render_template {
  my ($self, $meth, $template, $c) = @_;
  
  my $TT = $self->$meth;
  local $self->{_current_context} = $c;
  local $self->{_div_wrap} = 1 if ($meth eq 'Template_wrap');
  my $vars = $self->get_wrapped_tt_vars($template);
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
  my $vars = $self->get_wrapped_tt_vars($template);
  my $output;
  local $self->{_no_exception_error_content} = 1;
  return $TT->process( $template, $vars, \$output ) ? undef : $TT->error;
}

# Internal render function - designed to be called interactively
# from other parts of the application to render a template (i.e.
# not associated with a Template::Controller request)
# 
# TODO: This function will replace/merge with $c->template_render
# in RapidApp::Role::CatalystApplication
sub template_render {
	my ($self, $template, $vars, $c) = @_;
  $vars ||= {};
  $c ||= RapidApp->active_request_context;
  
  # The current context may not be available:
  # see DummyAccess in RapidApp::Template::Access:
  local $self->{_dummy_access} = 1 unless ($c);
  local $self->{_current_context} = $c || $self->_app;
  
  # The get_template_vars() API in the Access class expects
  # to have access to the catalyst context (i.e. request) so
  # we only call it and merge it in if we have $c, which is
  # optional in this method
  %$vars = (%{ $self->get_wrapped_tt_vars($template) }, %$vars) 
    if ($c);
  
  my $TT = $self->Template_raw;

	my $out;
	$TT->process($template,$vars,\$out) or die $TT->error;

	return $out;
}


# Wraps all CodeRef vars to cleanly catch exceptions that may be
# thrown by them. TT isn't able to handle them properly...
sub get_wrapped_tt_vars {
  my ($self,$template) = @_;
  my $vars = $self->Access->get_template_vars($template);
  
  die "Access class method 'get_template_vars()' didn't return a HashRef!"
    unless (ref($vars) eq 'HASH');
  
  for my $var (keys %$vars) {
    next unless (ref($vars->{$var}) eq 'CODE');
    my $coderef = delete $vars->{$var};
    $vars->{$var} = sub {
      my @args = @_;
      my $ret;
      try {
        $ret = $coderef->(@args);
      }
      catch {
        my $err_msg = "!! EXCEPTION IN CODEREF TEMPLATE VARIABLE '$var': $_";
        
        # TODO/FIXME:
        # We set the return value with the exception as a string (i.e. as content) 
        # instead of re-throwing because TT will display a useless and confusing 
        # error message, something like: "...Useless bare catch()..."
        $ret = $err_msg;
        
        # We may not actually be able to see the error in the template rendering
        # but at least it will be printed on the console (an exception here isn't
        # actually a *Template* error, per-se ... its an error in the perl code 
        # that is called by this CodeRef)
        warn RED.BOLD . $err_msg . CLEAR;
      };
      return $ret;
    };
  }
  
  return $vars;
}

1;