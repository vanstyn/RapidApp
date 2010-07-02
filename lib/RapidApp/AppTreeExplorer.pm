package RapidApp::AppTreeExplorer;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Grid object
#
#
# 2010-01-18:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::AppBase';


use Clone;
use Term::ANSIColor qw(:constants);

our $VERSION = '0.1';

use SBL::Web::ExtJS;
use RapidApp::ExtJS::DynGrid;

use RapidApp::Tree;

use Switch;

#### --------------------- ####

has 'TreeConfig' 						=> ( is => 'ro',	required		=> 1,	isa => 'ArrayRef'		);
has 'Tree' 								=> ( is => 'ro',	lazy_build	=> 1								);
#has 'TreePanel_code' 				=> ( is => 'ro',	lazy_build	=> 1								);
has 'subapps'			 				=> ( is => 'ro',	lazy_build	=> 1,	isa => 'HashRef'		);
has 'title' 							=> ( is => 'ro',	lazy_build	=> 1								);
has 'content_id' 						=> ( is => 'ro',	lazy_build	=> 1								);
has 'navtree_id' 						=> ( is => 'ro',	lazy_build	=> 1								);
has 'treepanel_id' 					=> ( is => 'ro',	lazy_build	=> 1								);
has 'expand_nodes'					=> ( is => 'ro',	default		=> sub { {} }					);
has 'iconCls' 							=> ( is => 'ro',	default		=> ''								);
has 'main_id' 							=> ( is => 'ro',	default		=> 'apptreeexplorer'			);
has 'use_tabs' 						=> ( is => 'ro',	default		=> 0								);

#### --------------------- ####

sub _build_pathmap 			{ return {}; 										}
sub _build_subapps 			{ return {}; 										}
sub _build_title				{ ref(shift);										}
sub _build_content_id			{ (shift)->title . '_content_area';			}
sub _build_navtree_id			{ (shift)->title . '_nav_tree';				}
sub _build_treepanel_id		{ (shift)->title . '_treepanel';				}


sub _build_Tree {
	my $self = shift;
	
	return RapidApp::Tree->new(
		treepanel_id			=> $self->treepanel_id,
		TreeConfig				=> $self->TreeConfig,
		click_handler			=> $self->tree_click_handler,
		
		treewalk_coderef		=> sub {
			my $node_cfg = shift;
			my $cfg = shift;
			if (defined $node_cfg->{subapp}) {
				$cfg->{navtarget} = $self->base_url . '/' . $node_cfg->{subapp};
				$cfg->{params} = $node_cfg->{params} if (defined $node_cfg->{params});
			}
		},
	);
}



###########################################################################################

sub BUILD {
	my $self = shift;
	$self->Tree;
}


sub Controller {
	my ( $self, $c, $opt, @args ) = @_;
	
	my $data = '';
	
	switch($opt) {
	
		case 'navtree' 				{ $data = $self->JSON_encode($self->navtree_panel($c));		}
		case 'main_panel'				{ $data = $self->JSON_encode($self->main_panel($c));			}
		case 'default_content'		{ $data = $self->JSON_encode($self->default_content);		}

		else {
		
			return $self->subapps->{$opt}->($c)->Controller($c,@args) if (
				defined $self->subapps and
				defined $self->subapps->{$opt} and
				ref($self->subapps->{$opt}) eq 'CODE'
			);
			
		}
	}
	
	$c->response->header('Cache-Control' => 'no-cache');
	return $c->response->body( $data );
}



sub main {
	my $self = shift;
	return {
		region			=> 'center',
		id					=> $self->main_id,
		xtype				=> 'autopanel',
		bodyCssClass	=> 'sbl-panel-body-noborder',
		layout 			=> 'fit',
		autoLoad			=> $self->base_url . '/main_panel',
	};
}


sub main_panel {
	my $self = shift;
	my $c = shift;
	
	my $params;
	$params = $c->req->params if (defined $c);

	return {
		region	=> 'center',
		#id			=> $self->main_id,
		xtype		=> 'panel',
		layout	=> 'border',
		title		=> $self->title,
		iconCls	=> $self->iconCls,
		items		=> [
			$self->content_area,
			$self->nav_tree($params),
		]
	};
}


