package RapidApp::Role::Module;
use Moose::Role;
use strict;
#
# -------------------------------------------------------------- #
#

use RapidApp::Include qw(sugar perlutil);


use Clone qw(clone);
use Time::HiRes qw(gettimeofday);
use Catalyst::Utils;
use Scalar::Util 'weaken';

our $VERSION = '0.1';


has 'module_name'						=> ( is => 'ro',	isa => 'Str', required => 1 );
has 'module_path'						=> ( is => 'ro',	isa => 'Str', required => 1 );
has 'parent_module_ref'					=> ( is => 'ro',	isa => 'Maybe[RapidApp::Role::Module]', weak_ref => 1, required => 1);
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'rw',	default => 'default_module' );
has 'create_module_params'			=> ( is => 'ro',	default => sub { {} } );
has 'modules_params'					=> ( is => 'ro',	default => sub { {} } );

has 'print_rapidapp_handlers_call_debug' => ( is => 'rw', isa => 'Bool', default => 0 );


# All purpose options:
has 'module_options' => ( is => 'ro', lazy => 1, default => sub {{}}, traits => [ 'RapidApp::Role::PerRequestVar' ] );

has 'modules' => (
	traits	=> ['Hash'],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_modules			=> 'set',
		 get_module				=> 'get',
		 has_module				=> 'exists',
		 module_class_list	=> 'values'
	}
);


has 'per_request_attr_build_defaults' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );
has 'per_request_attr_build_not_set' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );

sub timed_new {
	my ($class, @args)= @_;
	my ($sec0, $msec0)= gettimeofday;
	my $result= $class->new(@args);
	my ($sec1, $msec1)= gettimeofday;
	my $elapsed= ($sec1-$sec0)+($msec1-$msec0)*.000001;
	if (RapidApp::ScopedGlobals->varExists("RapidAppModuleLoadTimeTracker")) {
		RapidApp::ScopedGlobals->RapidAppModuleLoadTimeTracker->{$result->base_url}= { module => ref $result, loadTime => $elapsed };
	}
	elsif (RapidApp::ScopedGlobals->varExists("log")) {
		RapidApp::ScopedGlobals->log->debug(sprintf("Loaded RapidApp module ".(ref $result)." at ".$result->base_url.": %0.3f s", $elapsed));
	}
	return $result;
};

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	
	# Init ONREQUEST_called to true to prevent ONREQUEST from running during BUILD:
	$self->ONREQUEST_called(1);
	
	foreach my $mod ($self->module_class_list) {
		my $class= ref($mod) eq ''? $mod : ref $mod eq 'HASH'? $mod->{class} : undef;
		Catalyst::Utils::ensure_class_loaded($class) if defined $class;
	};
	
	# Init:
	$self->cached_per_req_attr_list;
};

sub cached_per_req_attr_list {
	my $self = shift;
	# XXX TODO: I think there is some Moose way of applying roles to the meta object,
	#   but I'm not taking the time to look it up.  This would also help with clearing the cache
	#   if new attributes were defined.
	my $attrs= (ref $self)->meta->{RapidApp_Module_PerRequestAttributeList};
	if (!defined $attrs) {
		my $attrs= [ grep { $self->should_clear_per_req($_) } $self->meta->get_all_attributes ];
		# we don't want this cache to make attributes live longer than needed, so weaken the references
		for (my $i=$#$attrs; $i>=0; $i--) {
			weaken $attrs->[$i];
		}
		(ref $self)->meta->{RapidApp_Module_PerRequestAttributeList}= $attrs;
	}
	return $attrs;
};

sub should_clear_per_req {
	my $self = shift;
	my $attr = shift;
	
	return 1 if (
		$attr->does('RapidApp::Role::PerRequestBuildDefReset') or 
		$attr->does('RapidApp::Role::PerRequestVar')
	);
	
	return 0;
}


# Does the same thing as apply_modules but also init/loads the modules
sub apply_init_modules {
	my $self = shift;
	my %mods = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$self->apply_modules(%mods);
	foreach my $module (keys %mods) {
		# Initialize every module that we just added and set ONREQUEST_called back to false:
		$self->Module($module)->ONREQUEST_called(0);
	}
}

# 'ONREQUEST' is called once per web request. Add before modifiers to any classes that
# need to run code at this time
#has 'ONREQUEST_called' => ( is => 'rw', lazy => 1, default => 0, traits => [ 'RapidApp::Role::PerRequestVar' ] );

has 'ONREQUEST_called' => ( is => 'rw', lazy => 1, default => 0 );

has '_lastRequestApplied' => ( is => 'rw', default => 0 );

sub reset_ONREQUEST {
	my $self = shift;
	$self->_lastRequestApplied(0);
}



