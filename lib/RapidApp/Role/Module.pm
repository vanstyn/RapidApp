package RapidApp::Role::Module;
#
# -------------------------------------------------------------- #
#


use strict;
use Moose::Role;

our $VERSION = '0.1';


has 'module_name'						=> ( is => 'ro',	default => undef );
has 'parent_module'					=> ( is => 'ro',	default => undef );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module' );
has 'create_module_params'			=> ( is => 'ro',	default => sub { {} } );
has 'content'							=> ( is => 'ro',	default => sub { {} } );
has 'modules_params'					=> ( is => 'ro',	default => sub { {} } );


sub BUILD {
	my $self = shift;
	foreach my $class (values %{$self->modules}) {
		eval "use $class";
	};
}


sub Module {
	my $self = shift;
	my $name = shift;
	
	$self->_load_module($name) or die "Failed to load Module '$name'";
	return $self->modules_obj->{$name};
}


sub _load_module {
	my $self = shift;
	my $name = shift or return 0;
	
	my $class_name = $self->modules->{$name} or return 0;

	return 1 if (defined $self->modules_obj->{$name} and ref($self->modules_obj->{$name}) eq $class_name);
	
	my $Object = $self->create_module($name,$class_name) or die "Failed to create new $class_name object";

	$self->modules_obj->{$name} = $Object;

	return 1;
}

sub create_module {
	my $self = shift;
	my $name = shift;
	my $class_name = shift;
	
	my $params = $self->create_module_params;
	
	if (defined $self->modules_params->{$name}) {
		foreach my $k (keys %{$self->modules_params->{$name}}) {
			$params->{$k} = $self->modules_params->{$name}->{$k};
		}
	}
	
	$params->{module_name} = $name;
	$params->{parent_module} = $self;
	
	return $class_name->new($params);
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

1;