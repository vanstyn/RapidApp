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
      type => 'directory',
      include => 'ext-3.4.0',
      html_head_css_subfiles =>[qw(
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
      type => 'css',
      include => 'rapidapp/src.d/css',
    },
    {
      controller => 'Assets::RapidApp::JS',
      type => 'js',
      include => 'rapidapp/src.d/js',
    }  
  ];
  
  # Add local assets if src include dirs exist in the App directory
  push @$assets, {
    controller => 'Assets::Local::CSS',
    type => 'css',
    include => 'root/src.d/css',
  } if (-d dir($c->config->{home})->subdir('root/src.d/css'));
  
  push @$assets, {
    controller => 'Assets::Local::JS',
    type => 'js',
    include => 'root/src.d/js',
  } if (-d dir($c->config->{home})->subdir('root/src.d/js'));
  
  # apply defaults:
  %$_ = (%defaults,%$_) for (@$assets);
  

  $c->config( 'Plugin::AutoAssets' => 
    Catalyst::Utils::merge_hashes(
      { assets => $assets }, 
      $c->config->{'Plugin::AutoAssets'} || {} 
    )
  );
};


1;