sub ONREQUEST {
	my $self = shift;
	
	#$self->c->log->debug(MAGENTA . '[' . $self->get_rapidapp_module_path . ']->ONREQUEST (' . $self->c->stash->{rapidapp_request_id} . ')');
	
	$self->_lastRequestApplied($self->c->stash->{rapidapp_request_id});
	
	$self->init_per_req_attrs;
	$self->c->stash->{rapidapp_called_modules}->{$self->module_path} = undef;
	
	#$self->new_clear_per_req_attrs;
	
	$self->call_rapidapp_handlers($self->all_ONREQUEST_calls_early);
	$self->call_rapidapp_handlers($self->all_ONREQUEST_calls);
	$self->call_rapidapp_handlers($self->all_ONREQUEST_calls_late);
	
	$self->ONREQUEST_called(1);
	return $self;
}



sub init_per_req_attrs {
	my $self = shift;
	
	foreach my $attr (@{$self->cached_per_req_attr_list}) {
		if($attr->has_value($self)) {
			unless (defined $self->per_request_attr_build_defaults->{$attr->name}) {
				my $val = $attr->get_value($self);
				$val = clone($val) if (ref($val));
				$self->per_request_attr_build_defaults->{$attr->name} = $val;
			}
		}
		else {
			$self->per_request_attr_build_not_set->{$attr->name} = 1;
		}
	}
}

sub reset_per_req_attrs {
	my $self = shift;
	my $c = shift;
	
	foreach my $attr (@{$self->cached_per_req_attr_list}) {

		# Reset to "not_set":
		if (defined $self->per_request_attr_build_not_set->{$attr->name}) {
			#$c->log->debug(GREEN . BOLD . ' =====> ' . $attr->name . ' (clear_value)' . CLEAR);
			$attr->clear_value($self);
		}
		# Reset to default:
		elsif(defined $self->per_request_attr_build_defaults->{$attr->name}) {
			my $val = $self->per_request_attr_build_defaults->{$attr->name};
			$val = clone($val) if (ref($val));
			#$c->log->debug(YELLOW . BOLD . ' =====> ' . $attr->name . ' (set_value)' . CLEAR);
			$attr->set_value($self,$val);
		}
	}
	
	# Legacy:
	$self->clear_attributes if ($self->no_persist);
}




#sub new_clear_per_req_attrs {
#	my $self = shift;
#	
#	#$self->ONREQUEST_called(0);
#	
#	foreach my $attr (@{$self->cached_per_req_attr_list}) {
#		# Reset to default:
#		if(defined $self->per_request_attr_build_defaults->{$attr->name}) {
#			my $val = $self->per_request_attr_build_defaults->{$attr->name};
#			$val = clone($val) if (ref($val));
#			$attr->set_value($self,$val);
#		}
#		# Initialize default:
#		else {
#			my $val = $attr->get_value($self);
#			$val = clone($val) if (ref($val));
#			$self->per_request_attr_build_defaults->{$attr->name} = $val;
#		}
#	}
#	
#	# Legacy:
#	$self->clear_attributes if ($self->no_persist);
#}




sub THIS_MODULE {
	my $self = shift;
	return $self unless (defined $self->c);
	
	return $self->ONREQUEST if (defined $self->c && $self->c->stash->{rapidapp_request_id} != $self->_lastRequestApplied);
	return $self;
}


sub Module {
	my $self = shift;
	my $name = shift;
	my $no_onreq = shift;
	
	$self->_load_module($name) or die "Failed to load Module '$name'";
	
	#return $self->modules_obj->{$name} if ($no_onreq);
	return $self->modules_obj->{$name}->THIS_MODULE;
}


sub _load_module {
	my $self = shift;
	my $name = shift or return 0;
	return 0 unless ($self->has_module($name));
	
	#my $class_name = $self->modules->{$name} or return 0;
	my $class_name = $self->get_module($name);
	my $params;
	if (ref($class_name) eq 'HASH') {
		$params = $class_name->{params};
		$class_name = $class_name->{class} or die "Missing required parameter 'class'";
	}

	return 1 if (defined $self->modules_obj->{$name} and ref($self->modules_obj->{$name}) eq $class_name);
	
	my $Object = $self->create_module($name,$class_name,$params) or die "Failed to create new $class_name object";
	
	$self->modules_obj->{$name} = $Object;
	
	return 1;
}

sub create_module {
	my $self = shift;
	my $name = shift;
	my $class_name = shift;
	my $params = shift;
	
	$params = $self->create_module_params unless (defined $params);
	
	if (defined $self->modules_params->{$name}) {
		foreach my $k (keys %{$self->modules_params->{$name}}) {
			$params->{$k} = $self->modules_params->{$name}->{$k};
		}
	}
	
	$params->{module_name} = $name;
	$params->{module_path} = $self->module_path;
	$params->{module_path} .= '/' unless substr($params->{module_path}, -1) eq '/';
	$params->{module_path} .= $name;
	$params->{parent_module_ref} = $self;
	
	my $Object = $class_name->timed_new($params) or die "Failed to create module instance ($class_name)";
	die "$class_name is not a valid RapidApp Module" unless ($Object->does('RapidApp::Role::Module'));
	
	return $Object;
}

