package RapidApp::AppCmp;

use strict;
use Moose;

extends 'RapidApp::AppBase';

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);


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
	traits    => ['Array','RapidApp::Role::PerRequestBuildDefReset'],
	is        => 'ro',
	isa       => 'ArrayRef',
	default   => sub { [] },
	handles => {
		add_plugin		=> 'push',
		has_no_plugins	=> 'is_empty',
		plugin_list		=> 'uniq'
	}
);




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;