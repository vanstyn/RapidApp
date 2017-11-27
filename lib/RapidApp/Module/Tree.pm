package RapidApp::Module::Tree;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::ExtComponent';

use RapidApp::Util qw(:all);


has 'add_button_text' => ( is => 'ro', isa => 'Str', default => 'Add' );
has 'add_button_iconCls' => ( is => 'ro', isa => 'Str', default => 'ra-icon-add' );
has 'delete_button_text' => ( is => 'ro', isa => 'Str', default => 'Delete' );
has 'delete_button_iconCls' => ( is => 'ro', isa => 'Str', default => 'ra-icon-delete' );

has 'use_contextmenu' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'no_dragdrop_menu' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'setup_tbar' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'no_recursive_delete' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'no_recursive_copy' => ( is => 'ro', isa => 'Bool', default => 1 );

# Double-pane tree - useful for drag/drop
has 'double_tree' => ( is => 'ro', isa => 'Bool', default => 0 );

#Controls if nodes can drag/drop between nodes as well as into (append) nodes
has 'ddAppendOnly' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'extra_node_actions' => ( is => 'ro', isa => 'Maybe[ArrayRef]', lazy => 1, default => undef );

has 'node_types', is => 'ro', isa => 'Maybe[ArrayRef[HashRef]]', default => undef, traits => ['ExtProp'];


sub BUILD {
  my $self = shift;
  $self->apply_extconfig(
    xtype            => 'apptree',
    border          => \0,
    layout          => 'fit',
    #containerScroll     => \1,
    #autoScroll        => \1,
    animate          => \1,
    useArrows        => \1,
    use_contextmenu    => jstrue($self->use_contextmenu) ? \1 : \0,
    no_dragdrop_menu    => jstrue($self->no_dragdrop_menu) ? \1 : \0,
    setup_tbar        => jstrue($self->setup_tbar) ? \1 : \0,
    no_recursive_delete  => jstrue($self->no_recursive_delete) ? \1 : \0,
    no_recursive_copy    => jstrue($self->no_recursive_copy) ? \1 : \0,
    double_tree        => jstrue($self->double_tree) ? \1 : \0,
    ddAppendOnly      => jstrue($self->ddAppendOnly) ? \1 : \0,
  );
  
  $self->apply_extconfig( extra_node_actions => $self->extra_node_actions ) if ($self->extra_node_actions);
  
  $self->apply_extconfig(
    add_node_text       => $self->add_button_text,
    add_node_iconCls    => $self->add_button_iconCls,
    delete_node_text    => $self->delete_button_text,
    delete_node_iconCls  => $self->delete_button_iconCls
  );
  
  $self->apply_actions( nodes   => 'call_fetch_nodes' );
  $self->apply_actions( node   => 'call_fetch_node' ) if ($self->can('fetch_node'));
  
  if($self->op_available('add_node')) {
    $self->apply_actions( add   => 'call_add_node' );
    $self->apply_extconfig( add_node_url => $self->suburl('add') );
  }
  
  if($self->op_available('delete_node')) {
    $self->apply_actions( delete   => 'call_delete_node' ); 
    $self->apply_extconfig( delete_node_url => $self->suburl('delete') );
  }
  
  if($self->op_available('rename_node')) {
    $self->apply_actions( rename   => 'call_rename_node' );
    $self->apply_extconfig( rename_node_url => $self->suburl('rename') );
  }
  
  if($self->op_available('copy_node')) {
    $self->apply_actions( copy => 'call_copy_node' );
    $self->apply_extconfig( copy_node_url => $self->suburl('copy') );
  }
  
  if($self->op_available('move_node')) {
    $self->apply_actions( move => 'call_move_node' );
    $self->apply_extconfig( move_node_url => $self->suburl('move') );
  }
  
  if($self->op_available('expand_node')) {
    $self->apply_actions( expand   => 'call_expand_node' );
    $self->apply_extconfig( expand_node_url => $self->suburl('expand') );
  }
  
  $self->add_ONREQUEST_calls('init_onreq');
}

# New: this method is provided so subclass can hook/override
sub op_available {
  my ($self, $op_name) = @_;
  $self->can($op_name)
}


around 'content' => sub {
  my $orig = shift;
  my $self = shift;
  
  my $content = $self->$orig(@_);
  
  return $content unless ($self->double_tree);

  my $cfg = {
    xtype => 'container',
    
    #Emulate border layout:
    style => { 'background-color' => '#f0f0f0' },
    
    layout => 'hbox',
    layoutConfig => {
      align => 'stretch',
      pack => 'start'
    },
    
    items => [
      {
        %$content,
        flex => \1,
        hideBorders => \1,
        margins => {
          top => 0,
          right => 5,
          bottom => 0,
          left => 0
        },
      },
      {
        %$content,
        id => $content->{id} . '2',
        flex => \1,
        hideBorders => \1,
      }
    ]
  };
  
  my @p = qw/tabTitle tabIconCls/;
  $content->{$_} and $cfg->{$_} = $content->{$_} for (@p);
  
  return $cfg
};



