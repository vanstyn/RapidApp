package RapidApp::AppStoreForm2;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use strict;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::Web1RenderContext::ExtCfgToHtml;

has 'reload_on_save' 		=> ( is => 'ro', default => 0 );
has 'closetab_on_create'	=> ( is => 'ro', default => 0 );

has 'link_buttons_by_id'   => ( is => 'rw', default => 0 );

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
}

sub init_onrequest {
	my $self = shift;
	
	if ($self->link_buttons_by_id) {
		$self->clear_add_button;
		$self->clear_save_button;
		$self->clear_reload_button;
	}
	$self->apply_extconfig( 
		id 		=> $self->instance_id,
		tbar 		=> $self->formpanel_tbar,
		items 	=> $self->formpanel_items,
		($self->link_buttons_by_id?
			(addBtnId => $self->instance_id.'_addBtn',
			saveBtnId => $self->instance_id.'_saveBtn') : ()
		)
	);
}

sub web1_render_extcfg {
	my ($self, $renderCxt, $extCfg)= @_;
	$renderCxt->renderer->isa('RapidApp::Web1RenderContext::ExtCfgToHtml')
		or die "Renderer for automatic ext->html conversion must be a Web1RenderContext::ExtCfg2ToHtml";
	
	# get the cfg if it wasn't gotten already
	$extCfg ||= $self->get_complete_extconfig;
	
	# load the data for the form
	my $storeFetchParams= $extCfg->{store}{parm}{baseParams};
	my $data= $self->Module('store')->read_raw($storeFetchParams);
	
	# if we got it, fill in the values
	if (scalar(@{$data->{rows}})) {
		$self->mergeStoreValues($extCfg->{items}, $data->{rows}->[0]);
	}
	
	# now render using the renderer for xtype "form"
	my $formRenderer= $renderCxt->renderer->findRendererForXtype('form');
	$formRenderer->renderAsHtml($renderCxt, $extCfg);
	
	# for debugging, show the complete contents of the extCfg hash
	($ENV{DEBUG_CFG_OBJECTS} || $self->c->req->params->{DEBUG_CFG_OBJECTS})
		and $renderCxt->data2html($extCfg);
}

sub mergeStoreValues {
	my ($self, $items, $row)= @_;
	
	my %itemByName= ();
	for my $item (@$items) {
		defined $item->{name}
			and $itemByName{$item->{name}}= $item;
	}
	for my $key (keys %$row) {
		defined $itemByName{$key}
			and $itemByName{$key}->{value}= $row->{$key};
	}
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
			($self->link_buttons_by_id? (appstoreform_id => $self->instance_id) : () ),
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
			($self->link_buttons_by_id?
				(appstoreform_id => $self->instance_id,
				id => $self->instance_id.'_saveBtn') : ()
			),
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
			($self->link_buttons_by_id?
				(appstoreform_id => $self->instance_id,
				id => $self->instance_id.'_addBtn') : ()
			),
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

sub options_menu_items {
	my $self = shift;
	return undef;
}


sub options_menu {
	my $self = shift;
	
	my $items = $self->options_menu_items or return undef;
	return undef unless (ref($items) eq 'ARRAY') && scalar(@$items);
	
	return {
		xtype    => 'button',
		text     => '<div class="'.$self->button_text_cls.'">Options</div>',
		iconCls  => 'icon-gears-24x24',
		scale    => $self->button_scale,
		menu => {
			items	=> $items
		}
	};
}

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
	
	my $menu = $self->options_menu;
	defined $menu and push @$items, $menu, ' ', '-';
	
	push @$items, $self->add_button if (defined $Store->create_handler and $Store->has_flag('can_create'));
	push @$items, $self->reload_button if (defined $Store->read_handler and not $Store->has_flag('can_create') and $Store->has_flag('can_read'));
	push @$items, '-' if (defined $Store->read_handler and defined $Store->update_handler and $Store->has_flag('can_read') and $Store->has_flag('can_update'));
	push @$items, $self->save_button if (defined $Store->update_handler and $Store->has_flag('can_update'));
	
	return {
		items => $items
	};
}

#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;

1;