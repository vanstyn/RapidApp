package RapidApp::Role::CatalystApplication;

use Moose::Role;
use RapidApp::Include 'perlutil';

use CatalystX::InjectComponent;

after 'BUILD' => sub {
	my $self= shift;
	# access root module, forcing it to get built now, instead of on the first request
	
	RapidApp::ScopedGlobals->applyForSub(
		{ catalystInstance => $self },
		sub { $self->rapidApp->rootModule },
	);
}

sub r { (shift)->rapidApp } # handy alias
has 'rapidApp' => ( is => 'ro', isa => 'RapidApp::RapidApp', lazy_build => 1 );
sub _build_rapidApp {
	my $self= shift;
	return RapidApp::RapidApp->new($self->config->{'RapidApp'});
}

sub module {
	my ($self, @path)= @_;
	if (scalar(@path) == 1) { # if path is a string, break it into its components
		@path= split('/', $path[0]);
	}
	@path= grep /.+/, @path;  # ignore empty strings
	
	my $m= $self->rapidApp->rootModule;
	foreach $part (@path) {
		$m= $m->module($part) or die "No such module: ".join('/',@path);
	}
	return $m;
}

our $catClass;
our $log;
after 'setup_components' => sub {
	# At this point, we don't have a catalyst instance yet, just the package name.
	# Catalyst has an amazing number of package methods that masquerade as instance methods later on.
	local $catClass= shift;
	local $log= $catClass->log;
	
	my @names= keys %{ $catClass->components };
	my @controllers= grep /[^:]+::Controller.*/, @names;
	my $haveRoot= 0;
	foreach my $ctlr (@controllers) {
		if ($ctlr->DOES('RapidApp::Role::TopController')) {
			$log->info("RapidApp: Found $ctlr which implements TopController.");
			$haveRoot= 1;
		}
	}
	if (!$haveRoot) {
		$log->info("RapidApp: No TopController found, using default");
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
	if (!$catClass->components->{$virtual}) {
		$log->debug("RapidApp: Installing virtual $virtual");
		CatalystX::InjectComponent->inject( into => $catClass, component => $actual, as => $virtual );
	}
}

1;