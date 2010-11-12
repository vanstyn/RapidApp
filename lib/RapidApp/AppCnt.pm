package RapidApp::AppCnt;


use strict;
use Moose;

extends 'RapidApp::AppBase';


use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);


has 'listeners' => (is => 'ro', builder => '_build_listeners', isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );
sub _build_listeners { return {}; }

has 'config' => ( is => 'ro', builder => '_build_config', isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );
sub _build_config { return {} }

use RapidApp::MooseX::ClassAttrSugar;
setup_apply_methods_for('config');



sub content {
	my $self = shift;
	
	$self->apply_config(listeners => $self->listeners) if (keys %{$self->listeners});
	
	return $self->config;
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;