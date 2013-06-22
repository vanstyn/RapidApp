package Catalyst::Plugin::RapidApp::NavCore::NavTree::Manage;

use strict;
use warnings;
use Moose;
extends 'Catalyst::Plugin::RapidApp::NavCore::NavTree';

use RapidApp::Include qw(sugar perlutil);

#has '+root_node_text' => ( default => 'Navtree' );
#has '+show_root_node' => ( default => 1 );

#has '+add_button_text' => ( default => 'Add Category' );
#has '+add_button_iconCls' => ( default => 'icon-folder-add' );

has '+use_contextmenu' => ( default => 1 );
has '+no_dragdrop_menu' => ( default => 1 );
has '+setup_tbar' => ( default => 1 );

has '+no_recursive_delete', default => 0;

# Allow drag and drop move to go between as well as into nodes:
has '+ddAppendOnly', default => 0;

has '+instance_id', default => 'manage-nav-tree';
has '+double_click_nav', default => 1;

# -- Turn off AppNavTree features:
sub TreeConfig {[]}
sub apply_node_navopts_recursive {}
sub apply_node_navopts {}
#sub setup_nav_listeners {}
# --

has '+fetch_nodes_deep', default => 0;

sub auth_active {
  my $self = shift;
  return $self->c->can('user') ? 1 : 0;
}

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		border => \1,
    tabTitle => 'Organize Navtree',
    tabIconCls => 'icon-tree-edit'
	);
	
	# Automatically reload the main nav tree when closed:
	$self->add_listener( removed => 'Ext.ux.RapidApp.NavCore.reloadMainNavTrees' );
	
	$self->root_node->{allowDrop} = \0;
	$self->root_node->{allowAdd} = \0;
	
	$self->add_ONCONTENT_calls('apply_permissions');
}

sub apply_permissions {
	my $self = shift;
	return if ($self->can_edit_navtree);
	
	$self->apply_extconfig(
		add_node_url => undef,
		expand_node_url => undef
	);
}


sub fetch_nodes {
	my $self = shift;
	my ($node) = @_;
	
	my $admin = $self->is_admin;

	# Wrap the tree in another level:
	if ($node eq 'root') {
		my $nodes = [];
		
		push @$nodes, {
			id => 'manage/root', #<-- because the id ends in "root" the root nodes will be fetched into this node
			text	=> 'Public Navigation Tree',
			iconCls => 'icon-server-database',
			expanded => \1,
			rootValidActions => \1 #<-- prevents actions that wouldn't be valid for the root node (rename, etc)
		} if ($admin);
    
    if($self->auth_active) {
		
      my $my_searches = {
        id => 'my_searches',
        text => 'My Views',
        iconCls => 'icon-folder-view',
        expanded => \1,
        rootValidActions => \1, #<-- prevents actions that wouldn't be valid for the root node (rename, etc)
        allowLeafDropOnly => \1,
        allowChildrenLeafDropOnly => \1,
        allowDrag => \0,
        allowAdd => \0,
      };
      
      $my_searches->{cls} = 'pad-top-7px' if ($admin);
      
      push @$nodes, $my_searches;
      
      push @$nodes, {
        id => 'user_searches',
        text => 'Other User\'s Views',
        iconCls => 'icon-data-views',
        cls => 'pad-top-7px',
        expanded => \0,
        rootValidActions => \1, #<-- prevents actions that wouldn't be valid for the root node (rename, etc)
        allowDrop => \0,
        allowDrag => \0,
        allowAdd => \0,
      } if ($admin);
    
    }
		
		return $nodes;
	}
	
	return $self->my_searches_nodes if ($node =~ /my_searches$/);
	
	return [] unless ($admin); #<-- fail-safe, non-admins should never get this far
	
	return $self->user_searches_nodes if ($node =~ /user_searches$/);
	return $self->next::method(@_);
};

sub my_searches_nodes {
	my $self = shift;
  
	my $User = $self->c->user->get_from_storage or die "Failed to get user";
	return $self->searches_nodes_for_User($User);
}

sub searches_nodes_for_User {
	my $self = shift;
	my $User = shift;
  
	my $path = 'user_searches/' . $User->get_column('username');
	
	# Todo: use an accessor on $User instead of this (why am I doing it this way?):
	my $PrivSearchesRs = $self->SearchesRs->search_rs({ 'me.node_id' => undef });
	#my $SearchObjectsRs = $self->c->model('DB::Object')->search_rs(
	#	{ 'saved_state.node_id' => undef, 'type.name' => 'saved_state' },
	#	{ join => [ 'saved_state', 'type' ] }
	#);
		
	my $children = [];
	foreach my $State ($PrivSearchesRs->search_rs({ 'me.user_id' => $User->get_column('id') })->all) {
	#foreach my $Object ($SearchObjectsRs->search_rs({ 'me.owner_id' => $User->get_column('id') })->all) {
		#my $State = $Object->saved_state;
		
		# Make sure its not deleted or otherwise invalid object:
		#next unless ($State->object);
		
		my $cnf = $self->get_Node_config($State);
		$cnf = { %$cnf,
			id => $path . '/' . $cnf->{id},
			leaf => \1,
			loaded => \1,
			#allowDelete => \0,
			#allowLeafDropOnly => \1,
		};
		push @$children, $cnf;
	}
	
	return $children;
}

