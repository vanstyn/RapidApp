package Catalyst::Plugin::RapidApp;
use Moose::Role;
use namespace::autoclean;

use RapidApp;

# Built-in plugins required for all RapidApp Applications:
with qw(
 RapidApp::Role::CatalystApplication
 RapidApp::CatalystX::SimpleCAS
 RapidApp::Role::AssetControllers
);

use RapidApp::AttributeHandlers;

1;

__END__

=head1 NAME

Catalyst::Plugin::RapidApp - main plugin class for RapidApp

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp /;

=head1 DESCRIPTION

This is the primary Catalyst plugin that enables RapidApp in a Catalyst application.

This plugin is loaded automatically by all RapidApp plugins and typically doesn't need to be
loaded directly.

=head1 SEE ALSO

=over

=item *

L<RapidApp>

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

