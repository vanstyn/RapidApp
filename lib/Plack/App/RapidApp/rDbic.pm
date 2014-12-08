package Plack::App::RapidApp::rDbic;
use strict;
use warnings;

# ABSTRACT: Plack::App interface to rDbic

use Moo;
extends 'Plack::Component';

use Types::Standard qw(:all);

use RapidApp::Helper;
use String::Random;
use File::Spec;
use Path::Class qw( file dir );
use String::CamelCase qw(camelize decamelize wordsplit);
use Module::Runtime;
use Catalyst::Utils;
use Class::Load 'is_class_loaded';

use RapidApp::Include qw(sugar perlutil);

has 'dsn',          is => 'ro', isa => Str, required => 1;
has 'crud_profile', is => 'ro', isa => Str, default => sub { 'editable' };
has 'no_cleanup',   is => 'ro', isa => Bool, default => sub {0};

has '_def_ns_pfx', is => 'ro', isa => Str, default => sub { 'rDbicApp' };

has 'app_namespace', is => 'ro', isa => Str,  lazy => 1, default => sub { 
  my $self = shift;
  my ($class, $i) = ($self->_def_ns_pfx,0);
  $class = join('',$self->_def_ns_pfx,++$i) while( is_class_loaded $class );
  $class
};

has 'tmpdir', 
  is      => 'ro', predicate => 1, lazy => 1,
  isa     => InstanceOf['Path::Class::Dir'],
  coerce  => sub { dir( $_[0] ) },
  default => sub { File::Spec->tmpdir };

has 'tmp', is => 'ro', lazy => 1, predicate => 1, default => sub {
  my $self = shift;
  
  -d $self->tmpdir or die "tmpdir doesn't exist";
  
  my $tmp = dir( $self->tmpdir, join('-',
    'rdbic','tmp',
    String::Random->new->randregex('[a-z0-9A-Z]{8}')
  ));

  -d $tmp ? die "tmp dir already exists, aborting" : $tmp->mkpath(1);
  die "Error creating temp dir $tmp" unless (-d $tmp);
  
  $tmp
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])}, init_arg => undef;

has 'app_dir', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $name = $self->app_namespace;
  $name =~ s/\:\:/\-/g;
  
  my $app_dir = $self->tmp->subdir( $name );
  $app_dir->mkpath(1);
  
  $app_dir
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])}, init_arg => undef;

has 'isolate_app_tmp', is => 'ro', isa => Bool, default => 0;

has 'app_tmp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  return dir( Catalyst::Utils::class2tempdir( $self->app_namespace ) )
    unless ($self->isolate_app_tmp);
  
  my $app_tmp = $self->tmp->subdir( 'tmp' );
  $app_tmp->mkpath(1);
  
  $app_tmp
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])}, init_arg => undef;


has '_catalyst_psgi_app', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $name = $self->app_namespace;
  $self->app_tmp;
  
  die "App class name '$name' already loaded!" if (is_class_loaded $name);
  
  my $dsn  = $self->dsn;
  
  my $model_name = &_guess_model_name_from_dsn($dsn);
  my $schema_class = join('::',$name,$model_name);

  my $helper = RapidApp::Helper->new_with_traits({
      '.newfiles' => 1, 'makefile' => 0, 'scripts' => 0,
      _ra_rapiddbic_opts => {
        dsn            => $dsn,
        'model-name'   => $model_name,
        'schema-class' => $schema_class,
        crud_profile   => $self->crud_profile
      },
      traits => ['RapidApp::Helper::Traits::RapidDbic'],
      name   => $name,
      dir    => $self->app_dir,
  });
  
  # Override function used to determine tempdir:
  no warnings 'redefine';
  local *Catalyst::Utils::class2tempdir = sub { $self->app_tmp->stringify };
  
  $helper->mk_app( $name ) or die "mk_app failed";
  
  Module::Runtime::require_module($name);
  
  $name->apply_default_middlewares( $name->psgi_app );
  
}, isa => CodeRef, init_arg => undef;


sub call {
  my $self = shift;
  
  # Override function used to determine tempdir:
  no warnings 'redefine';
  local *Catalyst::Utils::class2tempdir = sub { $self->app_tmp->stringify };
  
  $self->_catalyst_psgi_app->(@_);
}


sub BUILD {
  my $self = shift;
  
  # init:
  $self->_catalyst_psgi_app
}



sub DEMOLISH {
  my $self = shift;
  
  if($self->has_tmp && -d $self->tmp) {
    my $tmp = $self->tmp;
    if($self->no_cleanup) {
      print STDERR "\nLeaving temporary directory '$tmp' ('no_cleanup' enabled)\n";
    }
    else {
      print STDERR "\nRemoving temporary directory '$tmp' ... ";
      $tmp->rmtree;
      -d $tmp ? die "Unknown error removing $tmp." : print "done.\n";
    }
  }
}



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




1;