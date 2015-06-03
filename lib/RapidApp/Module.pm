package RapidApp::Module;

use strict;
use warnings;

# ABSTRACT: Base class for RapidApp Modules

use Moose;

use Clone;
use Try::Tiny;
use String::Random;
use Module::Runtime;
use Clone qw(clone);
use Time::HiRes qw(gettimeofday tv_interval);
use Catalyst::Utils;
use Scalar::Util qw(blessed weaken);
use RapidApp::JSONFunc;
use RapidApp::JSON::MixedEncoder;

use RapidApp::Util qw(:all);

has 'base_params'         => ( is => 'ro',  lazy => 1, default => sub {{}}  );
has 'params'             => ( is => 'ro',  required   => 0,    isa => 'ArrayRef'  );
has 'base_query_string'      => ( is => 'ro',  default => ''    );
has 'exception_style'       => ( is => 'ro',  required => 0,    default => "color: red; font-weight: bolder;"      );
has 'auto_viewport'        => ( is => 'rw',  default => 0 );

has 'auto_init_modules', is => 'ro', isa => 'Maybe[HashRef]', default => sub{undef};
# ----------



has 'instance_id' => ( 
  is => 'ro', lazy => 1, 
  traits => ['RapidApp::Role::PerRequestBuildDefReset'], 
  default => sub {
    my $self = shift;
    return 'instance-' . String::Random->new->randregex('[a-z0-9A-Z]{5}');
});


###########################################################################################

sub BUILD {
  my $self= shift;
  
  # Init ONREQUEST_called to true to prevent ONREQUEST from running during BUILD:
  $self->ONREQUEST_called(1);
  
  foreach my $mod ($self->module_class_list) {
    my $class= ref($mod) eq ''? $mod : ref $mod eq 'HASH'? $mod->{class} : undef;
    Catalyst::Utils::ensure_class_loaded($class) if defined $class;
  };
  
  # Init:
  $self->cached_per_req_attr_list;
  
  $self->apply_actions(viewport => 'viewport');
  $self->apply_actions(printview => 'printview');
  
  $self->apply_init_modules(%{$self->auto_init_modules})
    if ($self->auto_init_modules);
}

sub suburl {
  my $self = shift;
  my $url = shift;
  
  my $new_url = $self->base_url;
  $new_url =~ s/\/$//;
  $url =~ s/^\/?/\//;
  
  $new_url .= $url;
  
  if (defined $self->base_query_string and $self->base_query_string ne '') {
    $new_url .= '?' unless ($self->base_query_string =~ /^\?/);
    $new_url .= $self->base_query_string;
  }
  
  return $new_url;
}

# like suburl, but also prefixes mount_url
sub local_url {
  my ($self,$url) = @_;
  $url = $url ? $self->suburl($url) : $self->base_url;
  join('',$self->c->mount_url,$url)
}


sub urlparams {
  my $self = shift;
  my $params = shift;
  
  my $new = Clone($self->base_params);
  
  if (defined $params and ref($params) eq 'HASH') {
    foreach my $k (keys %{ $params }) {
      $new->{$k} = $params->{$k};
    }
  }
  return $new;
}

sub content {
  die "Unimplemented";
}


sub viewport {
  my $self= shift;
  $self->c->stash->{current_view} ||= 'RapidApp::Viewport';
  $self->c->stash->{title} ||= $self->module_name;
  $self->c->stash->{config_url} ||= $self->base_url;
  if (scalar keys %{$self->c->req->params}) {
    $self->c->stash->{config_params} ||= { %{$self->c->req->params} };
  }
}

sub printview {
  my $self= shift;
  $self->c->stash->{current_view} ||= 'RapidApp::Printview';
  $self->c->stash->{title} ||= $self->module_name;
  $self->c->stash->{config_url} ||= $self->base_url;
  if (scalar keys %{$self->c->req->params}) {
    $self->c->stash->{config_params} ||= { %{$self->c->req->params} };
  }
}


## --------------------------------------------------------------
##
## Code from legacy roles which have been DEPRECATED:
##
##  * RapidApp::Role::Module
##  * RapidApp::Role::Controller
##
## Code below was moved from roles.
##
## The original rationales behind why these were separate
## no longer apply, and have been combined here 
##
## --------------------------------------------------------------


##################################
####   Original Module Role   ####
##################################


# In catalyst terminology, "app" is the package name of the class that extends catalyst
# Many catalyst methods can be called from the package level
has 'app', is => 'ro', required => 1;

