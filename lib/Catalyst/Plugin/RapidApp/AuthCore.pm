package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;

require Catalyst::Plugin::Session::Store::DBIC;
require Catalyst::Plugin::Session::State::Cookie;
require Catalyst::Plugin::Authorization::Roles;
require Catalyst::Authentication::Store::DBIx::Class;

my @req_plugins = qw/
Authentication
Authorization::Roles
Session
Session::State::Cookie
Session::Store::DBIC
/;

before 'setup_dispatcher' => sub {
  my $c = shift;
  my $plugins = [ grep { ! $c->registered_plugins($_) } @req_plugins ];
  $c->setup_plugins($plugins) if (scalar(@$plugins) > 0);
  
  $c->config(
    'Controller::Login' => {
      #traits => ['-RenderAsTTTemplate'],
    },
    'Plugin::Authentication' => {
      default_realm	=> 'progressive',
      realms => {
        progressive => {
          class => 'Progressive',
          realms => ['dbic'],
        },
        dbic => {
          credential => {
            class => 'Password',
            password_field => 'password',
            password_type => 'clear'
          },
          store => {
            class => 'DBIx::Class',
            user_model => 'RapidApp::CoreSchema::User',
            role_relation => 'roles',
            role_field => 'role',
            use_userdata_from_session => '1',
          }
        }
      }
    },
    'Plugin::Session' => {
      dbic_class => 'RapidApp::CoreSchema::Session',
      # TODO/FIXME: something is broken that prevents sessions from being
      # extended which forces the user to reauth every 'expires' seconds
      # regardless of recent requests. Need to dig into Plugin::Session
      expires    => 60*60*8, #<-- 8 hours
    }
  );
  
};


after 'setup_components' => sub {
  my $c = shift;
  
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));
  
  CatalystX::InjectComponent->inject(
      into => $c,
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


