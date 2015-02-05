package RapidApp::Module::NavTree;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::NavTree';

use RapidApp::Include qw(sugar perlutil);

has 'module_scope', is => 'ro', lazy => 1, default => sub { return shift };

has '+fetch_nodes_deep', default => 1;

has 'double_click_nav', is => 'ro', isa => 'Bool', default => 0;

sub BUILD {
  my $self = shift;
  $self->setup_nav_listeners;
}

# Add these listeners in a sub so derived classes can override/remove this:
sub setup_nav_listeners {
  my $self = shift;
  
  my $event = $self->double_click_nav ? 'dblclick' : 'click';
  
  $self->add_listener( $event => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.treenav_click' ) );
  $self->add_listener( beforerender => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' ) );
}

sub apply_node_navopts_recursive {
  my $self = shift;
  my $nodes = shift;
  
  return undef unless (ref($nodes) eq 'ARRAY');
  
  foreach my $item (@$nodes) {
    
    if (ref($item->{children}) eq 'ARRAY' and scalar $item->{children} > 0) {
      $self->apply_node_navopts_recursive($item->{children}) if ($item->{children});
    }
    else {
      #$item->{leaf} = \1;
      $item->{loaded} = \1;
      delete $item->{children} if ($item->{children});
    }
    
    $item->{expanded} = \1 if ($item->{expand});
    
    $self->apply_node_navopts($item);
  }
  
  return $nodes;
}

sub apply_node_navopts {
  my $self = shift;
  my $item = shift;
  
  my $autoLoad = {};
  $autoLoad->{params} = $item->{params} if ($item->{params});
  $autoLoad->{url} = $item->{url} if ($item->{params});
  
  my $module = $item->{module}; 
  if ($module) {
    $module = $self->module_scope->Module($item->{module}) unless(ref($module));
    $autoLoad->{url} = $module->base_url;
  }
  else {
    # Don't build a loadContentCnf if there is no module or url
    return unless ($autoLoad->{url});
  }
  
  my $loadCnf = {};
  $loadCnf->{itemId} = $item->{itemId};
  $loadCnf->{itemId} = $item->{id} unless ($loadCnf->{itemId});
  
  $loadCnf->{title} = $item->{title} || $item->{text};
  $loadCnf->{iconCls} = $item->{iconCls};
  
  $loadCnf->{autoLoad} = $autoLoad;
  $item->{loadContentCnf} = $loadCnf;
}

# Default fetch_nodes uses an array of nodes returned from 'TreeConfig'
sub fetch_nodes {
  my $self = shift;
  return $self->apply_node_navopts_recursive($self->TreeConfig) || [];
}




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;