has 'module_name'        => ( is => 'ro',  isa => 'Str', required => 1 );
has 'module_path'        => ( is => 'ro',  isa => 'Str', required => 1 );
has 'parent_module_ref'  => ( is => 'ro',  isa => 'Maybe[RapidApp::Module]', weak_ref => 1, required => 1);
has 'modules_obj'        => ( is => 'ro',   default => sub {{}} );
has 'default_module'     => ( is => 'rw',  default => 'default_module' );

# This is defined in Controller role
#has 'create_module_params'      => ( is => 'ro',  default => sub { {} } );
has 'modules_params'          => ( is => 'ro',  default => sub { {} } );

has 'print_rapidapp_handlers_call_debug' => ( is => 'rw', isa => 'Bool', default => 0 );


# All purpose options:
has 'module_options' => ( is => 'ro', lazy => 1, default => sub {{}}, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ] );

has 'modules' => (
  traits  => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
     apply_modules      => 'set',
     get_module        => 'get',
     has_module        => 'exists',
     module_class_list  => 'values'
  }
);


has 'per_request_attr_build_defaults' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );
has 'per_request_attr_build_not_set' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );

# TODO: add back in functionality to record the time to load the module. 
# removed during the unfactor work in Github Issue #41
sub timed_new { (shift)->new(@_) }

sub cached_per_req_attr_list {
  my $self = shift;
  # XXX TODO: I think there is some Moose way of applying roles to the meta object,
  #   but I'm not taking the time to look it up.  This would also help with clearing the cache
  #   if new attributes were defined.
  my $attrs= (ref $self)->meta->{RapidApp_Module_PerRequestAttributeList};
  if (!defined $attrs) {
    my $attrs= [ grep { $self->should_clear_per_req($_) } $self->meta->get_all_attributes ];
    # we don't want this cache to make attributes live longer than needed, so weaken the references
    for (my $i=$#$attrs; $i>=0; $i--) {
      weaken $attrs->[$i];
    }
    (ref $self)->meta->{RapidApp_Module_PerRequestAttributeList}= $attrs;
  }
  return $attrs;
};


sub should_clear_per_req {
  my ($self, $attr) = @_;
  $attr->does('RapidApp::Role::PerRequestBuildDefReset')
}


# Does the same thing as apply_modules but also init/loads the modules
sub apply_init_modules {
  my $self = shift;
  my %mods = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  $self->apply_modules(%mods);
  foreach my $module (keys %mods) {
    # Initialize every module that we just added and set ONREQUEST_called back to false:
    $self->Module($module)->ONREQUEST_called(0);
  }
}

# 'ONREQUEST' is called once per web request. Add before modifiers to any classes that
# need to run code at this time
#has 'ONREQUEST_called' => ( is => 'rw', lazy => 1, default => 0, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ] );

has 'ONREQUEST_called' => ( is => 'rw', lazy => 1, default => 0 );

has '_lastRequestApplied' => ( is => 'rw', default => 0 );

sub reset_ONREQUEST {
  my $self = shift;
  $self->_lastRequestApplied(0);
}



sub ONREQUEST {
  my $self = shift;
  my ($sec0, $msec0)= gettimeofday;
  
  #$self->c->log->debug(MAGENTA . '[' . $self->get_rapidapp_module_path . ']->ONREQUEST (' . $self->c->request_id . ')');
  
  $self->_lastRequestApplied($self->c->request_id);
  
  $self->init_per_req_attrs;
  $self->c->rapidApp->markDirtyModule($self);
  
  #$self->process_customprompt;
  
  #$self->new_clear_per_req_attrs;
  
  $self->call_ONREQUEST_handlers;
  
  $self->ONREQUEST_called(1);
  
  my ($sec1, $msec1)= gettimeofday;
  my $elapsed= ($sec1-$sec0)+($msec1-$msec0)*.000001;
  $self->c->stash->{onrequest_time_elapsed}+= $elapsed;
  
  #$self->log->debug(sprintf(GREEN."ONREQUEST for %s took %0.3f seconds".CLEAR, $self->module_path, $elapsed));
  return $self;
}

sub call_ONREQUEST_handlers {
  my $self = shift;
  $self->call_rapidapp_handlers($self->all_ONREQUEST_calls_early);
  $self->call_rapidapp_handlers($self->all_ONREQUEST_calls);
  $self->call_rapidapp_handlers($self->all_ONREQUEST_calls_late);
}



sub init_per_req_attrs {
  my $self = shift;
  
  foreach my $attr (@{$self->cached_per_req_attr_list}) {
    if($attr->has_value($self)) {
      unless (defined $self->per_request_attr_build_defaults->{$attr->name}) {
        my $val = $attr->get_value($self);
        $val = clone($val) if (ref($val));
        $self->per_request_attr_build_defaults->{$attr->name} = $val;
      }
    }
    else {
      $self->per_request_attr_build_not_set->{$attr->name} = 1;
    }
  }
}

