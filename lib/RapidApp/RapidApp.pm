package RapidApp::RapidApp;

use Moose;
use namespace::autoclean;
extends 'Catalyst::Model';

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::Debug 'DEBUG';
use RapidApp::ScopedGlobals 'sEnv';
use Time::HiRes qw(gettimeofday);
use RapidApp::Role::ErrorReportStore;
use RapidApp::FileErrorStore;

# the package name of the catalyst application, i.e. "GreenSheet" or "HOPS"
has 'catalystAppClass' => ( is => 'rw', isa => 'Str', required => 1, default => sub { sEnv->catalystClass } );

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
has 'rootModuleConfig'  => ( is => 'rw', isa => 'HashRef' );

# whether to preload the modules at catalyst setup time
has 'preloadModules'    => ( is => 'rw', isa => 'Bool', default => 1 );

# the root model instance
has 'rootModule'        => ( is => 'rw', lazy_build => 1 );

has 'enableDirectLink'  => ( is => 'rw', isa => 'Bool', default => 0 );

# Whether to save errors to whichever ExceptionStore is available via whatever configuration
# If this is true and no ExceptionStore is configured, we die
has 'saveErrorReports'  => ( is => 'rw', isa => 'Bool', default => 0 );

# either an exceptionStore instance, or the name of a catalyst Model implementing one
has 'errorReportStore'  => ( is => 'rw', isa => 'Maybe[RapidApp::Role::ErrorReportStore|Str]',
	lazy => 1, default => sub { RapidApp::FileErrorStore->new } );

has 'postprocessing_tasks' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );

sub add_postprocessing_task {
	my $self= shift;
	push @{$self->postprocessing_tasks}, @_;
}

sub resolveErrorReportStore {
	my $self= shift;
	my $store= $self->errorReportStore;
	ref $store or $store= $self->catalystAppClass->model($store);
	return $store;
}

# Each of the following is the path to a module implementing some useful feature.
# The module can be specified in the config, or it will be automatically set by the first
#    module of that type which gets loaded.
has 'errorViewPath' => ( is => 'rw', isa => 'Str' ); # ErrorView
has 'errorAddCommentPath' => ( is => 'rw', isa => 'Str' ); # ErrorCommentHandler
has 'appAuthPath'   => ( is => 'rw', isa => 'Str' ); # AppAuth

sub BUILD {
	my $self= shift;
}

sub _setup_finalize {
	my $self= shift;
	$self->performModulePreload() if ($self->preloadModules && !$ENV{NO_PRELOAD_MODULES});
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
	
	my $log= sEnv->log;
	sEnv->catalystClass->debug
		and $log->debug("Running require on root module ".$self->rootModuleClass);
	$log->_flush if $log->can('_flush');
	Catalyst::Utils::ensure_class_loaded($self->rootModuleClass);
	
	my $mParams= $self->rootModuleConfig || {};
	$mParams->{module_name}= '';
	$mParams->{module_path}= '/';
	$mParams->{parent_module_ref}= undef;
	return $self->rootModule($self->rootModuleClass->timed_new($mParams));
}

# Execute arbitrary code setup earlier in the init process that needs
# to be called after the RapidApp Module tree has been loaded.
# See RapidApp::Functions::rapidapp_add_global_init_coderef() for more info
our @GLOBAL_INIT_CODEREFS = ();
after '_load_root_module' => sub {
	my $self = shift;
	foreach my $coderef (@GLOBAL_INIT_CODEREFS) {
		$coderef->($self->rootModule);
	}
};


sub performModulePreload {
	my $self= shift;
	
	# Access the root module, causing it to get built
	# We set RapidAppModuleLoadTimeTracker to instruct the modules to record their load times.
	if ($self->catalystAppClass->debug) {
		my $loadTimes= {};
		sEnv->applyForSub(
			{ RapidAppModuleLoadTimeTracker => $loadTimes },
			sub { $self->rootModule($self->_load_root_module) }
		);
		scalar(keys %$loadTimes)
			and $self->displayLoadTimes($loadTimes);
	}
	else {
		$self->rootModule($self->_load_root_module);
	}
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

has 'dirtyModules' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

sub markDirtyModule {
	my ($self, $module)= @_;
	$self->dirtyModules->{$module}= $module;
}

sub cleanupAfterRequest {
	my ($self, $c)= @_;
	return unless scalar(keys %{$self->dirtyModules} );
	
	my ($sec0, $msec0)= $c->debug && gettimeofday;
	
	$self->cleanDirtyModules($c);
	
	if ($c->debug) {
		my ($sec1, $msec1)= gettimeofday;
		my $elapsed= ($sec1-$sec0)+($msec1-$msec0)*.000001;
		
		$c->log->info(sprintf("Module init (ONREQUEST) took %0.3f seconds", $c->stash->{onrequest_time_elapsed}));
		$c->log->info(sprintf("Cleanup took %0.3f seconds", $elapsed));
	}
	
	# Now that the request is done, we can run post-processing tasks.
	# These might also get modules dirty, so we clean again after each one.
	if (scalar @{$self->postprocessing_tasks}) {
		my ($sec0, $msec0)= $c->debug && gettimeofday;
		my $reqid= $c->request_id;
		my $i= 1;
		while (my $sub= shift @{$self->postprocessing_tasks}) {
			local $c->{request_id}= $reqid.'.'.$i++;
			RapidApp::ScopedGlobals->applyForSub(
				{ catalystInstance => $c },
				sub { $sub->($c); }
			);
			$self->cleanDirtyModules($c);
		}
		
		if ($c->debug) {
			my ($sec1, $msec1)= gettimeofday;
			my $elapsed= ($sec1-$sec0)+($msec1-$msec0)*.000001;
			
			$c->log->info(sprintf("Post-processing tasks took %0.3f seconds", $elapsed));
		}
	}
}

sub cleanDirtyModules {
	my ($self, $c)= @_;
	my @modules= values %{$self->dirtyModules};
	for my $module (@modules) {
		DEBUG('controller', ' >> CLEARING', $module->module_path);
		$module->reset_per_req_attrs;
	}
	%{$self->dirtyModules}= ();
}

has '_requestCount' => ( is => 'rw', default => 0 );
sub requestCount {
	(shift)->_requestCount;
}
sub incRequestCount {
	my $self= shift;
	$self->_requestCount($self->_requestCount+1);
}

1;
