package RapidApp::ExtJS::ContainerObject;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Tree
#
#
# 2010-02-28:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;


extends 'RapidApp::ExtJS::ConfigObject';


our $VERSION = '0.1';

#### --------------------- ####


has 'children_container'	=> ( is => 'rw',	init_arg => undef, default		=> 'items'			);
has '_Children' 				=> ( is => 'ro',	default		=> sub { [] },	isa => 'ArrayRef'		);
has '_has_parents'			=> ( is => 'rw',	default		=> 0											);


around '_build__param_hash' => sub {
	my $orig = shift;
	my $self = shift;
	
	$self->_exclude_attributes->{children_container} = 1;
	$self->_exclude_attributes->{_Children} = 1;
	$self->_exclude_attributes->{_has_parents} = 1;
	
	my $param_hash = $self->$orig;
	
	if (defined $param_hash->{$self->children_container}) {
		$self->add_child($param_hash->{$self->children_container});
		delete $param_hash->{$self->children_container};
	}
	
	return $param_hash;
};


around 'Config' => sub {
	my $orig = shift;
	my $self = shift;
	my $Config = $self->$orig;
	
	$Config->{$self->children_container} = $self->ChildConfigs;
	delete $Config->{$self->children_container} unless (defined $Config->{$self->children_container});
	
	return $Config;
};



sub ChildConfigs {
	my $self = shift;
	
	my @arr = ();
	
	foreach my $Child (@{$self->_Children}) {
		push @arr, $Child->Config;
	}
	
	return undef if (scalar @arr == 0);
	return $arr[0] if (scalar @arr == 1);
	return \@arr;
}


sub add_child {
	my $self = shift;
	my $child = shift;
	
	if (ref($child) eq 'ARRAY') {
		foreach my $ch (@$child) {
			$self->add_child($ch);
		}
		return 1;
	}
	
	my $Child;
	
	if (ref($child) eq 'HASH') {
		$Child = $self->meta->name->new($child);
	}
	elsif (ref($child) eq ref($self)) {
		$Child = $child;
	}
	else {
		die "Invalid child node specification!";
	}
	
	$Child->_has_parents(1);
	$Child->children_container($self->children_container);
	
	return push @{$self->_Children}, $Child;
}

sub no_children {
	my $self = shift;
	return 1 if (scalar @{$self->_Children} == 0);
	return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;