sub init_onreq {
  my $self = shift;
  
  $self->apply_extconfig(
    id            => $self->instance_id,
    dataUrl        => $self->suburl('/nodes'),
    rootVisible      => $self->show_root_node ? \1 : \0,
    root          => $self->root_node,
    tbar          => $self->tbar,
  );
  
  my $node = $self->init_jump_to_node or return;

  $self->add_listener( 
    afterrender => RapidApp::JSONFunc->new( raw => 1, func => 
      'function(tree) {' .
        'Ext.ux.RapidApp.AppTree.jump_to_node_id(tree,"' . $node . '");' .
      '}'
    )
  );
}


sub init_jump_to_node {
  my $self = shift;
  
  my $node;
  $node = $self->root_node_name if ($self->show_root_node);
  $node = $self->c->req->params->{node} if ($self->c->req->params->{node});
  
  return $node;
}

# If set to true, child nodes are automatically fetched recursively:
has 'fetch_nodes_deep', is => 'ro', isa => 'Bool', default => 0;

# Auto-sets 'expanded' on nodes with child nodes (only applies to children nodes
# loaded within 'call_fetch_nodes' because of 'fetch_nodes_deep' being set to true)
has 'default_expanded', is => 'ro', isa => 'Bool', default => 0;


##
##
## fetch_nodes(node_path) [Required]
##    method to fetch the tree dataUrl, first argument is the node path
has 'fetch_nodes'    => ( is => 'ro', default => sub { return []; } );
##


##
## show_root_node
##    whether or not to show the root node
has 'show_root_node'    => ( is => 'ro', default => 0 );
##

##
## root_node_name
##    Name of the root node (default 'root')
has 'root_node_name'    => ( is => 'ro', default => 'root' );
##


##
## root_node_text
##    text of the root node
has 'root_node_text'    => ( is => 'ro', lazy => 1, default => sub { (shift)->root_node_name; } );
##

##
## add_nodes: define as a method to support adding to the tree
##


sub apply_path_specific_node_opts {
  my $self = shift;
  my $node = shift; #<-- path of a parent node
  my $n = shift;
  
  return undef unless (exists $n->{id});
  
  die "Invalid node definition: id can't be the same as the parent node ($node): " . Dumper($n) 
    if($n->{id} eq $node);
  
  # The id should be a fully qualified '/' delim path prefixed with the (parent) node 
  # path ($node supplied to this function). If it is not, assume it is a relative path 
  # and prefix it automatically:
  $n->{id} = $node . '/' . $n->{id} unless ($n->{id} =~ /^\Q${node}\E/);
  
  # This is (imo) an ExtJS bug. It fixes the problem where empty nodes are automatically
  # made "leaf" nodes and get a stupid, non-folder default icon
  # http://www.sencha.com/forum/showthread.php?92553-Async-tree-make-empty-nodes-appear-as-quot-nodes-quot-not-quot-leaves-quot&p=441294&viewfull=1#post441294
  $n->{cls} = 'x-tree-node-collapsed' unless (exists $n->{cls});
  
  # legacy:
  $n->{expanded} = \1 if ($n->{expand} and ! exists $n->{expanded});
  
  $n->{leaf} = \1 if (exists $n->{allowChildren} and ! jstrue($n->{allowChildren}));
  
  $n->{loaded} = \1 if(jstrue($n->{leaf}) and ! exists $n->{loaded});

  return $n;
}

# Absolute maximum levels deep the whole tree can be
has 'max_node_path_depth', is => 'ro', isa => 'Int', default => 100;

# Max nested/recursive *single request* fetch depth that will be allowed. The tree can possibly
# be deeper than this value, but it wouldn't be fetch-able in a single request
has 'max_recursive_fetch_depth', is => 'ro', isa => 'Int', default => 3;

our $DEEP_FETCH_DEPTH = 0;

