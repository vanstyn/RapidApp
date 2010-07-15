package RapidApp::Tree;
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


use RapidApp::ExtJS;
use RapidApp::ExtJS::TreeNode;
use RapidApp::ExtJS::TreePanel;

our $VERSION = '0.1';

#### --------------------- ####

has 'TreeConfig' 						=> ( is => 'ro',	required		=> 1,				isa => 'ArrayRef'		);
has 'TreePanel' 						=> ( is => 'ro',	lazy_build	=> 1											);
has 'TreePanel_cfg' 					=> ( is => 'ro',	lazy_build	=> 1											);
has 'expand_nodes'					=> ( is => 'ro',	default		=> sub { {} }								);
has 'treepanel_id'					=> ( is => 'ro',	default		=> 'treepanel'								);

has 'click_handler' 					=> ( is => 'ro',	required 	=> 0,				isa => 'Str',		predicate => 'has_click_handler' 	);
has 'treewalk_coderef' 				=> ( is => 'ro',	required 	=> 0,				isa => 'CodeRef',	predicate => 'has_treewalk_coderef' );



sub _build_TreePanel {
	my $self = shift;

	my $RootNode = RapidApp::ExtJS::TreeNode->new({
		nodeType		=> 'async',
		id				=> 'root',
		#text			=> $self->title,
		text			=> 'root_node',
		expandable	=> 1,
		expanded		=> 1,
	}) or die 'Failed to create RapidApp::ExtJS::TreeNode object';

	foreach my $node_cfg (@{$self->TreeConfig}) {
		$RootNode->children($self->TreeNode_from_cfg($node_cfg)->Params);
	}


	my $config = {
		root						=> $RootNode->Params,
		id							=> $self->treepanel_id,
		rootVisible				=> 0,
		collapsible				=> 0,
		collapsed				=> 0,
		expand					=> 0,
		border					=> 0,
		bodyBorder 				=> 0,
		lines						=> 0,
		xtype						=> 'treepanelext',
		useArrows				=> 1,
	};
	
	$config->{click_handler_func} = $self->click_handler if ($self->has_click_handler);

	return RapidApp::ExtJS::TreePanel->new($config);
}


sub _build_TreePanel_cfg {
	my $self = shift;
	
	my $config = $self->TreePanel->Params;
	
	foreach my $path (keys %{ $self->expand_nodes }) {
		$config->{afterRender_eval} = '' unless (defined $config->{afterRender_eval});
		$config->{afterRender_eval} .= 
			q~var treepanel = Ext.getCmp('~ . $config->{id} . q~');~ .
			q~treepanel.expandPath('~ . $path . q~'); ~;
	}

	return $config;
}




###########################################################################################



sub TreeNode_from_cfg {
	my $self = shift;
	my $node_cfg = shift or die "node_cfg not passed";
	my $path = shift;
	$path = '/root' unless (defined $path);
	
	return undef unless (ref($node_cfg) eq 'HASH');
	
	$path .= '/';
	$path .= $node_cfg->{id} if (defined $node_cfg->{id});
	
	my $cfg = {};
	$cfg->{id} 			= $node_cfg->{id} 		if (defined $node_cfg->{id});
	$cfg->{text}		= $node_cfg->{text} 		if (defined $node_cfg->{text});
	$cfg->{iconCls}	= $node_cfg->{iconCls} 	if (defined $node_cfg->{iconCls});
	$cfg->{checked}	= $node_cfg->{checked} 	if (defined $node_cfg->{checked});
	
	###
	###
	###
	$self->treewalk_coderef->($node_cfg,$cfg) if ($self->has_treewalk_coderef);
	###
	###
	###
	
	#if (defined $node_cfg->{subapp}) {
	#	$cfg->{navtarget} = $self->base_url . '/' . $node_cfg->{subapp};
	#	$cfg->{params} = $node_cfg->{params} if (defined $node_cfg->{params});
	#}
	
	$self->expand_nodes->{$path} = 1 if ($node_cfg->{expand});
	
	my $Node = RapidApp::ExtJS::TreeNode->new($cfg) or return undef;
	
	return $Node unless (defined $node_cfg->{children} and ref($node_cfg->{children}) eq 'ARRAY');
	
	foreach my $child_node_cfg (@{$node_cfg->{children}}) {
		$Node->children($self->TreeNode_from_cfg($child_node_cfg,$path)->Params);
	}

	return $Node;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;