package RapidApp;
use strict;
use warnings;

our $VERSION = '0.99203';

# ABSTRACT: Turnkey ajaxy webapps

use Carp::Clan;
use Time::HiRes qw(gettimeofday);
use File::ShareDir qw(dist_dir);

# For statistics:
our $START = [gettimeofday];

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}

# global variable localized with '$c' automatically to provide
# simple/global API access within all code dispatched by RapidApp
# to be able to identify if there is a current request, and if so
# get the $c object without fuss.
# Note: this is/was also provided by the 'RapidApp::ScopedGlobals' system
# but that system is more complex than it needed to be and is planned
# for deprication/removal in the future.
our $ACTIVE_REQUEST_CONTEXT = undef;

sub active_request_context { $ACTIVE_REQUEST_CONTEXT }



# Private - will be removed in the future:
our $ROOT_MODULE_INSTANCE = undef;
sub _rootModule { $ROOT_MODULE_INSTANCE }

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