sub reset_per_req_attrs {
  my $self = shift;
  my $c = shift;
  
  foreach my $attr (@{$self->cached_per_req_attr_list}) {

    # Reset to "not_set":
    if (defined $self->per_request_attr_build_not_set->{$attr->name}) {
      #$c->log->debug(GREEN . BOLD . ' =====> ' . $attr->name . ' (clear_value)' . CLEAR);
      $attr->clear_value($self);
    }
    # Reset to default:
    elsif(defined $self->per_request_attr_build_defaults->{$attr->name}) {
      my $val = $self->per_request_attr_build_defaults->{$attr->name};
      $val = clone($val) if (ref($val));
      #$c->log->debug(YELLOW . BOLD . ' =====> ' . $attr->name . ' (set_value)' . CLEAR);
      $attr->set_value($self,$val);
    }
  }
  
  # Legacy:
  $self->clear_attributes if ($self->no_persist);
}




#sub new_clear_per_req_attrs {
#  my $self = shift;
#  
#  #$self->ONREQUEST_called(0);
#  
#  foreach my $attr (@{$self->cached_per_req_attr_list}) {
#    # Reset to default:
#    if(defined $self->per_request_attr_build_defaults->{$attr->name}) {
#      my $val = $self->per_request_attr_build_defaults->{$attr->name};
#      $val = clone($val) if (ref($val));
#      $attr->set_value($self,$val);
#    }
#    # Initialize default:
#    else {
#      my $val = $attr->get_value($self);
#      $val = clone($val) if (ref($val));
#      $self->per_request_attr_build_defaults->{$attr->name} = $val;
#    }
#  }
#  
#  # Legacy:
#  $self->clear_attributes if ($self->no_persist);
#}




sub THIS_MODULE {
  my $self = shift;
  return $self unless (defined $self->c);
  
  return $self->ONREQUEST if (defined $self->c && $self->c->request_id != $self->_lastRequestApplied);
  return $self;
}


# Gets a Module by / delim path
sub get_Module {
  my $self = shift;
  my $path = shift or return $self->THIS_MODULE;
  
  my @parts = split('/',$path);
  my $first = shift @parts;
  # If $first is undef then the path is absolute (starts with '/'):
  return $self->topmost_module->get_Module(join('/',@parts)) unless ($first);
  
  # If there are no more parts in the path, then the name is a direct submodule:
  return $self->Module($first) unless (scalar @parts > 0);
  
  return $self->Module($first)->get_Module(join('/',@parts));
}



sub Module {
  my $self = shift;
  my $name = shift;
  my $no_onreq = shift;
  
  $self->_load_module($name) or confess "Failed to load Module '$name'";
  
  #return $self->modules_obj->{$name} if ($no_onreq);
  return $self->modules_obj->{$name}->THIS_MODULE;
}


sub _load_module {
  my $self = shift;
  my $name = shift or return 0;
  return 0 unless ($self->has_module($name));
  
  #my $class_name = $self->modules->{$name} or return 0;
  my $class_name = $self->get_module($name);
  my $params;
  if (ref($class_name) eq 'HASH') {
    $params = $class_name->{params};
    $class_name = $class_name->{class} or die "Missing required parameter 'class'";
  }

  return 1 if (defined $self->modules_obj->{$name} and ref($self->modules_obj->{$name}) eq $class_name);
  
  my $Object = $self->create_module($name,$class_name,$params) or die "Failed to create new $class_name object";
  
  $self->modules_obj->{$name} = $Object;
  
  return 1;
}

