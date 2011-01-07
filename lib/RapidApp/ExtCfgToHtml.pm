package RapidApp::ExtCfgToHtml;

use strict;
use warnings;
use RapidApp::Include 'perlutil', 'sugar';

our %XTYPE_RENDER_METHODS= ();
sub registerXtypeRenderFunction {
	my ($unused, $xtype, $code)= @_;
	defined $XTYPE_RENDER_METHODS{$xtype}
		and warn "Render fn for xtype $xtype being overridden at ".sprintf('%s [%s line %s]',caller);
	$XTYPE_RENDER_METHODS{$xtype}= $code;
}

# sub registerXtypeRenderFunction {
	# my ($class, $xtype, $code)= @_;
	# my $subName= "render_xtype_$xtype";
	# $class->can($subName)
		# and warn "Render fn for xtype $xtype being overwritten at ".sprintf('%s [%s line %s]',caller);
	# *__PACKAGE__::$subName= $code;
# }


sub rendererForXtype {
	my ($unused, $xtype)= @_;
	return $XTYPE_RENDER_METHODS{$xtype};
}

sub new {
	my ($class)= @_;
	return bless {}, $class;
}

sub render {
	my ($classOrSelf, $renderContext, $extCfg, $xtype)= @_;
	my @result;
	my $renderFn;
	# try to find an appropriate renderer for the config
	if (!defined $xtype && defined $extCfg->{rapidapp_custom_cfg2html}) {
		my $moduleName= $extCfg->{rapidapp_author_module};
		defined $moduleName
			or ra_die "Config object requests custom rendering, but does not name its author_module", extCfg=>$extCfg;
		
		my $module= RapidApp::ScopedGlobals->catalystInstance->rapidApp->module($moduleName);
		defined $module
			or ra_die "No module by name of $moduleName", extCfg=>$extCfg;
		
		$module->web1_render($renderContext, $extCfg);
	}
	else {
		$xtype ||= $extCfg->{xtype};
		defined $xtype
			or ra_die "Config does not have an xtype, and none specified", extCfg=>$extCfg;
		
		if ($renderFn= $XTYPE_RENDER_METHODS{$xtype}) {
			@result= $renderFn->($classOrSelf, $renderContext, $extCfg);
		} else {
			warn "No render plugin defined for xtype '".$xtype."'";
		}
	}
	return @result;
}

1;
