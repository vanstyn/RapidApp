package Catalyst::Plugin::RapidApp::CoreSchemaAdmin;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::RapidDbic';

use RapidApp::Util qw(:all);
use Module::Runtime;

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
    ++$src{SavedState} if ($c->can('_navcore_inject_controller'));
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


__END__

=head1 NAME

Catalyst::Plugin::RapidApp::CoreSchemaAdmin - CRUD access to the CoreSchema via RapidDbic

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ 
   RapidApp::RapidDbic
   RapidApp::AuthCore
   RapidApp::CoreSchemaAdmin
 /;

=head1 DESCRIPTION

This convenience plugin automatically sets up access to 
L<Model::RapidApp::CoreSchema|Catalyst::Model::RapidApp::CoreSchema> 
via the RapidDbic plugin. This is basically just an automatic RapidDbic config.

When used with L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> (which is 
typically the whole reason you would want this plugin in the first place), the RapidApp
Module config option C<require_role> is set by default to C<'administrator'> on the 
automatically configured tree/grids, since the CoreSchema usually contains the 
privileged user database for the app (although, not necessarily).

Also, by default, only CoreSchema sources which are actually in use by a given
Core plugin are configured for access (in the navtree/grids). For instance, the 
"Sessions" grid is only setup when AuthCore is loaded, "Source Default Views" 
is only setup with NavCore, and so on.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp::RapidDbic>

=item *

L<Catalyst::Plugin::RapidApp::AuthCore>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchema>

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