sub user_searches_nodes {
	my $self = shift;
	
	return [] unless ($self->can_edit_navtree); #<-- fail-safe, non-admins should never get this far
	
	my $nodes = [];
	
	my $UserRs = $self->UsersRs;
	
	my $empties = [];
	
	my $uid = $self->c->user->get_column('id');
	
	foreach my $User ($UserRs->all) {
		
		# Skip the current user
		next if($User->get_column('id') == $uid);
	
		my $path = 'user_searches/' . $User->username;
		
		my $children = $self->searches_nodes_for_User($User);
		
		my $data = {
			id => $path,
			text => $User->full_name . ' [' . $User->username . ']',
			iconCls => 'icon-user',
			rootValidActions => \1, #<-- prevents actions that wouldn't be valid for the root node (rename, etc)
			#allowDrop => \0,
			allowLeafDropOnly => \1,
			allowChildrenLeafDropOnly => \1,
			#allowReload => \0,
			allowDrag => \0,
			allowAdd => \0,
			children => $children
		};
		
		if(@$children > 0) {
			push @$nodes, $data;
		}
		else {
			$data = { %$data,
				loaded => \1,
				expanded => \1
			};
			
			# If the user has no searches, skip them if they are disaled:
			next if ($User->disabled);
			push @$empties, $data;
		}	
	}
	
	# empties last:
	push @$nodes,@$empties;
	
	return $nodes;
}


sub add_node {
	my $self = shift;
	my $name = shift;
	my $node = shift;
	
	my $id = $self->get_node_id($node);
	
	# strip whitespace
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	
	my $order = $self->get_order_string($id,'append');
	
	my $Node = $self->Rs->create({
		pid => $id,
		text => $name,
		ordering => $order
	});
	
	return {
		msg		=> 'Created',
		success	=> \1,
		child => $self->get_Node_config($Node)
	};
}

sub my_searches_target {
	my $self = shift;
	my $User = $self->c->user->get_from_storage or die "Failed to get current User!!";
	return 'user_searches/' . $User->get_column('username');
}

sub move_node {
	my $self = shift;
	my $node = shift;
	my $target = shift;
	my $point = shift;
  
	# remap my_searches target for moves into "My Searches"
	$target = $self->my_searches_target if ($target =~ /my_searches/);
	
	my $point_node = shift || $target;
	
	##
	return $self->move_to_private_search($node,$target,$point,$point_node) if ($target =~ /user_searches/);
	##
	
	my $Node = $self->get_node_Row($node) || die "Node not found! ($node)";
	
	my $pid = $self->get_node_id($target);
	die "Failed to find target pid" unless (defined $pid);
	
	my $order = $self->get_order_string($point_node,$point);
	
	return $Node->update({ 'node_id' => $pid, 'ordering' => $order }) if ($Node->can('node_id')); #<-- SavedSearch row
	return $Node->update({ 'pid' => $pid, 'ordering' => $order });
}

