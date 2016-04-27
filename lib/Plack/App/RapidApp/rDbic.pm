package Plack::App::RapidApp::rDbic;
use strict;
use warnings;

# ABSTRACT: Plack::App interface to rDbic

use Moo;
extends 'Plack::Component';

use Types::Standard qw(:all);

use File::Temp;

# Doing this so our temp dirs still get cleaned up if the user does a Ctrl-C...
# todo - this might be overstepping, but what else can be done??
$SIG{INT} ||= sub { exit };

use RapidApp::Helper;
use String::Random;
use File::Spec;
use Path::Class qw( file dir );
use String::CamelCase qw(camelize decamelize wordsplit);
use Module::Runtime;
use Catalyst::Utils;
use Class::Load 'is_class_loaded';

use RapidApp::Util qw(:all);

has 'connect_info', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my ($dsn,$user,$pass) = $self->has_schema
    ? ('dbi:SQLite::memory:','','')
    : split(/\,/,$self->dsn,3);
    
  return {
    dsn       => $dsn,
    user      => $user || '',
    password  => $pass || ''
  }
}, isa => HashRef, predicate => 1, coerce => \&_coerce_connect_info;

has 'dsn', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  ( $self->has_schema ||
    $self->has_connect_info
  ) or die "Must supply either dsn or connect_info or schema";
  
  my $info = $self->connect_info;
  
  my $dsn = $info->{dsn} or die "dsn must be supplied in connect_info";
  return $dsn unless ($info->{user} || $info->{user} ne '');
  
  join(',',$dsn, (
    grep { $_ && $_ ne '' }
    $info->{user}, $info->{password}
  ))
  
}, isa => Str, predicate => 1;

has 'crud_profile',
  isa => Enum[qw/editable edit-instant edit-gridadd ed-inst-gridadd read-only/],
  is => 'ro', default => sub { 'editable' };

has 'total_counts_off', is => 'ro', isa => Bool, default => 0;

has 'no_cleanup',      is => 'ro', isa => Bool, default => sub {0};
has 'isolate_app_tmp', is => 'ro', isa => Bool, default => 0;

has 'metakeys', is => 'ro', isa => Maybe[Any], default => sub { undef };

has 'limit_tables_re',    is => 'ro', isa => Maybe[Str], default => sub { undef };
has 'limit_schemas_re',   is => 'ro', isa => Maybe[Str], default => sub { undef };
has 'exclude_tables_re',  is => 'ro', isa => Maybe[Str], default => sub { undef };
has 'exclude_schemas_re', is => 'ro', isa => Maybe[Str], default => sub { undef };

has 'loader_options',  is => 'ro', isa => ArrayRef[Str], default => sub { [] };
has 'connect_options', is => 'ro', isa => ArrayRef[Str], default => sub { [] };


has '_def_ns_pfx', is => 'ro', isa => Str, default => sub { 'rDbicApp' };

has 'app_namespace', is => 'ro', isa => Str,  lazy => 1, default => sub { 
  my $self = shift;
  my ($class, $i) = ($self->_def_ns_pfx,0);
  $class = join('',$self->_def_ns_pfx,++$i) while( is_class_loaded $class );
  $class
};


has 'schema', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->prepare_app;
  $self->app_namespace->model($self->model_name)->schema
}, isa => InstanceOf['DBIx::Class::Schema'], predicate => 1;

has 'schema_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->has_schema 
    ? blessed $self->schema
    : join('::',$self->app_namespace,$self->model_name)
}, isa => Str, predicate => 1;


has 'tmpdir', 
  is      => 'ro', predicate => 1, 
  isa     => InstanceOf['Path::Class::Dir'],
  coerce  => sub { dir( $_[0] ) },
  default => sub { File::Spec->tmpdir };

has 'workdir', is => 'ro', lazy => 1, predicate => 1, default => sub {
  my $self = shift;
  
  -d $self->tmpdir or die "tmpdir doesn't exist";
  
  my $tmp = dir( File::Temp::tempdir(
    'rdbic-tmp-XXXXX',
    DIR      => $self->tmpdir,
    CLEANUP  => !$self->no_cleanup,
    UNLINK   => 1
  ));
  
  $tmp
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])};

has 'app_dir', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $name = $self->app_namespace;
  $name =~ s/\:\:/\-/g;
  
  my $app_dir = $self->workdir->subdir( $name );
  $app_dir->mkpath(1);
  
  $app_dir
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])}, init_arg => undef;


