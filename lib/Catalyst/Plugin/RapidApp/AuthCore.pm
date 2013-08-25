package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::CoreSchema';

use RapidApp::Include qw(sugar perlutil);
require Catalyst::Utils;
use CatalystX::InjectComponent;

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

sub _authcore_config {
  my $c = shift;
  
  $c->config->{'Plugin::RapidApp::AuthCore'} ||= {};
  my $config = $c->config->{'Plugin::RapidApp::AuthCore'};
  
  $config->{credential} ||= {
    class => 'Password',
    password_field => 'password',
    password_type => 'clear'
  };
  
  $config->{store} ||= {
    class => 'DBIx::Class',
    user_model => 'RapidApp::CoreSchema::User',
    role_relation => 'roles',
    role_field => 'role',
    use_userdata_from_session => '1',
  };
  
  # Default session expire 1 hour
  $config->{expires} ||= 60*60;

  return $config;
}



before 'setup_dispatcher' => sub {
  my $c = shift;
  
  # FIXME: see comments in Catalyst::Plugin::RapidApp::AuthCore::PlugHook
  $c->_authcore_load_plugins;
  
  my $config = $c->_authcore_config;
  
  # Allow the user to totally override the auto config:
  $c->config->{'Plugin::Authentication'} ||= {
    default_realm	=> 'dbic',
    realms => {
      dbic => {
        credential => $config->{credential},
        store => $config->{store}
      }
    }
  };
  
  $c->config->{'Plugin::Session'} ||= {
    dbic_class => 'RapidApp::CoreSchema::Session',
    expires => $config->{expires}
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


