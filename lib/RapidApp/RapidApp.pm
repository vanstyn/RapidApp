package RapidApp::RapidApp;

use Moose;
use namespace::autoclean;
extends 'Catalyst::Model';

use RapidApp::Include 'perlutil';

# the package name of the catalyst application, i.e. "GreenSheet" or "HOPS"
has 'packageNamespace' => ( is => 'rw', isa => 'Str', required => 1 );

# the class name of the root module
has 'rootModuleClass' => ( is => 'rw', isa => 'Str', lazy_build => 1 );
sub _build_rootModuleClass {
	return (shift)->defaultRootModuleClass;
}

# the default root module class name
sub defaultRootModuleClass {
	return (shift)->packageNamespace . '::Modules::Root';
}

# the config hash for the modules
has 'rootModuleConfig' => ( is => 'rw', isa => 'HashRef' );

# whether to preload the modules at catalyst setup time
has 'preloadModules' => ( is => 'rw', isa => 'Bool', default => 1 );

# the root model instance
has 'rootModule' => ( is => 'rw', lazy_build => 1 );

around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $result= $class->$orig(@args);
	$result->{packageNamespace} ||= RapidApp::ScopedGlobals->catalystClass;
	return $result;
};

sub BUILD {
	my $self= shift;
	
	RapidApp::ScopedGlobals->log->debug("Running require on root module ".$self->rootModuleClass);
	Catalyst::Utils::ensure_class_loaded($self->rootModuleClass);
	
	if ($self->preloadModules) {
		$self->rootModule;
	}
}

sub _build_rootModule {
	my $self= shift;
	
	my $mParams= $self->rootModuleConfig || {};
	return $self->rootModule($self->rootModuleClass->new($mParams));
}

sub module {
	my ($self, @path)= @_;
	if (scalar(@path) == 1) { # if path is a string, break it into its components
		@path= split('/', $path[0]);
	}
	@path= grep /.+/, @path;  # ignore empty strings
	
	my $m= $self->rapidApp->rootModule;
	for my $part (@path) {
		$m= $m->Module($part) or die "No such module: ".join('/',@path);
	}
	return $m;
}

1;
