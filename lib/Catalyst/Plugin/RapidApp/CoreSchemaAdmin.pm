package Catalyst::Plugin::RapidApp::CoreSchemaAdmin;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::RapidDbic';

use RapidApp::Include qw(sugar perlutil);

=pod

=head1 DESCRIPTION

Convenience plugin automatically sets up access to RapidApp::CoreSchema
via the RapidDbic plugin

=cut

before 'setup_components' => sub {
  my $c = shift;
  
  my $model = 'RapidApp::CoreSchema';
  
  $c->config->{'Plugin::RapidApp::RapidDbic'} ||= {};
  my $config = $c->config->{'Plugin::RapidApp::RapidDbic'};
  
  $config->{dbic_models} ||= [];
  $config->{configs} ||= {};
  
  my %existing = map {$_=>1} @{$config->{dbic_models}};
  die join("\n",
    "Don't use the CoreSchemaAdmin plugin with a RapidDbic config" .
    "already configured to access the $model model"
  ) if ($existing{$model});
  
  push @{$config->{dbic_models}}, $model;
  
  $config->{configs}->{'RapidApp::CoreSchema'} ||= {};
  my $cnf = $config->{configs}->{'RapidApp::CoreSchema'};
  
  # By default, set 'require_role' to administrator since this is
  # typically used with AuthCore and only admins should be able to access
  # these system-level configs. Note that no default role_checker is
  # setup when there is no Catalyst user auth/sessions, meaning this has 
  # no effect in that case.
  $cnf->{require_role} ||= 'administrator';
  
  # TODO: add support for a merged config
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
  
};


1;