sub call_fetch_nodes {
  my $self = shift;
  my $node = shift || $self->c->req->params->{node};
  
  my @node_pth = split(/\//,$node);
  die usererr "max_node_path_depth (" . $self->max_node_path_depth . ") exceeded ($node)" 
    if (scalar(@node_pth)  > $self->max_node_path_depth);
  
  #Track recursive depth:
  local $DEEP_FETCH_DEPTH = $DEEP_FETCH_DEPTH + 1;
  
  # It shouldn't be possible to exceed 'max_recursive_fetch_depth':
  die "call_fetch_nodes deep recursion stopped at depth $DEEP_FETCH_DEPTH ($node)!!" 
    if($DEEP_FETCH_DEPTH > $self->max_recursive_fetch_depth);
  
  
  ######
  ######
  my $nodes = clone($self->fetch_nodes($node));
  ######
  ######
  
  # -- New: automatically test/exclude nodes according to 'require_role'
  @$nodes = grep { 
    ! $_->{require_role} or
    $self->role_checker->($self->c,$_->{require_role})
  } @$nodes if ($self->role_checker);
  # --
  
  die "Error: 'fetch_nodes()' was supposed to return an ArrayRef, but instead it returned: " . Dumper($nodes)
    unless (ref($nodes) eq 'ARRAY');
  
  my %seen_id = ();
  
  foreach my $n (@$nodes) {
    die "Invalid node definition: duplicate id ($n->{id}): " . Dumper($n)
      if($n->{id} && $seen_id{$n->{id}}++);
    
    $self->prepare_node($n,$node);
  }
  
  return $nodes;
}

sub prepare_node {
  my ($self, $n, $parent) = @_;
  
  if (jstrue($n->{leaf}) or (exists $n->{allowChildren} and ! jstrue($n->{allowChildren}))) {
    $n->{loaded} = \1 unless (exists $n->{loaded});
    return $n;
  }
  
  if($parent) {
    $self->apply_path_specific_node_opts($parent,$n) or return $n;
  }
  
  ## If we've gotten this far, it means the current node can contain child nodes
  
  my $recurse = 0;
  $recurse = 1 if (
    ( $self->fetch_nodes_deep or jstrue($n->{expanded}) )
    and ! exists $n->{children}
    and ! jstrue($n->{loaded})
    and $DEEP_FETCH_DEPTH < $self->max_recursive_fetch_depth
  );
  
  if($recurse) { # Pre-fetch child nodes automatically:
    my $children = $self->call_fetch_nodes($n->{id});
    if(@$children > 0) {
      $n->{children} = $children;
      $n->{expanded} = \1 if ($self->default_expanded and ! exists $n->{expanded});
    }
    else {
      # Set loaded to true if this node is empty (prevents being initialized with a +/- toggle):
      $n->{loaded} = \1 unless (exists $n->{loaded});
    }
  }
  
  # WARNING: note that setting 'children' of a node to an empty array will prevent subsequent
  # ajax loading of the node's children (should any exist later)
  
  $n
}


sub call_fetch_node {
  my $self = shift;
  my $node = $self->c->req->params->{node};
  my $n = $self->fetch_node($node);
  $self->prepare_node($n);
  $n
}

sub call_add_node {
  my $self = shift;
  my $params = clone($self->c->req->params);
  my $name = $params->{name};
  my $node = $params->{node};
  my $data = $self->add_node($name,$node,$params);
  
  # The config/params of the created node should have been returned in the 'child' key:
  if ($data->{child}) {
    my $n = $data->{child};
    die "id was not returned in 'child'" unless (exists $n->{id});
    $self->apply_path_specific_node_opts($node,$n); 
    
    # Assume the new node doesn't have any children yet and force to loaded/expanded:
    # (todo: it is conceivable that a new node might be created with children, add support for this in the future)
    $n->{loaded} = \1;
    $n->{expanded} = \1;
  }
  
  return $data;
}

sub call_delete_node {
  my $self = shift;
  my $name = $self->c->req->params->{name};
  my $node = $self->c->req->params->{node};
  my $recursive = $self->c->req->params->{recursive};
  return $self->delete_node($node,$recursive);
}

sub call_rename_node {
  my $self = shift;
  my $params = clone($self->c->req->params);
  my $name = $params->{name};
  my $node = $params->{node};
  return $self->rename_node($node,$name,$params);
}

sub call_expand_node {
  my $self = shift;
  my $node = shift; $node = $self->c->req->params->{node} unless (defined $node);
  my $expanded = shift; $expanded = $self->c->req->params->{expanded} unless (defined $expanded);
  
  # -- Handle optional batched updates:
  if (ref($node) eq 'ARRAY' or ref($expanded) eq 'ARRAY') {
    die "batch expand_node update data mismatch" unless (
      ref($node) eq 'ARRAY' and
      ref($expanded) eq 'ARRAY' and
      scalar @$node == scalar @$expanded #<-- both should be arrays of equal length
    );
    
    my $num = scalar @$node;
    
    for(my $i = 0; $i < $num; $i++) {
      $self->call_expand_node($node->[$i],$expanded->[$i]);
    };
    
    # Note: we don't actually check if this was successful on each call above...
    # Currently we can't really do anything about it if it didn't work, the info is
    # not important enough to subject the client to remediations/complexity. This should
    # probably be handled properly in the future, though
    return {
      msg    => 'Set Expanded State of ' . $num . ' nodes',
      success  => \1,
    };
  }
  # --
  
  $expanded = 0 if ($expanded eq '0' || $expanded eq 'false');
  return {
    msg    => 'Set Expanded',
    success  => \1,
  } if ( $self->expand_node($node,$expanded ? 1 : 0) );
  
  # Doesn't do anything, informational only:
  return {
    msg    => 'note: expand_node did not return true',
    success  => \0,
  }
}

sub call_copy_node {
  my $self = shift;
  my $node = $self->c->req->params->{node};
  my $target = $self->c->req->params->{target};
  my $name = $self->c->req->params->{name};
  
  # point and point_node will be defined for positional information, if
  # a node is dragged in-between 2 nodes (point above/below instead of append)
  # point_node is undef if point is append
  my $point_node = $self->c->req->params->{point_node};
  my $point = $self->c->req->params->{point};
  
  my $data = $self->copy_node($node,$target,$point,$point_node,$name);
  
  die "copy_node() returned invalid data" unless (ref($data) eq 'HASH' and $data->{child}); 
  
  # The config/params of the created node should have been returned in the 'child' key:
  if ($data->{child}) {
    my $n = $data->{child};
    die "id was not returned in 'child'" unless (exists $n->{id});
    $self->apply_path_specific_node_opts($target,$n); 
    
    ## Assume the new node doesn't have any children yet and force to loaded/expanded:
    ## (todo: it is conceivable that a new node might be created with children, add support for this in the future)
    #$n->{loaded} = \1;
    #$n->{expanded} = \1;
  }
  
  # Setting this so it can be picked up in javascript to add the new child next to
  # the copied node instead of within it (this logic was borrowed from add originally 
  # and extended for copy) TODO: clean up this API
  $data->{child_after} = \1;
  
  return $data;
}

sub call_move_node {
  my $self = shift;
  my $node = $self->c->req->params->{node};
  my $target = $self->c->req->params->{target};
  
  # point and point_node will be defined for positional information, if
  # a node is dragged in-between 2 nodes (point above/below instead of append)
  # point_node is undef if point is append
  my $point_node = $self->c->req->params->{point_node};
  my $point = $self->c->req->params->{point};
  
  return {
    msg    => 'Moved',
    success  => \1,
  } if ( $self->move_node($node,$target,$point,$point_node) );
  
  die usererr "Move failed!";
}


has 'root_node' => ( is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return {
    nodeType    => 'async',
    id        => $self->root_node_name,
    text      => $self->root_node_text,
    draggable  => \0
  };
});


