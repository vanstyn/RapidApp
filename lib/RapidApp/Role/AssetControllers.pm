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

use Catalyst::Controller::AutoAssets 0.19;
with 'Catalyst::Plugin::AutoAssets';

before 'inject_asset_controllers' => sub {
  my $c = shift;
  
  my %defaults = (
    persist_state => 1,
    sha1_string_length => 15
  );
  
  my $assets = [
    {
      controller => 'Assets::ExtJS',
      type => 'Directory',
      include => 'ext-3.4.0',
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
      )]
    },
    {
      controller => 'Assets::RapidApp::CSS',
      type => 'CSS',
      include => 'rapidapp/share/assets/css',
    },
    {
      controller => 'Assets::RapidApp::JS',
      type => 'JS',
      include => 'rapidapp/share/assets/js',
    },
    {
      controller => 'Assets::RapidApp::Icons',
      type => 'IconSet',
      include => 'rapidapp/share/assets/icons',
    },
    {
      controller => 'Assets::RapidApp::Filelink',
      type => 'Directory',
      include => 'rapidapp/share/assets/filelink',
      html_head_css_subfiles => ['filelink.css']
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
