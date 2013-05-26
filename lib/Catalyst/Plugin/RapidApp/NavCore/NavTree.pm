package Catalyst::Plugin::RapidApp::NavCore::NavTree;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppNavTree';

use RapidApp::Include qw(sugar perlutil);

has 'plugin_config', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  my $c = $self->app;
  my $config = clone($c->config->{'Plugin::RapidApp::NavCore'} || {});
  
  # -- Default configs --
  
  # allow_manage: Whether or not to allow managing the Navtree (Organize Navtree)
  $config->{allow_manage} //= 1;
  
  # user_views: Whether or not to enable saved views/searches on a per-user basis
  # (also requires Auth to be enabled)
  $config->{user_views} //= 1;
  
  return $config;
};

sub BUILD {
  my $self = shift;
  
  if($self->plugin_config->{allow_manage}) {
    $self->apply_init_modules(
      'manager' => 'Catalyst::Plugin::RapidApp::NavCore::NavTree::Manage'
    ) unless ($self->isa('Catalyst::Plugin::RapidApp::NavCore::NavTree::Manage'));
  }

}

#has '+module_scope', default => sub { return (shift)->parent_module };
has '+instance_id', default => 'main-nav-tree';

has '+fetch_nodes_deep', default => 1;


#has 'Rs', is => 'ro', lazy => 1, default => sub {
sub Rs {
	my $self = shift;
	
	my $Rs = $self->c->model('RapidApp::CoreSchema::NavtreeNode')->search_rs(undef,{ 
		order_by => { -asc => 'me.ordering' },
		group_by => 'me.id'
	});
	
  
  # TODO: apply perms:
  
	#my $uid = $self->c->model("DB")->current_user_id;
	#my @roles = uniq($self->c->model('DB::Role')->search_rs({
	#	'user_to_roles.user_id' => $uid
	#},{ join => 'user_to_roles' })->get_column('role')->all);
	#
	#$Rs = $Rs->search_rs([
	#	{ 'navtree_node_to_roles.role' => { '-in' => \@roles } },
	#	{ 'navtree_node_to_roles.role' => undef }
	#],{ join => 'navtree_node_to_roles' }) unless ($self->c->model('DB')->has_roles(qw/admin/));
	
	return $Rs;
};

has 'SearchesRs', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->c->model('RapidApp::CoreSchema::SavedState')->search_rs(undef,
		# First by order:
    { order_by => { -asc => 'me.ordering' }}
	)->search_rs(undef,
  # Then by title:
    { order_by => { -asc => 'me.title' }}
  );
};

has 'UsersRs', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->c->model('RapidApp::CoreSchema::User')->search_rs(undef,
		{ order_by => { -asc => 'me.username' }}
	);
};