has 'local_tmp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $tmp = $self->workdir->subdir( 'tmp' );
  $tmp->mkpath(1);
  
  $tmp
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])};

has 'app_tmp', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  $self->isolate_app_tmp
    ? $self->local_tmp
    : dir( Catalyst::Utils::class2tempdir( $self->app_namespace ) )
  
}, isa => InstanceOf['Path::Class::Dir'], coerce => sub {dir($_[0])}, init_arg => undef;


has 'model_name', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  &_guess_model_name_from_dsn( $self->dsn )
}, predicate => 1;

has 'model_class', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $class = join('::',$self->app_namespace,'Model',$self->model_name);
  Module::Runtime::require_module($class);
  $class
}, isa => ClassName, init_arg => undef;

has 'model_config', is => 'ro', isa => Maybe[HashRef], default => sub { undef };


sub BUILD {
  my $self = shift;
  
  my $tempdir = $self->app_tmp->stringify;
  
  # Override function used to determine tempdir:
  no warnings 'redefine';
  local *Catalyst::Utils::class2tempdir = sub { $tempdir };
  
  # init:
  $self->_bootstrap
}


has '_catalyst_psgi_app', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  
  my $name = $self->app_namespace;
  
  # Handle user-supplied, existing/connected schema object:
  if($self->has_schema) {
  
    ##  -----
    ## Hackish/abusive (but effective) way to set 'quote_names' if not already set, after
    ## the fact. This code is no longer enabled as of GH Issue #99 where we dropped the
    ## hard quote_names requirement
    #unless($self->schema->storage->_sql_maker_opts->{quote_names}) {
    #  warn join('',
    #    "Warning: Applying 'quote_names' option to storage object on schema ",
    #    blessed $self->schema
    #  );
    #  $self->schema->storage->_sql_maker_opts->{quote_names} = 1;
    #  $self->schema->storage->_sql_maker(undef);
    #  $self->schema->storage->sql_maker;
    #};
    ## -----
  
    # These override hacks are needed to set the existing schema object
    # and stop Model::DBIC from changing the existing storage/connection.
    no warnings 'redefine';
    local *DBIx::Class::Schema::connection = sub { shift };
    local *Catalyst::Model::DBIC::Schema::setup = sub {
      my $o = shift;
      $o->schema( $self->schema );
    };
    
    Module::Runtime::require_module($name);
  }
  else {
    Module::Runtime::require_module($name);
  }

  $name->apply_default_middlewares( $name->psgi_app )

}, isa => CodeRef, init_arg => undef;

# Init:
sub prepare_app {
  my $self = shift;
  
  # Override function used to determine tempdir:
  no warnings 'redefine';
  local *Catalyst::Utils::class2tempdir = sub { $self->app_tmp->stringify };

 $self->_catalyst_psgi_app 
}


sub call {
  my ($self, $env) = @_;

  # Override function used to determine tempdir:
  no warnings 'redefine';
  local *Catalyst::Utils::class2tempdir = sub { $self->app_tmp->stringify };

  $self->_catalyst_psgi_app->($env);
}

sub _bootstrap {
  my $self = shift;
  
  my $name = $self->app_namespace;
  
  die "App class namespace '$name' already loaded!" if (is_class_loaded $name);
  
  my @keys = qw/metakeys limit_schemas_re exclude_schemas_re limit_tables_re exclude_tables_re/;
  my $extra = { map { $_ => scalar $self->$_ } @keys };
  
  $extra->{'loader-option'}  = $self->loader_options;
  $extra->{'connect-option'} = $self->connect_options;

  my $helper = RapidApp::Helper->new_with_traits({
      '.newfiles' => 1, 'makefile' => 0, 'scripts' => 0,
      _ra_rapiddbic_opts => {
        dsn            => $self->dsn,
        'model-name'   => $self->model_name,
        'schema-class' => $self->schema_class,
        crud_profile   => $self->crud_profile,
        total_counts_off => $self->total_counts_off,
        %$extra
      },
      traits => ['RapidApp::Helper::Traits::RapidDbic'],
      name   => $name,
      dir    => $self->app_dir,
  });
  
  $helper->mk_app( $name ) or die "mk_app failed";
  
  if (my $config = $self->model_config) {
    my $new_cfg = Catalyst::Utils::merge_hashes(
      $self->model_class->config || {},
      $config
    );
    $self->model_class->config( $new_cfg );
  }
  
  if($self->has_connect_info) {
    my $new_info = Catalyst::Utils::merge_hashes(
      $self->model_class->config->{connect_info} || {},
      $self->connect_info
    );
    $self->model_class->config( connect_info => $new_info );
  }
  
}




