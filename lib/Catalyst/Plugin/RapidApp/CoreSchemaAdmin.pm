package Catalyst::Plugin::RapidApp::CoreSchemaAdmin;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::RapidDbic';

use RapidApp::Include qw(sugar perlutil);
use Module::Runtime;

=pod

=head1 DESCRIPTION

Convenience plugin automatically sets up access to RapidApp::CoreSchema
via the RapidDbic plugin

=cut

before 'setup_components' => sub {
  my $c = shift;
  my $config = $c->config->{'Plugin::RapidApp::CoreSchemaAdmin'} || {};
  
  my $cmp_class = 'Catalyst::Model::RapidApp::CoreSchema';
  Module::Runtime::require_module($cmp_class);
  
  my $cnf = $config->{RapidDbic} || {};

  # Unless the 'all_sources' option is set, limit RapidDbic grids to
  # sources which are actually being used
  unless($config->{all_sources} || $cnf->{limit_sources}) {
    my %src = ();
    ++$src{Session} if ($c->can('session'));
    ++$src{User} and ++$src{Role} if ($c->can('_authcore_load_plugins'));
    ++$src{DefaultView} if ($c->can('_navcore_inject_controller'));
    my @limit_sources = keys %src;
    # If none of the above sources were added, don't configure the CoreSchema
    # tree item for RapidDbic at all:
    return unless (scalar @limit_sources > 0);
    $cnf->{limit_sources} = \@limit_sources;
  }
  
  # By default, set 'require_role' to administrator since this is
  # typically used with AuthCore and only admins should be able to access
  # these system-level configs. Note that no default role_checker is
  # setup when there is no Catalyst user auth/sessions, meaning this has 
  # no effect in that case.
  $cnf->{require_role} ||= 'administrator';
  
  $cnf->{grid_params} ||= {
    '*defaults' => {
      updatable_colspec => ['*'],
      creatable_colspec => ['*'],
      destroyable_relspec => ['*'],
    },
    Role => {
      no_page => 1,
      persist_immediately => { create => \0, update => \0, destroy	=> \0 },
      extra_extconfig => { use_add_form => \0 }
    },
    User => {
      no_page => 1,
      toggle_edit_cells_init_off => 0
    }
  };
  
  $cmp_class->config( RapidDbic => $cnf );
};

1;
