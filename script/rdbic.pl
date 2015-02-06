#!/usr/bin/perl

use strict;
use Getopt::Long;
use Pod::Usage;

use File::Spec;
use Path::Class qw( file dir );

use Plack::Runner;
use Plack::App::RapidApp::rDbic;

use RapidApp::Include qw(sugar perlutil);

# Special case - move cuddled '-I' arg from post to last so 
# that dbi arg logic can still work (as the second arg)
push @ARGV, (shift @ARGV) if($ARGV[0] && $ARGV[0] =~ /^\-I\S+/);

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

my $schema_class;
my $no_cleanup   = 0;
my $help         = 0;
my $name         = 'rDbicServer';
my $crud_profile = 'editable';
my $tmpdir       = dir( File::Spec->tmpdir );
my $port         = 3500;
my $run_webapi   = 0;
my $includes     = [];
my $metakeys;

# From 'prove': Allow cuddling the paths with -I, -M and -e
@ARGV = map { /^(-[IMe])(.+)/ ? ($1,$2) : $_ } @ARGV;

GetOptions(
  'help+'           => \$help,
  'dsn=s'           => \$dsn,
  'schema-class=s'  => \$schema_class,
  'port=i'          => \$port,
  'tmpdir=s'        => \$tmpdir,
  'no-cleanup+'     => \$no_cleanup,
  'app-class=s'     => \$name,
  'crud-profile=s'  => \$crud_profile,
  'run-webapi+'     => \$run_webapi,
  'I=s@'            => $includes,
  'metakeys=s'      => \$metakeys
);

pod2usage(1) if ($help || !$dsn);


if (@$includes) {
  require lib;
  lib->import(@$includes);
}

{

  my $cnf = {
    app_namespace    => $name,
    dsn              => $dsn,
    tmpdir           => $tmpdir,
    no_cleanup       => $no_cleanup,
    crud_profile     => $crud_profile,
    isolate_app_tmp  => 1,
    metakeys         => $metakeys
  };
  
  $cnf->{schema_class} = $schema_class if ($schema_class);

  my $App = Plack::App::RapidApp::rDbic->new( $cnf );

  print "\n\n";

  my $psgi = $run_webapi
    ? &_webapi_psgi($App)
    : $App->to_app;

  my $runner = Plack::Runner->new;
  $runner->parse_options('--port',$port);

  $runner->run($psgi);

}

sub _webapi_psgi {
  my $App = shift;

  print "Running WebAPI::DBIC::WebApp/HAL-Browser...\n";

  use Plack::Builder;

  Module::Runtime::require_module('WebAPI::DBIC::WebApp');
  Module::Runtime::require_module('Plack::App::File');
  Module::Runtime::require_module('Alien::Web::HalBrowser');

  my $hal_dir = Alien::Web::HalBrowser->dir;
  
  my $model = $App->model_class;
  Module::Runtime::require_module($model);
  
  my $connect_info = $model->config->{connect_info};
  my $schema_class = $model->config->{schema_class};
  
  Module::Runtime::require_module($schema_class);
  
  my $schema = $schema_class->connect(
    $connect_info->{dsn},
    $connect_info->{user},
    $connect_info->{password}
  );
  
  my $app = WebAPI::DBIC::WebApp->new({
    schema         => $schema,
    writable       => $crud_profile eq 'read-only' ? 0 : 1,
    http_auth_type => 'none'
  })->to_psgi_app;

  my $app_prefix = "/webapi-dbic";
  
  my $plack = builder {
    enable "SimpleLogger";  # show on STDERR

    mount "$app_prefix/" => builder {
        mount "/browser" => Plack::App::File->new(root => "$hal_dir")->to_app;
        mount "/" => $app;
    };

    # root redirect for discovery - redirect to API
    mount "/" => sub { [ 302, [ Location => "$app_prefix/" ], [ ] ] };
  };
  
  return $plack
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
   --schema-class  DBIC schema class name (blank/non-existant to auto-generate with Schema::Loader)
   --port          Local TCP port to use for the test server (defaults to 3500)
   --tmpdir        To use a different dir than is returned by File::Spec->tmpdir()
   --no-cleanup    To leave auto-generated files on-disk after exit (in tmpdir)
   --app-class     Name to use for the generated app (defaults to 'rDbicServer')
   --run-webapi    EXPERIMENTAL: Run WebAPI::DBIC w/ HAL Browser instead of RapidApp
   --metakeys      EXPERIMENTAL: Path to a RapidApp::Util::MetaKeys data file

   --crud-profile  One of five choices to broadly control CRUD interface behavior (see below)

    -I  Specifies Perl library include paths, like "perl"'s -I option. You
        may add multiple paths by using this option multiple times.

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

   rdbic.pl my_sqlt.db -Ilib --schema-class My::Existing::Schema

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

C<rdbic.pl> is a wrapper around L<Plack::App::RapidApp::rDbic> which can be used 
directly in Plack-based setups and provides additional options and functionality not exposed in 
this script. 

See L<Plack::App::RapidApp::rDbic> for more information.

The C<rdbic.pl> script and L<rDbic|Plack::App::RapidApp::rDbic> Plack App were also featured in the 
2014 Catalyst Advent Calendar:

=over

=item * 

L<Day 16 - "Instant database admin tool with RapidApp and rdbic.pl"|http://www.catalystframework.org/calendar/2014/16>

=item * 

L<Day 17 - "The Plack::App::RapidApp::rDbic interface to RapidApp"|http://www.catalystframework.org/calendar/2014/17>

=back

=head1 SEE ALSO

L<RapidApp>, L<rapidapp.pl>, L<Plack::App::RapidApp::rDbic>

=cut
