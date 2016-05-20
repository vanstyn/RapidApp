#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Pod::Usage;

use RapidApp::Helper;

my $force    = 0;
my $help     = 0;
my $makefile = 0;
my $scripts  = 0;
my $dir;

my $helpers;

# We no longer support "upgrading" existing apps like catalyst.pl
# -- no longer accept those options from the command line
GetOptions(
    'help|?'      => \$help,
    #'force|nonew' => \$force,
    #'makefile'    => \$makefile,
    #'scripts'     => \$scripts,
    'helpers=s'   => \$helpers,
    'dir=s'       => \$dir
);

my $name = shift @ARGV;
my @extra_args = @ARGV;

pod2usage(1) if ( $help || !$name );

# Attempt to catch the common error of forgetting the app name with extra args
die "rapidapp.pl: Missing application-name!\n" if ($name =~ /^\-\-/);

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
    ( $dir ? ('dir' => $dir) : () ),
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

 'rapidapp.pl' creates a skeleton for a new RapidApp application

 Options:
  --help      display this help and exit
  --dir       optional custom target directory (must be empty or not exist)
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
   rapidapp.pl --helpers RapidDbic MyApp -- --from-sqlite-ddl my-schema.sql
   rapidapp.pl --helpers RapidDbic MyApp -- --blank-ddl

   rapidapp.pl --helpers RapidDbic MyApp -- \
     --dsn 'dbi:Pg:dbname=foo;host=localhost;port=5432',larry,secretpw \
     --loader-option db_schema='%' --loader-option generate_pod=1 \
     --connect-option quote_names=0

   rapidapp.pl --helpers RapidDbic MyApp -- --dsn \
     'dbi:ODBC:Driver=TDS;TDS_Version=7.0;Server=10.1.2.3;Port=1433;Database=Blah',sa,topsecret \


=head1 DESCRIPTION

The C<rapidapp.pl> script bootstraps a RapidApp/Catalyst application, creating a
directory structure populated with skeleton files.  

This script is simply an extension on top of C<catalyst.pl>. See L<catalyst>.

=head1 SEE ALSO

L<RapidApp>, L<rdbic.pl>, L<catalyst>, L<Catalyst::Manual>, L<Catalyst::Manual::Intro>

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
