package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use RapidApp::ScopedGlobals 'sEnv';
use Scalar::Util 'blessed';

use CatalystX::InjectComponent;

sub r        { (shift)->rapidApp } # handy alias
sub rapidApp { (shift)->model("RapidApp"); }
sub module   { (shift)->model("RapidApp")->module(@_); }

after 'setup_components' => sub {
	my ($app) = @_;
	# At this point, we don't have a catalyst instance yet, just the package name.
	# Catalyst has an amazing number of package methods that masquerade as instance methods later on.
	#local $SIG{__DIE__}= \&RapidApp::Error::dieConverter;
	try {
		RapidApp::ScopedGlobals->applyForSub(
			{ catalystClass => $app, log => $app->log },
			sub { $app->setupRapidApp }
		);
	}
	catch {
		print STDERR $_->dump if (blessed($_) && $_->can('dump'));
		die $_;
	};
};

sub setupRapidApp {
	my $app= shift;
	my $log= RapidApp::ScopedGlobals->log;
	injectUnlessExist('RapidApp::RapidApp', 'RapidApp');
	
	my @names= keys %{ $app->components };
	my @controllers= grep /[^:]+::Controller.*/, @names;
	my $haveRoot= 0;
	foreach my $ctlr (@controllers) {
		if ($ctlr->isa('RapidApp::ModuleDispatcher')) {
			$log->info("RapidApp: Found $ctlr which implements ModuleDispatcher.");
			$haveRoot= 1;
		}
	}
	if (!$haveRoot) {
		$log->info("RapidApp: No Controller extending ModuleDispatcher found, using default");
		injectUnlessExist( 'RapidApp::Controller::DefaultRoot', 'Controller::RapidApp::Root' );
	}
	
	# Enable the DirectLink feature, if asked for
	$app->rapidApp->enableDirectLink
		and injectUnlessExist( 'RapidApp::Controller::DirectLink', 'Controller::RapidApp::DirectLink' );
	
	# for each view, inject it if it doens't exist
	injectUnlessExist( 'Catalyst::View::TT', 'View::RapidApp::TT' );
	injectUnlessExist( 'RapidApp::View::Viewport', 'View::RapidApp::Viewport' );
	injectUnlessExist( 'RapidApp::View::JSON', 'View::RapidApp::JSON' );
	injectUnlessExist( 'RapidApp::View::Web1Cfg', 'View::RapidApp::Web1Cfg' );
	injectUnlessExist( 'RapidApp::View::HttpStatus', 'View::RapidApp::HttpStatus' );
};

sub injectUnlessExist {
	my ($actual, $virtual)= @_;
	my $app= RapidApp::ScopedGlobals->catalystClass;
	if (!$app->components->{$virtual}) {
		sEnv->log->debug("RapidApp: Installing virtual $virtual");
		CatalystX::InjectComponent->inject( into => $app, component => $actual, as => $virtual );
	}
}

after 'setup_finalize' => sub {
	my $app= shift;
	#local $SIG{__DIE__}= \&RapidApp::Error::dieConverter;
	try {
		RapidApp::ScopedGlobals->applyForSub(
			{ catalystClass => $app, log => $app->log },
			sub { $app->rapidApp->_setup_finalize }
		);
	}
	catch {
		print STDERR $_->dump if (blessed($_) && $_->can('dump'));
		die $_;
	};
};

1;