sub create_module {
  my $self = shift;
  my $name = shift;
  my $class_name = shift;
  my $params = shift;
  
  die "Bad module name '$name' -- cannot contain '/'" if ($name =~ /\//);

  Module::Runtime::require_module($class_name);
  
  $params = $self->create_module_params unless (defined $params);
  
  if (defined $self->modules_params->{$name}) {
    foreach my $k (keys %{$self->modules_params->{$name}}) {
      $params->{$k} = $self->modules_params->{$name}->{$k};
    }
  }
  
  $params->{app} = $self->app;
  $params->{module_name} = $name;
  $params->{module_path} = $self->module_path;
  $params->{module_path} .= '/' unless substr($params->{module_path}, -1) eq '/';
  $params->{module_path} .= $name;
  $params->{parent_module_ref} = $self;
  

  # Colorful console messages, non-standard, replaced with normal logging below:
  #print STDERR
  #  ' >> ' .
  #  CYAN . "Load: " . BOLD . $params->{module_path} . CLEAR . 
  #  CYAN . " [$class_name]" . CLEAR . "\n"
  #if ($self->app->debug);
  
  my $start = [gettimeofday];
  
  my $Object = $class_name->new($params) or die "Failed to create module instance ($class_name)";
  die "$class_name is not a valid RapidApp Module" unless ($Object->isa('RapidApp::Module'));
  
  my $c = $self->app;
  $c->log->debug( join('', 
    " >> Loaded: ",$params->{module_path}," [$class_name] ",
    sprintf("(%0.3fs)",tv_interval($start))
  )) if ($c->debug);
  
  return $Object;
}

sub parent_module {
  my $self = shift;
  return $self->parent_module_ref ? $self->parent_module_ref->THIS_MODULE : undef;
}


sub topmost_module {
  my $self = shift;
  return $self unless (defined $self->parent_module);
  return $self->parent_module->topmost_module;
}


sub parent_by_name {
  my $self = shift;
  my $name = shift;
  return $self if (lc($self->module_name) eq lc($name));
  return undef unless (defined $self->parent_module);
  return $self->parent_module->parent_by_name($name);
}



sub applyIf_module_options {
  my $self = shift;
  my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  my %unset = ();
  foreach my $opt (keys %new) {
    next if (defined $self->module_options->{$opt});
    $unset{$opt} = $new{$opt};
  }
  
  return $self->apply_module_options(%unset);
}


sub apply_module_options {
  my $self = shift;
  my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
    
  %{ $self->module_options } = (
    %{ $self->module_options },
    %new
  );
}

sub get_module_option {
  my $self = shift;
  my $opt = shift;
  return $self->module_options->{$opt};
}


has 'ONREQUEST_calls' => (
  traits    => [ 'Array' ],
  is        => 'ro',
  isa       => 'ArrayRef[RapidApp::Handler]',
  default   => sub { [] },
  handles => {
    all_ONREQUEST_calls    => 'elements',
    add_ONREQUEST_calls    => 'push',
    has_no_ONREQUEST_calls  => 'is_empty',
  }
);
around 'add_ONREQUEST_calls' => __PACKAGE__->add_ONREQUEST_calls_modifier;

has 'ONREQUEST_calls_early' => (
  traits    => [ 'Array' ],
  is        => 'ro',
  isa       => 'ArrayRef[RapidApp::Handler]',
  default   => sub { [] },
  handles => {
    all_ONREQUEST_calls_early    => 'elements',
    add_ONREQUEST_calls_early    => 'push',
    has_no_ONREQUEST_calls_early  => 'is_empty',
  }
);
around 'add_ONREQUEST_calls_early' => __PACKAGE__->add_ONREQUEST_calls_modifier;

has 'ONREQUEST_calls_late' => (
  traits    => [ 'Array' ],
  is        => 'ro',
  isa       => 'ArrayRef[RapidApp::Handler]',
  default   => sub { [] },
  handles => {
    all_ONREQUEST_calls_late    => 'elements',
    add_ONREQUEST_calls_late    => 'push',
    has_no_ONREQUEST_calls_late  => 'is_empty',
  }
);
around 'add_ONREQUEST_calls_late' => __PACKAGE__->add_ONREQUEST_calls_modifier;

sub add_ONREQUEST_calls_modifier { 
  return sub {
    my $orig = shift;
    my $self = shift;
    return $self->$orig(@_) if (ref($_[0]));
    
    my @new = ();
    foreach my $item (@_) {
      push @new, RapidApp::Handler->new(
        method  => $item,
        scope    => $self
      );
    }
    return $self->$orig(@new);
  }; 
}

sub call_rapidapp_handlers {
  my $self = shift;
  foreach my $Handler (@_) {
    die 'not a RapidApp::Handler' unless (ref($Handler) eq 'RapidApp::Handler');
    
    if($self->print_rapidapp_handlers_call_debug) {
      my $msg = YELLOW . '->call_rapidapp_handlers[' . $self->get_rapidapp_module_path . '] ' . CLEAR;
      $msg .= GREEN;
      if (defined $Handler->scope) {
        $msg .= '(' . ref($Handler->scope);
        if ($Handler->scope->isa('RapidApp::Module')) {
          $msg .= CLEAR . BLUE . ' ' . $Handler->scope->get_rapidapp_module_path;
        }
        $msg .= CLEAR . GREEN . ')' . CLEAR;
      }
      else {
        $msg .= '(no scope)';
      }
      
      if (defined $Handler->method) {
        $msg .= BOLD . '->' . $Handler->method . CLEAR;
      }
      else {
        $msg .= BOLD . '==>CODEREF->()' . CLEAR;
      }
    
      $self->app->log->debug($msg);
    }
    
    $Handler->call;
  }
}

#before 'ONREQUEST' => sub {
#  my $self = shift;
#  $self->call_rapidapp_handlers($self->all_ONREQUEST_calls_early);
#};
#
#after 'ONREQUEST' => sub {
#  my $self = shift;
#  $self->call_rapidapp_handlers($self->all_ONREQUEST_calls_late);
#};


# All purpose flags (true/false) settings
has 'flags' => (
  traits    => [
    'Hash',
    'RapidApp::Role::PerRequestBuildDefReset'
  ],
  is        => 'ro',
  isa       => 'HashRef[Bool]',
  default   => sub { {} },
  handles   => {
     apply_flags  => 'set',
     has_flag    => 'get',
     delete_flag  => 'delete',
     flag_defined  => 'exists',
     all_flags    => 'elements'
  },
);


# function for debugging purposes - returns a string of the module path
sub get_rapidapp_module_path {
  return (shift)->module_path;
}


has 'customprompt_button' => ( 
  is => 'rw',
  isa => 'Maybe[Str]',
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset'  ],
  lazy => 1,
  default => sub {
    my $self = shift;
    return $self->c->req->header('X-RapidApp-CustomPrompt-Button') || $self->c->req->params->{'X-RapidApp-CustomPrompt-Button'};
  }
);


has 'customprompt_data' => ( 
  is => 'rw',
  isa => 'HashRef',
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset'  ],
  lazy => 1,
  default => sub {
    my $self = shift;
    my $rawdata = $self->c->req->header('X-RapidApp-CustomPrompt-Data') || $self->c->req->params->{'X-RapidApp-CustomPrompt-Data'};
    return {} unless (defined $rawdata);
    return $self->json->decode($rawdata);
  }
);


##################################
#### Original Controller Role ####
##################################


has 'base_url' => ( 
  is => 'rw', lazy => 1, default => sub { 
    my $self = shift;
    my $ns = $self->app->module_root_namespace;
    $ns = $ns eq '' ? $ns : '/' . $ns;
    my $parentUrl= defined $self->parent_module? $self->parent_module->base_url.'/' : $ns;
    return $parentUrl . $self->{module_name};
  },
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ] 
);

