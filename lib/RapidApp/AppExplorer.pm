package RapidApp::AppExplorer;
#
# -------------------------------------------------------------- #
#
#  General-purpose 'Explorer' - nav tree with tab content
#

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppBase';

use RapidApp::Include qw(sugar perlutil);

require Module::Runtime;

has 'title', is => 'ro', default => 'AppExplorer';
has 'right_footer', is => 'ro', lazy => 1, default => sub {(shift)->title};
has 'iconCls', is => 'ro',	default => 'icon-server_database';

has 'navtree_class', is => 'ro', isa => 'Str', required => 1;
has 'navtree_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub{{}};

has 'dashboard_class', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};
has 'dashboard_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub{{}};

sub BUILD {
	my $self = shift;
	
	Module::Runtime::require_module($self->navtree_class);
	$self->apply_init_modules(
		navtree => {
			class => $self->navtree_class,
			params => $self->navtree_params
		}
	);
  
  if ($self->dashboard_class) {
    Module::Runtime::require_module($self->dashboard_class);
    $self->apply_init_modules(
      dashboard => {
        class => $self->dashboard_class,
        params => $self->dashboard_params
      }
    );
  }
}


sub content {
	my $self = shift;

	return {
		#id			=> $self->instance_id,
		id			=> 'explorer-id',
		xtype		=> 'panel',
		layout	=> 'border',
		items		=> [
			$self->content_area,
			{
				region	=> 'west',
				title		=> $self->title,
				iconCls		=> $self->iconCls,
				collapsible => \1,
				split => \1,
				minSize => 150,
				width	=> 240,
				margins => '3 3 3 3',
				layout	=> 'fit',
				#tools => [{
				#	id => 'refresh',
				#	qtip => 'Refresh Nav Tree',
				#	handler => jsfunc 'Ext.ux.RaSakila.reloadMainNavTreeOnly'
				#}],
				collapseFirst => \0,
				items => $self->west_area_items,
			}
		],
		footer => \1,
		footerCfg => {
			tag => 'div',
			html => q{
<div class="ra-footer no-text-select"><div class="wrap">
	<table width="100%"><tr>
		<td width="25%" class="left">
		
		</td>
		<td width="50%" class="center">
			<div id="infostatus"></div>
		</td>
		<td width="25%" class="right">
			} . $self->right_footer . q{
		</td>
	</tr></table>
</div></div>
}
		},
	};
}


sub west_area_items {
	my $self = shift;
	
	return $self->Module('navtree')->content;
}


sub content_area {
	my $self = shift;
	
	my $cnf = {
		# main-load-target is looked for by RapidApp js functions:
		id => 'main-load-target',
		region		=> 'center',
		margins		=> '3 3 3 0',
		bodyCssClass		=> 'sbl-panel-body-noborder',
	};
	
	#$cnf->{margins} = '3 3 3 3' unless ($self->show_navtree);
  
  $cnf->{initLoadTabs} = [
    {
      title	=> '<img src="/static/rapidapp/images/toolbar_home.png" height=15 width=16>',
      iconCls => '',
      closable	=> \0,
      autoLoad => {
        url 	=> $self->Module('dashboard')->base_url,
        params	=> {}
      }
    }
  ] if ($self->dashboard_class);
	
	return  RapidApp::JSONFunc->new(
		func => 'new Ext.ux.RapidApp.AppTab.TabPanel',
		parm => $cnf
	);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;