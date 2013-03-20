package RapidApp::RootModule;

use Moose;
use RapidApp::Include 'perlutil';
extends 'RapidApp::AppBase';

require Module::Runtime;

=head1 NAME

RapidApp::RootModule;

=head1 DESCRIPTION

RootModule adds a small amount of custom processing needed for the usual "root module".

You can just as easily write your own root module.

=head1 METHODS

=head2 BUILD

RootModule enables the auto_viewport capability of Controller by default.

=cut

our @GLOBAL_INIT_CODEREFS = ();

has 'app_title', is => 'rw', isa => 'Str', default => 'RapidApp Application';

has 'main_module_class', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => undef;
has 'main_module_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {{}};

# default_module now 'main' by default:
around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $params= $class->$orig(@args);
	$params->{default_module} ||= 'main';
	$params->{module_name} ||= '';
	return $params;
};

sub BUILD {
	my $self= shift;
	
	# Make the root module instance available as a ScopedGlobal
	# see _load_root_module
	$RapidApp::ScopedGlobals::_vals->{'rootModule'} = $self
		# this line is just for safety:
		if (exists $RapidApp::ScopedGlobals::_vals->{'rootModule'});
	
	# Execute arbitrary code setup earlier in the init process that needs
	# to be called after the RapidApp Module tree has been loaded
	# See RapidApp::Functions::rapidapp_add_global_init_coderef() for more info
	foreach my $coderef (@RapidApp::RootModule::GLOBAL_INIT_CODEREFS) {
		$coderef->($self);
	}
	
	$self->auto_web1(1);
	$self->auto_viewport(1);
	
	## ---
	## NEW: optional auto initialization of the 'main' Module
	if($self->main_module_class) {
		Module::Runtime::require_module($self->main_module_class);
		$self->apply_init_modules(
			main => {
				class => $self->main_module_class,
				params => $self->main_module_params
			}
		);
	}
	##
	## ---
}

sub Controller {
	my $self= shift;
	$self->c->stash->{title} = $self->app_title;
	return $self->SUPER::Controller(@_);
}

# build a HTML viewport for the ExtJS content
# we override the config_url and the title
sub viewport {
	my $self= shift;
	my $ret= $self->SUPER::viewport;
	$self->c->stash->{config_url} = $self->base_url . '/' . $self->default_module;
	return $ret;
};

no Moose;
__PACKAGE__->meta->make_immutable;
1;