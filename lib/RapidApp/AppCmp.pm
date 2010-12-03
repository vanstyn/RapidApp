package RapidApp::AppCmp;

use strict;
use Moose;

extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);


sub BUILD {
	my $self = shift;
	
	# Add the Ext.ux.RapidApp.Plugin.EventHandlers plugin to all AppCmp
	# based objects:
	$self->add_plugin({ ptype => 'rappeventhandlers' });
}



sub content {
	my $self = shift;
	
	$self->apply_all_extconfig_attrs;
	
	return $self->extconfig;
}


sub apply_all_extconfig_attrs {
	my $self = shift;
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (
			$attr->does('RapidApp::Role::AppCmpConfigParam') and
			$attr->has_value($self)
		);
		
		$self->apply_extconfig( $attr->name => $attr->get_value($self) );
	}
}


has 'extconfig' => (
	traits    => [
		'Hash',
		'RapidApp::Role::PerRequestBuildDefReset'
	],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_extconfig			=> 'set',
		 get_extconfig_param		=> 'get',
		 has_extconfig_param		=> 'exists',
		 has_no_extconfig 		=> 'is_empty',
		 num_extconfig_params	=> 'count',
		 delete_extconfig_param	=> 'delete'
	},
);
# 'config' is being renamed to 'extconfig' 
# These mappings are for backward compatability and will be removed
# at some point. Once they are removed, it will force an API change
# that can be made at any time, since 'extconfig' is already active
sub config 						{ (shift)->extconfig(@_) }
sub apply_config 				{ (shift)->apply_extconfig(@_) }
sub get_config_param			{ (shift)->get_extconfig_param(@_) }
sub has_config_param			{ (shift)->has_extconfig_param(@_) }
sub has_no_config				{ (shift)->has_no_extconfig(@_) }
sub num_config_params		{ (shift)->num_extconfig_params(@_) }
sub delete_config_param		{ (shift)->delete_extconfig_param(@_) }
sub apply_all_config_attrs	{ (shift)->apply_all_extconfig_attrs(@_) }


has 'listeners' => (
	traits    => [
		'Hash',
		'RapidApp::Role::AppCmpConfigParam',
		'RapidApp::Role::PerRequestBuildDefReset'
	],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_listeners	=> 'set',
		 get_listener		=> 'get',
		 has_no_listeners => 'is_empty',
		 num_listeners		=> 'count',
		 delete_listeners	=> 'delete'
	},
);


has 'plugins' => (
	traits    => [
		'Array',
		'RapidApp::Role::AppCmpConfigParam',
		'RapidApp::Role::PerRequestBuildDefReset',
	],
	is        => 'ro',
	isa       => 'ArrayRef',
	default   => sub { [] },
	handles => {
		add_plugin		=> 'push',
		has_no_plugins	=> 'is_empty',
		plugin_list		=> 'uniq'
	}
);

# event_handlers do basically the same thing as "listeners" except it is
# setup as a list instead of a hash, allowing multiple handlers to be
# defined for the same event. Items should be added as ArrayRefs, with
# the first element defining a string representing the event name, and the
# remaining elements representing 1 or more handlers (RapidApp::JSONFunc
# objects). Unlike "listeners" which is a built-in config param associated
# with all Ext.Observable objects, "event_handlers" is a custom param that
# is processed in the Ext.ux.RapidApp.Plugin.EventHandlers plugin which is
# also setup in AppCmp
has 'event_handlers' => (
	traits    => [
		'Array',
		'RapidApp::Role::AppCmpConfigParam',
		'RapidApp::Role::PerRequestBuildDefReset',
	],
	is        => 'ro',
	isa       => 'ArrayRef[ArrayRef]',
	default   => sub { [] },
	handles => {
		add_event_handlers		=> 'push',
		has_no_event_handlers	=> 'is_empty',
	}
);

#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;