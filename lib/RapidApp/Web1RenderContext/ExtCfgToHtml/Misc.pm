package RapidApp::Web1RenderContext::ExtCfgToHtml::Misc;
use Moose::Role;

sub render_xtype_superboxselect {
	my ($self, $renderCxt, $cfg)= @_;
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSMisc.css');
	$renderCxt->write("<h2>SUPERBOX</h2>");
}

sub render_xtype_htmleditor {
	my ($self, $renderCxt, $cfg)= @_;
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSMisc.css');
	$renderCxt->write("<div class='xt-htmleditor'>".$cfg->{value}."</div>");
}

no Moose;
1;