sub nav_tree {
	my $self = shift;
	my $params = shift;
	
	my $autoLoad = {
		url => $self->base_url . '/navtree'
	};
	
	$autoLoad->{params} = $params if (defined $params and ref($params) eq 'HASH');
	
	return {
		region			=> 'west',
		id					=> $self->navtree_id,
		xtype				=> 'container',
		margins			=> '3 3 3 3',
		layout			=> 'fit',
		autoEl			=> {},
		width				=> 200,
		minSize			=> 200,
		maxSize			=> 200,
		collapsible		=> 0,
		items				=> {
			id					=> 'navtree_area',
			xtype				=> 'autopanel',
			layout			=> 'fit',
			bodyCssClass	=> 'sbl-panel-body-noborder',
			autoLoad			=> $autoLoad
		}
	};
}


sub content_area {
	my $self = shift;
	return {
		region			=> 'center',
		id					=> $self->content_id,
		xtype				=> 'autopanel',
		bodyCssClass	=> 'sbl-panel-body-noborder',
		margins 			=> '3 3 3 0',
		layout 			=> 'fit',
		autoLoad			=> $self->base_url . '/default_content',
	} unless ($self->use_tabs);
	return $self->tabpanel;
}


sub tabpanel {
	my $self = shift;
	return {
		region				=> 'center',
		xtype					=> 'tabpanel',
		bodyCssClass		=> 'sbl-panel-body-noborder',
		margins 				=> '3 3 3 0',
		id						=> $self->content_id,
		forceLayout			=> \1,
		deferredRender		=> \0,
		layoutOnTabChange => \1,
		enableTabScroll	=> \1,
		defaults => {
			autoHeight => \0,
			closable => \1,
		}
	};
}



sub default_content {
	my $self = shift;
	return {};
}


