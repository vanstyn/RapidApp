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
use List::MoreUtils qw(uniq);

# Override these functions to do nothing, because they create files we don't want:
sub _mk_images    { 1 }
sub _mk_favicon   { 1 }
sub _mk_rootclass { 1 }
sub _mk_config    { 1 } #<-- since we don't setup ConfigLoader

# Replace _mk_appclass to call the RapidApp version which is totally
# different from the default:
sub _mk_appclass  { (shift)->_ra_mk_appclass(@_) }

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

      ## To directly serve templates from the application root (/) namespace for
      ## easy, public-facing content (paths relative to 'root/templates'):
      #root_template_prefix  => 'site/public/page/',
      #root_template         => 'site/public/page/home',
    },
END
,
<<END,
    # Customize additional behaviors of the built-in "Template Controller" which is
    # used to serve template files application-wide. Locally defined Templates, if
    # present, are served from 'root/templates' (relative to the app home directory)
    'Controller::RapidApp::Template' => {
      default_template_extension => 'html',
      access_params => {
        ## To make all template paths under site/ (root/templates/site/) editable:
        #writable_regex      => '^site\/',
        #creatable_regex     => '^site\/',
        #deletable_regex     => '^site\/',

        ## To declare templates under site/public/ (root/templates/site/public/)
        ## to be 'external' (will render in an iframe in the TabGui):
        #external_tpl_regex  => '^site\/public\/',
      },

      # To declare a custom template access class instead of the default (which 
      # is RapidApp::Template::Access). The Access class is used to determine
      # exactly what type of access is allowed for each template/user, as well as
      # which template variables should be available when rendering each template
      # (Note: the access_params above are supplied to ->new() ):
      #access_class => '$self->{name}::Template::Access'
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