sub parent_module {
	my $self = shift;
	return $self->parent_module_ref ? $self->parent_module_ref->THIS_MODULE : undef;
}


sub topmost_module {
	my $self = shift;
	return $self unless (defined $self->parent_module);
	return $self->parent_module->topmost_module;
}


sub parent_by_name {
	my $self = shift;
	my $name = shift;
	return $self if (lc($self->module_name) eq lc($name));
	return undef unless (defined $self->parent_module);
	return $self->parent_module->parent_by_name($name);
}



sub applyIf_module_options {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my %unset = ();
	foreach my $opt (keys %new) {
		next if (defined $self->module_options->{$opt});
		$unset{$opt} = $new{$opt};
	}
	
	return $self->apply_module_options(%unset);
}


sub apply_module_options {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
		
	%{ $self->module_options } = (
		%{ $self->module_options },
		%new
	);
}

sub get_module_option {
	my $self = shift;
	my $opt = shift;
	return $self->module_options->{$opt};
}


has 'ONREQUEST_calls' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_ONREQUEST_calls		=> 'elements',
		add_ONREQUEST_calls		=> 'push',
		has_no_ONREQUEST_calls	=> 'is_empty',
	}
);
around 'add_ONREQUEST_calls' => __PACKAGE__->add_ONREQUEST_calls_modifier;

has 'ONREQUEST_calls_early' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_ONREQUEST_calls_early		=> 'elements',
		add_ONREQUEST_calls_early		=> 'push',
		has_no_ONREQUEST_calls_early	=> 'is_empty',
	}
);
around 'add_ONREQUEST_calls_early' => __PACKAGE__->add_ONREQUEST_calls_modifier;

has 'ONREQUEST_calls_late' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[RapidApp::Handler]',
	default   => sub { [] },
	handles => {
		all_ONREQUEST_calls_late		=> 'elements',
		add_ONREQUEST_calls_late		=> 'push',
		has_no_ONREQUEST_calls_late	=> 'is_empty',
	}
);
around 'add_ONREQUEST_calls_late' => __PACKAGE__->add_ONREQUEST_calls_modifier;

sub add_ONREQUEST_calls_modifier { 
	return sub {
		my $orig = shift;
		my $self = shift;
		return $self->$orig(@_) if (ref($_[0]));
		
		my @new = ();
		foreach my $item (@_) {
			push @new, RapidApp::Handler->new(
				method	=> $item,
				scope		=> $self
			);
		}
		return $self->$orig(@new);
	}; 
}

sub call_rapidapp_handlers {
	my $self = shift;
	foreach my $Handler (@_) {
		die 'not a RapidApp::Handler' unless (ref($Handler) eq 'RapidApp::Handler');
		
		if($self->print_rapidapp_handlers_call_debug) {
			my $msg = YELLOW . '->call_rapidapp_handlers[' . $self->get_rapidapp_module_path . '] ' . CLEAR;
			$msg .= GREEN;
			if (defined $Handler->scope) {
				$msg .= '(' . ref($Handler->scope);
				if ($Handler->scope->does('RapidApp::Role::Module')) {
					$msg .= CLEAR . BLUE . ' ' . $Handler->scope->get_rapidapp_module_path;
				}
				$msg .= CLEAR . GREEN . ')' . CLEAR;
			}
			else {
				$msg .= '(no scope)';
			}
			
			if (defined $Handler->method) {
				$msg .= BOLD . '->' . $Handler->method . CLEAR;
			}
			else {
				$msg .= BOLD . '==>CODEREF->()' . CLEAR;
			}
		
			$self->app->log->debug($msg);
		}
		
		$Handler->call;
	}
}

#before 'ONREQUEST' => sub {
#	my $self = shift;
#	$self->call_rapidapp_handlers($self->all_ONREQUEST_calls_early);
#};
#
#after 'ONREQUEST' => sub {
#	my $self = shift;
#	$self->call_rapidapp_handlers($self->all_ONREQUEST_calls_late);
#};


# All purpose flags (true/false) settings
has 'flags' => (
	traits    => [
		'Hash',
		'RapidApp::Role::PerRequestBuildDefReset'
	],
	is        => 'ro',
	isa       => 'HashRef[Bool]',
	default   => sub { {} },
	handles   => {
		 apply_flags	=> 'set',
		 has_flag		=> 'get',
		 delete_flag	=> 'delete',
		 flag_defined	=> 'exists',
		 all_flags		=> 'elements'
	},
);


# function for debugging purposes - returns a string of the module path
sub get_rapidapp_module_path {
	return (shift)->module_path;
}




1;