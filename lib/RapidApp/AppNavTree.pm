package RapidApp::AppNavTree;


use strict;
use Moose;

extends 'RapidApp::AppTree';



use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use RapidApp::MooseX::ClassAttrSugar;
setup_add_methods_for('listeners');
setup_add_methods_for('config');

add_default_listeners(
	'beforerender'	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' ),
	'click' 			=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.treenav_click' )
);



has 'module_scope' => ( is => 'ro', lazy => 1, default => sub { return shift; });



sub fetch_nodes {
	my $self = shift;
	
	my $recurse;
	$recurse = sub {
		my $node = shift;
		foreach my $item (@$node) {
		
			if (ref($item->{children}) eq 'ARRAY' and scalar $item->{children} > 0) {
				$recurse->($item->{children}) if ($item->{children});
			}
			else {
				$item->{leaf} = \1;
				$item->{loaded} = \1;
				delete $item->{children} if ($item->{children});
			}
			
			$item->{expanded} = \1 if ($item->{expand});
			
			my $autoLoad = {};
			$autoLoad->{params} = $item->{params} if ($item->{params});
			
			my $module = $item->{module};
			if ($module) {
				$module = $self->module_scope->Module($item->{module}) unless(ref($module));
				$autoLoad->{url} = $module->base_url;
			}
			
			my $loadCnf = {};
			$loadCnf->{itemId} = $item->{itemId};
			$loadCnf->{itemId} = $item->{id} unless ($loadCnf->{itemId});
			
			$loadCnf->{title} = $item->{text};
			$loadCnf->{iconCls} = $item->{iconCls};
			
			$loadCnf->{autoLoad} = $autoLoad;
			$item->{loadContentCnf} = $loadCnf;
		}
		return $node;
	};
	
	return $recurse->($self->TreeConfig);
}




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;