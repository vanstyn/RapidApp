package RapidApp::Catalyst;

# Built-in plugins required for all RapidApp Applications:
use Catalyst qw(
+RapidApp::Role::CatalystApplication
+RapidApp::CatalystX::SimpleCAS
);

use Moose;
extends 'Catalyst';

use RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);
use Template;

# -- override Static::Simple default config to ignore extensions like html.
before 'setup_plugins' => sub {
	my $c = shift;
	
	my $config
		= $c->config->{'Plugin::Static::Simple'}
		= $c->config->{'static'}
		= Catalyst::Utils::merge_hashes(
			$c->config->{'Plugin::Static::Simple'} || {},
			$c->config->{static} || {}
		);
	
	$config->{ignore_extensions} ||= [];
	$c->config->{'Plugin::Static::Simple'} = $config;
};
# --



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