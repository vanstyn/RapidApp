package RapidApp::AppTree;
use Moose;
extends 'RapidApp::AppCmp';

use RapidApp::Include qw(sugar perlutil);

#use RapidApp::MooseX::ClassAttrSugar;
#setup_apply_methods_for('config');
#setup_apply_methods_for('listeners');

#apply_default_config(
#		xtype					=> 'treepanel',
#		border				=> \0,
#		layout				=> 'fit',
#		containerScroll 	=> \1,
#		autoScroll			=> \1,
#		animate				=> \1,
#		useArrows			=> \1
#);


sub BUILD {
	my $self = shift;
	$self->apply_config(
		xtype					=> 'treepanel',
		border				=> \0,
		layout				=> 'fit',
		containerScroll 	=> \1,
		autoScroll			=> \1,
		animate				=> \1,
		useArrows			=> \1
	);
	
	$self->apply_actions( nodes 	=> 'call_fetch_nodes' );
	$self->apply_actions( node 	=> 'call_fetch_node' ) if ($self->can('fetch_node'));
	$self->apply_actions( add 		=> 'call_add_node' ) if ($self->can('add_node'));
	$self->apply_actions( delete 	=> 'call_delete_node' ) if ($self->can('delete_node'));
	
	
	$self->add_ONREQUEST_calls('init_onreq');
	
}


sub init_onreq {
	my $self = shift;
	
	$self->apply_extconfig(
		id						=> $self->instance_id,
		dataUrl				=> $self->suburl('/nodes'),
		rootVisible			=> $self->show_root_node ? \1 : \0,
		root					=> $self->root_node,
		tbar					=> $self->tbar,
	);
	
	my $node;
	$node = $self->root_node_name if ($self->show_root_node);
	$node = $self->c->req->params->{node} if ($self->c->req->params->{node});
	
	return unless($node);

	$self->add_listener( 
		afterrender => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(tree) {' .
				'Ext.ux.RapidApp.AppTree.jump_to_node_id(tree,"' . $node . '");' .
			'}'
		)
	);
}




##
##
## fetch_nodes(node_path) [Required]
##		method to fetch the tree dataUrl, first argument is the node path
has 'fetch_nodes'		=> ( is => 'ro', default => sub { return []; } );
##


##
## show_root_node
##		whether or not to show the root node
has 'show_root_node'		=> ( is => 'ro', default => 0 );
##

##
## root_node_name
##		Name of the root node (default 'root')
has 'root_node_name'		=> ( is => 'ro', default => 'root' );
##


##
## root_node_text
##		text of the root node
has 'root_node_text'		=> ( is => 'ro', lazy => 1, default => sub { (shift)->root_node_name; } );
##

##
## add_nodes: define as a method to support adding to the tree
##





sub call_fetch_nodes {
	my $self = shift;
	my $node = $self->c->req->params->{node};
	return $self->fetch_nodes($node);
}

sub call_fetch_node {
	my $self = shift;
	my $node = $self->c->req->params->{node};
	return $self->fetch_node($node);
}

sub call_add_node {
	my $self = shift;
	my $name = $self->c->req->params->{name};
	my $node = $self->c->req->params->{node};
	return $self->add_node($name,$node);
}

sub call_delete_node {
	my $self = shift;
	my $name = $self->c->req->params->{name};
	my $node = $self->c->req->params->{node};
	my $recursive = $self->c->req->params->{recursive};
	return $self->delete_node($node,$recursive);
}




has 'root_node' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		nodeType		=> 'async',
		id				=> $self->root_node_name,
		text			=> $self->root_node_text,
		draggable	=> \0
	};
});


has 'tbar' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $tbar = [];

	push @$tbar, $self->delete_button if ($self->can('delete_node'));
	push @$tbar, $self->add_button if ($self->can('add_node'));

	return undef unless (scalar @$tbar > 0);

	unshift @$tbar, '->';

	return $tbar;
});


#before 'content' => sub {
#	my $self = shift;
#	
#	$self->set_afterrender;
#	
#	$self->apply_config(
#		id						=> $self->instance_id,
#		dataUrl				=> $self->suburl('/nodes'),
#		rootVisible			=> $self->show_root_node ? \1 : \0,
#		root					=> $self->root_node,
#		tbar					=> $self->tbar,
#	);
#};



has 'add_button_text' => ( is => 'ro', isa => 'Str', default => 'Add' );
has 'add_button_iconCls' => ( is => 'ro', isa => 'Str', default => 'icon-add' );
has 'delete_button_text' => ( is => 'ro', isa => 'Str', default => 'Delete' );
has 'delete_button_iconCls' => ( is => 'ro', isa => 'Str', default => 'icon-delete' );

sub add_button {
	my $self = shift;
	
	my $items = [
		{
			xtype		=> 'textfield',
			name		=> 'name',
			fieldLabel	=> 'Name'
		}
	];
	
	my $fieldset = {
		style 			=> 'border: none',
		hideBorders 	=> \1,
		xtype 			=> 'fieldset',
		labelWidth 		=> 60,
		border 			=> \0,
		items 			=> $items,
	};
	
	my $cfg = {
		url => $self->suburl('/add'),
		title => $self->add_button_text
	};
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> $self->add_button_text,
			iconCls	=> $self->add_button_iconCls,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(btn) { ' . 
					'var tree = btn.ownerCt.ownerCt;'.
					'Ext.ux.RapidApp.AppTree.add(tree,' . $self->json->encode($cfg) . ');' .
					
				'}'
			)
	});
}


sub delete_button {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> $self->delete_button_text,
			iconCls	=> $self->delete_button_iconCls,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(btn) { ' . 
					'var tree = btn.ownerCt.ownerCt;'.
					'Ext.ux.RapidApp.AppTree.del(tree,"' . $self->suburl('/delete') . '");' .
					
				'}'
			)
	});
}




#### --------------------- ####


#no Moose;
#__PACKAGE__->meta->make_immutable;
1;