sub move_to_private_search {
	my $self = shift;
	my $node = shift;
	my $target = shift;
	my $point = shift;
	my $point_node = shift || $target;
	
	my $State = $self->get_node_Row($node) || die "move_to_private_search failed";
	my @path = split(/\//,$target);
	my $username = pop @path;
  
	die "Missing username" unless (defined $username and $username ne '');
	
	my $User = $self->UsersRs->
    search_rs({ username => $username })->first
      or die "Failed to find target User by username '$username'";
	
	my $uid = $User->get_column('id');
	
	$State->update({ user_id => $uid });
	$self->unlink_search($State);
	
	my $order = $self->get_order_string($point_node,$point);
	$State->update({ ordering => $order });
	
	return 1;
}

sub copy_node {
	my $self = shift;
	
	my $node = shift;
	my $target = shift;
	my $point = shift;
	my $point_node = shift || $target;
	my $name = shift;
	
	my $State = $self->get_node_Row($node) || die "Failed to find source!";
	die usererr "Only Saved Searches can be copied currently!" unless ($State->can('node_id'));
	
	die usererr "Name cannot be empty" unless ($name and $name ne '');
	
	$self->enforce_valid_new_search_name($name);
	
	my $create = { $State->get_columns };
  delete $create->{id};
	$create->{title} = $name if ($name);
	
	#delete $create->{$_} for(qw(id type_id name disp_name creator_id created owner_id));
	#delete $create->{saved_state}->{$_} for(qw(id));
	
	my $NewRow = $self->SearchesRs->create($create);
	
	$self->move_node($NewRow,$target,$point,$point_node);
	
	return {
		msg		=> 'Copied',
		success	=> \1,
		child => $self->get_Node_config($NewRow)
	};
}

sub enforce_valid_new_search_name {
	my $self = shift;
	my $name = shift;
	
	my $uid = $self->c->user->get_column('id');
	
	my $Rs = $self->SearchesRs->search_rs({ 'me.user_id' => $uid, 'me.title' => $name });
	
	die usererr "You already own a search named '$name'" if ($Rs->count);
}



sub get_node_pid {
	my $self = shift;
	my $node = shift;
	
	my $Node = ref($node) ? $node : $self->get_node_Row($node);
	
	return $Node->get_column('node_id') if ($Node->can('node_id')); #<-- SavedSearch row
	return $Node->get_column('pid');
}


sub get_node_order_boundary {
	my $self = shift;
	my $direction = shift;
	
	die "Direction can only be high or low" unless (
		$direction eq 'high' or
		$direction eq 'low'
	);
	
	my $Node = $self->get_node_Row(shift);
	
	my $pid = $self->get_node_pid($Node);
	
	my $Rs_list = [
		$self->Rs->search_rs({ 'me.pid' => $pid }),
		$self->SearchesRs->search_rs({'me.node_id' => $pid })
	];
	
	my $method = "get_Rs_order_boundary_" . $direction;
	
	return $self->$method($Rs_list,$Node->ordering);
}
sub get_node_order_boundary_high	{ (shift)->get_node_order_boundary('high',@_)	}
sub get_node_order_boundary_low	{ (shift)->get_node_order_boundary('low',@_)	}

sub get_Rs_order_boundary_high {
	my $self = shift;
	my $Rs = shift;
	my $order = shift;
	
	my $val = 10000000;
	
	if(ref($Rs) eq 'ARRAY') {
		# Recursive call for each Rs in the array, finding the lowest value:
		defined $_ and $_ < $val and $val = $_ 
			for( map { $self->get_Rs_order_boundary_high($_,$order) } @$Rs );
			
		return $val;
	}
	
	die "First argument was not a ResultSet!!!" unless ($Rs && $Rs->can('search_rs'));
	
	$Rs = $Rs->search_rs({ ordering => { '>' => $order }},{ order_by => { -asc => 'me.ordering' }});
	my $Next = $Rs->first;
	
	return $Next ? $Next->ordering : $val;
}

sub get_Rs_order_boundary_low {
	my $self = shift;
	my $Rs = shift;
	my $order = shift;
	
	my $val = 0;
	
	if(ref($Rs) eq 'ARRAY') {
		# Recursive call for each Rs in the array, finding the highest value:
		defined $_ and $_ > $val and $val = $_ 
			for( map { $self->get_Rs_order_boundary_low($_,$order) } @$Rs );
		
		return $val;
	}
	
	die "First argument was not a ResultSet!!!" unless ($Rs && $Rs->can('search_rs'));
	
	$Rs = $Rs->search_rs({ ordering => { '<' => $order }},{ order_by => { -desc => 'me.ordering' }});
	my $Next = $Rs->first;

	return $Next ? $Next->ordering : $val;
}


sub get_highest_order_child {
	my $self = shift;
	my $node = shift;
	
	return $self->get_highest_order_saved_search($node) if ($node =~ /user_searches/);
	
	my $Node = $self->get_node_Row($node);
	
	return undef unless ($Node->can('pid')); #<-- only NavtreeNode rows can have children
	
	my $id = $Node->get_column('id');
	
	my $ChildNode = $self->Rs->search_rs(
		{ 'me.pid' => $id, 'me.ordering' => { '!=' => undef } },
		{ order_by => { -desc => 'me.ordering' }}
	)->first;
	
	my $ChildSearch = $self->SearchesRs->search_rs(
		{ 'me.node_id' => $id, 'me.ordering' => { '!=' => undef } },
		{ order_by => { -desc => 'me.ordering' }}
	)->first;
	
	return undef unless ($ChildNode or $ChildSearch);
	return $ChildNode unless ($ChildSearch);
	return $ChildSearch unless ($ChildNode);
	
	return $ChildSearch if ($ChildSearch->ordering > $ChildNode->ordering);
	return $ChildNode;
}

sub get_highest_order_saved_search {
	my $self = shift;
	my $target = shift;
	
	my @path = split(/\//,$target);
	my $username = pop @path;
	
	die "Missing username" unless (defined $username and $username ne '');
	
	my $User = $self->UsersRs->search_rs({ username => $username })->first
		or die "Failed to find target User by username '$username'";
	
	my $ChildSearch = $self->SearchesRs->search_rs(
		{ 'object.owner_id' => $User->get_column('id'), 'me.ordering' => { '!=' => undef } },
		{ order_by => { -desc => 'me.ordering' }}
	)->first;
	
	return $ChildSearch;
}

sub get_order_string {
	my $self = shift;
	my $PointNode = $self->get_node_Row(shift) || return 5000000;
	my $point = shift;
	
	my $min = 0;
	my $max = 10000000;
	
	if($point eq 'append') {
		my $Child = $self->get_highest_order_child($PointNode);
		return $self->get_order_string($Child,'below');
	}

	if ($point eq 'below') {
		$min = $PointNode->ordering + 1;
		$max = $self->get_node_order_boundary_high($PointNode);
	}
	elsif ($point eq 'above') {
		$max = $PointNode->ordering - 1;
		$min = $self->get_node_order_boundary_low($PointNode);
	}
	else { die "Unknown point value '$point' (expected 'append', 'above' or 'below')"; }
	
	
	my $range = $max - $min;
	
	# TODO: write logic that will update/redistribute order values if the range is too small.
	
	my $order = $min + int($range/2);
	
	return $order;
}


sub rename_node {
	my $self = shift;
	my $node = shift;
	my $name = shift;
	
	# strip whitespace
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	
	#my $id = $self->get_node_id($node);
	my $Node = $self->get_node_Row($node) or die "Failed to get Node";
	return $self->rename_search($Node,$name) if ($Node->can('node_id'));
	
	#my $Node = $self->Rs->search_rs({ 'me.id' => $id })->first;
	$Node->update({ 'text' => $name });
	
	return {
		msg		=> 'Renamed',
		success	=> \1,
		new_text => $Node->text,
	};
}

sub rename_search {
	my $self = shift;
	my $State = shift;
	my $name = shift;
	
	return {
		msg		=> 'Renamed Search',
		success	=> \1,
		new_text => $State->title
	} if ($State->update({ title => $name }));
	
	die "Rename error";
}


sub delete_node {
	my $self = shift;
	my $node = shift;
	my $recursive = shift;
	
	my $Node = $self->get_node_Row($node) or die "Failed to get Node";
	#return $self->unlink_search($Node) if ($Node->can('node_id'));
	return $self->delete_search($Node) if ($Node->can('node_id'));
	
	my $count = 1;
	
	if ($recursive) {
		try {
			$self->c->model('RapidApp::CoreSchema')->txn_do(sub { $count = $self->Node_delete_recursive($Node) });
		}
		catch { 
			my $err = shift;
			die $err; 
		};
	}
	else {
		die usererr "Cannot delete - not empty" if ($self->node_child_count($Node));
		$Node->delete or die "Non-Recursive Node delete failed.";
	};
	
	return {
		msg		=> "Deleted $count Tree Nodes",
		success	=> \1
	};
}

sub unlink_search {
	my $self = shift;
	my $State = shift;
	return $State->update({ node_id => undef }) if (defined $State->node_id);
}


# TODO: check permissions:
sub delete_search {
	my $self = shift;
	my $State = shift;
	$self->unlink_search($State);
	return $State->delete;
}

sub Node_delete_recursive {
	my $self = shift;
	my $Node = shift;
	
	my $id = $Node->get_column('id');
	
	my $count = 0;
	
	# Recursive delete any children:
	$count += $self->Node_delete_recursive($_) for ($self->Rs->search_rs({ 'me.pid' => $id })->all);
	
	# Unlink all Saved States:
	#$self->unlink_search($_) and $count++ for ($self->SearchesRs->search_rs({ 'me.node_id' => $id })->all);
	$self->delete_search($_) and $count++ for ($self->SearchesRs->search_rs({ 'me.node_id' => $id })->all);
	
	# Node should have 0 children at this point:
	die "Fatal error! Somehow the node (id: $id) still has children, so something went wrong."
		if ($self->node_child_count($Node));
	
	# Finally, delete this Node:
	$Node->delete or die "Recursive Node delete failed.";
	return ++$count;
}

# always return true/success - the info isn't important enough to take failure actions:
sub expand_node {
	my $self = shift;
	my $node = shift;
	my $expanded = shift;
	
	my $NavtreeNode = $self->get_NavtreeNode($node) || return 1;
	$NavtreeNode->update({ 'expanded' => $expanded });
	
	return 1;
}


1;

