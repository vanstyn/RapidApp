package RapidApp::Catalyst;

# Built-in plugins required for all RapidApp Applications:
use Catalyst qw(
	+RapidApp::Role::CatalystApplication
	+RapidApp::CatalystX::SimpleCAS	
);

use base 'Catalyst';

use RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);
use Template;

# convenience util function
my $TT;
sub template_render {
	my $c = shift;
	my $template = shift;
	my $vars = shift || {};
	
	$TT ||= Template->new({ INCLUDE_PATH => $c->config->{home} . '/root' });
	
	my $out;
	$TT->process($template,$vars,\$out) or die $TT->error;

	return $out;
}


1;