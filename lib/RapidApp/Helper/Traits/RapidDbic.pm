package RapidApp::Helper::Traits::RapidDbic;
use Moose::Role;

use strict;
use warnings;

use RapidApp::Util qw(:all);

use Catalyst::Helper::Model::DBIC::Schema::ForRapidDbic;

use Catalyst::ScriptRunner;
use Path::Class qw/file dir/;
use FindBin;
use List::Util;
use IPC::Cmd qw[can_run run_forked];

requires '_ra_catalyst_plugins';
requires '_ra_catalyst_configs';
requires '_ra_mk_appclass';
requires 'extra_args';

use Getopt::Long qw(GetOptionsFromArray);

sub BUILD {
  my $self = shift;
  
  # Initialize to throw any option errors early:
  $self->_ra_rapiddbic_opts;
}

has '_ra_rapiddbic_opts', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
  my $self = shift;
  my @args = @{$self->extra_args};
  
  my %opts = ();
  GetOptionsFromArray(\@args,\%opts,
    'dsn=s',
    'from-sqlite=s',
    'from-sqlite-ddl=s',
    'loader-option=s@',
    'connect-option=s@'
  );
  
  my $count = 0;
  exists $opts{dsn} and $count++;
  exists $opts{'from-sqlite'} and $count++;
  exists $opts{'from-sqlite-ddl'} and $count++;
  
  die "RapidDbic: must supply --dsn, --from-sqlite or --from-sqlite-ddl option\n" 
    unless($count);
  
  die "RapidDbic: --dsn|--from-sqlite|--from-sqlite-ddl options cannot be used together\n"
    if ($count > 1);
  
  if($opts{'from-sqlite'}) {
    my $sqlt_orig = file($opts{'from-sqlite'});
    die "RapidDbic: --from-sqlite file '$sqlt_orig' not found\n" unless (-f $sqlt_orig);
  }
  elsif($opts{'from-sqlite-ddl'}) {
    can_run('sqlite3') or die "RapidDbic: sqlite3 not found - cannot bootstrap from DDL\n";
    my $ddl = file($opts{'from-sqlite-ddl'});
    die "RapidDbic: --from-sqlite-ddl file '$ddl' not found\n" unless (-f $ddl);
    
    # For safety, if the file is huge its probably not the right thing anyway, setting
    # a 20M limit is still way way huge for what we ever expect which is a few K
    my $size = $ddl->stat->size;
    die "RapidDbic: ddl file '$ddl' size ($size b) exceeds max allowed 20MB limit"
      if($size > 20*1024*1024);
  }
  
  my $name = $self->{name};
  
  $opts{'model-name'}   ||= 'DB';
  $opts{'schema-class'} ||= join('::',$name,$opts{'model-name'});
  
  return \%opts;
};

around _ra_catalyst_plugins => sub {
  my ($orig,$self,@args) = @_;
  
  my @list = $self->$orig(@args);
  
  return grep { 
    $_ ne 'RapidApp' #<-- Base plugin redundant
  } @list, 'RapidApp::RapidDbic';
};


around '_mk_create' => sub {
  my ($orig,$self,@args) = @_;
  
  my $file = $self->$orig(@args) 
    || file($self->{script}, "$self->{appprefix}\_create.pl");

  # Fool FindBin into thinking the app's create script is what's running:
  local $FindBin::Bin = $file->parent->absolute->resolve->stringify;
  
  # And dump/generate the schema and model immediately after the create script
  # was generated (note that we're not actually calling the real create script):
  $self->_ra_rapiddbic_generate_model;
  
  return $file;
};

