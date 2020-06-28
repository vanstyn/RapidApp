package Catalyst::Plugin::RapidApp::AuthCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::CoreSchema';

use RapidApp::Util qw(:all);
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
  
  # Default session expire 2 hour
  $config->{expires} ||= 2*60*60;
  
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
  
  # Admin/backdoor option. This is useful if the passphrase config is changed
  # after the user database is already setup to be able to login and
  # set the password to be hashed by the new function (or if you forget the pw).
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
  
  $class->_initialize_linked_user_model;
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

# Updated version of original method from Catalyst::Plugin::Session::Store::DBIC -
#  also deletes sessions with undef expires
sub delete_expired_sessions {
  my $c = shift;
  $c->session_store_model->search([
    $c->session_store_dbic_expires_field => { '<', time() },
    $c->session_store_dbic_expires_field => undef,
  ])->delete;
}

sub _initialize_linked_user_model {
  my $c = shift;
  
  my $model = $c->config->{'Plugin::RapidApp::AuthCore'}{linked_user_model} or return undef;
  my $M = $c->model($model) or die "AuthCore: Failed to load linked_user_model '$model'";
  
  my $lSource = $M->result_source;
  my $lClass  = $lSource->result_class;
  
  my $cSource = $c->model('RapidApp::CoreSchema::User')->result_source;
  my $cClass  = $cSource->result_class;
  
  my $key_col = 'username';
  
  die "linked_user_model '$model' does not have '$key_col' column" 
    unless ($lSource->has_column($key_col));

  my @shared_cols = grep { 
    $_ ne 'id' && $cClass->has_column($_) 
  } $lClass->columns;
  
  $lClass->load_components('+RapidApp::DBIC::Component::LinkedResult');
  $lSource->{_linked_source} = $cSource;
  $lSource->{_linked_key_column} = $key_col;
  $lSource->{_linked_shared_columns} = [@shared_cols];
  
  $cClass->load_components('+RapidApp::DBIC::Component::LinkedResult');
  $cSource->{_linked_source} = $lSource;
  $cSource->{_linked_key_column} = $key_col;
  $cSource->{_linked_shared_columns} = [@shared_cols];
  
}

# Can be called as user/pass, or just user as a user object
sub _authcore_apply_login {
  my ($c, $user, $pass) = @_;

  my $error    = undef;
  my $username = undef;
  
  $c->delete_expired_sessions;
  
  if($c->user) {
    $c->delete_session('logout');
    $c->logout;
  }
  
  if(blessed $user) {
    $c->set_authenticated( $user )
  }
  else {
    if($c->authenticate({ username => $user, password => $pass })) {
      $c->log->info("Password authentication success for user '$user'")
    }
    else {
      $error = "Password authentication failure for user '$user'";
    }
  }
  
  $username = $c->user->username unless ($error);
  
  $error ||= 'unknown login failure' unless ($username);
  
  if ($error) {
    $c->log->info("AuthCore: $error");
    return 0;
  }
  
  $c->session->{RapidApp_username} = $username;
  
  # New: set the X-RapidApp-Authenticated header now so the response
  # itself will reflect the successful login (since in either case, the
  # immediate response is a simple redirect). This is for client info/debug only
  $c->res->header('X-RapidApp-Authenticated' => $username);

  my $dt = DateTime->now( time_zone => 'local' );
  $c->user->update({ last_login_ts => join(' ',$dt->ymd('-'),$dt->hms(':')) });
    
  # Something is broken!
  $c->_save_session_expires;
  
  1
}


1;

__END__

=head1 NAME

Catalyst::Plugin::RapidApp::AuthCore - instant authentication, authorization and sessions

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp::AuthCore /;

=head1 DESCRIPTION

This plugin provides a full suite of standard users and sessions with authentication and
authorization for Catalyst/RapidApp applications.

It loads and auto-configures a bundle of standard Catalyst plugins:

 Authentication
 Authorization::Roles
 Session
 Session::State::Cookie
 Session::Store::DBIC

As well as the L<RapidApp::CoreSchema|Catalyst::Plugin::RapidApp::CoreSchema> plugin, 
which sets up the backend model/store.

The common DBIC-based L<Catalyst::Model::RapidApp::CoreSchema> database is used for 
the store and persistence of all data, which is automatically deployed as an SQLite
database on first load.

