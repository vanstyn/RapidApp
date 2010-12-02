package RapidApp::RapidApp;

use Moose;
use RapidApp::Include 'perlutil';

has 'rootModuleName' => ( is => 'rw', isa => 'Str' );
has 'preloadModules' => ( is => 'rw', isa => 'Bool', default => 1 );
has 'rootModule' => ( is => 'rw', lazy_build => 1 );
sub _build_rootModule {
	my $self= shift;
	
	# try setting the default
	my $mName= $self->rootModuleName || 'Root';
	
	eval { require $mName; } or die "Failed to load root module.
Set config->{RapidApp}->{rootModuleName},
or create a module named Root,
or assign $c->r->rootModule($module) )";
	
	my $mParams= $config->{RapidApp}->{'ModuleTreeConfig'}
	$self->rootModule($mName->new($mParams));
}

1;