#has 'extra_actions'      => ( is => 'ro',   default => sub {{}} );
has 'default_action'      => ( is => 'ro',  default => undef );
has 'render_as_json'      => ( is => 'rw',  default => 1, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ]  );

# NEW: if true, sub-args (of url path) are passed in even if the sub path does
# not exist as a defined action or sub-module. TODO: refactor and use built-in Catalyst
# functionality for controller actions. ALL of Module/Controller should be refactored
# into proper sub-classes of Catalyst controllers
has 'accept_subargs', is => 'rw', isa => 'Bool', default => 0;

has 'actions' => (
  traits  => ['Hash'],
  is        => 'ro',
  isa       => 'HashRef',
  default   => sub { {} },
  handles   => {
     apply_actions  => 'set',
     get_action    => 'get',
     has_action    => 'exists'
  }
);

# In catalyst terminology, "c" is the catalyst instance, embodying a request.
sub c { RapidApp->active_request_context }

# The current logger object, probably the same as ->c->log, but maybe not.
sub log { (shift)->app->log }


has 'no_persist' => ( is => 'rw', lazy => 1, default => sub {
  my $self = shift;
  # inherit the parent's no_persist setting if its set:
  return $self->parent_module->no_persist if (
    defined $self->parent_module and 
    defined $self->parent_module->no_persist
  );
  return undef;
});

has 'render_append'      => ( is => 'rw', default => '', isa => 'Str' );

sub add_render_append {
  my $self = shift;
  my $add or return;
  die 'ref encountered, string expected' if ref($add);
  
  my $cur = $self->render_append;
  return $self->render_append( $cur . $add );
}


has 'no_json_ref_types' => ( is => 'ro', default => sub {
  return {
    'IO::File'  => 1
  }
});

has 'create_module_params' => ( is => 'ro', lazy => 1, default => sub {{}} );

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
  my $self = shift;
  #$self->log->warn((ref $self)."->json still being used");
  return RapidApp::JSON::MixedEncoder->new;
}

sub JSON_encode {
  my $self = shift;
  return $self->json->encode(shift);
}


