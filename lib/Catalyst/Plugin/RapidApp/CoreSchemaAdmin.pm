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
  
  # TODO: add support for a merged config
  $config->{configs}->{'RapidApp::CoreSchema'} = {
    grid_params => {
      '*defaults' => {
        updatable_colspec => ['*'],
        creatable_colspec => ['*'],
        destroyable_relspec => ['*'],
      },
      Role => {
        no_page => 1,
        persist_immediately => {
          create => \0,
          update => \0,
          destroy	=> \0
        },
        extra_extconfig => { use_add_form => \0 }
      }
    }
  };
  
};


1;