package RapidApp::View::Web1Render;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::Web1RenderContext::ExtCfgToHtml;

has 'defaultRenderer' => ( is => 'rw', isa => 'RapidApp::Web1RenderContext::Renderer', lazy_build => 1 );

sub _build_defaultRenderer {
	my $self= shift;
	return RapidApp::Web1RenderContext::ExtCfgToHtml->new();
}

sub process {
	my ($self, $c)= @_;
	
	$c->res->header('Cache-Control' => 'no-cache');
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystClass => ref $c, catalystInstance => $c, log => $c->log },
		\&_process, $self, $c
	);
}

sub _process {
	my ($self, $c)= @_;
	# generate the html
	my $renderCxt= RapidApp::Web1RenderContext->new(renderer => $self->defaultRenderer);
	my $module= $c->stash->{module} or die "Missing argument: ->{module}";
	defined $module or die "Nothing to render";
	$module->web1_render($renderCxt);
	
	# get the params set up for the template
	$c->stash->{css_inc_list}= [ $renderCxt->getCssIncludeList ];
	$c->stash->{js_inc_list}= [ $renderCxt->getJsIncludeList ];
	$c->stash->{header}= $renderCxt->getHeaderLiteral;
	$c->stash->{content}= $renderCxt->getBody;
	$c->stash->{template}= 'templates/rapidapp/web1_page.tt';
	return $c->view('RapidApp::TT')->process($c);
}

1;