## TODO: REMOVE 'simulateRequest' ---
# This method attempts to set up a catalyst request instance such that a new request can be executed
#   to a different module and with different parameters and HTTP headers than were used for the main
#  request.
sub simulateRequest {
  my ($self, $req)= @_;
  
  my $c = RapidApp->active_request_context;
  
  my $tempResp= Catalyst::Response->new();
  
  my $origReq= $c->request;
  my $origResp= $c->response;
  my $origStash= $c->stash;
  
  try {
    $c->request($req);
    $c->response($tempResp);
    
    # This is dangerous both any way you do it.  We could make an empty stash, but then might lose important
    #   settings (like those set by ModuleDispatcher)
    $c->stash({ %$origStash });
    
    my $path= $req->uri->path;
    $path =~ s|^/||;
    my @args= split('/', $path);
    $self->c->log->debug("Simulate Request: \"".join('", "', @args));
    my $ctl_ret= $self->Controller($c, @args);
    
    $c->log->debug('controller return: '.(length($ctl_ret) > 20? (ref $ctl_ret).' length='.length($ctl_ret) : $ctl_ret));
    $c->log->debug('body: '.(length($tempResp->body) > 20? (ref $tempResp->body).' length='.length($tempResp->body) : $tempResp->body));
    
    # execute the specified view, if needed
    if (!defined $c->res->body) {
      my $view= $self->c->stash->{current_view_instance} || $c->view($c->stash->{current_view});
      $view->process($c);
    }
    
    $c->request($origReq);
    $c->response($origResp);
    $c->stash($origStash);
  }
  catch {
    $c->request($origReq);
    $c->response($origResp);
    $c->stash($origStash);
    die $_;
  };
  return $tempResp;
}

sub simulateRequestToSubUrl {
  my ($self, $uri, @params)= @_;
  blessed($uri) && $uri->isa('URI') or $uri= URI->new($uri);
  
  # if parameters were part of the URI, extract them first, then possibly override them with @params
  # Note that "array-style" URI params will be returned as duplicate key entries, so we have to do some work to
  #   assemble the values into lists to match the way you'd expect it to work.
  my @uriParams= $uri->query_form;
  my %paramHash;
  for (my $i=0; $i < $#uriParams; $i+= 2) {
    my ($key, $val)= ($uriParams[$i], $uriParams[$i+1]);
    $paramHash{$key}= (!defined $paramHash{$key})?
      $val
      : (ref $paramHash{$key} ne 'ARRAY')?
        [ $paramHash{$key}, $val ]
        : [ @{$paramHash{$key}}, $val ];
  }
  
  # add in the supplied parameters
  %paramHash= ( %paramHash, @params );
  
  my $req= Catalyst::Request->new( uri => $uri, parameters => \%paramHash );
    
  return $self->simulateRequest($req);
}

sub simulateRequestToSubUrl_asString {
  my $self= shift;
  my $resp= $self->simulateRequestToSubUrl(@_);
  $resp->status == 200
    or die "Simulated request to ".$_[0]." returned status ".$resp->status;
  my $ret= $resp->body;
  if (ref $ret) {
    my $fd= $ret;
    local $/= undef;
    $ret= <$fd>;
    $fd->close;
  }
  return $ret;
}

# Initializes variables of the controller based on the details of the current request being handled.
# This is a stub for 'after's and 'before's and overrides.
sub prepare_controller {
}

=head2 Controller( $catalyst, @pathArguments )

This method handles a request.

=cut
sub Controller {
  my ($self, $c, @args) = @_;

  $self->prepare_controller(@args);

  # dispatch the request to the appropriate handler

  $c->log->debug('--> ' . 
    GREEN.BOLD . ref($self) . CLEAR . '  ' . 
    GREEN . join('/',@args) . CLEAR
  ) if ($c->debug);

  $self->controller_dispatch(@args);
}

# module or action:
sub has_subarg {
  my ($self, $opt) = @_;
  return ($opt && (
    $self->has_module($opt) ||
    $self->has_action($opt)
  )) ? 1 : 0;
}


has 'get_local_args', is => 'ro', isa => 'Maybe[CodeRef]', lazy => 1, default => undef;

sub local_args {
  my $self = shift;
  
  return $self->get_local_args->() if ($self->get_local_args);
  
  my $path = '/' . $self->c->req->path;
  my $base = quotemeta($self->base_url . '/');
  my ($match) = ($path =~ /^${base}(.+$)/);
  my $argpath = defined $match ? $match : '';
  return split('/',$argpath);
}

# is this being used anyplace??
sub clear_attributes {
  my $self = shift;
  for my $attr ($self->meta->get_all_attributes) {
    next if ($attr->name eq 'actions');
    $attr->clear_value($self) if ($attr->is_lazy or $attr->has_clearer);
  }
}


=head2 controller_dispatch( @args )

controller_dispatch performs the standard RapidApp dispatch processing for a Module.

