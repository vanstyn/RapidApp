package RapidApp::AppTree;


use strict;
use Moose;

extends 'RapidApp::AppCnt';

use RapidApp::MooseX::ClassAttrSugar;
setup_add_methods_for('config');
setup_add_methods_for('listeners');


add_default_config(
		xtype					=> 'treepanel',
		border				=> \0,
		layout				=> 'fit',
		containerScroll 	=> \1,
		autoScroll			=> \1,
		animate				=> \1,
		useArrows			=> \1
);


use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);



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




has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $node = $self->c->req->params->{node};
	my $name = $self->c->req->params->{name};
	my $recursive = $self->c->req->params->{recursive};
	
	my $actions = {
		'nodes'	=> sub { $self->fetch_nodes($node) }
	};
	
	$actions->{add} = sub { $self->add_node($name,$node) } if ($self->can('add_node'));
	$actions->{delete} = sub { $self->delete_node($node,$recursive) } if ($self->can('delete_node'));
	
	# Fetch a single node rather than an array of its children
	$actions->{node} = sub { $self->fetch_node($node) } if ($self->can('fetch_node'));
	
	return $actions;
});


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


before 'content' => sub {
	my $self = shift;
	
	$self->set_afterrender;
	
	$self->add_config(
		id						=> $self->instance_id,
		dataUrl				=> $self->suburl('/nodes'),
		rootVisible			=> $self->show_root_node ? \1 : \0,
		root					=> $self->root_node,
		tbar					=> $self->tbar,
	);
};



sub set_afterrender {
	my $self = shift;
	
	my $node;
	$node = $self->root_node_name if ($self->show_root_node);
	$node = $self->c->req->params->{node} if ($self->c->req->params->{node});
	
	return unless($node);

	$self->add_listeners( 
		afterrender => RapidApp::JSONFunc->new( raw => 1, func => 
			'function(tree) {' .
				'Ext.ux.RapidApp.AppTree.jump_to_node_id(tree,"' . $node . '");' .
			'}'
		)
	);
}



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
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> 'Add',
			iconCls	=> 'icon-add',
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(btn) { ' . 
					'var tree = btn.ownerCt.ownerCt;'.
					'Ext.ux.RapidApp.AppTree.add(tree,"' . $self->suburl('/add') . '");' .
					
				'}'
			)
	});
}


sub delete_button {
	my $self = shift;
	
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> 'Delete',
			iconCls	=> 'icon-delete',
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