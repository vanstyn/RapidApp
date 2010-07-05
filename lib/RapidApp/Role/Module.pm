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






1;