sub get_node_id {
	my $self = shift;
	my $node = shift;
	
	# Allow a Node Row object to be supplied instead of a path string (secondary functionality):
	if(ref($node)) {
		return $node->get_column('id') if (ref($node) =~ /NavtreeNode/);
		return 's-' . $node->get_column('id') if (ref($node) =~ /SavedState/);
	}
	
	my @parts = split(/\//,$node);
	my $id = pop @parts;
	$id = 0 if ($id eq 'root');

	return $id;
}

# Returns either a Navtree node row, or a saved state row:
sub get_node_Row {
	my $self = shift;
	my $node = shift;
	my $NavtreeNode_only = shift;
	
	# Return the supplied node object if it is already a Row:
	return $node if (ref($node));
	
	
	my $id = $self->get_node_id($node);
	return undef if ($NavtreeNode_only and ! ($id =~ /^\d+$/));
	
	if($id =~ /^s\-/) { #<-- if the id starts with 's-' its a SavedState id
		$id =~ s/^s\-//;
		return $self->SearchesRs->search_rs({ 'me.id' => $id })->first;
	}
	
	return $self->Rs->search_rs({ 'me.id' => $id })->first;
}

sub get_NavtreeNode {
	my $self = shift;
	my $node = shift;
	return $self->get_node_Row($node,1);
}


sub node_child_count {
	my $self = shift;
	my $node = shift;
	
	my $id = $self->get_node_id($node);
	
	my $count = 0;
	$count += $self->Rs->search_rs({ 'me.pid' => $id })->count;
	$count += $self->SearchesRs->search_rs({ 'me.node_id' => $id })->count;

	return $count;
}


sub get_Node_config {
	my $self = shift;
	my $Node = shift;
	
	my $d = { $Node->get_columns };
	#my $snode = $node . '/' . $d->{id};
	my $opts = {
		#id => $snode,
		id => $d->{id},
		sort_order => $d->{ordering},
		text	=> $d->{text} || $d->{title},
		iconCls => $d->{iconcls},
	};
	
	$opts->{expanded} = ($d->{expanded} ? \1 : \0) if (defined $d->{expanded});
	
	# Saved State/Search specific:
	if($Node->can('node_id')) {
		$opts->{$_} = \1 for(qw(leaf expanded loaded allowDelete));
		%$opts = ( %$opts,
			id => 's-' . $opts->{id},
			loadContentCnf => $Node->loadContentCnf,
			#href => '#!/view/' . $opts->{id}
			# note: not using 'href' only because we don't want it in the ManageNavTree (subclass)
		);
	}
	# Navtree Node specific
	else {
		$opts->{allowCopy} = \0;
	}
	
	return $opts;
}


sub fetch_nodes {
	my $self = shift;
	my ($node) = @_;
	
	my $id = $self->get_node_id($node);
	
	# Ignore non-numeric node ids:
	return [] unless ($id =~ /^\d+$/);
	
	my $data = [];
	
	# Nodes (folder/containers)
	foreach my $Node ($self->Rs->search_rs({ 'me.pid' => $id })->all) {
		
		my $opts = $self->get_Node_config($Node);
		my $snode = $node . '/' . $opts->{id};
		
		unless ($self->fetch_nodes_deep or $self->node_child_count($snode)) {
			# Set loaded/expanded to true if this node is empty (causes +/- to not be displayed initially):
			$opts->{loaded} = \1;
			delete $opts->{expanded};
			#$opts->{expanded} = \1;
		}
		
		push @$data, $opts;
	}
	
	# Saved Searches:
	foreach my $State ($self->SearchesRs->search_rs({ 'me.node_id' => $id })->all) {
		my $opts = $self->get_Node_config($State);
		push @$data, $opts;
	}
	
	# Re-Sort heterogeneous node types together (navtree_nodes and saved_states)
	@$data = sort { $a->{sort_order} <=> $b->{sort_order} } @$data;
	
	# Add extra, static root items from TreeConfig (original AppNavTree behavior):
	push @$data, @{$self->next::method} if ($node eq 'root');
	
	return $data;
}


# TODO: checking perms:

#sub is_admin {
#	my $self = shift;
#	return 1 if ($self->c->model('DB')->has_roles(qw/admin/));
#}
#
#sub can_edit_navtree {
#	my $self = shift;
#	return 1 if ($self->c->model('DB')->has_roles(qw/admin edit_navtree/));
#}
#
#sub can_delete {
#	my $self = shift;
#	return 1 if ($self->c->model('DB')->has_roles(qw/admin delete/));
#}
#


sub can_edit_navtree { 1 }

sub is_admin {
  my $self = shift;
  
  return $self->c->check_user_roles('administrator')
    if ($self->c->can('check_user_roles'));
  
  # If we're here it means no Auth is loaded and we're in "single-user" mode
  # (i.e. automatically an admin)
  return 1;
}

sub TreeConfig {
	my $self = shift;
  my @items = ();
  
  if ($self->plugin_config->{user_views}) {
    my $User = try{$self->c->user->get_from_storage};
    push @items, $self->saved_search_tree_items($User) if ($User);
  }

	push @items, $self->organize_navtree_node 
    if ($self->plugin_config->{allow_manage});

	return \@items;
}


sub saved_search_tree_items {
	my $self = shift;
  my $User = shift;
  
	my $saved_searches = [];
  # TODO: permissions:
	#my $Rs = $self->c->model('DB::SavedState')->my_saved_states;
  #my $Rs = $self->c->model('RapidApp::CoreSchema::SavedState');
  my $Rs = $User->saved_states;
	
	#exclude searches with a node_id (which means they are shown in the public tree above)
	$Rs = $Rs->search_rs({ 'me.node_id' => undef }); 
	
	foreach my $State ($Rs->all) {
		my $search_id = $State->get_column('id');
		push @$saved_searches, {
			id			=> 'search-' . $search_id,
			text		=> $State->title,
			iconCls	=> $State->iconcls,
			loadContentCnf => $State->loadContentCnf,
			#href => '#!/view/' . $search_id,
			# note: not using 'href' only because we don't want it in the ManageNavTree (subclass)
			expand	=> 1,
			children	=> []
		};
	}
	
	return {
		id			=> 'my-saved-searches',
		text		=> 'My Views',
		iconCls		=> 'icon-folder-view',
		expand		=> 1,
		children	=> $saved_searches
	};
}





sub organize_navtree_node {
	my $self = shift;
	return {
		id			=> 'manager',
		text		=> $self->is_admin ? 'Organize Navtree' : 'Organize Views',
		cls		=> 'pad-top-7px-bottom-4px',
		iconCls		=> 'icon-tree-edit',
		module		=> 'manager',
		params		=> {},
		expand		=> 1,
		children	=> []
	};
}

#sub deleted_objects_node {{
#	id			=> 'deleted_objects',
#	text		=> 'Deleted Objects',
#	cls		=> 'pad-top-bottom-4px',
#	iconCls	=> 'icon-garbage-full',
#	module	=> 'deleted_objects',
#	params	=> {},
#	expand	=> 1,
#	children	=> []
#}}
#

1;
