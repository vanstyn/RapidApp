package RapidApp::View::Web1Render;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::Web1RenderContext::ExtCfgToHtml;

has 'defaultRenderer' => ( is => 'rw', isa => 'RapidApp::Web1RenderContext::Renderer', lazy_build => 1 );

sub renderAsIgnored {
	my ($renderCxt, $obj)= @_;
	if (RapidApp::ScopedGlobals->catalystInstance->debug) {
		$renderCxt->write("<div><b>[unrenderable content]</b></div>");
	}
}

sub _build_defaultRenderer {
	my $self= shift;
	return RapidApp::Web1RenderContext::ExtCfgToHtml->new(
		defaultRenderer => RapidApp::Web1RenderContext::RenderFunction->new(\&renderAsIgnored),
	);
}

sub process {
	my ($self, $c)= @_;
	
	$c->res->header('Cache-Control' => 'no-cache');
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => ref $c, catalystInstance => $c, log => $c->log },
		\&_process, $self, $c->stash
	);
}

sub render {
	my ($self, $hash)= @_;
	# generate the html
	my $renderCxt= RapidApp::Web1RenderContext->new(renderer => $self->defaultRenderer);
	my $module= $hash->{module} or die "Missing argument: module => x";
	$module->web1_render($renderCxt);
	
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	# get the params set up for the template
	$c->stash->{css_inc_list}= [ $renderCxt->getCssIncludeList ];
	$c->stash->{js_inc_list}= [ $renderCxt->getJsIncludeList ];
	$c->stash->{header}= $renderCxt->getHeaderLiteral;
	$c->stash->{content}= $renderCxt->getBody;
	$c->stash->{template}= 'templates/rapidapp/web1_page.tt';
	return $c->view('RapidApp::TT')->process($c);
}

1;