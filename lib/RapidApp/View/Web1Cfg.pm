package RapidApp::View::Web1Cfg;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::Include 'perlutil', 'sugar';

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
	my $renderCxt= RapidApp::Web1RenderContext->new();
	my $cfg= $c->stash->{web1cfg};
	defined $cfg or die "Nothing to render";
	my @html= $renderCxt->render($cfg);
	
	# get the params set up for the template
	$c->stash->{css_inc_list}= [ $renderCxt->getCssIncludeList ];
	$c->stash->{js_inc_list}= [ $renderCxt->getJsIncludeList ];
	$c->stash->{header}= $renderCxt->getHeaderLiteral;
	$c->stash->{content}= join('', @html);
	$c->stash->{template}= 'templates/rapidapp/web1_page.tt';
	return $c->view('RapidApp::TT')->process($c);
}

1;