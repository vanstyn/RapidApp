package RapidApp::ExtJS::CheckTreePanel;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Tree
#
#
# 2010-04-21:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::ExtJS::ContainerObject';


our $VERSION = '0.1';

#### --------------------- ####


has 'children_container'	=> ( is => 'rw',	init_arg => undef,		default		=> 'children'		);

# These must be an array, even if there is only 1 element:
around 'ChildConfigs' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $ChildConfigs = $self->$orig or return undef;
	return $ChildConfigs if (ref($ChildConfigs) eq 'ARRAY');
	return [ $ChildConfigs ];
};




around 'Config' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $Config = $self->$orig;

	delete $Config->{header} if (defined $Config->{header});
	
	$Config->{leaf} = \1;
	$Config->{leaf} = \0 unless ($self->no_children);

	unless ($self->_has_parents) {
		my $children = $Config->{children};
		delete $Config->{children};
		
		$Config->{xtype} 			= 'checktreepanel'	unless (defined $Config->{xtype});
		$Config->{bubbleCheck} 	= 'none'					unless (defined $Config->{bubbleCheck});			
		$Config->{autoScroll} 	= \1						unless (defined $Config->{autoScroll});
		$Config->{border} 		= \1						unless (defined $Config->{border}); 	
		$Config->{rootVisible}	= \0						unless (defined $Config->{rootVisible});
		$Config->{isFormField}	= \1						unless (defined $Config->{isFormField});
		
		my @bodyStyle = (
			'background-color:white;',
			'border:1px solid #B5B8C8;',
			'padding-top:1px;',
			'padding-bottom:8px;',
		);
		$Config->{bodyStyle} =  join('',@bodyStyle)	unless (defined $Config->{bodyStyle});
		
		$Config->{root} = {
			nodeType		=> 'async',
			text			=> 'root',
			id				=> 'root',
			expanded		=> \1,
			children		=> $children
		};
		
		$Config->{root}->{checked} = $Config->{checked} if (defined $Config->{checked});
		
	}

	return $Config;
};



no Moose;
__PACKAGE__->meta->make_immutable;
1;