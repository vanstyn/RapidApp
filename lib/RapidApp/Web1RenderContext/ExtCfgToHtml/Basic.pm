package RapidApp::Web1RenderContext::ExtCfgToHtml::Basic;
use Moose::Role;

sub render_xtype_panel {
	my ($self, $renderCxt, $cfg)= @_;
	
	my $hasFrame= ref $cfg->{frame} && ${$cfg->{frame}};
	# first the top bar context, if any
	my $tbar= ref $cfg->{tbar} eq 'ARRAY'? $cfg->{tbar} : undef;
	my $bbar= ref $cfg->{bbar} eq 'ARRAY'? $cfg->{bbar} : undef;
	
	# then the body elements
	my $items= $self->build_container_item_list($cfg);
	
	my $layout= $cfg->{layout} || "box";
	my $layoutFn= $self->can("render_layout_$layout") || \&render_layout_box;
	my $renderClosure= sub { $self->$layoutFn($renderCxt, $items, $cfg) };
	
	$self->render_panel_structure($renderCxt, $hasFrame, $tbar, $bbar, $renderClosure);
}

sub render_panel_structure {
	my ($self, $renderCxt, $hasFrame, $tbar, $bbar, $renderContent)= @_;
	
	$renderCxt->incCSS('/static/ext/resources/css/ext-all.css', -100);
	$renderCxt->incCSS('/static/ext/resources/css/xtheme-gray.css', -1);
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSBasic.css');
	
	$renderCxt->write('<div class="x-panel">');
	
	$hasFrame
		and $renderCxt->write('<div class="x-panel-tl"><div class="x-panel-tr"><div class="x-panel-tc"></div></div></div>'."\n");
	
	$renderCxt->write('<div class="x-panel-bwrap">'."\n");
	
	$hasFrame
		and $renderCxt->write('<div class="x-panel-ml"><div class="x-panel-mr"><div class="x-panel-mc">'."\n");
	
	# first the top bar context, if any
	defined $tbar
		and $self->render_panel_bar($renderCxt, $tbar, 1);
	
	# then the body elements
	if (defined $renderContent) {
		$renderCxt->write('<div class="x-panel-body">'."\n");
		$renderContent->();
		$renderCxt->write('</div>'."\n");
	}
	
	# then the bbar, if any
	defined $bbar
		and $self->render_panel_bar($renderCxt, $bbar, 0);
	
	$hasFrame
		and $renderCxt->write('</div></div></div>'
			.'<div class="x-panel-bl x-panel-nofooter"><div class="x-panel-br"><div class="x-panel-bc"></div></div></div>'."\n");
	
	$renderCxt->write('</div>');
	
	$renderCxt->write('</div>'."\n");
}

sub build_container_item_list {
	my ($self, $cfg)= @_;
	
	my $items= defined $cfg->{items}? $cfg->{items} : [];
	ref $items eq 'ARRAY' or $items= [ $items ]; # items is allowed to be a single item
	
	my @combined= defined $cfg->{defaults}?
		map { {%{$cfg->{defaults}}, %$_} } @$items
		: @$items;
	
	my @visible= grep { !$_->{hidden} || !${$_->{hidden}} } @combined;
	
	return [ @visible ];
}

sub render_panel_bar {
	my ($self, $renderCxt, $barItems, $isTop)= @_;
	my @textItems= grep { ! ref $_ && ! ($_ =~ /^[-><].?$/) } @$barItems;
	my $styles= $isTop? 'x-panel-tbar x-panel-tbar-noheader':'x-panel-bbar x-panel-bbar-noheader';
	$renderCxt->write('<div class="'.$styles.'"><div class="x-toolbar x-toolbar-layout-ct">'.join(' ', @textItems).'</div></div>');
}

sub render_layout_box {
	my ($self, $renderCxt, $items, $parent)= @_;
	$renderCxt->write('<div class="ly-box">');
	for my $item (@$items) {
		$self->renderAsHtml($renderCxt, $item);
	}
	$renderCxt->write('</div>');
}

sub render_layout_anchor {
	my ($self, $renderCxt, $items, $parent)= @_;
	render_layout_box(@_); # temporary
}

sub render_layout_hbox {
	my ($self, $renderCxt, $items, $parent)= @_;
	$renderCxt->write('<table class="ly-hbox"><tr>');
	for my $item (@$items) {
		$renderCxt->write('<td>');
		$self->renderAsHtml($renderCxt, $item);
		$renderCxt->write('</td>');
	}
	$renderCxt->write('</tr></table>');
}

sub render_xtype_spacer {
	my ($self, $renderCxt, $cfg)= @_;
	my ($w, $h)= ($cfg->{width}, $cfg->{height});
	$renderCxt->write('<div style="'.($w? "width:".$w."px;":'').($h? "height:".$h."px;":'').'"></div>');
}

no Moose;
1;
