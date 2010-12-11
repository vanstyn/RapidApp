package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';
use RapidApp::RapidApp;
use Scalar::Util 'blessed';

use CatalystX::InjectComponent;

after 'BUILD' => sub {
	my $self= shift;
	# access root module, forcing it to get built now, instead of on the first request
	
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystInstance => $self, log => $self->log },
		sub { $self->rapidApp->rootModule },
	);
};

sub r        { (shift)->rapidApp } # handy alias
sub rapidApp { (shift)->model("RapidApp"); }
sub module   { (shift)->model("RapidApp")->module(@_); }

after 'setup_components' => sub {
	my ($class) = @_;
	# At this point, we don't have a catalyst instance yet, just the package name.
	# Catalyst has an amazing number of package methods that masquerade as instance methods later on.
	#local $SIG{__DIE__}= \&RapidApp::Error::dieConverter;
	try {
		RapidApp::ScopedGlobals->applyForSub(
			{ catalystClass => $class, log => $class->log },
			sub { $class->setupRapidApp }
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
	
	# for each view, inject it if it doens't exist
	injectUnlessExist( 'Catalyst::View::TT', 'View::RapidApp::TT' );
	injectUnlessExist( 'RapidApp::View::Viewport', 'View::RapidApp::Viewport' );
	injectUnlessExist( 'RapidApp::View::JSON', 'View::RapidApp::JSON' );
	injectUnlessExist( 'RapidApp::View::HttpStatus', 'View::RapidApp::HttpStatus' );
};

sub injectUnlessExist {
	my ($actual, $virtual)= @_;
	my $catClass= RapidApp::ScopedGlobals->catalystClass;
	if (!$catClass->components->{$virtual}) {
		RapidApp::ScopedGlobals->log->debug("RapidApp: Installing virtual $virtual");
		CatalystX::InjectComponent->inject( into => $catClass, component => $actual, as => $virtual );
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