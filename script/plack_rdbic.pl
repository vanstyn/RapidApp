#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;

use File::Spec;
use Path::Class qw( file dir );

use Plack::App::RapidApp::rDbic;

use RapidApp::Include qw(sugar perlutil);

my $dsn;

if($ARGV[0] && ! ($ARGV[0] =~ /^\-/) ) {
  if($ARGV[0] =~ /^dbi\:/) {
    # If the first argument is obviously a DBI dsn, use it
    $dsn = shift @ARGV;
  }
  elsif(-f $ARGV[0]) {
    # If the first argument is a path to a real file, assume it is SQLite
    $dsn = join(':','dbi','SQLite',shift @ARGV);
  }
}

sub _cleanup_exit {
  exit 
}

END { &_cleanup_exit };
$SIG{$_} = \&_cleanup_exit for qw(INT KILL TERM HUP QUIT ABRT);


my $no_cleanup;

my $help         = 0;
my $name         = 'rDbicServer';
my $crud_profile = 'editable';
my $tmpdir       = dir( File::Spec->tmpdir );
my $port         = 3500;
my $run_webapi   = 0;

GetOptions(
  'help+'           => \$help,
  'dsn=s'           => \$dsn,
  'port=i'          => \$port,
  'tmpdir=s'        => \$tmpdir,
  'no-cleanup+'     => \$no_cleanup,
  'app-class=s'     => \$name,
  'crud-profile=s'  => \$crud_profile,
  'run-webapi+'     => \$run_webapi
);

pod2usage(1) if ($help || !$dsn);


my $app = Plack::App::RapidApp::rDbic->new({
  #app_namespace => $name,
  dsn => $dsn,
  tmpdir => $tmpdir,
  no_cleanup => $no_cleanup,
  crud_profile => $crud_profile
})->to_app;


if($run_webapi) {
  ...
}
else {

  use Plack::Runner;

  my $runner = Plack::Runner->new;
  $runner->parse_options('--port',$port);
  
  $runner->run($app);
}


1;

__END__

=head1 NAME

rdbic.pl - Instant CRUD webapp for your database using RapidApp/Catalyst/DBIx::Class

=head1 SYNOPSIS

 rdbic.pl DSN[,USER,PW] [options]

 rdbic.pl --dsn DSN[,USER,PW] [options]
 rdbic.pl SQLITE_DB [options]

 Options:
   --help          Display this help screen and exit
   --dsn           Valid DBI dsn connect string (+ ,user,pw) - REQUIRED
   --port          Local TCP port to use for the test server (defaults to 3500)
   --tmpdir        To use a different dir than is returned by File::Spec->tmpdir()
   --no-cleanup    To leave auto-generated files on-disk after exit (in tmpdir)
   --app-class     Name to use for the generated app (defaults to 'rDbicServer')
   --run-webapi    EXPERIMENTAL: Run WebAPI::DBIC w/ HAL Browser instead of RapidApp

   --crud-profile  One of five choices to broadly control CRUD interface behavior (see below)

 CRUD Profiles:
   * editable         Full CRUD is enabled with 'persist_immediately' turned off globally which 
                      means the user has to click "Save" to apply queued-up changes (DEFAULT)

   * edit-instant     Full CRUD is enabled with 'persist_immediately' turned on. Changes are
                      applied as soon as the cell is blurred after making a change

   * edit-gridadd     Same as 'editable' except new rows are added directly to the grid 
                      instead of displaying an add record form

   * ed-inst-gridadd  Same as 'edit-instant' except new rows are added directly to the grid;
                      "Save" must still be clicked before the row is actually inserted

   * read-only        No create/update/delete interfaces at all (rapidapp.pl default)

 Examples:
   rdbic.pl dbi:mysql:dbname,root,''
   rdbic.pl to/any/sqlite_db_file
   rdbic.pl dbi:mysql:somedb,someusr,smepass --port 5005 --tmpdir /foo --no-cleanup

   rdbic.pl --dsn dbi:mysql:database=somedb,root,''
   rdbic.pl --port 4001 --dsn dbi:SQLite:/path/to/sqlt.db
   rdbic.pl --dsn dbi:SQLite:/path/to/sqlt.db --tmpdir . --no-cleanup
   rdbic.pl my_sqlt.db --crud-profile=edit-gridadd
   rdbic.pl dbi:Pg:dbname=foo,usr,1234 --crud-profile=edit-instant
   rdbic.pl dbi:mysql:foo,root,'' --run-webapi

=head1 DESCRIPTION

C<rdbic.pl> is a handy utility which fires up a fully-functional RapidDbic/RapidApp application 
for a given database/DSN on-the-fly with a single shell command. This avoids having to bootstrap 
a real application with a name, config, directory, etc with L<rapidapp.pl> or L<catalyst>. 
All that needs to be supplied to C<rdbic.pl> is a DSN, although additional options are also available.

C<rdbic.pl> can be used to replace tools like Navicat or PhpMyAdmin for a general-purpose database 
client.

Internally, C<rdbic.pl> simply bootstraps a new application using L<RapidApp::Helper> in the same
manner as L<rapidapp.pl>, but the new app is generated in a temporary directory and immediately 
launched using the standard L<Catalyst> test server, all in one swoop.

The generated/temporary files are automatically cleaned up on exit unless the C<--no-cleanup> 
option is supplied.

You can also specify the location of the temporary directory with the C<--tmpdir> option 
(defaults to C</tmp> or whatever is returned by File::Spec->tmpdir). If you combine with 
C<--no-cleanup> you can easily get the full working Catalyst/RapidApp app which was generated, for 
later use. For instance, these options will create and leave the generated app files within the 
current directory:

 --tmpdir . --no-cleanup

A shorthand first argument syntax is also supported. If the first argument looks like a dsn (starts
with 'dbi:') then it will be used as the dsn without having to supply C<--dsn> first. Additionally,
if the first argument is a path to an existing regular file it is assumed to be an SQLite database 
file, and the appropriate dsn (i.e. "dbi:SQLite:$ARGV[0]") is used automatically.

=head1 SEE ALSO

L<RapidApp>, L<rapidapp.pl>

=cut