has 'tbar' => ( is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return undef;
  return ['->'];
  
  my $tbar = [];

  push @$tbar, $self->delete_button if ($self->can('delete_node'));
  push @$tbar, $self->add_button if ($self->can('add_node'));

  return undef unless (scalar @$tbar > 0);

  unshift @$tbar, '->';

  return $tbar;
});






sub add_button {
  my $self = shift;
  
  return RapidApp::JSONFunc->new(
    func => 'new Ext.Button', 
    parm => {
      text     => $self->add_button_text,
      iconCls  => $self->add_button_iconCls,
      handler   => RapidApp::JSONFunc->new( 
        raw => 1, 
        func => 'function(btn) { ' . 
          'var tree = btn.ownerCt.ownerCt;'.
          'tree.nodeAdd();' .
          #'tree.nodeAdd(tree.activeNonLeafNode());' .        
        '}'
      )
  });
}


sub delete_button {
  my $self = shift;
  
  return RapidApp::JSONFunc->new(
    func => 'new Ext.Button', 
    parm => {
      tooltip    => $self->delete_button_text,
      iconCls  => $self->delete_button_iconCls,
      handler   => RapidApp::JSONFunc->new( 
        raw => 1, 
        func => 'function(btn) { ' . 
          'var tree = btn.ownerCt.ownerCt;'.
          'tree.nodeDelete(tree.getSelectionModel().getSelectedNode());' .
          #'Ext.ux.RapidApp.AppTree.del(tree,"' . $self->suburl('/delete') . '");' .
          
        '}'
      )
  });
}




#### --------------------- ####


#no Moose;
#__PACKAGE__->meta->make_immutable;
1;