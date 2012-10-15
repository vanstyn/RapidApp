package RapidApp::Catalyst;

# Built-in plugins required for all RapidApp Applications:
use Catalyst qw(
+RapidApp::Role::CatalystApplication
+RapidApp::CatalystX::SimpleCAS
+RapidApp::CatalystX::AutoAssets
);

use Moose;
extends 'Catalyst';

use RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);
use Template;

sub app_version { eval '$' . (shift)->config->{name} . '::VERSION' }

before 'setup_plugins' => sub {
	my $c = shift;

	# -- override Static::Simple default config to ignore extensions like html.
	my $config
		= $c->config->{'Plugin::Static::Simple'}
		= $c->config->{'static'}
		= Catalyst::Utils::merge_hashes(
			$c->config->{'Plugin::Static::Simple'} || {},
			$c->config->{static} || {}
		);
	
	$config->{ignore_extensions} ||= [];
	$c->config->{'Plugin::Static::Simple'} = $config;
	# --
	
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

our $ON_FINALIZE_SUCCESS = [];

## -- 'on_finalize_success' provides a mechanism to call code at the end of the request
## only if successful
sub add_on_finalize_success {
	my $c = shift;
	# make sure this is the CONTEXT object and not a class name
	$c = RapidApp::ScopedGlobals->get("catalystInstance") unless (ref $c);
	my $code = shift or die "No CodeRef supplied";
	die "add_on_finalize_success(): argument not a CodeRef" 
		unless (ref $code eq 'CODE');
	
	if(try{$c->stash}) {
		$c->stash->{on_finalize_success} ||= [];
		push @{$c->stash->{on_finalize_success}},$code;
	}
	else {
		push @$ON_FINALIZE_SUCCESS,$code;
	}
	return 1;
}

before 'finalize' => sub {
	my $c = shift;
	my $coderefs = try{$c->stash->{on_finalize_success}} or return;
	return unless (scalar @$coderefs > 0);
	my $status = $c->res->code;
	return unless ($status =~ /^2\d{2}$/); # status code 2xx = success
	$c->log->info(
		"finalize_body(): calling " . (scalar @$coderefs) .
		" CodeRefs added by 'add_on_finalize_success'"
	);
	$c->run_on_finalize_success_codes($coderefs);
};
END { __PACKAGE__->run_on_finalize_success_codes($ON_FINALIZE_SUCCESS); }

sub run_on_finalize_success_codes {
	my $c = shift;
	my $coderefs = shift;
	my $num = 0;
	foreach my $ref (@$coderefs) {
		try {
			$ref->($c);
		}
		catch {
			# If we get here, we're screwed. Best we can do is log the error. (i.e. we can't tell the user)
			my $err = shift;
			my $errStr = RED.BOLD . "EXCEPTION IN CodeRefs added by 'add_on_finalize_success!! [coderef #" . 
				++$num . "]:\n " . CLEAR . RED . (ref $err ? Dumper($err) : $err) . CLEAR;
			
			try{$c->log->error($errStr)} or warn $errStr;
			
			# TODO: handle exceptions here like any other. This might require a bit
			# of work to achieve because by the time we get here we're already past the
			# code that handles RapidApp exceptions, and the below commented out code doesn't work
			#
			# This doesn't work (Whenever this *concept* is able to work, handle in a single
			# try/catch instead of a separate one as is currently done - which we're doing because
			# we're not able to let the user know something went wrong, so we try our best to
			# run each one):
			#delete $c->stash->{on_finalize_success};
			#my $view = $c->view('RapidApp::JSON') or die $err;
			#$c->stash->{exception} = $err;
			#$c->forward( $view );
		};
	}
};
##
## --


1;