sub navtree_panel {
	my $self = shift;
	my $c = shift;
	
	my $params;
	$params = $c->req->params if (defined $c);
	
	my $config = Clone::clone($self->Tree->TreePanel_cfg);
	
	if (defined $params and ref($params) eq 'HASH' and defined $params->{path}) {
		$config->{afterRender_eval} = '' unless (defined $config->{afterRender_eval});
		$config->{afterRender_eval} .= 

			q~var treepanel = Ext.getCmp('~ . $config->{id} . q~');~ .
			q~treepanel.selectPath('~ . $params->{path} . q~','id',function(bSuccess,oSelNode) { ~ .
				'if(bSuccess) { '.
					$self->content_panel_load_path("oSelNode.attributes.navtarget",$params) .
				'}' .
			'});';
	}
	
	return $config;
}





sub tree_click_handler {
	my $self = shift;
	
	my $code =
		"var Target = 'default';" . 
		'if (node.attributes.navtarget) { ' .
			'Target = node.attributes.navtarget;';
			
			if ($self->use_tabs) {
				$code .= 	'var loadcfg = {' .
					'url:     node.attributes.navtarget,' .
					'params:  node.attributes.params,' .
					'id:      node.getPath(),' .
					'iconCls: node.attributes.iconCls,' .
					'title:   node.attributes.text' .
				'};' . $self->tabpanel_load_code('loadcfg');
			}
			else {
				$code .= $self->content_panel_load_path('Target','node.attributes.params');
			}
			
		$code .= '}';

	return $code;
}


sub tabpanel_load_code_coderef {
	my $self = shift;
	return sub {
		my $loadcfg = shift;
		return $self->tabpanel_load_code($loadcfg);
	};
}

sub tabpanel_load_code {
	my $self = shift;
	my $loadcfg = shift;
	
	$loadcfg = $self->JSON_encode($loadcfg) if (ref($loadcfg) eq 'HASH');
	
	my $cfg = {
		layout	=> 'fit',
		#layout => 'hbox',
		closable	=> \1,
		#viewConfig => { forceFit => \0 },
		xtype		=> 'autopanel',
		#xtype		=> 'panel',
		headerCfg => {style => 'border-bottom: 0px;'},
		autoLoad => {
			text		=> 'Loading...',
			nocache	=> 1,
		} 
	};
	
	my $code =
		'var TabP = Ext.getCmp(' . "'" . $self->content_id . "'" . ');' .
		'if (TabP) { ' .
			'var attr = ' . $loadcfg . ';' .
			'var cfg = ' . $self->JSON_encode($cfg) . ';' .
			'cfg.id = "tab-" + attr.id;' . 
			"cfg.autoLoad['url'] = attr.url;" . 
			"cfg.title = cfg.id;" .
			"if(attr.title)    { cfg.title = attr.title; }" .
			"if(attr.iconCls) { cfg.iconCls = attr.iconCls; }" .
			"if(attr.params)  { cfg.autoLoad['params'] = attr.params; }" .
			"var new_tab = 0;" . 
			'if(! Ext.getCmp(cfg.id)) { TabP.add(cfg); new_tab = 1; }' .
			"TabP.setActiveTab(cfg.id);" .
			"if (!new_tab) { var dyngrid = Ext.getCmp(cfg.id).findByType('dyngrid'); if (dyngrid[0]) { dyngrid[0].getStore().reload(); }}" .
		'}';
	
	return $code;
}



sub tabpanel_load_code_old {
	my $self = shift;
	my $id = shift;
	my $path = shift;
	my $attr = shift;
	
	my $cfg = {
		layout	=> 'fit',
		closable	=> \1,
		xtype		=> 'autopanel',
		autoLoad => {
			text		=> 'Loading...',
			nocache	=> 1,
		} 
	};
	
	my $code =
		'var TabP = Ext.getCmp(' . "'" . $id . "'" . ');' .
		'if (TabP) { ' .
			'var path = ' . $path . ';' . 
			'var attr = ' . $attr . ';' .
			'var cfg = ' . $self->JSON_encode($cfg) . ';' .
			'cfg.id = "tab-" + path;' . 
			"cfg.autoLoad['url'] = path;" . 
			"cfg.title = path;" .
			"if(attr.text)    { cfg.title = attr.text; }" .
			"if(attr.iconCls) { cfg.iconCls = attr.iconCls; }" .
			"if(attr.params)  { " .
				"cfg.autoLoad['params'] = attr.params;" .
				"for (i in attr.params) { cfg.id += '-' + attr.params[i]; }" . 
			"}" .
			'if(! Ext.getCmp(cfg.id)) { TabP.add(cfg); }' .
			"TabP.setActiveTab(cfg.id);" .
		'}';
	
	return $code;
}



sub content_panel_load_path {
	my $self = shift;
	my $path = shift;
	my $params = shift;
	
	return $self->panel_load_code($self->content_id,$path,$params);
}


sub panel_load_code {
	my $self = shift;
	my $id = shift;
	my $path = shift;
	my $params = shift;
	
	my $cfg = {
		text		=> 'Loading...',
		nocache	=> 1
	};
	
	my $code =
		'var ContentP = Ext.getCmp(' . "'" . $id . "'" . ');' .
		'if (ContentP) { ' .
			'var cfg = ' . $self->JSON_encode($cfg) . ';' .
			'cfg.url = ' . $path . ';';
	$code .= 'cfg.params = ' . $params . ';' if (defined $params and ref(\$params) eq 'SCALAR');
	$code .= 'ContentP.load(cfg); ' .
		'}';
	
	return $code;
	
}





sub main_panel_reload {
	my $self = shift;
	my $tree_path = shift;
	
	my $params = { path => $tree_path };
	
	return $self->panel_load_code($self->main_id,"'" . $self->base_url . '/main_panel' . "'",$params);

}



sub add_subapp {
	my $self = shift;
	my $name = shift;
	my $app = shift or die '$app is a required parameter';
	
	die "subapp '$name' already defined!" if (defined $self->subapps->{$name});
	
	$self->subapps->{$name} = $app;
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;