package Rapi;

use strict;
use warnings;

1;


__END__

=pod

=head1 NAME

Rapi - Namespace for RapidApp-based apps

=head1 DESCRIPTION

This is the designated namespace for applications which are based on RapidApp
and will be distributed via CPAN. The idea is that these applications will
support their own bootstrap functionality (like L<rapidapp.pl>, but be 
specific to the given app). 

The I<plan> is to create a C<rapi.pl> to call into this bootstrap API, such as:

 # Create.bootstrap a new Rapi::CMS app named My::CmsApp:
 rapi.pl CMS My::CmsApp

B<Note that this I<doesn't> exist yet...>

=head1 SEE ALSO

=over

=item *

L<RapidApp>

=back

=cut

=head1 SUPPORT
 
IRC:
 
    Join #rapidapp on irc.perl.org.

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
