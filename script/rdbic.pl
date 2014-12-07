#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;

use RapidApp::Helper;

use String::Random;
use File::Spec;
use Path::Class qw( file dir );
use String::CamelCase qw(camelize decamelize wordsplit);
use Module::Runtime;

use RapidApp::Include qw(sugar perlutil);

################################################################################
my $tmp;
my $no_cleanup = 0;
my $cleanup_recur = 0;

sub _cleanup_exit {
  exit if $cleanup_recur++;
  if($tmp && -d $tmp) {
    if($no_cleanup) {
      print "\nLeaving temporary directory '$tmp' ('no-cleanup' enabled)\n";
    }
    else {
      print "\nRemoving temporary directory '$tmp' ... ";
      $tmp->rmtree;
      -d $tmp ? die "Unknown error removing $tmp." : print "done.\n";
    }
  }
  exit;
}

END { &_cleanup_exit };
$SIG{$_} = \&_cleanup_exit for qw(INT KILL TERM HUP QUIT ABRT);
################################################################################


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

$tmpdir = dir( $tmpdir || File::Spec->tmpdir )->resolve;
die "Error finding tmpdir ('$tmpdir') -- doesn't exist or not a directory" 
  unless (-d $tmpdir);

$tmp = dir( $tmpdir, join('-',
  'rdbic','tmp',
  String::Random->new->randregex('[a-z0-9A-Z]{8}')
));


-d $tmp ? die "tmp dir already exists, aborting" : $tmp->mkpath(1);
die "Error creating temp dir $tmp" unless (-d $tmp);

my $app_dir = $tmp->subdir($name);
$app_dir->mkpath(1);

my $model_name = &_guess_model_name_from_dsn($dsn);
my $schema_class = join('::',$name,$model_name);

my $helper = RapidApp::Helper->new_with_traits({
    '.newfiles' => 1, 'makefile' => 0, 'scripts' => 0,
    _ra_rapiddbic_opts => {
      dsn            => $dsn,
      'model-name'   => $model_name,
      'schema-class' => $schema_class,
      crud_profile   => $crud_profile
    },
    traits => ['RapidApp::Helper::Traits::RapidDbic'],
    name   => $name,
    dir    => $app_dir,
});

pod2usage(1) unless $helper->mk_app( $name );

if($run_webapi) {
  print "\n\nRunning WebAPI::DBIC::WebApp/HAL-Browser...\n";
  &_run_webapi_webapp;
}
else {
  print "\n\nStarting Catalyst test server...\n\n";

  no warnings 'redefine';

  # Disable warnings about GetOpt
  require Catalyst::Script::Server;
  local *Catalyst::Script::Server::_getopt_spec_warnings = sub {};
  
  my $app_tmp = $tmp->subdir('tmp');
  $app_tmp->mkpath(1);

  # Override function used to determine tempdir:
  local *Catalyst::Utils::class2tempdir  = sub { $app_tmp->stringify };
  
  local $ENV{CATALYST_PORT} = $port;
  local $ENV{CATALYST_SCRIPT_GEN} = 40;
  
  require Catalyst::ScriptRunner;
  Catalyst::ScriptRunner->run($name, 'Server');
}


# Should never get here:

&_cleanup_exit;


####################################################

sub _guess_model_name_from_dsn {
  my $odsn = shift;
  
  # strip username/password if present
  my $dsn = (split(/,/,$odsn))[0];
  
  my $name = 'DB'; #<-- default
  
  my ($dbi,$drv,@extra) = split(/\:/,$dsn);
  
  die "Invalid dsn string" unless (
    $dbi && $dbi eq 'dbi'
    && $drv && scalar(@extra) > 0
  );
  
  $name = camelize($drv); #<-- second default
  
  # We don't know how to handle more than 3 colon-separated vals
  return $name unless (scalar(@extra) == 1);
  
  my $parm_info = shift @extra;
  
  # 3rd default, is the last part of the dsn is already safe chars:
  return camelize($parm_info) if ($parm_info =~ /^[0-9a-zA-Z\-\_]+$/);
  
  $name = &_normalize_dbname($parm_info) || $drv;
  
  # Fall back to the driver name unless $name contains only simple/safe chars
  camelize( $name =~ /^[0-9a-zA-Z\-\_]+$/ ? $name : $drv )
  
}

sub _normalize_dbname {
  my $dbname = shift;
  
  if($dbname =~ /\;/) {
    my %cfg = map {
      my ($k,$v) = split(/\=/,$_,2);
      $k && $v ? ($k => $v) : ()
    } split(/\;/,$dbname);
    
    my $name = $cfg{dbname} || $cfg{database};
    
    return &_normalize_dbname($name) if ($name);
  }
  elsif($dbname =~ /\//) {
    my @parts = split(/\//,$dbname);
    $dbname = pop @parts;
  }
  
  # strip after . (i.e. Foo.Db becomes Foo)
  $dbname = (split(/\./,$dbname))[0] if ($dbname && $dbname =~ /\./);
  
  $dbname
}


sub _run_webapi_webapp {

  use Plack::Builder;
  use Plack::Runner;

  Module::Runtime::require_module('WebAPI::DBIC::WebApp');
  Module::Runtime::require_module('Plack::App::File');
  Module::Runtime::require_module('Alien::Web::HalBrowser');

  my $hal_dir = Alien::Web::HalBrowser->dir;
  
  my $model = join('::',$name,'Model',$model_name);
  Module::Runtime::require_module($model);
  
  my $connect_info = $model->config->{connect_info};
  
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
  
  my $runner = Plack::Runner->new;
  $runner->parse_options('--port',$port);
  
  $runner->run($plack);
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
