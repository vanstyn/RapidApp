package RapidApp::AppTree;


use strict;
use Moose;

extends 'RapidApp::AppBase';


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
	
	my $actions = {
		'nodes'	=> sub { $self->fetch_nodes($node) }
	};
	
	$actions->{add} = sub { $self->add_node($name,$node) } if ($self->can('add_node'));
	
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
	
	my $tbar = [
		'->',
	];
	
	push @$tbar, $self->add_button if ($self->can('add_node'));

	return $tbar;
});




sub content {
	my $self = shift;

	return {
		xtype				=> 'treepanel',
		dataUrl			=> $self->suburl('/nodes'),
		rootVisable		=> $self->show_root_node ? \0 : \1,
		root				=> $self->root_node,
		border			=> \0,
		layout			=> 'fit',
		containerScroll => \1,
		autoScroll		=> \1,
		animate			=> \1,
		useArrows		=> \1,
		tbar				=> $self->tbar,
		
	};
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



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;