sub _ra_rapiddbic_generate_model {
  my $self = shift;
  
  my $name = $self->{name};
  my $opts = $self->_ra_rapiddbic_opts;
  
  my @connect_info = $opts->{dsn} ? split(/\,/,$opts->{dsn},3) : ();
  push @connect_info, '' while (scalar(@connect_info) < 3);
  
  if($opts->{'from-sqlite'}) {
    
    my $home = dir( $self->{dir} );
    die "RapidDbic: error finding new app home dir '$home'" unless (-d $home);
    
    my $sqlt_orig = file($opts->{'from-sqlite'});
    my $sqlt = file($home,$sqlt_orig->basename);
    
    if (-f $sqlt) {
      # TODO: support the regenerate/rescan and/or -force cases...
      die "RapidDbic: error - will not overwrite existing file '$sqlt'\n" ;
      #print " exists \"$sqlt\"\n";
    }
    else {
      print "Copying \"$sqlt_orig\" to \"$sqlt\"\n";
      $sqlt_orig->copy_to( $sqlt );
      die "RapidDbic: unexpected error copying '$sqlt_orig' to '$sqlt'" unless (-f $sqlt);
    }

    # We are using the current, *absolute* path to the db file here on purpose. This 
    # will be dynamically converted to be a *runtime* relative path in the actual
    # model class which is created by our DBIC::Schema::ForRapidDbic model helper:
    @connect_info = ( join(':','dbi','SQLite',$sqlt->absolute->resolve->stringify) );
  }
  elsif($opts->{'from-sqlite-ddl'}) {
    
    my $home = dir( $self->{dir} );
    die "RapidDbic: error finding new app home dir '$home'" unless (-d $home);
    
    my $sqldir = $home->subdir('sql');
    $sqldir->mkpath(1) unless (-d $sqldir);
    
    my $ddl_orig = file($opts->{'from-sqlite-ddl'});
    my $ddl = file($sqldir,$ddl_orig->basename);
    
    if (-f $ddl) {
      die "RapidDbic: error - will not overwrite existing file '$ddl'\n" ;
      #print " exists \"$sqlt\"\n";
    }
    else {
      print "Copying \"$ddl_orig\" to \"$ddl\"\n";
      $ddl_orig->copy_to( $ddl );
      die "RapidDbic: unexpected error copying '$ddl_orig' to '$ddl'" unless (-f $ddl);
    }
    
    my $bn = $ddl->basename;
    $bn =~ s/\.(sql|ddl)$//i; # strip extension if its .sql or .ddl
    
    my $sqlt = file($home,$bn . '.db');
    
    if (-f $sqlt) {
      # TODO: support the regenerate/rescan and/or -force cases...
      die "RapidDbic: error - will not overwrite existing file '$sqlt'\n" ;
      #print " exists \"$sqlt\"\n";
    }
    else {
      my $ddl_text = $ddl->slurp;
      my $sqlite3 = can_run('sqlite3') or die 'sqlite3 not available!';
      
      my @cmd = ($sqlite3,$sqlt);
      
      print "  calling command -->  sqlite3 $sqlt < $ddl ";
      
      my $result = run_forked( \@cmd, { child_stdin => $ddl_text });
      my $exit = $result->{exit_code};
      
      print " [exit: $exit]\n";
      
      if($exit) {
        print join("\n",'',"STDERR:",
          $result->{'stderr'},''
        );
        die $result->{err_msg};
      }
    }
    
    -f $sqlt or die "db file '$sqlt' wasn't created; an unknown error has occured.";

    # We are using the current, *absolute* path to the db file here on purpose. This 
    # will be dynamically converted to be a *runtime* relative path in the actual
    # model class which is created by our DBIC::Schema::ForRapidDbic model helper:
    @connect_info = ( join(':','dbi','SQLite',$sqlt->absolute->resolve->stringify) );
  }
  
  my @loader_opts = $opts->{'loader-option'} ? @{$opts->{'loader-option'}} : qw/generate_pod=0/;
  my @connect_opts = ();
  if($opts->{'connect-option'}) {
    @connect_opts = @{$opts->{'connect-option'}};
  }
  else {
    # When there are no user-supplied connect options, set some 
    # sane defaults for certain common DBD driver types:
    if($connect_info[0] && $connect_info[0] =~ /^dbi\:SQLite\:/) {
      # Turn on unicode and forein keys for SQLite:
      @connect_opts = qw/sqlite_unicode=1 on_connect_call=use_foreign_keys/;
    }
    elsif($connect_info[0] && $connect_info[0] =~ /^dbi\:mysql\:/) {
      # Turn on unicode and auto-reconnect for MySQL:
      @connect_opts = qw/mysql_enable_utf8=1 mysql_auto_reconnect=1/;
    }
    # TODO: add default opts for pgsql, etc
    #...
  }
  
  # quote_names is always required for newly generated schemas:
  push @connect_opts, 'quote_names=1' unless (
    List::Util::first { $_ eq 'quote_names=1' } @connect_opts
  );
  
  die "loader-option 'create=dynamic' is not allowed - use create=static" if (
    List::Util::first { $_ eq 'create=dynamic' } @loader_opts
  );
  
  # create=static is always required, and must be the first arg:
  @loader_opts = ('create=static', grep { $_ ne 'create=static' } @loader_opts);
  
  my $schema_class = $opts->{'schema-class'} or die "missing required opt 'schema-class'";
  
  try {
    # If this succeeds we are dealing with an existing schema - clear loader opts
    Module::Runtime::require_module($schema_class);
    @loader_opts = ();
  };

  my @args = (
    'model'                      => $opts->{'model-name'},
    'DBIC::Schema::ForRapidDbic' => $schema_class,
    @loader_opts, @connect_info, @connect_opts
  );
  
  {
    local @ARGV = @args;
    
    # This is ugly but is the cleanest way to pass in extra configs without mucking with
    # the complex arg call structure of the public/legacy API (of Model::DBIC::Schema)
    local $RapidApp::Helper::Traits::RapidDbic::_ra_rapiddbic_opts = $opts;
    print join("\n",
      'Generating DBIC schema/model using create script argument list:',
      "  -------------------------------",
      "  model $opts->{'model-name'}",
      "  DBIC::Schema::ForRapidDbic $opts->{'schema-class'}",
      (map { "     $_" } @loader_opts), 
      "  " . join(' ',@connect_info),
      (map { "     $_" } @connect_opts),
      "  -------------------------------",''
    );
    Catalyst::ScriptRunner->run($name => 'Create');
  }
}


## No longer using these configs in favor of letting the ForRapidDbic create
## script create the config within the individual model (new feature)
#
#around _ra_catalyst_configs => sub {
#  my ($orig,$self,@args) = @_;
#  
#  my $model = $self->_ra_rapiddbic_opts->{'model-name'};
#  
#  my @list = $self->$orig(@args);
#  
#  return ( @list,
#<<END,
#    'Plugin::RapidApp::RapidDbic' => {
#      # This is the only required option:
#      dbic_models => ['$model'],
#      # use only the relationship column of a foreign-key and hide the 
#      # redundant literal column when the names are different:
#      hide_fk_columns => 1,
#      configs => {
#        '$model' => {
#          grid_params => {
#            # The special '*defaults' key applies to all sources at once
#            '*defaults' => {
#              # uncomment these lines to turn on editing in all grids
#              #updatable_colspec   => ['*'],
#              #creatable_colspec   => ['*'],
#              #destroyable_relspec => ['*'],
#            }
#          },
#          TableSpecs => {
#            # Define optional TableSpec configs for each source name here:
#            # ...
#          }
#        },
#      }
#    },
#END
#  );
#
#};

1;
