package Catalyst::Plugin::RapidApp::CoreSchema;
use Moose::Role;
use namespace::autoclean;

=pod

=head1 DESCRIPTION

Base Catalyst Role/Plugin for setting up the CoreSchema model.
This role should be loaded by any modules which use the CoreSchema,
such as AuthCore and NavCore

=cut

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
use CatalystX::InjectComponent;

after 'setup_components' => sub {
  my $c = shift;
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));
};

1;
