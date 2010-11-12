package RapidApp::AppCnt;


use strict;
use Moose;

extends 'RapidApp::AppBase';


use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);


has 'listeners' => (is => 'ro', builder => '_build_listeners', isa => 'HashRef' );
sub _build_listeners { return {}; }

has 'config' => ( is => 'ro', builder => '_build_config', isa => 'HashRef' );
sub _build_config { return {} }

use RapidApp::MooseX::ClassAttrSugar;
setup_apply_methods_for('config');


around 'ONREQUEST' => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->init_reset_hash_attribute_defaults('config','listeners');
	
	return $self->$orig(@_);
};


has 'default_attrs' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );
sub init_reset_hash_attribute_defaults {
	my $self = shift;
	my @attrs = @_;
	
	# Reset attributes to default on every request:
	# We need to do this to make sure the these attrs are built fresh on every request.
	# We don't do this by setting the RapidApp::Role::PerRequestVar trait on the attributes
	# because that would reset them to empty, and we need to preserve the base options that
	# may be set by "apply_default_*" (i.e. apply_default_config) in any number of subclasses.
	# apply_default_* (setup by RapidApp::MooseX::ClassAttrSugar::setup_apply_methods_for)
	# are called in class context and should apply to every object. This technique allows us
	# to purge the changes made in object context (i.e. $obj->apply_config) but not purge the defaults
	# set by apply_default_config OR the defaults that came out of the initial object construction
	# (i.e. during BUILD):
	
	foreach my $attr (@attrs) {
		if (defined $self->default_attrs->{$attr}) {
			# On every other call, we reset to the previously set defaults:
			%{ $self->$attr } = %{ $self->default_attrs->{$attr} };
		}
		else {
			# On the first call, we set the defaults:
			%{ $self->default_attrs->{$attr} } = %{ $self->$attr };
		}
	}
}





sub content {
	my $self = shift;
	
	$self->apply_config(listeners => $self->listeners) if (keys %{$self->listeners});
	
	return $self->config;
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;