package RapidApp::RootModule;

use Moose;
use RapidApp::Include 'perlutil';
extends 'RapidApp::AppBase';

=head1 NAME

RapidApp::RootModule;

=cut

has 'app_title' => ( is => 'rw', isa => 'Str', default => 'RapidApp Application' );

=head1 DESCRIPTION

RootModule adds a small amount of custom processing needed for the usual "root module".

You can just as easily write your own root module.

=head1 METHODS

=head2 BUILD

RootModule enables the auto_viewport capability of Controller by default.

=cut

our @GLOBAL_INIT_CODEREFS = ();

sub BUILD {
	my $self= shift;
	
	# Execute arbitrary code setup earlier in the init process that needs
	# to be called after the RapidApp Module tree has been loaded
	# See RapidApp::Functions::rapidapp_add_global_init_coderef() for more info
	foreach my $coderef (@RapidApp::RootModule::GLOBAL_INIT_CODEREFS) {
		$coderef->($self);
	}
	
	$self->auto_web1(1);
	$self->auto_viewport(1);
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