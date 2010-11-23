package RapidApp::Role::Module;
#
# -------------------------------------------------------------- #
#
use Term::ANSIColor qw(:constants);

use strict;
use Moose::Role;

use Clone qw(clone);

our $VERSION = '0.1';


has 'module_name'						=> ( is => 'ro',	default => undef );
has 'parent_module_ref'					=> ( is => 'ro',	default => undef );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module' );
has 'create_module_params'			=> ( is => 'ro',	default => sub { {} } );
has 'content'							=> ( is => 'ro',	default => sub { {} } );
has 'modules_params'					=> ( is => 'ro',	default => sub { {} } );

# All purpose options:
has 'module_options' => ( is => 'ro', lazy => 1, default => sub {{}}, traits => [ 'RapidApp::Role::PerRequestVar' ] );


has 'per_request_attr_build_defaults' => ( is => 'ro', default => sub {{}}, isa => 'HashRef' );

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	
	# Init ONREQUEST_called to true to prevent ONREQUEST from running during BUILD:
	$self->ONREQUEST_called(1);
	
	foreach my $class (values %{$self->modules}) {
		eval "use $class";
	};
};

# 'ONREQUEST' is called once per web request. Add before modifiers to any classes that
# need to run code at this time
has 'ONREQUEST_called' => ( is => 'rw', lazy => 1, default => 0, traits => [ 'RapidApp::Role::PerRequestVar' ] );
sub ONREQUEST {
	my $self = shift;
	
	foreach my $attr ($self->meta->get_all_attributes) {
		if ($attr->does('RapidApp::Role::PerRequestBuildDefReset')) {
			# Reset to default:
			if(defined $self->per_request_attr_build_defaults->{$attr->name}) {
				my $val = $self->per_request_attr_build_defaults->{$attr->name};
				$val = clone($val) if (ref($val));
				$attr->set_value($self,$val);
			}
			# Initialize default:
			else {
				my $val = $attr->get_value($self);
				$val = clone($val) if (ref($val));
				$self->per_request_attr_build_defaults->{$attr->name} = $val;
			}
		}
	}
	
	$self->ONREQUEST_called(1);
	return $self;
}

sub THIS_MODULE {
	my $self = shift;
	return $self->ONREQUEST unless ($self->ONREQUEST_called);
	return $self;
}


sub Module {
	my $self = shift;
	my $name = shift;
	
	$self->_load_module($name) or die "Failed to load Module '$name'";
	
	return $self->modules_obj->{$name}->THIS_MODULE;
}


sub _load_module {
	my $self = shift;
	my $name = shift or return 0;
	
	my $class_name = $self->modules->{$name} or return 0;
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
	$params->{parent_module_ref} = $self;
	
	my $Object = $class_name->new($params) or die "Failed to create module instance ($class_name)";
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

sub recursive_clear_per_request_vars {
	my $self= shift;
	
	# clear our own
	$self->clear_per_request_vars;
	
	# now clean up all sub-modules
	foreach my $subobj (values %{$self->modules_obj}) {
		$subobj->recursive_clear_per_request_vars;
	}
}

sub clear_per_request_vars {
	my $self= shift;
	
	#my $listmsg= $self->c->log->is_debug? ($self->module_name? $self->module_name : '[root]').': Clearing' : undef;
	
	# if the no_persist property is true, clear ALL the lazy parameters
	# note that no_persist is not quite the same as PerRequestVar, because PerRequestVar can also reset non-lazy attributes
	if ($self->can('no_persist') && $self->no_persist) {
		for my $attr ($self->meta->get_all_attributes) {
			if ($attr->is_lazy or $attr->has_clearer) {
				$attr->clear_value($self);
				#defined $listmsg and $listmsg.= ' '.$attr->name;
			}
		}
	}
	
	# clear all attributes which have the role 'PerRequestVar'
	foreach my $attr (grep { Moose::Util::does_role($_, 'RapidApp::Role::PerRequestVar') } $self->meta->get_all_attributes) {
		#defined $listmsg and $listmsg.= ' '.$attr->name;
		$attr->clear_value($self);
		# reset the default, if it isn't lazy
		if (!$attr->is_lazy && $attr->has_default) {
			$attr->set_initial_value($self, $attr->default($self));
		}
	}
	#defined $listmsg and $self->c->log->debug($listmsg);
}

# add or replace modules (i.e. as passed to the modules param of the constructor):
sub apply_modules {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	%{ $self->modules } = (
		%{ $self->modules },
		%new
	);
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




1;