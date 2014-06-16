package Catalyst::Plugin::RapidApp::CoreSchema;
use Moose::Role;
use namespace::autoclean;

use strict;
use warnings;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
use CatalystX::InjectComponent;

# setupRapidApp is the main function which injects components
after 'setupRapidApp' => sub {
  my $c = shift;
  $c->injectUnlessExist(
    'Catalyst::Model::RapidApp::CoreSchema',
    'Model::RapidApp::CoreSchema'
  );
};

1;


__END__

=head1 NAME

Catalyst::Plugin::RapidApp::CoreSchema - Injects the CoreSchema model

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp::CoreSchema /;

=head1 DESCRIPTION

This is the base RapidApp/Catalyst plugin which sets up the "CoreSchema" database
for use as the common persistence store for multiple optional
"Core" plugins, such as L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> and 
L<NavCore|Catalyst::Plugin::RapidApp::NavCore>.

All plugins which use the CoreSchema and provide actual end-user features automatically
load this plugin, so it should never need to be loaded manually/directly.

This plugin simply injects the special DBIC-based 
L<Model::RapidApp::CoreSchema|Catalyst::Model::RapidApp::CoreSchema>
into the application to be available as:

 $c->model('RapidApp::CoreSchema');

With the default configuration, the L<Model::RapidApp::CoreSchema|Catalyst::Model::RapidApp::CoreSchema> 
automatically initializes and deploys itself to an SQLite database file in the root of 
the application named C<rapidapp_coreschema.db>.

=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<Catalyst::Model::RapidApp::CoreSchema>

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
