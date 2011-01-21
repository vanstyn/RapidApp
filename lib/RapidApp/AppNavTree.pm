package RapidApp::AppNavTree;
use Moose;
extends 'RapidApp::AppTree';

use RapidApp::Include qw(sugar perlutil);

sub BUILD {
	my $self = shift;

	$self->add_listener( click => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.treenav_click' ) );
	$self->add_listener( beforerender => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' ) );
}


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
			
			my $module = $item->{module} or next; # <-- Don't build a loadContentCnf if there is no module
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