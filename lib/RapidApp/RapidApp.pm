package RapidApp::RapidApp;

use Moose;
use namespace::autoclean;
extends 'Catalyst::Model';

use RapidApp::Include 'perlutil';
BEGIN { use RapidApp::Error; }

use RapidApp::ScopedGlobals 'sEnv';

# the package name of the catalyst application, i.e. "GreenSheet" or "HOPS"
has 'catalystAppClass' => ( is => 'rw', isa => 'Str', required => 1 );

# the class name of the root module
has 'rootModuleClass' => ( is => 'rw', isa => 'Str', lazy_build => 1 );
sub _build_rootModuleClass {
	return (shift)->defaultRootModuleClass;
}

# the default root module class name
sub defaultRootModuleClass {
	return (shift)->catalystAppClass . '::Modules::Root';
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
	$result->{catalystAppClass} ||= sEnv->catalystClass;
	return $result;
};

sub BUILD {
	my $self= shift;
}

sub _setup_finalize {
	my $self= shift;
	$self->performModulePreload() if ($self->preloadModules);
}

sub _build_rootModule {
	my $self= shift;
	
	# if we're doing this at runtime, just load the module.
	if (sEnv->varExists('catalystInstance')) {
		return $self->_load_root_module;
	}
	# else, we're preloading, and we want diagnostics
	else {
		$self->performModulePreload;
		return $self->rootModule;
	}
}

sub _load_root_module {
	my $self= shift;
	
	sEnv->log->debug("Running require on root module ".$self->rootModuleClass);
	Catalyst::Utils::ensure_class_loaded($self->rootModuleClass);
	
	my $mParams= $self->rootModuleConfig || {};
	return $self->rootModule($self->rootModuleClass->timed_new($mParams));
}

sub performModulePreload {
	my $self= shift;
	
	# Access the root module, causing it to get built
	# We set RapidAppModuleLoadTimeTracker to instruct the modules to record their load times.
	my $loadTimes= {};
	sEnv->applyForSub(
		{ RapidAppModuleLoadTimeTracker => $loadTimes },
		sub { $self->rootModule($self->_load_root_module) }
	);
	scalar(keys %$loadTimes)
		and $self->displayLoadTimes($loadTimes);
}

sub displayLoadTimes {
	my ($self, $loadTimes)= @_;
	
	my $bar= '--------------------------------------------------------------------------------------';
	my $summary= "Loaded RapidApp Modules:\n";
	my @colWid= ( 25, 50, 7 );
	$summary.= sprintf(".%.*s+%.*s+%.*s.\n",     $colWid[0],      $bar,  $colWid[1],    $bar,  $colWid[2],   $bar);
	$summary.= sprintf("|%*s|%*s|%*s|\n",       -$colWid[0], ' Module', -$colWid[1], ' Path', -$colWid[2], ' Time');
	$summary.= sprintf("+%.*s+%.*s+%.*s+\n",     $colWid[0],      $bar,  $colWid[1],    $bar,  $colWid[2],   $bar);
	my @prevPath= ();
	for my $key (sort keys %$loadTimes) {
		my ($path, $module, $time)= ($key, $loadTimes->{$key}->{module}, $loadTimes->{$key}->{loadTime});
		$path=~ s|[^/]*?/| /|g;
		$path=~ s|^ /|/|;
		$module =~ s/^(.*::)//; # trim the leading portion of the package name
		$module = substr($module, -$colWid[0]);  # cut of the front of the string if necesary
		$path= substr($path, -$colWid[1]);
		$summary.= sprintf("| %*s| %*s| %*.3f |\n", -($colWid[0]-1), $module, -($colWid[1]-1), $path, $colWid[2]-2, $time);
	}
	$summary.= sprintf("'%.*s+%.*s+%.*s'\n",     $colWid[0],      $bar,  $colWid[1],    $bar,  $colWid[2],   $bar);
	$summary.= "\n";
	
	sEnv->log->debug($summary);
}

sub largestCommonPrefix {
	my ($a, $b)= @_;
	my $i= 0;
}

sub module {
	my ($self, @path)= @_;
	if (scalar(@path) == 1) { # if path is a string, break it into its components
		@path= split('/', $path[0]);
	}
	@path= grep /.+/, @path;  # ignore empty strings
	
	my $m= $self->rootModule;
	for my $part (@path) {
		$m= $m->Module($part) or die "No such module: ".join('/',@path);
	}
	return $m;
}

1;