=over

=item *

If the first argument names an action, the action is executed.

=item *

If the first argument names a sub-module, the processing is passed to the sub-module.

=item *

If the first argument does not match anything, then the default action is called, if specified,
otherwise a 404 is returned to the user.

=item *

If there are no arguments, and the client was not requesting JSON, the viewport is executed.

=item *

Else, content is called, and its return value is passed to render_data.

=back

=cut

sub controller_dispatch {
  my ($self, $opt, @subargs)= @_;
  my $c = $self->c;
  
  return $self->Module($opt)->Controller($self->c,@subargs)
    if ($opt && !$self->has_action($opt) && $self->_load_module($opt));
    
  return $self->process_action($opt,@subargs)
    if ($opt && $self->has_action($opt));
    
  return $self->process_action($self->default_action,@_)
    if (defined $self->default_action);
  
  my $ct= $self->c->stash->{requestContentType};
  
  $self->_maybe_special_path_redirect($opt,@subargs) if ($opt);
  
  # if there were unprocessed arguments which were not an action, and there was no default action, generate a 404
  # UPDATE: unless new 'accept_subargs' attr is true (see attribute declaration above)
  if (defined $opt && !$self->accept_subargs) {
    # Handle the special case of browser requests for 'favicon.ico' (#57)
    return $c->redispatch_public_path(
      $c->default_favicon_url
    ) if ($opt eq 'favicon.ico' && !$c->is_ra_ajax_req);

    $self->c->log->debug(join('',"--> ",RED,BOLD,"unknown action: $opt",CLEAR)) if ($self->c->debug);
    $c->stash->{template} = 'rapidapp/http-404.html';
    $c->stash->{current_view} = 'RapidApp::Template';
    $c->res->status(404);
    return $c->detach;
  }
  # --
  # TODO: this is the last remaining logic from the old "web1" stuff (see the v0.996xx branch for
  #       the last state of that code before it was unfactored)
  #
  #       this needs to be merged with the next, newer codeblock (render_viewport stuff...)
  elsif ($self->auto_viewport && !$self->c->is_ra_ajax_req) {
    $self->c->log->debug("--> " . GREEN . BOLD . "[auto_viewport_content]" . CLEAR . ". (no action)")
      if($self->c->debug);
    return $self->viewport;
  }
  # --
  else {
    my $rdr_vp = $self->c->stash->{render_viewport};
    if($rdr_vp && $rdr_vp eq 'printview' && $self->can('printview')) {
      return $self->printview;
    }
    elsif($rdr_vp && $self->can('viewport')) {
      return $self->viewport;
    }
    else {
      ## ---
      ## detect direct browser GET requests (i.e. not from the ExtJS client)
      ## and redirect them back to the #! hashnav path
      $self->auto_hashnav_redirect_current;
      # ---
      $self->c->log->debug("--> " . GREEN . BOLD . "[content]" . CLEAR . ". (no action)")
        if($self->c->debug);
      return $self->render_data($self->content);
    }
  }
  
}

sub _maybe_special_path_redirect {
  my ($self, $opt, @subargs)= @_;
  my $c = $self->c;
  
  # Special handling for relative requests to special/reserved controller paths.
  # This allows us to use relative paths in front-side code and for it to just
  # work, even if we change our mount path later on
  $c->redispatch_public_path($c->mount_url,$opt,@subargs) && $c->detach if (
       $opt eq 'simplecas'
    || $opt eq 'assets'
    #|| $opt eq 'rapidapp'   #<-- we don't need this that much
  );
}


# This call happens via local method so subclasses are able to override
sub auto_hashnav_redirect_current {
  my $self = shift;
  $self->c->auto_hashnav_redirect_current
}



=head2 process_action( $actionName, [optional @args] )

This routine handles the execution of a selected action.  The action must exist.
For actions that map to coderefs, the coderef is executed.
For actions that map to strings, a method of that name is called on $self.

=cut
sub process_action {
  my $self = shift;
  my ( $opt, @args ) = @_;
  
  die "No action specified" unless ($opt);
  
  $self->c->log->debug('--> ' . 
    GREEN.BOLD . ref($self) . CLEAR . '  ' . 
    GREEN . "action{ " . $opt . " }" . CLEAR . '  ' . 
    GREEN . join('/',@args) . CLEAR
  ) if ($self->c->debug);
  
  my $coderef = $self->get_action($opt) or die "No action named $opt";
  
  # If $coderef is not actually a coderef, we assume its a string representing an 
  # object method and we call it directly:
  return $self->render_data( 
    ref($coderef) eq 'CODE' ? 
      $coderef->($self,@args) : 
        $self->$coderef(@args) 
  );
}

