package RapidApp::Role::Module;
#
# -------------------------------------------------------------- #
#


use strict;
use Moose::Role;

our $VERSION = '0.1';


has 'module_name'						=> ( is => 'ro', default => undef );
has 'parent_module'					=> ( is => 'ro', default => undef );
has 'modules'							=> ( is => 'ro', 	default => sub {{}} );
has 'modules_obj'						=> ( is => 'ro', 	default => sub {{}} );
has 'default_module'					=> ( is => 'ro',	default => 'default_module' );
has 'create_module_params'			=> ( is => 'ro',	default => sub { {} } );


sub create_module {
	my $self = shift;
	my $name = shift;
	my $class_name = shift;
	
	my $params = $self->create_module_params;
	$params->{module_name} = $name;
	$params->{parent_module} = $self;
	
	return $class_name->new($params);
}


sub _load_module {
	my $self = shift;
	my $mod = shift or return 0;
	
	my $class_name = $self->modules->{$mod} or return 0;

	return 1 if (defined $self->modules_obj->{$mod} and ref($self->modules_obj->{$mod}) eq $class_name);
	
	my $Object = $self->create_module($mod,$class_name) or die "Failed to create new $class_name object";

	$self->modules_obj->{$mod} = $Object;

	return 1;
}


1;