sub DEMOLISH {
  my $self = shift;
  
  if($self->has_workdir && -d $self->workdir) {
    my $tmp = $self->workdir;
    if($self->no_cleanup) {
      print STDERR "\nLeaving temporary workdir '$tmp' ('no_cleanup' enabled)\n";
    }
    # This is now done for us by File::Temp
    #else {
    #  print STDERR "\nRemoving temporary workdir '$tmp' ... ";
    #  $tmp->rmtree;
    #  -d $tmp 
    #    ? die "Unknown error removing $tmp." 
    #    : print STDERR "done.\n"
    #}
  }
}



sub _guess_model_name_from_dsn {
  my $odsn = shift;
  
  # strip username/password if present
  my $dsn = (split(/,/,$odsn))[0];
  
  # camelize doesn't handle '-' for us but its a bad class name! (GitHub Issue #124)
  $dsn =~ s/\-/_/g; 
  
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

sub _coerce_connect_info {
  my $arg = $_[0];
  
  $arg && ref $arg eq 'ARRAY' ? do {
    my ($dsn,$user,$pass,$attrs,$extra) = @$arg;
    $attrs ||= {};
    $extra ||= {};
    die "4th connect_info argument, if defined, must be a HashRef" unless (ref $attrs eq 'HASH');
    die "5th connect_info argument, if defined, must be a HashRef" unless (ref $extra eq 'HASH');
    {
      dsn      => $dsn,
      user     => $user || '',
      password => $pass || '',
      %{ $attrs },
      %{ $extra }
    }
  } : $arg
}

1;

__END__

=head1 NAME

Plack::App::RapidApp::rDbic - Instant database CRUD using RapidApp

=head1 SYNOPSIS

 use Plack::App::RapidApp::rDbic;

 $app = Plack::App::RapidApp::rDbic->new({
   connect_info => {
     dsn      => 'dbi:SQLite:my_sqlt.db',
     user     => '',
     password => ''
   }
 })->to_app;

 # Or, for an existing schema class:
 $app = Plack::App::RapidApp::rDbic->new({
   schema_class => 'My::Schema',
   connect_info => {
     dsn      => 'dbi:SQLite:my_sqlt.db',
     user     => '',
     password => ''
   }
 })->to_app;

 # For an existing schema connection:
 my $schema = My::Schema->connect('dbi:SQLite:my_sqlt.db');
 $app = Plack::App::RapidApp::rDbic->new({
   schema => $schema
 })->to_app;

=head1 DESCRIPTION

This module provides a Plack interface to a runtime-generated database CRUD application. 
It bootstraps and loads a fully working L<RapidApp> application with a 
L<RapidDbic|Catalyst::Plugin::RapidApp::RapidDbic> configuration for an arbitrary database, which 
can be supplied as either an existing L<DBIx::Class::Schema> or a simple DBI connect string (dsn) 
to have L<DBIx::Class> schema classes generated for you.

This module is used internally by L<rdbic.pl> which exposes only a portion of the available options 
as a command-line script.

=head1 CONFIGURATION

=head2 connect_info

Your connect_info args normalized to hashref form (with dsn/user/password.) See
L<DBIx::Class::Storage::DBI/connect_info> for more info on the hashref form of
L</connect_info>.

=head2 dsn

Alternative way to supply C<connect_info>, as a string. The database user and password can be 
optionally inlined using commas.

For example:

 dsn => 'dbi:mysql:mydb,dbuser,dbpass'

Is equivalent to:

 connect_info => ['dbi:mysql:mydb','dbuser','dbpass']

Is equivelent to:

 connect_info => {
   dsn      => 'dbi:mysql:mydb',
   user     => 'dbuser',
   password => 'dbpass'
 }

=head2 schema_class

Optional existing L<DBIx::Class::Schema> class name. Leave unconfigured to have the schema classes
generated on-the-fly using L<DBIx::Class::Schema::Loader>.

=head2 schema

Optional alternative existing/connected schema object. This option can be used instead of 
C<connect_info>/C<schema_class>.

=head2 app_namespace

Name of the generated RapidApp/Catalyst app. Defaults to C<rDbicApp>. When multiple instances are
loaded, subsequent names are generated as C<rDbicApp1>, C<rDbicApp2> and so on.

=head2 crud_profile

One of five choices to broadly control CRUD interface behavior:

=over 4

=item editable

B<Default>

Full CRUD is enabled with 'persist_immediately' turned off globally which 
means the user has to click "Save" to apply queued-up changes

=item edit-instant

Full CRUD is enabled with 'persist_immediately' turned on. Changes are
applied as soon as the cell is blurred after making a change

=item edit-gridadd

Same as 'editable' except new rows are added directly to the grid 
instead of displaying an add record form

=item ed-inst-gridadd

Same as 'edit-instant' except new rows are added directly to the grid;
"Save" must still be clicked before the row is actually inserted

=item read-only

No create/update/delete interfaces at all (L<rapidapp.pl> default)

=back

For more fine-grained control, RapidDbic configs can also be applied in C<model_config>.

=head2 no_cleanup

Set to true to prevent the temp C<workdir> from being cleaned up on exit (ignored when C<workdir> 
is manually configured). 

Defaults to false.

=head2 tmpdir

Parent temporary directory. Defaults to C<tmpdir> from L<File::Spec> (usually C</tmp/>)

=head2 workdir

Directory in which to generate temporary application files. If left unconfigured, this is an
automatically generated directory C<'rdbic-tmp-XXXXX'> within C<tmpdir> which is automatically 
cleaned/removed unless C<no_cleanup> is true.



=head2 isolate_app_tmp

Set to true to override the location used for Catalyst temporary files to be contained within
the C<workdir> instead of within the system temp. This is useful to avoid leaving temporary
files behind, but will slow startup because the asset files will be generated on each load.

Defaults to false, but set to true in the L<rdbic.pl> script.

=head2 local_tmp

Directory to use for C<app_tmp> when C<isolate_app_tmp> is true. Defaults to C<tmp/> within the
C<workdir>

=head2 model_name

Name of the C<Model::DBIC> in the generated app. Defaults to an auto-generated name based on the 
schema/dsn

=head2 model_config

Optional extra config to apply to the C<Model::DBIC> in the generated app. This is useful to be 
able to customize RapidDbic configs (See L<Catalyst::Plugin::RapidApp::RapidDbic>)

=head1 METHODS

=head2 to_app

PSGI C<$app> CodeRef. Derives from L<Plack::Component>

=head2 model_class

Full class name of the C<Model::DBIC> in the generated app.

=head2 app_dir

Home directory for the generated RapidApp/Catalyst app. This will be the app name within the 
C<workdir>

=head2 app_tmp

The temporary directory used by the generated RapidApp/Catalyst app. If C<isolate_app_tmp> is
true this will be within the C<workdir>, or whatever directory is set in C<local_tmp>. 
Otherwise it is the standard location returned by C<Catalyst::Utils::class2tempdir> for
the generated app (which is not cleaned up).

=head2 loader_options

Optional ArrayRef of loader_options which will be passed to the Schema::Loader. These should
be supplied as a list of name=value pairs, for example:

  loader_options => [qw/db_schema='%' generate_pod=1/]

This has the same effect as C<-o> options supplied to L<dbicdump>. For a complete list of
suported options, see L<DBIx::Class::Schema::Loader::Base>.

=head2 connect_options

Optional ArrayRef of connect_options to be added to the C<%extra_attributes> of the C<connect_info>.
(See L<DBIx::Class::Storage::DBI/connect_info>). Like C<loader_options>, these should be supplied 
as a list of name=value pairs, for example:

  connect_options => [qw/quote_names=0 mysql_enable_utf8=0/]

Note: the options in the above example are both set to C<'1'> by default (second only for MySQL).
So the above example is how you would go about turning these options off if needed for some reason.

=head2 total_counts_off

If set to true, grids will be initialized with the total count turned off (but they can still
be turned back on). Defaults to false (0)

=head1 SEE ALSO

=over

=item *

L<rdbic.pl>

=item * 

L<RapidApp>

=item * 

L<Plack::Component>

=item * 

L<Catalyst Advent 2014 - Day 16|http://www.catalystframework.org/calendar/2014/16>

=item * 

L<Catalyst Advent 2014 - Day 17|http://www.catalystframework.org/calendar/2014/17>

=back


=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


