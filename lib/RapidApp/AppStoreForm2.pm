package RapidApp::AppStoreForm2;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use strict;

use RapidApp::Include qw(sugar perlutil);
	my ($self, $context, $cfg)= @_;
use RapidApp::ExtCfgToHtml;
use RapidApp::ExtCfgToHtml::ExtJSForm;

has 'reload_on_save' 		=> ( is => 'ro', default => 0 );
has 'closetab_on_create'	=> ( is => 'ro', default => 0 );

sub BUILD {
	my $self = shift;
	
	$self->Module('store',1)->add_listener( load => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.store_load_handler' ));	
	$self->Module('store',1)->add_listener( write => RapidApp::JSONFunc->new( raw => 1, func =>  'function(store) { store.load(); }' )) if ($self->reload_on_save);
	#$self->Module('store',1)->add_listener( write => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.store_create_closetab' )) if ($self->closetab_on_create);
	$self->Module('store',1)->add_listener( write => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.store_create_handler' ));	

	$self->apply_extconfig(
		xtype		=> 'appstoreform2',
		trackResetOnLoad => \1
	);

	$self->add_listener( clientvalidation	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.clientvalidation_handler' ) );
	$self->add_listener( afterrender			=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.afterrender_handler' ) );

	$self->add_ONREQUEST_calls('init_onrequest');
	$self->enableAuthorRendering;
}

sub init_onrequest {
	my $self = shift;
	
	$self->apply_extconfig( 
		id 		=> $self->instance_id,
		tbar 		=> $self->formpanel_tbar,
		items 	=> $self->formpanel_items,
	);
}

sub web1_render {
	my ($self, $cxt)= @_;
	my $cfg= $self->get_complete_extconfig;
	RapidApp::ExtCfgToHtml->render($cxt, $cfg, 'form');
}

############# Buttons #################
has 'button_text_cls' => ( is => 'ro', default => 'tbar-button-medium' );
has 'button_scale' => ( is => 'ro',	default => 'medium'	);

has 'reload_button_text' => ( is => 'ro',	default => ' Reload '	);
has 'reload_button_iconCls' => ( is => 'ro',	default => 'icon-refresh-24x24'	);
has 'reload_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->reload_button_text . '</div>',
			iconCls	=> $self->reload_button_iconCls,
			itemId	=> 'reload-btn',
			scale		=> $self->button_scale,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.reload_handler' ) 
	});
}

has 'save_button_text' => ( is => 'ro',	default => ' Save '	);
has 'save_button_iconCls' => ( is => 'ro',	default => 'icon-save-24x24'	);
has 'save_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->save_button_text . '</div>',
			iconCls	=> $self->save_button_iconCls,
			itemId	=> 'save-btn',
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.save_handler' ) 
	});
}


has 'add_button_text' => ( is => 'ro',	default => ' Add '	);
has 'add_button_iconCls' => ( is => 'ro',	default => 'icon-add-24x24'	);
has 'add_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_add_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->add_button_text . '</div>',
			iconCls	=> $self->add_button_iconCls,
			itemId	=> 'add-btn',
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppStoreForm2.add_handler' ) 
	});
}
###############################################




has 'tbar_icon' => ( is => 'ro', isa => 'Str' );
has 'tbar_title' => ( is => 'ro', isa => 'Str' );
#has 'formpanel_items' => ( is => 'ro', default => sub {[]} );



has 'formpanel_items' => (
	traits    => [ 'Array' ],
	is        => 'ro',
	isa       => 'ArrayRef[HashRef]',
	default   => sub { [] },
	handles => {
		all_formpanel_items		=> 'elements',
		add_formpanel_items		=> 'push',
	}
);



has 'tbar_title_text_cls' => ( is => 'ro', default => 'tbar-title-medium' );
#has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
#sub _build_formpanel_tbar {
sub formpanel_tbar {

	my $self = shift;
	
	my $Store = $self->Module('store',1);
	
	my $items = [];
		
	push @$items, '<img src="' . $self->tbar_icon . '">' if (defined $self->tbar_icon);
	push @$items, '<div class="' . $self->tbar_title_text_cls . '">' . $self->tbar_title . '</div>' if (defined $self->tbar_title);
	
	push @$items, '->';
	
	push @$items, $self->add_button if (defined $Store->create_handler and $Store->has_flag('can_create'));
	push @$items, $self->reload_button if (defined $Store->read_handler and not $Store->has_flag('can_create') and $Store->has_flag('can_read'));
	push @$items, '-' if (defined $Store->read_handler and defined $Store->update_handler and $Store->has_flag('can_read') and $Store->has_flag('can_update'));
	push @$items, $self->save_button if (defined $Store->update_handler and $Store->has_flag('can_update'));
	
	return {
		items => $items
	};
}

# RapidApp::Web1RenderContext->registerXtypeRenderFunction('appstoreform2' => \&web1_render_appstoreform2);
# sub web1_render_appstoreform2 {
	# my ($context, $cfg)= @_;
	# if ($cfg->{store} && $cfg->{store}{parm} && $cfg->{store}{parm}{api} && $cfg->{store}{parm}{api}{read}) {
		# my $storeReadUrl= $cfg->{store}{parm}{api}{read};
		
	# }
	# $context->render($cfg, 'form');
# }

#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;

1;