package RapidApp::View::Viewport;

use strict;
use warnings;

use base 'Catalyst::View::TT';

use RapidApp::Include qw(sugar perlutil);

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
  my ($self, $c)= @_;

  $c->response->header('Cache-Control' => 'no-cache');
  $c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
  
  my @img = ();
  
  push @img, $self->_get_asset_controller_urls(
     $c->controller('Assets::ExtJS'), (qw(
      resources/images/gray/qtip/tip-sprite.gif
      resources/images/gray/qtip/tip-anchor-sprite.gif
      resources/images/gray/tabs/tab-strip-bg.gif
      resources/images/gray/tabs/tab-close.gif
      resources/images/gray/tabs/tabs-sprite.gif
      resources/images/gray/panel/white-top-bottom.gif
      resources/images/gray/panel/tool-sprites.gif
      resources/images/default/grid/loading.gif
      resources/images/gray/tree/arrows.gif
      resources/images/gray/window/left-corners.png
      resources/images/gray/window/right-corners.png
      resources/images/gray/window/top-bottom.png
      resources/images/gray/window/left-right.png
      resources/images/gray/button/btn.gif
      resources/images/gray/qtip/bg.gif
      resources/images/gray/progress/progress-bg.gif
      resources/images/gray/window/icon-warning.gif
      resources/images/default/shadow.png
      resources/images/default/shadow-lr.png
      resources/images/default/shadow-c.png
      resources/images/gray/panel/corners-sprite.gif
      resources/images/gray/panel/top-bottom.gif
      resources/images/gray/panel/left-right.gif
     ))
  );
  
  push @img, $self->_get_asset_controller_urls(
     $c->controller('Assets::RapidApp::Icons'), (qw(
      warning.png
      loading.gif
      refresh.gif
      refresh_24x24.png
     ))
  );
   
  push @img, $self->_get_asset_controller_urls(
     $c->controller('Assets::RapidApp::Misc'), (qw(
      images/rapidapp_powered_logo_tiny.png
     ))
  );
  
  # Misc static images:
  push @{$c->stash->{precache_imgs}}, (qw(
    /assets/rapidapp/misc/static/icon-error.gif
    /assets/rapidapp/misc/static/s.gif
  ));
  
  
  $c->stash->{precache_imgs} ||= [];
  @{$c->stash->{precache_imgs}} = uniq(@{$c->stash->{precache_imgs}},@img);
  
  # make sure config_params is a string of JSON
  if (ref $c->stash->{config_params}) {
    $c->stash->{config_params}= RapidApp::JSON::MixedEncoder::encode_json($c->stash->{config_params});
  }

  return $self->next::method($c);
}


sub _get_asset_controller_urls {
  my ($self, $controller, @paths)= @_;
  return () unless ($controller);
  return map { $controller->asset_path($_) } @paths;
}


1;
