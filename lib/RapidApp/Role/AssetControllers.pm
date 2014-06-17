package RapidApp::Role::AssetControllers;

use strict;
use warnings;

# This class must declare the version because we declared it before (and PAUSE knows)
our $VERSION = '0.99301';

use Moose::Role;
use namespace::autoclean;

# This Role handles setting up AutoAssets controllers needed for the proper functioning
# of the RapidApp system

use RapidApp::Include qw(sugar perlutil);

use CatalystX::InjectComponent;
use Catalyst::Utils;
use Path::Class qw(dir);
use RapidApp;
use JavaScript::ExtJS::V3;
use Time::HiRes qw(gettimeofday tv_interval);

use Catalyst::Controller::AutoAssets 0.29;
with 'Catalyst::Plugin::AutoAssets';

sub get_extjs_dir { JavaScript::ExtJS::V3->dir->stringify }


around 'inject_asset_controllers' => sub {
  my ($orig,$c,@args) = @_;
  
  my $start = [gettimeofday];
  $c->log->debug("RapidApp - Injecting Asset Controllers...") if ($c->debug);
  
  my %defaults = (
    sha1_string_length => 15,
    use_etags => 1,
  );
  
  my $share_dir = RapidApp->share_dir;
  
  my $assets = [
    {
      controller => 'Assets::ExtJS',
      type => 'Directory',
      include => $c->get_extjs_dir,
      html_head_css_subfiles => [qw(
        resources/css/ext-all.css
        resources/css/xtheme-gray.css
        examples/ux/fileuploadfield/css/fileuploadfield.css
      )],
      html_head_js_subfiles => [qw(
        adapter/ext/ext-base.js
        ext-all-debug.js
        src/debug.js
        examples/ux/fileuploadfield/FileUploadField.js
      )],
      persist_state => 1,
    },
    {
      controller => 'Assets::RapidApp::CSS',
      type => 'CSS',
      include => $share_dir . '/assets/css',
    },
    {
      controller => 'Assets::RapidApp::CSS::ScopedReset',
      type => 'CSS',
      include => $share_dir . '/assets/css-scoped/ra-scoped-reset.css',
      scopify => ['.ra-scoped-reset', merge => ['html','body']]
    },
    {
      controller => 'Assets::RapidApp::CSS::ScopedDoc',
      type => 'CSS',
      include => $share_dir . '/assets/css-scoped/ra-doc.css',
      scopify => ['.ra-doc', merge => ['html','body']]
    },
    {
      controller => 'Assets::RapidApp::JS',
      type => 'JS',
      include => $share_dir . '/assets/js',
    },
    {
      controller => 'Assets::RapidApp::Icons',
      type => 'IconSet',
      include => $share_dir . '/assets/icons',
      css_file_name => 'ra-icons.css',
      icon_name_prefix => 'ra-icon-'
    },
    {
      controller => 'Assets::RapidApp::Filelink',
      type => 'Directory',
      include => $share_dir . '/assets/filelink',
      html_head_css_subfiles => ['filelink.css']
    },
    {
      controller => 'Assets::RapidApp::Misc',
      type => 'Directory',
      include => $share_dir . '/assets/misc',
      allow_static_requests => 1,
      use_etags => 1,
      static_response_headers => {
        'Cache-Control' => 'max-age=3600, must-revalidate, public'
      }
    },
  ];
  
  ## -----------
  # Easy automatic setup of local assets
  
  # Default to true if not set(i.e. can be set to 0/false to disable)
  my $auto_setup = (
    ! exists $c->config->{'Model::RapidApp'}->{auto_local_assets} ||
    $c->config->{'Model::RapidApp'}->{auto_local_assets}
  ) ? 1 : 0;
  
  my $home = dir( Catalyst::Utils::home($c) );
  
  # We can't setup auto local assets if we have no home dir:
  $auto_setup = 0 unless ($home && -d $home);
  
  if($auto_setup) {
  
    # New, automatic 'local_asset_dir' can now be specified via config:
    my $dir = dir(
      $c->config->{'Model::RapidApp'}->{local_assets_dir} || 'root/assets'
    );
    
    # If relative, make relative to app home:
    $dir = $home->subdir($dir) if ($dir->is_relative);
    
    # Add local assets if asset include dirs exist in the App directory
    push @$assets, {
      controller => 'Assets::Local::CSS',
      type => 'CSS',
      include => "$dir/css",
    } if (-d $dir->subdir('css'));
    
    push @$assets, {
      controller => 'Assets::Local::JS',
      type => 'JS',
      include => "$dir/js",
    } if (-d $dir->subdir('js'));
    
    push @$assets, {
      controller => 'Assets::Local::Icons',
      type => 'IconSet',
      include => "$dir/icons",
    } if (-d $dir->subdir('icons'));
    
    push @$assets, {
      controller => 'Assets::Local::Misc',
      type => 'Directory',
      include => "$dir/misc",
      allow_static_requests => 1,
    } if (-d $dir->subdir('misc'));
  }
  #
  ## -----------
  
  # Check for any configs in the existing local app config:
  my $existing = $c->config->{'Plugin::AutoAssets'}->{assets};
  push @$assets, @$existing if ($existing);
  
  # apply defaults:
  %$_ = (%defaults,%$_) for (@$assets);
  
  $c->config( 'Plugin::AutoAssets' => { assets => $assets } );
  
  my $ret = $c->$orig(@args);
  
  $c->log->debug(sprintf(
    "RapidApp - Asset Controllers Setup in %0.3f seconds",
    tv_interval($start)
  )) if ($c->debug);

  return $ret;
};

1;
