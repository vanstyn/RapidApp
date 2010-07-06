#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Tree
#
#
# 2010-02-28:	Version 0.1 (HV)
#	Initial development

## ROLE ##
package RapidApp::ExtJS::CheckTreePanel::IsRoot;
use strict;
use Moose::Role;

has 'xtype' 					=> ( is => 'rw',	default => 'checktreepanel'							);
has 'bubbleCheck'				=> ( is => 'rw',	default => 'none'											);
has 'autoScroll' 				=> ( is => 'rw',	default => sub { \1 }										);
has 'border' 					=> ( is => 'rw',	default => sub { \1 }										);
has 'rootVisible'				=> ( is => 'rw',	default => sub { \0 }										);
has 'isFormField'				=> ( is => 'rw',	default => sub { \1 }										);

has 'root' => (
	is => 'ro',
	default => sub {{
		nodeType		=> 'async',
		text			=> 'root',
		id				=> 'root',
		expanded		=> \1
	}}
);

has 'bodyStyle' => (
	is => 'ro',
	default => sub {
		my @bodyStyle = (
			'background-color:white;',
			'border:1px solid #B5B8C8;',
			'padding-top:1px;',
			'padding-bottom:8px;',
		);
		return join('',@bodyStyle);
	}
);
## END ROLE ##

package RapidApp::ExtJS::CheckTreePanel;

use strict;
use Moose;

extends 'RapidApp::ExtJS::BASEConfigObject';


our $VERSION = '0.1';

#### --------------------- ####


has 'leaf' 						=> ( is => 'ro',	lazy_build	=> 1, init_arg => undef					);
has 'is_child' 				=> ( is => 'ro',	default		=> 0											);

has '_Children' 				=> ( is => 'ro',	default		=> sub { [] },	isa => 'ArrayRef'		);
has 'children'					=> ( is => 'ro',	lazy_build	=> 1											);


sub BUILD {
	my $self = shift;
	$self->_exclude_attributes->{_Children} = 1;
	$self->_exclude_attributes->{is_child} = 1;
	RapidApp::ExtJS::CheckTreePanel::IsRoot->meta->apply($self) unless ($self->is_child);
}


before 'Config' => sub {
	my $self = shift;
	my $children_attr = $self->meta->get_attribute('children');
	if ($children_attr and $children_attr->has_value($self)) {
		$self->add_child($children_attr->get_value($self));
		$children_attr->clear_value($self);
	}
	
	
	delete $self->_additional_parameters->{header} if (defined $self->_additional_parameters->{header});
	
	
	if ($self->is_child) {
		my $role_meta = RapidApp::ExtJS::CheckTreePanel::IsRoot->meta;
		foreach my $attr ($role_meta->get_attribute_list) {
			delete $self->_additional_parameters->{$attr} if (defined $self->_additional_parameters->{$attr});
			$self->meta->remove_attribute($attr) if ($self->meta->has_attribute($attr));
		}
	}
	else {
		$self->_additional_parameters->{root}->{children} = $self->children;
	}
};


around 'Config' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $Config = $self->$orig;
	
	unless ($self->is_child) {
	
	#my $Base = RapidApp::ExtJS::BASEConfigObject->new;
	#RapidApp::ExtJS::CheckTreePanel::IsRoot->meta->apply($Base);
	
	
		$Config->{root}->{nodeType}		= 'async';
		$Config->{root}->{text}				= 'root';
		$Config->{root}->{id}				= 'root';
		$Config->{root}->{expanded}		= \1;
		$Config->{root}->{children} 		= $Config->{children};
		
		delete $Config->{leaf};
		delete $Config->{children};
		
	}
	
	delete $Config->{children} if (defined $Config->{children} and scalar @{$Config->{children}} == 0);
	

	return $Config;

};




sub _build_leaf {
	my $self = shift;
	my $leaf = \1;
	
	$leaf = \0 if (scalar @{$self->_Children} > 0);
	return $leaf;
}


sub _build_children {
	my $self = shift;
	my $children = [];
	
	foreach my $CheckTree (@{$self->_Children}) {
				
		push @$children, $CheckTree->Config;
	}
	return $children;
}


## ------------------------------------------- ##

sub add_child {
	my $self = shift;
	my $child = shift;
	
	if (ref($child) eq 'ARRAY') {
		foreach my $ch (@$child) {
			$self->add_child($ch);
		}
		return 1;
	}
	
	my $child_conf = $child;
	$child_conf = $child->Config if (ref($child) eq ref($self));
	
	return unless (ref($child_conf) eq 'HASH');
	
	die "Invalid child node specification!" unless (ref($child_conf) eq 'HASH');
		
	$child_conf->{is_child} = 1;
	
	return push @{$self->_Children}, __PACKAGE__->new($child_conf);
	
	#return push @{$self->_Children}, RapidApp::ExtJS::CheckTreePanel->new($child_conf);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;