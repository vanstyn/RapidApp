package RapidApp::AppExplorer;
#
# -------------------------------------------------------------- #
#
#  General-purpose 'Explorer' - nav tree with tab content
#

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCmp';

use RapidApp::Include qw(sugar perlutil);

require Module::Runtime;

has 'title', is => 'ro', default => 'AppExplorer';
has 'right_footer', is => 'ro', lazy => 1, default => sub {(shift)->title};
has 'iconCls', is => 'ro',	default => 'ra-icon-server-database';

has 'navtree_class', is => 'ro', isa => 'Maybe[Str]', default => sub{undef};
has 'navtree_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub{{}};
has 'navtree_load_collapsed', is => 'ro', isa => 'Bool', default => 0;
has 'navtree_disabled', is => 'ro', isa => 'Bool', default => 0;

has 'navtrees', is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub {
  my $self = shift;
  die "either navtrees or navtree_class is required" unless ($self->navtree_class);
  return [{
    module => 'navtree',
    class => $self->navtree_class,
    params => $self->navtree_params
  }];
};

has 'dashboard_class', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};
has 'dashboard_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub{{}};

# NEW
has 'dashboard_url', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

# New:
has 'navtree_footer_template', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

# Extra optional class for rendering any tt files or other files
# Feature added with RapidApp::AppPageViewer in mind, but it doesn't
# actually care. This module will be loaded as 'page' and nothing else
# will be done (i.e. expects direct links from markup to access content)
has 'page_viewer_class', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};
has 'page_viewer_params', is => 'ro', isa => 'HashRef', lazy => 1, default => sub{{}};


sub BUILD {
	my $self = shift;
	
  my %seen = ();
  for my $cnf (@{$self->navtrees}) {
    my $name = $cnf->{module} or next;
    my $class = $cnf->{class} or die "Missing class name";
    my $params = $cnf->{params} || {};
    die "Duplicate module '$name'" if ($seen{$name}++);
    
    Module::Runtime::require_module($class);
    $self->apply_init_modules( $name => { class => $class, params => $params } );
  }
  
  if ($self->dashboard_class) {
    Module::Runtime::require_module($self->dashboard_class);
    $self->apply_init_modules(
      dashboard => {
        class => $self->dashboard_class,
        params => $self->dashboard_params
      }
    );
  }
  
  if ($self->page_viewer_class) {
    Module::Runtime::require_module($self->page_viewer_class);
    $self->apply_init_modules(
      page => {
        class => $self->page_viewer_class,
        params => $self->page_viewer_params
      }
    );
  }
}


around 'content' => sub {
	my $orig = shift;
  my $self = shift;
  
  my $cnf = $self->$orig(@_);
  
	return { %$cnf,
		id			=> 'explorer-id',
		xtype		=> 'panel',
		layout	=> 'border',
		items		=> [
			$self->content_area,
			$self->navtree_area
		],
		footer => \1,
		footerCfg => {
			tag => 'div',
      # FIXME: convert to template
			html => q{
<div class="ra-footer no-text-select"><div class="wrap">
	<table width="100%"><tr>
		<td width="25%">
      <a class="left" target="_blank" href="http://www.rapidapp.info"></a>
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
};

sub navtree_area {
  my $self = shift;
  
  return () if ($self->navtree_disabled);

  my $west = {
    region	=> 'west',
    title		=> $self->title,
    iconCls		=> $self->iconCls,
    collapsible => \1,
    split => \1,
    minSize => 150,
    width	=> 240,
    margins => '3 3 3 3',
    layout	=> 'fit',
    tools => [{
      id => 'refresh',
      qtip => 'Refresh Nav Tree',
      handler => jsfunc 'Ext.ux.RapidApp.NavCore.reloadMainNavTrees'
    }],
    collapseFirst => \0,
    autoScroll => \0,
    items => {
      # We need to nest within an additional panel layer to ensure
      # proper scrolling. Note that autoScroll is set in this panel,
      # and *not* in the parent panel above (region: west)
      id => 'main-navtrees-container',
      xtype => 'panel',
      autoScroll => \1,
      border => \0, bodyBorder => \0,
      items => $self->west_area_items
    }
  };
  
  $west->{collapsed} = \1 if ($self->navtree_load_collapsed);
  
  # Render a custom footer at the bottom of the navtree
  if($self->navtree_footer_template) {
    my $html;
    try{
      $html = $self->c->template_render(
        $self->navtree_footer_template
      );
    }
    catch {
      my $err = shift;
      $html = "$err";
    };
    
    $west = { %$west,
      bodyStyle => 'border-bottom: 0px;',
      footer => \1,
      footerCfg => {
        tag => 'div',
        cls => 'x-panel-body',
        html => $html
      }
    };
  }
  
  return $west;
}

sub west_area_items {
	my $self = shift;
  
  # Dynamic "typing" (of sorts). Allow raw ExtJS configs to
  # be interspersed among module cnfs 
  my @items = map {
    $_->{module} ? $self->Module($_->{module})->allowed_content : $_
  } @{$self->navtrees};
  
  return \@items;
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
  
  $cnf->{margins} = '3 3 3 3' if ($self->navtree_disabled);
  
  my $initTab = {
    title	=> '&nbsp;',
    iconCls => 'ra-tab-icon-only-16px ra-icon-home',
    closable	=> \0,
    autoLoad => {
      params	=> {}
    }
  };

  if ($self->dashboard_class) {
    $initTab->{autoLoad}{url} = $self->Module('dashboard')->base_url;
    $cnf->{initLoadTabs} = [$initTab];
  }
  elsif ($self->dashboard_url) {
    $initTab->{autopanel_ignore_tabtitle} = \1;
    $initTab->{autoLoad}{url} = $self->dashboard_url;
    $cnf->{initLoadTabs} = [$initTab];
  }
  
	return  RapidApp::JSONFunc->new(
		func => 'new Ext.ux.RapidApp.AppTab.TabPanel',
		parm => $cnf
	);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;