package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::CoreSchema';

use RapidApp::Include qw(sugar perlutil);
require Catalyst::Utils;
use CatalystX::InjectComponent;

use Switch qw(switch);
use Digest;
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
  
  my $cred = {
    class => 'Password',
    password_field => 'password'
  };
  
  # Combining password_type/password_hash_type into a single,
  # simpler AuthCore-specific config that supports specific
  # options (currently only 'clear'), with any other value 
  # taken to be a hash type (i.e. 'SHA-1', 'MD5', etc). 
  # Note that the whole 'credential' config can still be set 
  # to override this, and the whole 'Plugin::Authentication'
  # config can be set to override that...
  # We're provide multiple layers of config overrides....
  $config->{pw_type} ||= 'clear';
  switch ($config->{pw_type}) {
    case 'clear' {
      $cred->{password_type} = 'clear';
    }
    else {
      %$cred = ( %$cred,
        password_type => 'hashed',
        password_hash_type => $config->{pw_type}
      );
    }
  }
  
  # pw_type is ignored if 'credential' is set
  $config->{credential} ||= $cred;
  
  $config->{store} ||= {
    class => 'DBIx::Class',
    user_model => 'RapidApp::CoreSchema::User',
    role_relation => 'roles',
    role_field => 'role',
    use_userdata_from_session => '1',
  };
  
  # Default session expire 1 hour
  $config->{expires} ||= 60*60;
  
  # ---
  # Setup the password_hasher() to be used when administratively setting
  # passwords via the 'set_pw' virtual column. This provides a mechanism
  # for changing paswords via the raw/default CoreSchema grid interface.
  # Values entered in the column 'set_pw' are set in the 'password' column
  # after being passed through the password_hasher coderef/function, which
  # we are dynamically setting to match the supplied 'password_hash_type'
  my $pw_hash_type = (
    ! $c->config->{'Plugin::Authentication'} &&
    $config->{credential}{password_type} &&
    $config->{credential}{password_type} eq 'hashed'
  ) ? $config->{credential}{password_hash_type} : undef;
  
  if($pw_hash_type) {
    my $Digest = Digest->new($pw_hash_type);
    # FIXME: this is ugly/global/evil. But it works... Assumes
    # that the CoreSchema classes are only used here, which
    # is a reasonable assumtion but technically the end-user
    # app could be loading it too in which case this change would
    # also reach into and effect other parts of the app.
    RapidApp::CoreSchema::Result::User->password_hasher(sub {
      my $new_pass = shift;
      $Digest->reset->add($new_pass)->hexdigest;
    });
  }
  # ---
  
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
    
    my $do_auth = 0;
    my $browser_req = $c->req->header('X-RapidApp-RequestContentType') ? 0 : 1;
    
    if ($c->session_is_valid and $c->user_exists) {
      $c->delete_expired_sessions;
      $c->res->header('X-RapidApp-Authenticated' => $c->user->username);
    }
    else {
      $c->res->header('X-RapidApp-Authenticated' => 0);
      $do_auth = 1 if (
        # Only do auth for browser requests:
        $browser_req &&
        $class->_is_auth_required_path($self,@$args)
      );
    }
    
    return $do_auth ? $c->controller('Auth')->render_login_page($c) : $self->$orig(@_);
  });
};


sub _is_auth_required_path {
  my ($c, $rootModule, @path) = @_;
  
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


