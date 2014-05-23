package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::CoreSchema';

use RapidApp::Include qw(sugar perlutil);
require Catalyst::Utils;
use CatalystX::InjectComponent;

use Module::Runtime;
use RapidApp::CoreSchema;

use Catalyst::Plugin::Session::Store::DBIC 0.14;
use Catalyst::Plugin::Session::State::Cookie 0.17;
use Catalyst::Plugin::Authorization::Roles 0.09;
use Catalyst::Authentication::Store::DBIx::Class 0.1505;

my @req_plugins = qw/
Authentication
Authorization::Roles
Session
Session::State::Cookie
Session::Store::DBIC
RapidApp::AuthCore::PlugHook
/;

sub _authcore_load_plugins {
  my $c = shift;
  
  # Note: these plugins have to be loaded like this because they
  # aren't Moose Roles. But this causes load order issues that
  # we overcome by loading our own extra plugin, 'RapidApp::AuthCore::PlugHook'
  # which contains extra method modifiers that need to be applied
  # after the other plugins are loaded.
  my $plugins = [ grep { ! $c->registered_plugins($_) } @req_plugins ];
  $c->setup_plugins($plugins) if (scalar(@$plugins) > 0);
}

before 'setup_dispatcher' => sub {
  my $c = shift;
  
  # FIXME: see comments in Catalyst::Plugin::RapidApp::AuthCore::PlugHook
  $c->_authcore_load_plugins;
  
  $c->config->{'Plugin::RapidApp::AuthCore'} ||= {};
  my $config = $c->config->{'Plugin::RapidApp::AuthCore'};
  
  # Default CodeRef used to check if the current user/request has a given role
  #  - automatically includes administrator - Used by other modules, such as
  # TabGui to optionally filter navtrees
  $config->{role_checker} ||= sub {
    my $ctx = shift; #<-- expects CONTEXT object
    return $ctx->check_any_user_role('administrator',@_);
  };
  
  # Passthrough config:
  if($config->{init_admin_password}) {
    $c->config->{'Model::RapidApp::CoreSchema'} ||= {};
    my $cs_cnf = $c->config->{'Model::RapidApp::CoreSchema'};
    die "Conflicting 'init_admin_password' cnf (AuthCore/CoreSchema)" 
      if ($cs_cnf->{init_admin_password});
    $cs_cnf->{init_admin_password} = $config->{init_admin_password};
  }
  
  die "AuthCore: don't use 'pw_type' with 'credential' config opts" if (
    exists $config->{pw_type} && exists $config->{credential}
  );
  
  # Default session expire 1 hour
  $config->{expires} ||= 60*60;
  
  $config->{credential} ||= {
    class => 'Password',
    password_field => 'password',
    password_type => 'self_check'
  };
  
  $config->{store} ||= {
    class => 'DBIx::Class',
    user_model => 'RapidApp::CoreSchema::User',
    role_relation => 'roles',
    role_field => 'role',
    use_userdata_from_session => '1',
  };
  
  if($config->{passphrase_class}) {
    Module::Runtime::require_module($config->{passphrase_class});
    my $rclass = 'RapidApp::CoreSchema::Result::User';
    $rclass->authen_passphrase_class($config->{passphrase_class});
    if(exists $config->{passphrase_params}) {
      die "passphrase_params must be a HashRef" 
        unless (ref $config->{passphrase_params} eq 'HASH');
      $rclass->authen_passphrase_params($config->{passphrase_params});
    }
  }
  
  # Admin/backdoor option. This is useful if the pw_type is changed
  # after the user database is already setup to be able to login and
  # set the password to be hashed by the new function.
  if($config->{no_validate_passwords} && !$c->config->{'Plugin::Authentication'}) {
    $c->log->warn(join("\n",'',
      ' AuthCore: WARNING: "no_validate_passwords" enabled. Any password',
      ' typed will be accepted for any valid username. This is meant for',
      ' temp admin access, don\'t forget to turn this back off!',''
    ));
    $config->{credential}{password_type} = 'none';
  }
  
  $c->log->warn(
    ' AuthCore: WARNING: using custom "Plugin::Authentication" config'
  ) if ($c->config->{'Plugin::Authentication'});
  
  # Allow the user to totally override the auto config:
  $c->config->{'Plugin::Authentication'} ||= {
    default_realm	=> 'dbic',
    realms => {
      dbic => {
        credential  => $config->{credential},
        store       => $config->{store}
      }
    }
  };
  
  $c->log->warn(
    ' AuthCore: WARNING: using custom "Plugin::Session" config'
  ) if ($c->config->{'Plugin::Session'});
  
  $c->config->{'Plugin::Session'} ||= {
    dbic_class  => 'RapidApp::CoreSchema::Session',
    expires     => $config->{expires}
  };
};


after 'setup_components' => sub {
  my $class = shift;
  
  CatalystX::InjectComponent->inject(
      into => $class,
      component => 'Catalyst::Plugin::RapidApp::AuthCore::Controller::Auth',
      as => 'Controller::Auth'
  );
};

after 'setup_finalize' => sub {
  my $class = shift;
  
  $class->rapidApp->rootModule->_around_Controller(sub {
    my $orig = shift;
    my $self = shift;
    my $c = $self->c;
    my $args = $c->req->arguments;
    
    # Do auth_verify for auth required paths. If it fails it will detach:
    $c->controller('Auth')->auth_verify($c) if $class->is_auth_required_path($self,@$args);
    
    return $self->$orig(@_);
  });
};


sub is_auth_required_path {
  my ($c, $rootModule, @path) = @_;
  
  # TODO: add config opt for 'public_module_paths' and check here
  #  OR - user can wrap this method to override a given path/request
  #       to not require auth according to whatever rules they wish

  # All RapidApp Module requests require auth, including the root 
  # module when not deployed at /
  return 1 if ($c->module_root_namespace ne '');
  
  # Always require auth on requests to RapidApp Modules:
  return 1 if ($path[0] && $rootModule->has_subarg($path[0]));
  
  # Special handling for '/' - require auth unless a root template has
  # been defined
  return 1 if (
    @path == 0 &&
    ! $c->config->{'Model::RapidApp'}->{root_template}
  );
  
  # Temp - no auth on other paths (template alias paths)
  return 0;
}


1;


