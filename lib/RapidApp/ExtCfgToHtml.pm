package RapidApp::ExtCfgToHtml;

use strict;
use warnings;
use RapidApp::Include 'perlutil';

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
	try {
		my $renderFn;
		if (!defined $xtype && defined $extCfg->{author_module}) {
			my $module= RapidApp::ScopedGlobals->c->rapidApp->module($extCfg->{author_module});
			@result= $module->web1_render($renderContext);
			#@result= $extCfg->$renderFn($renderContext);
		}
		else {
			$xtype ||= $extCfg->{xtype};
			defined $xtype or die RapidApp::Error->new("Config does not have an xtype, and none specified");
			if ($renderFn= $XTYPE_RENDER_METHODS{$xtype}) {
				@result= $renderFn->($classOrSelf, $renderContext, $extCfg);
			} else {
				warn "No render plugin defined for xtype '".$xtype."'";
			}
		}
	}
	catch {
		# add some debugging info if possible
		blessed($_) && $_->can('data') and $_->data->{extCfg}= $extCfg;
		die $_; # rethrow
	};
	return @result;
}

1;
