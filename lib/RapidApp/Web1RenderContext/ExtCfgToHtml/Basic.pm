package RapidApp::Web1RenderContext::ExtCfgToHtml::Basic;
use Moose::Role;

sub render_xtype_box {
	my ($self, $renderCxt, $cfg)= @_;
	$renderCxt->write('<div>'.$cfg->{html}.'</div>');
}

sub render_xtype_panel {
	my ($self, $renderCxt, $cfg)= @_;
	
	# This function first builds a list of pieces which can either be literals or functions that
	#   perform rendering, and then writes or runs each of them at the end.
	# This way, it is possible to override the generated HTML for any/all parts of the panel, and
	#   should allow maximum re-use by other renderers.
	
	my $cssClass= $cfg->{baseCls};
	if (!defined $cssClass) {
		$cssClass= 'x-panel';
		$renderCxt->incCSS('/static/ext/resources/css/ext-all.css', -100);
		$renderCxt->incCSS('/static/ext/resources/css/xtheme-gray.css', -1);
		$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSBasic.css');
	}
	
	my ($frameContentBegin, $titleContent, $frameContentBody, $tbarContent, $bodyContent, $bbarContent, $frameContentEnd);
	
	my $hasFrame= ref $cfg->{frame} eq 'SCALAR'? ${$cfg->{frame}} : $cfg->{frame};
	if ($hasFrame) {
		$frameContentBegin= $cfg->{frameContentBegin};
		defined $frameContentBegin
			or $frameContentBegin= '<div class="'.$cssClass.'-tl"><div class="'.$cssClass.'-tr"><div class="'.$cssClass.'-tc"></div></div></div>'."\n";
		$frameContentBody= $cfg->{frameContentBody};
		defined $frameContentBody
			or $frameContentBody= '<div class="'.$cssClass.'-ml"><div class="'.$cssClass.'-mr"><div class="'.$cssClass.'-mc">'."\n";
		$frameContentEnd= $cfg->{frameContentEnd};
		defined $frameContentEnd
			or $frameContentEnd= '</div></div></div>'
			.'<div class="'.$cssClass.'-bl '.$cssClass.'-nofooter"><div class="'.$cssClass.'-br"><div class="'.$cssClass.'-bc"></div></div></div>'."\n";
	}
	
	$titleContent= $cfg->{titleContent};
	!defined $titleContent && defined $cfg->{title}
		and $titleContent= '<div class="'.$cssClass.'"><div class="'.$cssClass.'-header">'
			.'<span class="'.$cssClass.'-header-text">'.$cfg->{title}.'</span></div></div>';
	
	$tbarContent= $cfg->{tbarContent};
	if (!defined $tbarContent && defined $cfg->{tbar}) {
		my $tbarCfg= ref $cfg->{tbar} eq 'HASH'? $cfg->{tbar} : { items => $cfg->{tbar} };
		$tbarContent= sub {
			$renderCxt->write("<div class='$cssClass-tbar $cssClass-tbar-noheader'>");
			$self->render_xtype_toolbar($renderCxt, $tbarCfg);
			$renderCxt->write("</div>");
		};
	}
	
	$bbarContent= $cfg->{bbarContent};
	if (!defined $bbarContent && defined $cfg->{bbar}) {
		my $bbarCfg= ref $cfg->{bbar} eq 'HASH'? $cfg->{bbar} : { items => $cfg->{bbar} };
		$bbarContent= sub {
			$renderCxt->write("<div class='$cssClass-bbar $cssClass-bbar-noheader'>");
			$self->render_xtype_toolbar($renderCxt, $bbarCfg);
			$renderCxt->write("</div>");
		};
	}
	
	$bodyContent= $cfg->{bodyContent};
	if (!defined $bodyContent && defined $cfg->{items}) {
		my $items= $self->build_container_item_list($cfg);
		my $layout= $cfg->{layout} || "box";
		my $layoutFn= $self->can("render_layout_$layout") || \&render_layout_box;
		$bodyContent= sub {
			$renderCxt->write('<div class="'.$cssClass.'-body">'."\n");
			$self->$layoutFn($renderCxt, $items, $cfg);
			$renderCxt->write('</div>'."\n");
		};
	}
	
	for my $part (
		'<div class="'.$cssClass.'">',
		$frameContentBegin,
		'<div class="'.$cssClass.'-bwrap">',
		$titleContent,
		$frameContentBody,
		$tbarContent,
		$bodyContent,
		$bbarContent,
		$frameContentEnd,
		"</div></div>\n")
	{
		next unless defined $part && $part ne '';
		ref $part eq 'CODE'? $part->($renderCxt) : $renderCxt->write($part);
	}
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

sub render_xtype_toolbar {
	my ($self, $renderCxt, $extCfg)= @_;
	
	my $barItems= ref $extCfg->{items} eq 'ARRAY' ? $extCfg->{items} : [ $extCfg->{items} ];
	
	# ignore anything that isn't plain html or text, and which isn't aan alignment indicator
	# TODO: process the alignment indicators
	my @leftItems= grep { ! ref $_ && ! ($_ =~ /^[-><].?$/) } @$barItems;
	my @rightItems;
	
	# if nothing is in the toolbar, then skip rendering it
	return unless scalar(@leftItems) || scalar(@rightItems);
	
	my $cssClass= $extCfg->{baseCls} || 'x-toolbar';
	my $leftContent= scalar(@leftItems) == 0? ''
		: '<table><tr>'.join('', map({ "<td class='$cssClass-cell'>$_</td>" } @leftItems)).'</tr></table>';
	my $rightContent= scalar(@rightItems) == 0? ''
		: '<table><tr>'.join('', map({ "<td class='$cssClass-cell'>$_</td>" } @rightItems)).'</tr></table>';
	my $style= $extCfg->{style}? ' style="'.$extCfg->{style}.'"' : '';
	
	$renderCxt->write(
		"<div class='$cssClass $cssClass-layout-ct'$style>"
			."<table class='$cssClass-ct'>\n"
				."<tr>\n"
					.(length($leftContent)? "<td class='$cssClass-left' align='left'>$leftContent</td>\n" : '')
					.(length($rightContent)? "<td class='$cssClass-right' align='right'>$rightContent</td>\n" : '')
				."</tr>"
			."</table>"
		."</div>\n");
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
