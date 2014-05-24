#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;

use RapidApp::Helper;

my $force    = 0;
my $help     = 0;
my $makefile = 0;
my $scripts  = 0;

GetOptions(
    'help|?'      => \$help,
    'force|nonew' => \$force,
    'makefile'    => \$makefile,
    'scripts'     => \$scripts,
);

pod2usage(1) if ( $help || !$ARGV[0] );

my $helper = RapidApp::Helper->new(
    {
        '.newfiles' => !$force,
        'makefile'  => $makefile,
        'scripts'   => $scripts,
        name => $ARGV[0],
    }
);
# Pass $ARGV[0] for compatibility with old ::Devel
pod2usage(1) unless $helper->mk_app( $ARGV[0] );

1;

__END__

=head1 NAME

rapidapp.pl - Bootstrap a RapidApp/Catalyst application

=head1 SYNOPSIS

rapidapp.pl [options] application-name

'rapidapp.pl' creates a skeleton for a new application, and allows you to
upgrade the skeleton of your old application.

 Options:
   -force      don't create a .new file where a file to be created exists
   -help       display this help and exit
   -makefile   only update Makefile.PL
   -scripts    only update helper scripts

 application-name must be a valid Perl module name and can include "::", 
 which will be converted to '-' in the project name.


 Examples:
    rapidapp.pl My::App
    rapidapp.pl MyApp

=head1 DESCRIPTION

The C<rapidapp.pl> script bootstraps a RapidApp/Catalyst application, creating a
directory structure populated with skeleton files.  

This script is simply an extension on top of C<catalyst.pl>. See L<catalyst>.

=head1 SEE ALSO

L<RapidApp>, L<catalyst>, L<Catalyst::Manual>, L<Catalyst::Manual::Intro>

=cut
