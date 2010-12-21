package RapidApp::ExtCfgToHtml::Basic;

use strict;
use warnings;
use RapidApp::ExtCfgToHtml;

{ # Register these functions with the RenderContext
	my @xtypes= qw(panel spacer htmleditor);
	for my $xt (@xtypes) {
		my $methodName= "render_xtype_$xt";
		RapidApp::ExtCfgToHtml->registerXtypeRenderFunction($xt => \&$methodName);
	}
	
	push @RapidApp::ExtCfgToHtml::ISA, __PACKAGE__;
}

sub render_xtype_panel {
	my ($self, $context, $cfg)= @_;
	
	$context->incCSS('/static/rapidapp/css/web1_ExtJSBasic.css');
	
	$context->write('<div class="xt-panel">');
	# make sure we have items to render
	if (defined $cfg->{items} && scalar(@{$cfg->{items}}) > 0) {
		# build the completed list of items
		my %defaults= defined $cfg->{defaults}? %{$cfg->{defaults}} : ();
		my $itemList= [ map { {%defaults, %$_} } @{$cfg->{items}} ];
		
		my $layout= $cfg->{layout} || "box";
		my $layoutFn= $self->can("render_layout_$layout") || &render_layout_box;
		
		$self->$layoutFn($context, $itemList);
	}
	$context->write('</div>');
}

sub render_layout_box {
	my ($self, $context, $items)= @_;
	$context->write('<div class="ly-box">');
	for my $item (@$items) {
		$self->render($context, $item);
	}
	$context->write('</div>');
}

sub render_layout_anchor {
	my ($self, $context, $items)= @_;
	render_layout_box(@_); # temporary
}

sub render_layout_hbox {
	my ($self, $context, $items)= @_;
	$context->write('<table class="ly-hbox"><tr>');
	for my $item (@$items) {
		$context->write('<td>');
		$self->render($context, $item);
		$context->write('</td>');
	}
	$context->write('</tr></table>');
}

sub render_xtype_spacer {
	my ($self, $context, $cfg)= @_;
	my ($w, $h)= ($cfg->{width}, $cfg->{height});
	$context->write('<div style="'.($w? "width:$w;":'').($h? "height:$h;":'').'"> </div>');
}

sub render_xtype_htmleditor {
	my ($self, $context, $cfg)= @_;
	$context->write($cfg->{value});
}

1;
