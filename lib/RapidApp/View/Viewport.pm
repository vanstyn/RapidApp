package RapidApp::View::Viewport;

use strict;
use warnings;

use base 'Catalyst::View::TT';

use RapidApp::Util qw(:all);

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
  my $pfx = $c->mount_url || '';
  push @{$c->stash->{precache_imgs}}, map { "$pfx$_" } (qw(
    /assets/rapidapp/misc/static/icon-error.gif
    /assets/rapidapp/misc/static/s.gif
  ));
  
  
  $c->stash->{precache_imgs} ||= [];
  @{$c->stash->{precache_imgs}} = uniq(@{$c->stash->{precache_imgs}},@img);
  
  die "ERROR: stash params 'config_url' and 'panel_cfg' cannot be used together"
    if($c->stash->{config_url} && $c->stash->{panel_cfg});

  # make sure config_params is a string of JSON
  if (ref $c->stash->{config_params}) {
    $c->stash->{config_params}= RapidApp::JSON::MixedEncoder::encode_json($c->stash->{config_params});
  }

  if (ref $c->stash->{panel_cfg}) {
    $c->stash->{panel_cfg}= RapidApp::JSON::MixedEncoder::encode_json($c->stash->{panel_cfg});
  }

  return $self->next::method($c);
}


sub _get_asset_controller_urls {
  my ($self, $controller, @paths)= @_;
  return () unless ($controller);
  return map { $controller->asset_path($_) } @paths;
}


1;


__END__

=head1 NAME

RapidApp::View::Viewport - Render a Module within an ExtJS Viewport

=head1 DESCRIPTION

This is the main View for rendering a top-level RapidApp Module within the browser. This
component class is used internally by plugins like L<TabGui|Catalyst::Plugin::RapidApp::TabGui>.

The JavaScript function C<Ext.ux.RapidApp.AutoPanel> is used to fetch and decode the 
configured Module URL via Ajax.

More documentation TDB...

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Modules>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
