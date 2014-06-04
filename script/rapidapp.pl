#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;

use RapidApp::Helper;

my $force    = 0;
my $help     = 0;
my $makefile = 0;
my $scripts  = 0;

my $helpers;

GetOptions(
    'help|?'      => \$help,
    'force|nonew' => \$force,
    'makefile'    => \$makefile,
    'scripts'     => \$scripts,
    'helpers=s'   => \$helpers
);

my $name = shift @ARGV;
my @extra_args = @ARGV;

pod2usage(1) if ( $help || !$name );

my @default_traits = ('TabGui');

sub _traits_list {
  # Get the traits as a CSV list:
  my @list = $helpers ? split(/\,/,$helpers) : @default_traits;
  return map {
    $_ =~ s/^\+// ? $_ : "RapidApp::Helper::Traits::$_";
  } @list;
}

my $helper = RapidApp::Helper->new_with_traits({
    '.newfiles' => !$force,
    'makefile'  => $makefile,
    'scripts'   => $scripts,
    'traits'    => [&_traits_list],
    name        => $name,
    extra_args  => \@extra_args
});
# Pass $ARGV[0] for compatibility with old ::Devel
pod2usage(1) unless $helper->mk_app( $name );

1;

__END__

=head1 NAME

rapidapp.pl - Bootstrap a RapidApp/Catalyst application

=head1 SYNOPSIS

 rapidapp.pl [options] application-name [--] [extra options]

 'rapidapp.pl' creates a skeleton for a new application, and allows you to
 upgrade the skeleton of your old application.

 Options:
   -force      don't create a .new file where a file to be created exists
   -help       display this help and exit
   -makefile   only update Makefile.PL
   -scripts    only update helper scripts

  --helpers   comma-separated list of helper traits (RapidApp::Helper::Traits::*)

 Extra Options:
    When supplying --helpers, extra args can be supplied following -- after the
    application-name. These additional arguments will be processed by helpers
    which accept options.

 application-name must be a valid Perl module name and can include "::", 
 which will be converted to '-' in the project name.


 Examples:
   rapidapp.pl My::App
   rapidapp.pl MyApp
   rapidapp.pl --helpers Templates,TabGui,AuthCore,NavCore MyApp
   rapidapp.pl --helpers RapidDbic MyApp -- --dsn dbi:mysql:database=somedb,root,''
   rapidapp.pl --helpers RapidDbic MyApp -- --from-sqlite /path/to/existing/sqlt.db

=head1 DESCRIPTION

The C<rapidapp.pl> script bootstraps a RapidApp/Catalyst application, creating a
directory structure populated with skeleton files.  

This script is simply an extension on top of C<catalyst.pl>. See L<catalyst>.

=head1 SEE ALSO

L<RapidApp>, L<catalyst>, L<Catalyst::Manual>, L<Catalyst::Manual::Intro>

=cut