New databases are automatically setup with one user:

 username: admin
 password: pass

An C<administrator> role is also automatically setup, which the admin user belongs to.

For managing users and roles, seeing active sessions, etc, see the 
L<CoreSchemaAdmin|Catalyst::Plugin::RapidApp::CoreSchemaAdmin> plugin.

=head1 AUTH CONTROLLER

The AuthCore plugin automatically injects an L<Auth|Catalyst::Plugin::RapidApp::AuthCore::Controller::Auth>
controller at C</auth> in the Catalyst application. This controller implements a login (C</auth/login>)
and logout (C</auth/logout>) action.

The C</auth/login> action path handles both the rendering a login form (when accessed via GET) and
the actual login/authentication (when accessed via POST). The login POST should send these params:

=over

=item * 

username

=item * 

password

=item * 

redirect (optional)

=back

A C<redirect> URL can be supplied for the client to redirect to after successful login. The C<redirect>
param can also be supplied to a GET/POST to C</auth/logout> to redirect after logout.

The login form is also internally rendered from other URL paths which are password-protected (which
by default is all Module paths when AuthCore is loaded). The built-in login form template automatically
detects this case and sends the path in C<redirect> with the login POST. This allows RESTful paths
to be accessed and automatically authenticate, if needed, and then continue on to the desired location
thereafter.

=head1 CONFIG

Custom options can be set within the C<'Plugin::RapidApp::AuthCore'> config key in the main
Catalyst application config. All configuration params are optional.

=head2 init_admin_password

Default password to assign to the C<admin> user when initializing a fresh 
L<CoreSchema|Catalyst::Model::RapidApp::CoreSchema> database for the first time. Defaults to

  pass

=head2 passphrase_class

L<Authen::Passphrase> class to use for password hashing. Defaults to C<'BlowfishCrypt'>.
The Authen::Passphrase interface is implemented using the L<DBIx::Class::PassphraseColumn>
component class in the L<CoreSchema|Catalyst::Model::RapidApp::CoreSchema> database.

=head2 passphrase_params

Params supplied to the C<passphrase_class> above. Defaults to:

  {
    cost        => 9,
    salt_random => 1,
  }

=head2 expires

Set the timeout for Session expiration. Defaults to C<3600> (1 hour)

=head2 role_checker

Optional CodeRef used to check user roles. By default, this is just a pass-through to the standard
C<check_user_roles()> function. When AuthCore is active, Modules which are configured with the
C<require_role> param will call the role_checker to verify the current user is allowed before rendering. 
This provides a very simple API for permissions and authorization. More complex authorization rules
simply need to be implemented in code.

The C<require_role> API is utilized by the 
L<CoreSchemaAdmin|Catalyst::Plugin::RapidApp::CoreSchemaAdmin> plugin to restrict access to the 
L<CoreSchema|Catalyst::Model::RapidApp::CoreSchema> database to users with the C<administrator>
role (which will both hide the menu point and block module paths to non-administrator users).

Note that the C<role_checker> is only called by AuthCore-aware code (Modules or custom user-code), 
and doesn't modify the behavior of the standard role methods setup by 
L<Catalyst::Plugin::Authorization::Roles> which is automatically loaded by AuthCore. You can
still call C<check_user_roles()> in your custom controller code which will function in the
normal manner (which performs lookups against the Role tables in the CoreSchema)
regardless of the custom role_checker.


=head1 OVERRIDE CONFIGS

If any of the following configs are supplied, they will completely bypass and override the config
settings above.

=head2 no_validate_passwords

Special temp/admin bool option which when set to a true value will make any supplied password
successfully authenticate for any user. This is useful if you forget the admin password, so
you don't have to either manually edit the C<rapidapp_coreschema.db> database, or delete it
to have it recreated. The setting can also be used if the passphrase settings are changed
(which will break all pre-existing passwords already in the database) to be able to get back
into the app, if needed.

Obviously, this setting would never be used in production.

=head2 credential

To override the C<credential> param supplied to C<Plugin::Authentication>

=head2 store

To override the C<store> param supplied to C<Plugin::Authentication>

=head2 Plugin::Authentication

To completely override the C<Plugin::Authentication> config.

=head2 Plugin::Session

To completely override the C<Plugin::Session> config.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchema>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchemaAdmin>

=item * 

L<Catalyst>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