=head2 render_data( $data )

This is a very DWIM sort of routine that takes its parameter (likely the return value of
content or an action) and picks an appropriate view for it, possibly ignoring it altogether.

=over

=item *

If the action generated a body, no view is needed, and the parameter is ignored.

=item *

If the action chose its own view, no further processing is done, and the parameter is returned.

=item *

If the controller is configured to render json (the default) and the parameter isn't blacklisted
in no_json_ref_types, and the parameter isn't a plain string, the RapidApp::JSON view is chosen.
The parameter is returned (as-is) to get passed back to TopController who passes it to the view.

=item *

Else, the data is treated as an explicit string for the body.  The body is assigned, and returned.

=back

=cut
sub render_data {
  my ($self, $data)= @_;
  
  #$self->c->log->debug(Dumper($data));
  
  # do nothing if the body has been set
  if (defined $self->c->response->body && length $self->c->response->body) {
    $self->c->log->debug("(body set by user)");
    
    # check for the condition that will cause a "Wide character in syswrite" and give a better error message
    if (utf8::is_utf8($self->c->response->body)) {
      $self->c->response->content_type =~ /^text|xml$|javascript$|JSON$/
        or $self->c->log->warn("Controller ".(ref $self)." returned unicode text but isn't using a \"text\" content type!");
    }
    return undef;
  }
  
  # do nothing if the view has been configured
  if (defined $self->c->stash->{current_view} || defined $self->c->stash->{current_view_instance}) {
    $self->c->log->debug("(view set by user)");
    return $data;
  }
  
  # if we want auto-json rendering, use the JSON view
  if ($self->render_as_json && ref($data) && !defined $self->no_json_ref_types->{ref($data)}) {
    $self->c->stash->{current_view} = 'RapidApp::JSON';
    return $data;
  }
  # else set the body directly and use no view
  else {
    $self->c->response->header('Cache-Control' => 'no-cache');
    return $self->c->response->body( $data );
  }
}

sub set_response_warning { (shift)->c->set_response_warning(@_) }


# if response_callback_scoped is true when set_response_callback is called, the
# function will be called with the scope (this reference) of the Ext.data.Connection
# object that initiated the Ajax request (Ext.Ajax.request) and this.response will
# also contain the response object; This is false by default because setting the 
# scope breaks many functions, and this is usually not needed (the only reason to
# turn this on would be if you need to examine the specific request/response)
has 'response_callback_scoped' => (
  is => 'rw',
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
  default => 0
);

=head2 set_response_callback

examples

  $self->set_response_callback( 'Ext.ux.MyFunc' );
  
  $self->set_response_callback( alert => 'foo!' );
  
  $self->set_response_callback( 'Ext.Msg.alert' => ( 'A message!!', 'this is awesome!!' ) );
  
  my $func = RapidApp::JSONFunc->new( 
    raw => 1, 
    func => 'function(){ console.log("anon!!"); console.dir(this.response); }'
  );
  $self->response_callback_scoped(1);
  $self->set_response_callback( 
    $func => ( "arg1",{ key_in_arg2 => 'blah!!!' },'arg3',\1  ) 
  );

=cut

# when calling set_response_callback the JS function specified will be
# called after the request is completed successfully
sub set_response_callback {
  my ($self, $func, @args) = @_;

  my $data = {};
  $data->{arguments} = [ @args ] if (scalar @args > 0);
  
  if(ref($func) eq 'RapidApp::JSONFunc') {
    die "only 'raw' RapidApp::JSONFunc objects are supported" unless ($func->raw);
    $data->{anonfunc} = $func;
  }
  else {
    $data->{func} = $func;
  }
  
  $data->{scoped} = \1 if ($self->response_callback_scoped);
  
  return $self->c->response->header( 'X-RapidApp-Callback' => $self->json->encode($data) );
}


has 'response_server_events' => (
  is => 'ro',
  isa => 'ArrayRef[Str]',
  traits => [ 'Array' ],
  default => sub {[]},
  handles => {
    add_response_server_events  => 'push',
    all_response_server_events  => 'uniq'
  }
);
after 'add_response_server_events' => sub {
  my $self = shift;
  $self->c->response->header( 
    'X-RapidApp-ServerEvents' => $self->json->encode([ $self->all_response_server_events ]) 
  );
};


no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

RapidApp::Module - Base class for RapidApp Modules

=head1 SYNOPSIS

 package MyApp::Module::MyModule;
 use Moose;
 extends 'RapidApp::Module';

=head1 DESCRIPTION

This is the base class for all RapidApp Modules. Documentation still TDB...

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Modules>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

