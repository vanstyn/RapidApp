package RapidApp;
use strict;
use warnings;

our $VERSION = 0.99017;

use Carp::Clan;

# ABSTRACT: Turnkey ajaxy webapps

use File::ShareDir qw(dist_dir);

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}

1;


__END__

=pod

=head1 NAME

RapidApp - Turnkey ajaxy webapps

=head1 DESCRIPTION

Preliminary release of the RapidApp framework. More documentation TBD.

For more information and example usage, please see the RapidApp 
homepage: L<http://www.rapidapp.info>.


=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



