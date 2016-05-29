package RapidApp::Helper;

use strict;
use warnings;

require MooseX::Traits;

use Moose;
extends 'Catalyst::Helper';
with 'MooseX::Traits';

# Preliminary helper script for bootstrapping new Catalyst+RapidApp
# applications... API not yet finalized...

=head1 NAME

RapidApp::Helper - Bootstrap a RapidApp/Catalyst application

=head1 SYNOPSIS

  rapidapp.pl <myappname>

=cut

use RapidApp;
use Path::Class qw/dir file/;

use RapidApp::Util ':all';

# Override these functions to do nothing, because they create files we don't want:
sub _mk_images    { 1 }
sub _mk_favicon   { 1 }
sub _mk_rootclass { 1 }
sub _mk_config    { 1 } #<-- since we don't setup ConfigLoader

# Replace _mk_appclass to call the RapidApp version which is totally
# different from the default:
sub _mk_appclass  { (shift)->_ra_mk_appclass(@_) }

# NEW: unlike our parent, Catalyst::Helper, we no longer support running against
# an existing app/directory. We now check to see if the target directory directory
# already exists, and if it does and is not empty, we error. We also now cleanup
# after ourselves, tracking what we created and removing if an error occured.
around 'mk_app' => sub {
  my ($orig, $self, $name) = @_;
  $name or die "App name is required";
  
  # Copied from parent (Catalyst::Helper) class:
  if(!defined $self->{'dir'}) {
      $self->{dir} = $name;
      $self->{dir} =~ s/\:\:/-/g;
  }
  
  my $dir = dir( $self->{dir} );
  if(-e $dir) {
    die "Error: app target dir '$dir' already exists but is not a directory.\n" unless (-d $dir);
    my @children = $dir->children(no_hidden => 1);
    if(scalar(@children) > 0) {
      die "Error: app target dir '$dir' already exists but is not empty.\n";
    }
    else {
      $self->{_dir_was_empty} = 1;
    }
  }
  else {
    $self->{_dir_not_exist} = 1;
  }
  
  my $ret;
  try {
    $ret = $self->$orig($name);
  }
  catch {
    my $err = shift;
    warn "\nCaught exception:\n$err\n";
    $self->_error_cleanup;
    print "\n";
    die $err;
  };
  
  unless($ret) {
    print "Bootstrap failed.\n";
    $self->_error_cleanup;
  }
  
  return $ret
};


sub _error_cleanup {
  my $self = shift;
  
  if($self->{_dir_was_empty}) {
    my $dir = dir( $self->{dir} );
    if (-d $dir) {
      print "Cleaning up directory $dir ... \n";
      my @children = $dir->children(no_hidden => 1);
      $_->is_dir ? $_->rmtree(1,1) : $_->remove for (@children);
      print "done.\n";
    }
  }
  elsif($self->{_dir_not_exist}) {
    my $dir = dir( $self->{dir} );
    if (-d $dir) {
      print "Removing directory $dir ... \n";
      $dir->rmtree(1,1) and print "done.\n";
    }
  }

}

# Overide the Catalyst _mk_dirs to prevent certain dirs from being created
# (still mostly the same as the catalyst version)
sub _mk_dirs {
    my $self = shift;
    $self->mk_dir( $self->{dir} );
    $self->mk_dir( $self->{script} );
    $self->{lib} = dir( $self->{dir}, 'lib' );
    $self->mk_dir( $self->{lib} );
    $self->{root} = dir( $self->{dir}, 'root' );
    $self->mk_dir( $self->{root} );
    
    # These are made by catalyst.pl whichy we don't want:
    #$self->{static} = dir( $self->{root}, 'static' );
    #$self->mk_dir( $self->{static} );
    #$self->{images} = dir( $self->{static}, 'images' );
    #$self->mk_dir( $self->{images} );
    
    $self->{t} = dir( $self->{dir}, 't' );
    $self->mk_dir( $self->{t} );

    $self->{class} = dir( split( /\:\:/, $self->{name} ) );
    $self->{mod} = dir( $self->{lib}, $self->{class} );
    $self->mk_dir( $self->{mod} );

    if ( $self->{short} ) {
        $self->{m} = dir( $self->{mod}, 'M' );
        $self->mk_dir( $self->{m} );
        $self->{v} = dir( $self->{mod}, 'V' );
        $self->mk_dir( $self->{v} );
        $self->{c} = dir( $self->{mod}, 'C' );
        $self->mk_dir( $self->{c} );
    }
    else {
        $self->{m} = dir( $self->{mod}, 'Model' );
        $self->mk_dir( $self->{m} );
        $self->{v} = dir( $self->{mod}, 'View' );
        $self->mk_dir( $self->{v} );
        $self->{c} = dir( $self->{mod}, 'Controller' );
        $self->mk_dir( $self->{c} );
    }
    
    # We also don't create a Root controller for RapidApp:
    #my $name = $self->{name};
    #$self->{rootname} =
    #  $self->{short} ? "$name\::C::Root" : "$name\::Controller::Root";
    #$self->{base} = dir( $self->{dir} )->absolute;
    
    return $self->_ra_mk_dirs();
}

