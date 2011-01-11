package RapidApp::AppCmp;

use strict;
use Moose;

extends 'RapidApp::AppBase';

use RapidApp::Include qw(sugar perlutil);

sub BUILD {
	my $self = shift;
	
	# Add the Ext.ux.RapidApp.Plugin.EventHandlers plugin to all AppCmp
	# based objects:
	$self->add_plugin({ ptype => 'rappeventhandlers' });
	
	# if a subclass overrode the web1_render function, we need to let ExtConfig2Html know
	if ($self->can('web1_render') != \&web1_render) {
		#$self->extconfig->{rapidapp_author_module} ||= $self->module_path;
		$self->extconfig->{rapidapp_cfg2html_renderer}= RapidApp::AppCmp::SelfConfigRender->new($self->module_path);
	}
}

sub content {
	my $self = shift;
	#return bless { %{$self->get_complete_extconfig} }, 'RapidApp::AppCmp::SelfConfigRender';
	return $self->get_complete_extconfig;
}

sub web1_render {
	my ($self, $renderCxt, $extConfig)= @_;
	$renderCxt->renderer->isa('RapidApp::Web1RenderContext::ExtCfg2Html')
		or die "Renderer for automatic ext->html conversion must be a Web1RenderContext::ExtCfg2Html";
	$extConfig ||= $self->get_complete_extconfig;
	$renderCxt->render($renderCxt, $extConfig);
}

sub get_complete_extconfig {
	my $self = shift;
	$self->apply_all_extconfig_attrs;
	$self->call_rapidapp_handlers($self->all_ONCONTENT_calls);
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


has 'ONCONTENT_calls' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_ONCONTENT_calls		=> 'elements',
		add_ONCONTENT_calls		=> 'push',
		has_no_ONCONTENT_calls	=> 'is_empty',
	}
);
around 'add_ONCONTENT_calls' => __PACKAGE__->add_ONREQUEST_calls_modifier;




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



has 'listener_callbacks' => (
	traits    => [
		'Hash',
		'RapidApp::Role::AppCmpConfigParam',
		'RapidApp::Role::PerRequestBuildDefReset'
	],
	is        => 'ro',
	isa       => 'HashRef[ArrayRef[RapidApp::JSONFunc]]',
	default   => sub { {} },
	handles   => {
		 apply_listener_callbacks	=> 'set',
		 get_listener_callbacks		=> 'get',
		 has_listener_callbacks		=> 'exists'
	},
);
sub add_listener_callbacks {
	my $self = shift;
	my $event = shift;
	
	my $list = [];
	$list = $self->get_listener_callbacks($event) if ($self->has_listener_callbacks($event));
	
	push @$list, @_;
	
	return $self->apply_listener_callbacks( $event => $list );	
}



sub add_listener {
	my $self = shift;
	my $event = shift;
	
	$self->add_listener_callbacks($event,@_);
	
	my $handler = RapidApp::JSONFunc->new( raw => 1, func =>
		'function(scope) {' .
			'var args = arguments;' .
			'if(scope.listener_callbacks) {' .
				'var list = scope.listener_callbacks["' . $event . '"];' .
				'if(Ext.isArray(list)) {' .
					'Ext.each(list,function(fn) {' .
						'fn.apply(this,args);' .
					'},scope);' .
				'}' .
			'}' .
		'}'
	);
	
	return $self->apply_listeners( $event => $handler );
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;

package RapidApp::AppCmp::SelfConfigRender;
=pod

This class gets applied to ExtConfig hashes to cause them to come back to the originating module
to be correctly rendered.  It gets frequently created, and seldom used, so don't bother with Moose.
All it does is relay calls to "renderAsHtml" to a module's "web1_render", and hide itself during JSON
serialization.

=cut

our @ISA= ( 'RapidApp::Web1RenderContext::Renderer' );

sub new {
	my ($class, $moduleName)= @_;
	return bless \$moduleName, $class;
}

sub renderAsHtml {
	my ($self, $renderCxt, $extCfg)= @_;
	my $module= RapidApp::ScopedGlobals->catalystInstance->rapidApp->module($$self);
	defined $module or die "No module named $$self exists!";
	$module->web1_render($renderCxt, $extCfg);
}

sub TO_JSON {
	my $self= shift;
	return $$self;
}

1;