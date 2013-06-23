package RapidApp::Role::AssetControllers;

our $VERSION = '0.01';
use Moose::Role;
use namespace::autoclean;

# This Role handles setting up AutoAssets controllers needed for the proper functioning
# of the RapidApp system

use RapidApp::Include qw(sugar perlutil);

use CatalystX::InjectComponent;
use Catalyst::Utils;
use Path::Class qw(dir);
use RapidApp;

use Catalyst::Controller::AutoAssets 0.22;
with 'Catalyst::Plugin::AutoAssets';

sub get_extjs_dir {
  my $c = shift;
  return $c->config->{extjs_dir} || 'ext-3.4.0';
}

before 'inject_asset_controllers' => sub {
  my $c = shift;
  
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
      controller => 'Assets::RapidApp::JS',
      type => 'JS',
      include => $share_dir . '/assets/js',
    },
    {
      controller => 'Assets::RapidApp::Icons',
      type => 'IconSet',
      include => $share_dir . '/assets/icons',
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
  
  
  # Add local assets if src include dirs exist in the App directory
  push @$assets, {
    controller => 'Assets::Local::CSS',
    type => 'CSS',
    include => 'root/src.d/css',
  } if (-d dir($c->config->{home})->subdir('root/src.d/css'));
  
  push @$assets, {
    controller => 'Assets::Local::JS',
    type => 'JS',
    include => 'root/src.d/js',
  } if (-d dir($c->config->{home})->subdir('root/src.d/js'));
  
  # Check for any configs in the existing local app config:
  my $existing = $c->config->{'Plugin::AutoAssets'}->{assets};
  push @$assets, @$existing if ($existing);
  
  # apply defaults:
  %$_ = (%defaults,%$_) for (@$assets);
  
  $c->config( 'Plugin::AutoAssets' => { assets => $assets } );
};


1;