#########################################
### RapidApp-specific methods follow: ###
#########################################

# extra_args is received by rapidapp.pl and is meant to be available to
# helper traits which support additional options
has 'extra_args', is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]};

# Create extra, RapidApp-specific dirs:
sub _ra_mk_dirs {
  my $self = shift;
  
  # Create local root template dir:
  $self->{ra_templates} = dir( $self->{root}, 'templates' );
  $self->mk_dir( $self->{ra_templates} );

  # Create special asset dirs
  $self->{ra_assets} = dir( $self->{root}, 'assets' );
  $self->mk_dir( $self->{ra_assets} );
  $self->{ra_css} = dir( $self->{ra_assets}, 'css' );
  $self->mk_dir( $self->{ra_css} );
  $self->{ra_icons} = dir( $self->{ra_assets}, 'icons' );
  $self->mk_dir( $self->{ra_icons} );
  $self->{ra_js} = dir( $self->{ra_assets}, 'js' );
  $self->mk_dir( $self->{ra_js} );
  $self->{ra_misc} = dir( $self->{ra_assets}, 'misc' );
  $self->mk_dir( $self->{ra_misc} );
  
  # new devel/ dir for misc development scripts
  $self->{ra_devel} = dir( $self->{dir}, 'devel' );
  $self->mk_dir( $self->{ra_devel} );

}

sub _ra_mk_appclass {
  my $self = shift;
  my $mod  = $self->{mod};
  
  # This is what Catalyst::Helper::_mk_appclass did:
  #return $self->render_sharedir_file( file('lib', 'MyApp.pm.tt'), "$mod.pm" );
  
  my $tpl = file(
    RapidApp->share_dir,
    qw(devel bootstrap MyRapidApp.pm.tt)
  );
  
  confess "Error: template file '$tpl' not found" unless (-f $tpl);
  
  my $contents = $tpl->slurp(iomode =>  "<:raw");
  my $vars = $self->_ra_appclass_tt_vars;
  
  $self->render_file_contents($contents,"$mod.pm",$vars);

  # -- New: also create app.psgi so 'plackup' works w/o arguments
  my $apptpl = file(RapidApp->share_dir,qw(devel bootstrap app.psgi.tt));
  confess "Error: template file '$apptpl' not found" unless (-f $apptpl);
  my $appcontents = $apptpl->slurp(iomode =>  "<:raw");
  $self->render_file_contents($appcontents,file($self->{dir},"app.psgi"),$vars);
  # --
  
  # -- New: also create cpanfile
  my $cftpl = file(RapidApp->share_dir,qw(devel bootstrap cpanfile.tt));
  confess "Error: template file '$cftpl' not found" unless (-f $cftpl);
  my $cfcontents = $cftpl->slurp(iomode =>  "<:raw");
  $self->render_file_contents($cfcontents,file($self->{dir},"cpanfile"),$vars);
  # --
}

sub _ra_appclass_tt_vars {
  my $self = shift;
  return {
    %{$self},
    ra_ver  => $RapidApp::VERSION,
    plugins => [ uniq($self->_ra_catalyst_plugins) ],
    configs => [ $self->_ra_catalyst_configs ]
  };
}

sub _ra_catalyst_plugins {
  my $self = shift;
  return qw(-Debug RapidApp);
}

# Should be an arrayref of strings containing key/vals
# formatted for __PACKAGE__->config( ... )
# TODO: serialize real hahsrefs/structures...
sub _ra_catalyst_configs {
  my $self = shift;
  return (
<<END,
    # The general 'RapidApp' config controls aspects of the special components that
    # are globally injected/mounted into the Catalyst application dispatcher:
    'RapidApp' => {
      ## To change the root RapidApp module to be mounted someplace other than
      ## at the root (/) of the Catalyst app (default is '' which is the root)
      #module_root_namespace => 'adm',

      ## To load additional, custom RapidApp modules (under the root module):
      #load_modules => { somemodule => 'Some::RapidApp::Module::Class' },

      ## To set a custom favicon for all pages generated by RapidApp
      #default_favicon_url => '/assets/rapidapp/misc/static/images/rapidapp_icon_small.ico',
    },
END
,
  );
}



=head1 DESCRIPTION

This module is used by B<rapidapp.pl> to create a set of scripts for a
new RapidApp application.

This module extends L<Catalyst::Helper>.

=cut

1;