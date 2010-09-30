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



has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	return {
		'nodes'	=> sub { $self->fetch_nodes($self->c->req->params->{node}) }
	};
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
		tbar				=> [
			'->',
			'New'
		
		]
		
	
	
	};
}



sub nodes_read {
	my $self = shift;
	
}






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;