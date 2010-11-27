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
	
	$self->apply_all_config_attrs;
	
	return $self->config;
}


sub apply_all_config_attrs {
	my $self = shift;
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (
			$attr->does('RapidApp::Role::AppCmpConfigParam') and
			$attr->has_value($self)
		);
		
		$self->apply_config( $attr->name => $attr->get_value($self) );
	}
}


has 'config' => (
	traits    => [
		'Hash',
		'RapidApp::Role::PerRequestBuildDefReset'
	],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_config			=> 'set',
		 get_config_param		=> 'get',
		 has_no_config 		=> 'is_empty',
		 num_config_params	=> 'count',
		 delete_config_param	=> 'delete'
	},
);



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