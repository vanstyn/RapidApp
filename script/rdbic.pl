#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;

use RapidApp::Helper;

use String::Random;
use File::Spec;
use Path::Class qw( file dir );
use String::CamelCase qw(camelize decamelize wordsplit);

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

my $tmpdir = dir( File::Spec->tmpdir );
my $dsn;
my $port = 3500;


my $name = 'Rdbic::Explorer';

GetOptions(
  'dsn=s'        => \$dsn,
  'port=i'       => \$port,
  'tmpdir=s'     => \$tmpdir,
  'no-cleanup+'  => \$no_cleanup,
);

pod2usage(1) unless ($dsn);

$tmpdir = dir( $tmpdir || File::Spec->tmpdir )->resolve;
die "Error finding tmpdir ('$tmpdir') -- doesn't exist or not a directory" 
  unless (-d $tmpdir);

$tmp = dir( $tmpdir, join('-',
  'rdbic','tmp',
  String::Random->new->randregex('[a-z0-9A-Z]{8}')
));


-d $tmp ? die "tmp dir already exists, aborting" : $tmp->mkpath(1);
die "Error creating temp dir $tmp" unless (-d $tmp);

my $app_dir = $tmp->subdir('Rdbic-Explorer');
$app_dir->mkpath(1);

my $model_name = &_guess_model_name_from_dsn($dsn);

my $helper = RapidApp::Helper->new_with_traits({
    '.newfiles' => 1, 'makefile' => 0, 'scripts' => 0,
    _ra_rapiddbic_opts => {
      dsn            => $dsn,
      'model-name'   => $model_name,
      'schema-class' => join('::',$name,$model_name)
    },
    traits => ['RapidApp::Helper::Traits::RapidDbic'],
    name   => $name,
    dir    => $app_dir,
});

pod2usage(1) unless $helper->mk_app( $name );

{
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
  Catalyst::ScriptRunner->run('Rdbic::Explorer', 'Server');
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
  $dbname = (split(/\./,$name))[0] if ($name && $name =~ /\./);
  
  $dbname
}



1;

__END__

=head1 NAME

rdbic.pl - Instant database CRUD utility using RapidApp/DBIx::Class

=head1 SYNOPSIS

 rdbic.pl --dsn DSN [--port PORT]

 Options:
   --dsn          Valid DBI dsn connect string (required)
   --port         TCP port to use for the test server. Defaults 3500
   --no-cleanup   To leave auto-generated files on-disk after exit

 Examples:
   rdbic.pl --dsn dbi:mysql:database=somedb,root,''
   rdbic.pl --port 4001 --dsn dbi:sqlite:/path/to/sqlt.db

=head1 DESCRIPTION

rdbic.pl is a handy cmd-line utility to fire up new RapidDbic/RapidApp applications for a
given database/DSN on-the-fly, without needing to bootstrap a real app with directory structure. 
Internaly, rdbic.pl simply bootstraps a new application (like rapidapp.pl) but into a temporary 
directory and immediately launches the test server, all in one swoop. 

The temporary files are cleaned up on exit, unless the --no-cleanup option was supplied.

=head1 SEE ALSO

L<RapidApp>, L<rapidapp.pl>

=cut
