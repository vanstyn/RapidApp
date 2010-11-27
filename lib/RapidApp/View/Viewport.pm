package RapidApp::View::Viewport;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
	my ($self, $c)= @_;
	
	$c->response->header('Cache-Control' => 'no-cache');
	$c->stash->{template} = 'templates/rapidapp/ext_viewport.tt';
	
	# in the future, we will build the list of javascript includes here
=pod
	if ($c->debug) {
		$c->stash->{js_includes}= $self->js_includes;  # lazy-build to iterate modules and ask for their deps
		$c->stash->{css_includes}= $self->css_includes; # lazy-build to iterate modules and ask for their deps
	# when not in debug mode, we minify them to static files to be served directly by apache
	} else {
		if (!$self->minified) {
			if (dateof($self->minifiedJsFileName) < max(dateof($self->js_includes))) {
				do_js_minify($self->minifiedJsFileName, $self->js_includes);
			}
			if (dateof($self->minifiedCssFileName) < max(dateof($self->css_includes))) {
				do_css_minify($self->minifiedCssFileName, $self->css_includes);
			}
			$self->minified= 1;
		}
		$c->stash->{js_includes}= [ $self->minifiedJsFileName ];
		$c->stash->{css_includes}= [ $self->minifiedCssFileName ];
	}
	$c->stash->{static_elements}= $self->static_elements; # lazy-build to iterate modules and ask for their deps
=cut
	
	# make sure config_params is a string of JSON
	if (ref $c->stash->{config_params}) {
		$c->stash->{config_params}= RapidApp::JSON::MixedEncoder::encode_json($c->stash->{config_params});
	}
	
	return $self->SUPER::process($c);
}

1;
