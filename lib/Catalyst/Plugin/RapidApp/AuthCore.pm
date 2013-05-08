package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;

my @req_plugins = qw/
Authentication
Authorization::Roles
Session
Session::State::Cookie
Session::Store::FastMmap
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
            use_userdata_from_session => '1'
          }
        }
      }
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
  my $c = shift;
  
  #$c->session_expire_key( __user => 3600 );
  
  $c->rapidApp->rootModule->_around_Controller(sub {
    my $orig = shift;
    my $self = shift;
    
    $self->c->forward('/auth/auth_verify');
    
    return $self->$orig(@_);
  });
};


1;


