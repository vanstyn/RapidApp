package RapidApp::ExtCfgToHtml::Superbox;

use strict;
use warnings;
use RapidApp::ExtCfgToHtml;

{ # Register these functions with the RenderContext
	my @xtypes= qw(superboxselect);
	for my $xt (@xtypes) {
		my $methodName= "render_xtype_$xt";
		RapidApp::ExtCfgToHtml->registerXtypeRenderFunction($xt => \&$methodName);
	}
	
	push @RapidApp::ExtCfgToHtml::ISA, __PACKAGE__;
}

sub render_xtype_superboxselect {
	my ($self, $context, $cfg)= @_;
	$context->write("<h2>SUPERBOX</h2>");
}

1;