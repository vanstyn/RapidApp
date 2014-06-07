package RapidApp;
use strict;
use warnings;

our $VERSION = '0.99310';

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

=head1 SYNOPSIS

See L<www.rapidapp.info|http://www.rapidapp.info> and L<RapidApp::Manual> for more information.

  # Create new app named "MyApp" using all the helpers:
  rapidapp.pl --helpers RapidDbic,Templates,TabGui,AuthCore,NavCore MyApp \
    -- --dsn dbi:mysql:database=somedb,root,''

  # Start the test server (default login admin/pass):
  MyApp/script/myapp_server.pl



=head1 DESCRIPTION

This is the main class for the RapidApp web framework. RapidApp is an
extension to L<Catalyst> which provides an extended development stack as well as access
to common out-of-the-box application paradigms, such as a powerful CRUD
front-end for L<DBIx::Class> models.

More documentation TBD.

See the RapidApp website for more infomation and demos: L<http://www.rapidapp.info>

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



