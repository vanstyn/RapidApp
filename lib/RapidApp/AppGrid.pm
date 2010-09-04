package RapidApp::AppGrid;
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
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';


use Clone;

our $VERSION = '0.1';

use RapidApp::ExtJS;
use RapidApp::ExtJS::DynGrid;
use RapidApp::ExtJS::CheckTreePanel;
use RapidApp::ExtJS::SubmitForm;
use RapidApp::ExtJS::MsgBox;
use Try::Tiny;

use RapidApp::AppGrid::EditItem;
use RapidApp::AppGrid::AddItem;

use Switch;

use Term::ANSIColor qw(:constants);

#### --------------------- ####


has 'gridid' 							=> ( is => 'ro',	required => 1,		isa => 'Str'					);
has 'storeId'							=> ( is => 'ro',	default => undef );
has 'title' 							=> ( is => 'ro',	default => '',	isa => 'Str'						);
has 'title_icon_href' 				=> ( is => 'ro',	default => '',	isa => 'Str'						);

has 'edit_label' 						=> ( is => 'ro',	default => 'Update',		isa => 'Str'			);
has 'edit_label_iconCls' 			=> ( is => 'ro',	default => 'icon-edit',	isa => 'Str'			);
has 'edit_icon_text' 				=> ( is => 'ro',	default => undef										);
has 'edit_window_title' 			=> ( is => 'ro',	lazy => 1, default => sub { 'Edit ' . (shift)->item_title; } 	);
has 'add_label' 						=> ( is => 'ro',	default => 'Add',			isa => 'Str'			);
has 'add_label_iconCls' 			=> ( is => 'ro',	default => 'icon-add',	isa => 'Str'			);
has 'edit_window_height' 			=> ( is => 'ro',	default => 300											);
has 'edit_window_width' 			=> ( is => 'ro',	default => 400											);
has 'item_title' 						=> ( is => 'ro',	default => 'Item',		isa => 'Str'			);



#### ---
has 'remoteSort'			 			=> ( is => 'ro',	required => 0, default => sub { \0 }				);
has 'gridsearch'			 			=> ( is => 'ro',	required => 0, default => sub { \0 }				);
has 'gridsearch_remote'				=> ( is => 'ro',	required => 0, default => sub { \0 }				);
has 'gridfilter'			 			=> ( is => 'ro',	required => 0, default => sub { \0 }				);
has 'gridfilter_remote'				=> ( is => 'ro',	required => 0, default => sub { \0 }				);
#### ---

has 'ExtJS'								=> ( is => 'ro',	default => sub { RapidApp::ExtJS->new }			);


has 'pageSize' 						=> ( is => 'ro',	default => undef	);


### ---------------  'fields'  --------------- ###
##
##
has 'fields'							=> ( is => 'ro',	required => 1,		isa => 'ArrayRef'				);
##
##
## fields should be an ArrayRef of HashRefs, with each HashRef defining a 'field'
##
## HashRef Api:
##
##
##		'name' (Str):
##						Name of the field. This will be used as the key
##
##		'title' (Str):
##						Friendly name of the field. This will be used in Col headings and
##						labels
##
##		'header' (Str):
##						Same as title?
##
##		'heading' (Str):
##						Special text header to be displayed in the edit form
##
##		'sortable' (Bool; default 1):
##						If false, this field will not be sortable in the grid
##
##		'resizable' (Bool; default 1):
##						If false, the width of this field will not be adjustable in the grid
##
##		'hidden' (Bool):
##						
##
##		'width' (Int):
##						Default/min width of the grid column associated with this field
##
##		'viewable' (Bool):
##						If false, field will not be shown in the grid
##
##		'addable' (Bool):
##						If true, field will be listed on the add form
##
##		'edit_allow' (Bool):
##						If true, this field will be editable in the edit form
##
##		'edit_show' (Bool):
##						If true and edit_allow is false, the field will be shown on the edit
##						form read-only (label instead of text field)
##
##		'checkbox' (Bool):
##						If true, this field will be treated as a boolean and will be a checkbox
##						on the add and edit forms
##
##		'checktree' (Bool):
##						If true, this field will be a complex "check tree"
##
##
##
### ------------------------------------------ ###


####
#### --- coderef methods, should be supplied to the constructor to define the API
####

# datafetch_coderef code should return a ref to an array of hashrefs
has 'datafetch_coderef' 			=> ( is => 'ro',	required => 1,		isa => 'CodeRef'		);

# -- add_item_coderef 
# called upon submitting the add item form; 
# field params are passed into the coderef as a HashRef in the first argument
has 'add_item_coderef' 				=> ( is => 'ro',	default => undef		);

# -- delete_item_coderef
# called upon submitting a delete command for a single item
has 'delete_item_coderef' 			=> ( is => 'ro',	required => 0,		isa => 'CodeRef'		);

# -- edit_item_coderef
# called upon submitting the edit item form
# field params are passed into the coderef as a HashRef in the first argument
has 'edit_item_coderef' 			=> ( is => 'ro',	required => 0,		isa => 'CodeRef'		);

# -- itemfetch_coderef
# Optional custom code used to retrieve an item for display in the edit form
# This coderef will be passed a single argument HashRef representing the data in
# the Ext.data.record from the grid row of the item selected. The coderef should
# return a new HashRef, which will in turn be used to populate the edit form. If
# this coderef is not supplied, the edit form will be populated with the data cached
# in the Ext.data.record from the grid's store
has 'itemfetch_coderef' 			=> ( is => 'ro',	default => undef	);

# -- edit_custom_formfields_coderef
# coderef should return a custom set of fields for display on the edit form
has 'edit_custom_formfields_coderef' 	=> ( is => 'ro',	default => undef	);

# -- delete_allowed_coderef
# Optional coderef called to determine is the user is allowed to delete a given item
has 'delete_allowed_coderef' 		=> ( is => 'ro',	default => undef	);


# -- save_search_coderef
# Optional coderef to allowing saving the "state" (grid filters, columns, sort)
has 'save_search_coderef'	=> ( is => 'ro',	default => undef	);

# -- load_search_coderef
# Optional coderef to load a previously saved "state" (grid filters, columns, sort)
has 'load_search_coderef'	=> ( is => 'ro',	default => undef	);

# -- delete_search_coderef
# Optional coderef to delete a previously saved search by search_id
has 'delete_search_coderef'	=> ( is => 'ro',	default => undef	);

has 'loaded_grid_state' => ( is => 'rw', default => undef );

####
####
####


has 'item_key' 						=> ( is => 'ro',	required => 0,		isa => 'Str'			);

has 'extra_row_actions' 			=> ( is => 'ro',	default => undef	);

has 'add_item_help_html'			=> ( is => 'ro',	default => undef					);
has 'delete_item_confirm_html'	=> ( is => 'ro',	default => undef			);
has 'wrap_edit_window'				=> ( is => 'ro',	required => 0,		default => 0			);
has 'edit_form_validate'			=> ( is => 'ro',	required => 0,		default => 0			);


has 'celldblclick_eval'				=> ( is => 'ro',	default => undef			);



has 'edit_close_on_update'			=> ( is => 'ro',	default => 1											);
has 'dblclick_row_edit'				=> ( is => 'ro',	required => 0,		default => 1					);
has 'dblclick_row_edit_code'		=> ( is => 'ro',	lazy_build => 1										);
has 'row_checkboxes'					=> ( is => 'ro',	required => 0,		default => sub {\0}			);
has 'batch_delete'					=> ( is => 'ro',	required => 0,		default => 0					);

has 'labelAlign'						=> ( is => 'ro',	required => 0,		default => 'left'				);
has 'edit_form_ajax_load'			=> ( is => 'ro',	required => 0,		default => 0					);
has 'custom_edit_form_items'		=> ( is => 'ro',	required => 0,		default => undef				);
has 'custom_add_form_items'		=> ( is => 'ro',	required => 0,		default => undef				);

has 'no_rowactions'					=> ( is => 'ro',	required => 0,		default => 0					);

has 'UseAutoSizeColumns'			=> ( is => 'ro',	required => 0,		default => sub { \1 }			);
has 'MaxColWidth'						=> ( is => 'ro',	required => 0,		default => sub { 300 }		);
has 'enableColumnMove'				=> ( is => 'ro',	required => 0,		default => 0					);



# -- use_parent_tab_wrapper
# If this module's parent module has a tabpanel_load_code defined and this 
# option is on, the edit window will be opened with it instead of the default_action
# window (i.e. loads in a tab of an AppTreeExplorer)
has 'use_parent_tab_wrapper'		=> ( is => 'ro', default => 0 );

has 'edit_action_wrapper_code'	=> ( is => 'ro',	lazy_build => 1 );
has 'custom_add_item_code'			=> ( is => 'ro',	lazy_build => 1 );



has 'edit_record_class' => ( is => 'ro', default => 'RapidApp::AppGrid::EditItem' );
has 'add_record_class' => ( is => 'ro', default => 'RapidApp::AppGrid::AddItem' );

has 'modules' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		item		=> $self->edit_record_class,
		add		=> $self->add_record_class,
	};
});
has 'record_processor_module'	=> ( is => 'ro', default => 'item' );
has 'add_processor_module'	=> ( is => 'ro', default => 'add' );

has 'default_action' => ( is => 'ro', default => 'main' );
has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $actions = {
		'main'												=> sub { $self->JSON_encode($self->DynGrid->Params);		},
		#'action_' . $self->edit_label_iconCls		=> sub { $self->action_icon_edit; 								},
		'action_icon-delete'								=> sub { $self->action_icon_delete;								},
		'action_delete'									=> sub { $self->action_delete;										},
		'batch_delete'										=> sub { $self->batch_delete_submit;								},
		'action_batch_delete'							=> sub { $self->action_batch_delete;								},
		'add_window'										=> sub { $self->add_window;											},
		#'edit_window'										=> sub { $self->edit_window;										},
		#'edit_submitform'									=> sub { $self->JSON_encode($self->edit_submitform);		},
		#'add_submitform'									=> sub { $self->JSON_encode($self->add_submitform);			},
		#'add_submit'										=> sub { $self->JSON_encode($self->add_submit);				},
		#'edit_submit'										=> sub { $self->JSON_encode($self->edit_submit);				},
		'data'												=> sub { $self->JSON_encode($self->grid_rows($self->c->req->params));	},
		'item_form_load'									=> sub { $self->JSON_encode($self->item_form_load);			},
	};
	
	if (defined $self->extra_row_actions) {
		foreach my $h (@{$self->extra_row_actions}) {
			die "extra_row_actions must be a Ref to an Array of HashRefs" unless (ref($h) eq 'HASH');
			next unless (
				defined $h->{iconCls} and
				defined $h->{coderef} and
				ref($h->{coderef}) eq 'CODE' 
			);
			
			$actions->{'action_' . $h->{iconCls}} = sub { $h->{coderef}->($self->c->req->params); };
		}
	}
	
	$actions->{save_search} = sub { $self->action_save_search; } if (defined $self->save_search_coderef);
	$actions->{delete_search} = sub { $self->action_delete_search; } if (defined $self->delete_search_coderef);
	
	return $actions;
});


sub action_save_search {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $grid_state = {};
	$grid_state = $self->json->decode($params->{grid_state});
	my $search_name = $params->{search_name};
	return $self->save_search_coderef->($search_name,$grid_state);
}


sub action_delete_search {
	my $self = shift;
	
	my $params = $self->c->req->params;
	return $self->delete_search_coderef->($params->{search_id});
}



sub save_search_btn {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> 'Save Search',
			iconCls	=> 'icon-save-as',
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(btn) { ' . 
				
					'var default_txt = "";' .
					$self->save_search_default_txt_code .
				
				
					'Ext.MessageBox.prompt("Save Search","Name of Search",function(sel,val){' .
						'if(sel != "ok") return; ' .
						'if(! val || val == "") return; ' .
						'var grid = btn.ownerCt.ownerCt;'.
						'var state = grid.getState();' .
						'var save_state = {' .
							'filters: grid.getFilters(grid).getState()' .
						'};' .
						'for (i in state) save_state[i] = state[i];' .
						'var url = "' . $self->suburl('/save_search') . '";' .
						'var params = {' . 
							'search_name: val' .
						'};' .
						'params["grid_state"] = Ext.util.JSON.encode(save_state);' .
						'Ext.ux.FetchEval(url,params);' .
					'},btn,false,default_txt);' .
				'}' 
			)
	});
}

# This code should be refactored into something more robust:
# gets the tab title to be the default value in the search box
sub save_search_default_txt_code {
	my $self = shift;
	return '' unless ($self->c->req->params->{search_id}); 
	
	return
		'var grid = btn.ownerCt.ownerCt;' .
		'var TabP = grid.findParentByType("tabpanel");' .
		'var activePanel = TabP.getActiveTab();' .
		'default_txt = activePanel.title;'
}





sub delete_search_btn {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> 'Delete Search',
			iconCls	=> 'icon-delete',
			#id 		=> ,
			#scale		=> $self->button_scale,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(btn) { ' . 
				
					'Ext.Msg.show({ title: "Delete Search", msg: "Really Delete Search?", buttons: Ext.Msg.YESNO, fn: function(sel){' .
						'if(sel != "yes") return; ' .
						'var grid = btn.ownerCt.ownerCt;'.
						'var url = "' . $self->suburl('/delete_search') . '";' .
						'var params = {' . 
							'search_id: "' . $self->c->req->params->{search_id} . '"' .
						'};' .
						'Ext.ux.FetchEval(url,params);' .
						'var TabP = grid.findParentByType("tabpanel");' .
						'var activePanel = TabP.getActiveTab();' .
						'TabP.remove(activePanel);' .
						#'grid.ownerCt.close();' .
						#'console.dir(save_state);' .
						#'console.dir(grid.initialConfig);' . 
						#'console.dir(grid.filters.getState())' .
					'},scope: btn});' .
				'}' 
			)
	});
}



has 'edit_tab_title_code' => ( is => 'ro', lazy_build => 1 );
sub _build_edit_tab_title_code {
	my $self = shift;
	return '"' . $self->edit_label . '"';
	#return 'orig_params["' . $self->item_key . '"]'
}



has 'gid' => ( is => 'ro',	lazy => 1,	isa => 'Str', default => sub {
	my $self = shift;
	
	return $self->gridid . '-' . time;
	
	
	my $id = $self->gridid . '_' . $self->base_url;
	$id .= '-' . $self->base_query_string if (defined $self->base_query_string);
	
	$id =~ s/[^\_a-zA-Z0-9]/\_/g;

	return $id;
});

has 'reload_store_eval' => ( is => 'ro',	lazy => 1,	isa => 'Str', default => sub {
	my $self = shift;
	return 'try { Ext.getCmp(\'' . $self->gid . '\').getStore().reload(); } catch (err) {}'
});


has 'fields_hash' => ( is => 'ro', lazy => 1, isa => 'HashRef', default => sub {			
	my $self = shift;
	my $h = {};
	foreach my $field (@{$self->fields}) {
		next unless (defined $field->{name});
		$h->{$field->{name}} = $field;
	}
	return $h;
});



###########################################################################################



sub check_on 		{ '<img src="/static/rapidapp/images/checkmark.png">';				}
sub check_off 		{ '';																		}


sub tbar_items {
	my $self = shift;
	
	my $arrayref = [];
	
	push @{$arrayref}, '<img src="' . $self->title_icon_href . '" />' 		if (defined $self->title_icon_href);
	push @{$arrayref}, '<b>' . $self->title . '</b>'								if (defined $self->title);
	push @{$arrayref}, '-' if ($self->delete_search_coderef or $self->save_search_coderef);
	push @{$arrayref}, $self->delete_search_btn if ($self->delete_search_coderef and $self->c->req->params->{search_id});
	push @{$arrayref}, $self->save_search_btn if ($self->save_search_coderef);
	push @{$arrayref}, '->';
	#push @{$arrayref}, $self->refresh_button;
	push @{$arrayref}, $self->add_button if (defined $self->add_item_coderef);
	
	return $arrayref;
}



sub extract_filters {
	my $self = shift;
	my $field_list = shift;
	
	my $filters = [];
	foreach my $field (@$field_list) {
		next unless ($field->{filter});
		push @$filters, {
			dataIndex	=> $field->{id},
			%{$field->{filter}}
		};
	}
	return $filters;
}


sub DynGrid {

	my $self = shift;
	
	if (defined $self->load_search_coderef and $self->c->req->params->{search_id}) {
		$self->loaded_grid_state($self->load_search_coderef->($self->c->req->params->{search_id}));
	}
	
	my $field_list = $self->grid_fields;
	
	my $config = {
		#data_url					=> $self->suburl('/data'),
		field_list				=> $field_list,
		layout					=> 'fit',
		#reload_interval		=> 10000,
		stripeRows				=> 1,
		columnLines				=> 1,
		gridid 					=> $self->gid,
		border					=> 0,
		bodyBorder 				=> 0,
		id							=> $self->gid,
		UseAutoSizeColumns	=> $self->UseAutoSizeColumns,
		MaxColWidth				=> $self->MaxColWidth,
		#enableHdMenu			=> 0,
		enableColumnMove		=> $self->enableColumnMove,
		tbar						=> { items => $self->tbar_items },
		viewConfig				=> { forceFit => 0, enableRowBody => \1 },
		#remoteSort				=> $self->remoteSort,
		gridsearch				=> $self->gridsearch,
		gridsearch_remote		=> $self->gridsearch_remote,
		gridfilter				=> $self->gridfilter,
		gridfilter_remote		=> $self->gridfilter_remote,
		rowactions				=> $self->rowactions,
		row_checkboxes			=> $self->row_checkboxes
	};
	
	$config->{pageSize} = $self->pageSize if (defined $self->pageSize);
	$config->{paging_bbar} = [ 'Selection: ', $self->delete_items_button, '-' ] if ($self->batch_delete);
	
	$config->{celldblclick_eval} = $self->dblclick_row_edit_code if ($self->dblclick_row_edit);
	$config->{celldblclick_eval} = $self->celldblclick_eval if (defined $self->celldblclick_eval);

	$config->{store_config} = {
		storeId			=> $self->storeId,
		url				=> $self->suburl('/data'),
		root				=> 'rows',
		totalProperty	=> 'totalCount',
		autoDestroy		=> \1,
		remoteSort		=> $self->remoteSort,
	};
	
	$config->{init_state} = $self->loaded_grid_state if ($self->loaded_grid_state and $self->c->req->params->{search_id});

	#$config->{init_filters} = $self->extract_filters($field_list);

	my $DynGrid = RapidApp::ExtJS::DynGrid->new($config);
	return $DynGrid;
}


sub add_button {
	my $self = shift;

	return undef unless (defined $self->add_item_coderef);
	
	my $urlspec = {
		id			=> 'add-item-' . time,
		title		=> $self->add_label,
		iconCls	=> $self->add_label_iconCls,
		url 		=> $self->suburl('/' . $self->add_processor_module),
		params	=> {
			base_params => $self->json->encode($self->base_params),
		}
	};
	
	my $code = 
		"var urlspec = " . $self->json->encode($urlspec) . ";" . 
		$self->parent_module->tabpanel_load_code('urlspec');

	return {
		xtype				=> 'dbutton',
		text				=> $self->add_label,
		iconCls			=> $self->add_label_iconCls,
		handler_func	=> $code
#		handler_func	=> 
#			"var urlspec = {};" .
#			"urlspec['url'] = '" . $self->suburl('/add_submitform') . "';" .
#			$self->custom_add_item_code	
	};
}


sub _build_custom_add_item_code {
	my $self = shift;
	return
		"urlspec = '" . $self->suburl('/add_window') . "';" . 
		q~Ext.ux.FetchEval(urlspec);~
}




sub _build_dblclick_row_edit_code {
	my $self = shift;
	
	my $urlspec = {
		url 		=> $self->suburl('/' . $self->record_processor_module),
		params	=> {
			base_params => $self->json->encode($self->base_params),
			orig_params => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.util.JSON.encode(record.data)' )
		}
	};
	
	return 
		"var urlspec = " . $self->json->encode($urlspec) . ";" . 
		$self->edit_action_wrapper_code;
	
}

sub _build_edit_action_wrapper_code {
	my $self = shift;
	
	my $code;
	
	if ($self->use_parent_tab_wrapper and defined $self->parent_module) {
		my $tabcode = $self->parent_module->tabpanel_load_code('urlspec');
		if (defined $tabcode) {
			
			$code = 
				'var orig_params = Ext.util.JSON.decode(urlspec["params"]["orig_params"]);' .
				'urlspec["id"] = "edit-' . $self->gridid . '-" + orig_params["' . $self->item_key . '"];' . 
				'urlspec["title"] = ' . $self->edit_tab_title_code . ';' . 
				'urlspec["iconCls"] = "' . $self->edit_label_iconCls . '";' . $tabcode;
			
		}
	}
	else {
	
		$code = 
			'urlspec["url"] = "' . $self->base_url . '/edit_window";' .
			"Ext.ux.FetchEval(urlspec['url'],urlspec['params']);";
	}
	
	return $code;
}



#sub rowaction_code {
#	my $self = shift;
#	return 
#		"var params = {orig_params: Ext.util.JSON.encode(record.data)};" .
#		"Ext.ux.FetchEval('" . $self->base_url . "/action_' + action + '?" . $self->base_query_string . "',params);"
#}




#sub action_icon_edit { (shift)->edit_window; }
#sub action_icon_edit { 
#	my $self = shift;
#	
#	
#	my $code = 
#		"var urlspec = " . $self->edit_action_urlspec_code . ";" . 
#		$self->edit_action_wrapper_code;
#		
#	return $code;
#}
#
#sub edit_action_urlspec_code {
#	my $self = shift;
#	my $urlspec = {
#		#url 		=> $self->base_url . '/edit_window',
#		url 		=> $self->base_url . '/edit_submitform',
#		params	=> $self->c->req->params
#	};
#	
#	$urlspec->{url} = $self->suburl('/' . $self->record_processor_module) if ($self->record_processor_module);
#	
#	return $self->json->encode($urlspec);
#}




sub rowactions {
	my $self = shift;
	
	return {} if ($self->no_rowactions);
	
	my $ra = {};
	
	$ra = {
		header => 'Actions',
		keepSelection => 1,
		#callback_eval => q~alert(Ext.util.JSON.encode(action));~,
		callback_eval => $self->rowaction_code,
		actions => []
	} if (defined $self->delete_item_coderef or defined $self->edit_item_coderef);
	
	push @{$ra->{actions}}, {
		iconCls		=> $self->edit_label_iconCls,
		tooltip 		=> 'edit',
		text			=> $self->edit_icon_text,
	} if (defined $self->edit_item_coderef);
	
	push @{$ra->{actions}}, {
		iconCls => 'icon-delete',
		tooltip => 'delete',
	} if (defined $self->delete_item_coderef);
	
	if (defined $self->extra_row_actions) {
		foreach my $h (@{$self->extra_row_actions}) {
			die "extra_row_actions must be a Ref to an Array of HashRefs" unless (ref($h) eq 'HASH');
			my $cfg = {};
			$cfg->{iconCls} = $h->{iconCls} if (defined $h->{iconCls});
			$cfg->{tooltip} = $h->{tooltip} if (defined $h->{tooltip});
			push @{$ra->{actions}},$cfg;
		}
	}

	return $ra;
}



sub grid_rows {
	my $self = shift;
	my $params = shift;
	
	my $data = {};
	my $arrayref = [];
	my $ref = $self->datafetch_coderef->($params);
	if (ref($ref) eq 'HASH') {
		$arrayref = $ref->{rows};
		$data->{totalCount} = $ref->{totalCount};
	}
	else {
		$arrayref = $ref;
	}
	
	die "Fatal error: datafetch_coderef did not return an arrayref" unless (ref($arrayref) eq 'ARRAY');
	
	my $DynGrid = $self->DynGrid;
	
	foreach my $gridrow (@{$arrayref}) {
		$self->filter_gridrow($gridrow);
		$DynGrid->grid_rows($gridrow);
	}
		
	$data->{rows} = $DynGrid->grid_rows;
	
	return $data;
}


sub filter_gridrow {
	my $self = shift;
	my $gridrow = shift or return undef;
	
	foreach my $f (keys %{$gridrow}) {
		if (defined $self->fields_hash->{$f} and $self->fields_hash->{$f}->{checkbox}) {
			if ($gridrow->{$f}) {
				#$gridrow->{$f} = $self->check_on;
				$gridrow->{$f} = 1;
			}
			else {
				#$gridrow->{$f} = '';
				$gridrow->{$f} = 0;
			}
		}
	}
}



sub grid_fields {  # <-- column model
	my $self = shift;
	
	my @list = ();
	
	my $loaded_filters = {};
	$loaded_filters = $self->loaded_grid_state->{filters} if (
		defined $self->loaded_grid_state and
		defined $self->loaded_grid_state->{filters}
	);
		

	foreach my $field (@{$self->fields}) {
		next if (defined $field->{viewable} and $field->{viewable} == 0);
		
		$field->{filterable} = \1;
		
		unless (defined $field->{filter}) {
		
			$field->{data_type} = 'string' unless (defined $field->{data_type});
			$field->{filter} = { type => $field->{data_type} };
			
			$field->{filter} = { type => 'list', options => $field->{enum_list} } if (
				defined $field->{enum_list} and 
				ref($field->{enum_list}) eq 'ARRAY'
			);
			
			if ($field->{checkbox}) {
				$field->{filter} = { type => 'boolean' };
				
				$field->{xtype} = 'templatecolumn';
				$field->{tpl} = [ # <-- Ext.XTemplate string definition
					q~<tpl if="~ . $field->{name} . q~ != 0">~ ,
						$self->check_on ,
					'</tpl>',
					'<tpl if="' . $field->{name} . ' == 0">',
						'',
					'</tpl>'
				];
			}
			
			
			
			
			
		}
		
		# -- Custom Render Function, using XTemplate:
		if (defined $field->{render_fn}) {
			$field->{xtype} = 'templatecolumn';
			$field->{tpl} = '{[' . $field->{render_fn} . '(values.' . $field->{name} . ')]}';
		}
		# --
		
		push @list, $field;
	}
	
	#use Data::Dumper;
	#print STDERR BOLD . CYAN . Dumper(\@list) . CLEAR;
	
	
	return \@list;
}

######## "set field" methods ##########


sub set_field_heading {
	my $self = shift;
	my $field = shift or return undef;
	
	$field->{xtype} = 'panel';
	
	#$field->{collapsible} = \1;
	#$field->{animCollapse} = \0;
	#$field->{titleCollapse} = \1;
	#$field->{hideCollapseTool} = \1;
	
	$field->{edit_show} = 1;
	$field->{edit_allow} = 1;
	$field->{baseCls} = 'form-group',
}



sub set_field_checktree {
	my $self = shift;
	my $field = shift or return undef;
	my $tree = shift or return undef;
	
	my $CheckTree = RapidApp::ExtJS::CheckTreePanel->new($field);
	$CheckTree->add_child($tree);
	
	#$field = Clone::clone($CheckTree->Config);
	$field = $CheckTree->Config;

	return $field;
}


sub set_field_combo {
	my $self = shift;
	my $field = shift or return undef;
	
	my $d = [];
	foreach my $i (@{$field->{enum_list}}) {
		push @{$d},[$i];
	}
	
	$field->{xtype} = 'combo';
	$field->{store} = {
		xtype		=> 'arraystore',
		fields	=> [ $field->{name} ],
		data		=> $d
	};
	$field->{displayField} = $field->{name};
	$field->{typeAhead} = 1;
	$field->{mode} = 'local';
	$field->{triggerAction} = 'all';
	$field->{selectOnFocus} = 1;
	$field->{editable} = 0;
}

sub set_field_checkbox {
	my $self = shift;
	my $field = shift or return undef;
	
	$field->{xtype} = 'xcheckbox';
	$field->{checked} = 0;
	$field->{checked} = 1 if ($field->{value});

	
	#$field->{boxLabel} = 'My string next to checkbox';
}



sub displayfield {
	my $self = shift;
	my $field = shift;

	# Create a new field to display this field's value
	my $display_field = {};
	$display_field->{name} = $field->{name} . '__display';
	$display_field->{value} = $field->{value} if (defined $field->{value});
	$display_field->{fieldLabel} = $field->{fieldLabel};
	$display_field->{xtype} = 'displayfield';
	
	if ($field->{checkbox}) {
		$display_field->{value} = $self->check_off;
		$display_field->{value} = $self->check_on if ($field->{value});
	}
	
	return $display_field;
}



#######################################

####################################################
=pod
sub add_fields_list {
	my $self = shift;
	
	my @list = ();
	
	foreach my $field (@{$self->fields}) {
		next unless ($field->{addable});
		$self->set_field_heading($field) if ($field->{heading});
		
		my $new_field = Clone::clone($field);
		
		$new_field->{anchor} = '95%' unless (defined $new_field->{anchor});
		
		$new_field->{fieldLabel} = $new_field->{header} unless (defined $new_field->{fieldLabel});
		delete $new_field->{width} if (defined $new_field->{width});
		
		$self->set_field_combo($new_field) if (
			defined $new_field->{enum_list} and 
			ref($new_field->{enum_list}) eq 'ARRAY'
		);
		
		$self->set_field_checkbox($new_field) if ($new_field->{checkbox});
		
		push @list, $new_field;
	}
	return @list;
}


sub item_form_fields {
	my $self = shift;
	my $params = shift;

	$params = $self->itemfetch_coderef->($params) if (
		defined $self->itemfetch_coderef and
		not $self->edit_form_ajax_load
	);

	my @list = ();

	foreach my $field (@{$self->fields}) {
		next unless ($field->{edit_allow} or $field->{edit_show});
		my $new_field = Clone::clone($field);
		
		$new_field->{anchor} = '95%' unless (defined $new_field->{anchor});
		
		if ($new_field->{heading}) {
			$self->set_field_heading($new_field);
			push @list, $new_field;
			next;
		}

		$new_field->{hidden} = 0;
		
		$new_field->{fieldLabel} = $new_field->{header} unless (defined $new_field->{fieldLabel});
		$new_field->{fieldLabel} = $new_field->{name} unless (defined $new_field->{fieldLabel});
		
		if ($field->{edit_show} and not $field->{edit_allow}) {
			$new_field->{readOnly} = 1;
			my @style = (
				'background-color: transparent;',
				'border-color: transparent;',
				'background-image: none;'
			);
			$new_field->{style} = join('',@style);
		}
		
		unless (defined $new_field->{viewable} and not $new_field->{viewable}) {
			$new_field->{value} = $params->{$new_field->{name}} if (
				defined $params->{$new_field->{name}} and
				not $self->edit_form_ajax_load
			);
		}
		
		$self->set_field_combo($new_field) if (
			defined $new_field->{enum_list} and 
			ref($new_field->{enum_list}) eq 'ARRAY'
		);
	
		$self->set_field_checkbox($new_field) if ($new_field->{checkbox});
		
		if ($new_field->{checktree} and defined $params->{$new_field->{name}}) {
			my $newer_field = $self->set_field_checktree($new_field,$params->{$new_field->{name}});
			$new_field = $newer_field;
		}
		
		push @list, $new_field;
	}

	return @list;
}






sub add_edit_base_config {
	my $self = shift;

	my $config = {
		close_first	=> 1,
		height		=> $self->edit_window_height,
		width			=> $self->edit_window_width,
		layout		=> 'fit',
		#items			=> $self->add_edit_base_submitform
	};
	
	return $config;
}


sub add_edit_base_submitform {

	my $self = shift;
	
	my $id = $self->gid . '-sform-' . time;

	my $config = {
		do_action			=> 'jsonsubmit',
		id						=> $id,
		labelAlign			=> $self->labelAlign,
		onFail_eval			=> RapidApp::ExtJS::MsgBox->new(title => 'Error', msg => 'action.result.msg', style => $self->exception_style)->code,
		defaults				=> { xtype => 'textfield' },
		items => [],
	};
	
	foreach my $k (keys %{ $self->base_params }) {
		push @{$config->{items}}, {
			xtype			=> 'hidden',
			name			=> $k,
			value			=> $self->base_params->{$k},
		};
	}

	return $config;
}



sub add_submitform {
	my $self = shift;
	my $window_name = shift;
	
	my $config = $self->add_edit_base_submitform;
	
	$config->{url}						= $self->suburl('/add_submit');
	$config->{after_save_code}		= $self->reload_store_eval;
	$config->{close_on_success}	= 1;
	$config->{submit_btn_text} 	= $self->add_label;
	$config->{submit_btn_iconCls}	= $self->add_label_iconCls;
	
	unshift @{$config->{items}}, {
		xtype	=> 'box',
		html	=> '<center><div style="font-size:175%;margin-bottom:25px;">Fill out this form to add a new ' . $self->item_title . ':</div></center>'
	};
	
	push @{$config->{items}}, $self->add_fields_list;
	
	$config->{extra_buttons} = [{
		xtype				=> 'dbutton',
		text				=> 'Help',
		iconCls			=> 'icon-help',
		handler_func	=> q~new Ext.Window({iconCls: 'icon-help', autoScroll: true, height: 400, width: 350, html: '~ . $self->add_item_help_html . q~'}).show()~
	}] if (defined $self->add_item_help_html);
	
	$config->{items} = $self->custom_add_form_items if (defined $self->custom_add_form_items);

	return RapidApp::ExtJS::SubmitForm->new($config)->Config;
}




sub add_window_config {
	my $self = shift;
	
	my $window_name = $self->gid . '_add_window';
	
	my $config = $self->add_edit_base_config;
	
	$config->{name} 				= $window_name;
	$config->{title}				= $self->add_label;
	$config->{iconCls}			= $self->add_label_iconCls;
	$config->{items}				= $self->add_submitform;

	return $config;
}


sub edit_submitform {
	my $self = shift;
	
	my $params = JSON::decode_json($self->c->req->params->{orig_params});
	my $orig_params = $self->c->req->params;
	$orig_params->{orig_params} = $params;
	
	my $config = $self->add_edit_base_submitform;
	$config->{base_params} = { orig_params => JSON::to_json($orig_params) };
	
	my $id = $config->{id};

	$config->{url}						= $self->suburl('/edit_submit');
	$config->{after_save_code}		= $self->reload_store_eval;
	$config->{close_on_success}	= 1 if ($self->edit_close_on_update);
	$config->{submit_btn_text} 	= $self->edit_label;
	$config->{submit_btn_iconCls}	= $self->edit_label_iconCls;
	$config->{monitorValid}			= 1 if ($self->edit_form_validate);
	
	unshift @{$config->{items}}, {
		xtype			=> 'box',
		html			=> '<center><div style="font-size:175%;margin-bottom:20px;">' . $self->edit_window_title . ':</div></center>'
	};
	
	#push @{$config->{items}}, $self->edit_fields_list($params);
	
	push @{$config->{items}}, $self->item_form_fields($params);
	push @{$config->{items}}, $self->edit_custom_formfields_coderef->($params) if (defined $self->edit_custom_formfields_coderef);

	
	$config->{action_load} = {
		url		=> $self->suburl('/item_form_load'),
		params	=> $params
	} if ($self->edit_form_ajax_load and ref($self->itemfetch_coderef) eq 'CODE');
	
	$config->{items} = $self->custom_edit_form_items if (defined $self->custom_edit_form_items);

	return RapidApp::ExtJS::SubmitForm->new($config)->Config;
}


sub edit_window_config {
	my $self = shift;
	my $params = shift;
	
	my $config = $self->add_edit_base_config;
	
	$config->{title}			= $self->edit_window_title;
	$config->{iconCls}		= $self->edit_label_iconCls;
	$config->{items}			= $self->edit_submitform;
	
	return $config;
}



sub edit_window {
	my $self = shift;
	
	return $self->ExtJS->Window_code($self->edit_window_config);
}


sub add_window {
	my $self = shift;
	my $params = shift;
	
	return $self->ExtJS->Window_code($self->add_window_config);
}


sub add_submit {
	my $self = shift;

	my $h = {};
	
	try {
	
		my $json_params = $self->c->req->params->{json_params};
		my $params = JSON::decode_json($json_params);
	
		my $hash = $self->add_item_coderef->($self->process_submit_params($params));
		$h = $hash if (ref($hash) eq 'HASH');
	}
	catch {
		$h->{success} = 0;
		$h->{msg} = "$_";
		chomp $h->{msg};
	};
	
	$h->{success} = 0 unless (defined $h->{success});
	$h->{msg} = 'Add failed - unknown error' unless (defined $h->{msg});

	return $h;
}



sub edit_submit {
	my $self = shift;

	my $h = {};
	
	try {
	
		my $orig_json = $self->c->req->params->{orig_params};
		my $orig_params = JSON::from_json($orig_json);
	
		my $json_params = $self->c->req->params->{json_params};
		my $params = JSON::decode_json($json_params);
	
		my $hash = $self->edit_item_coderef->($self->process_submit_params($params),$orig_params);
		$h = $hash if (ref($hash) eq 'HASH');
	}
	catch {
		$h->{success} = 0;
		$h->{msg} = "$_";
		chomp $h->{msg};
	};
	
	$h->{success} = 0 unless (defined $h->{success});
	$h->{msg} = 'Update failed - unknown error' unless (defined $h->{msg});

	return $h;
}



sub item_form_load {
	my $self = shift;
	
	my $params = $self->c->req->params;
	
	my $data = {};
	$data = $self->itemfetch_coderef->($params) if (ref($self->itemfetch_coderef) eq 'CODE');
	
	return {
		success	=> 1,
		data		=> $data
	};
}
=cut


####################################################


## Batch deletes
sub delete_items_button {
	my $self = shift;

	return undef unless (defined $self->batch_delete);

	return {
		xtype				=> 'dbutton',
		text				=> 'delete',
		iconCls			=> 'icon-bullet_delete',
		handler_func	=> 
			q~var grid = Ext.getCmp('~ . $self->gid . q~');~ .
			q~var selmod = grid.getSelectionModel();~ .
			q~var records = selmod.getSelections();~ .
			q~if(records.length > 0) {~ .
				q~var grid_rows_params = [];~ .
				q~Ext.each(records, function(r) { ~ .
					q~grid_rows_params.push(r.data);~ .
				q~});~ .
				q~var sel_records = Ext.util.JSON.encode(grid_rows_params);~ .
				q~var params = {grid_rows_params: sel_records};~ .
				q~var url = "~ . $self->base_url . q~/batch_delete?~ . $self->base_query_string . q~";~ .
				q~Ext.ux.FetchEval(url,params);~ .
			q~}~
	};
}


sub batch_delete_submit {
	my $self = shift;
	return $self->batch_delete_confirm_window(JSON::decode_json($self->c->req->params->{grid_rows_params}));
}

sub batch_delete_confirm_window {
	my $self = shift;
	my $params_list = shift;
	
	my $msg;
	if (defined $self->delete_allowed_coderef) {
		foreach my $params (@$params_list) {
			unless ($self->delete_allowed_coderef->($params,\$msg)) {
				$msg = 'You are not allowed to delete one more more selected items' unless (defined $msg);
				return
					q~Ext.Msg.show({~ .
						q~title: 'Permission denied',~ .
						q~msg: '~ . $msg . q~',~ .
						q~buttons: Ext.Msg.OK,~ .
						q~icon: Ext.MessageBox.WARNING~ .
					q~});~;
			}
		}
	}
	
	my $delete_msg = q~<br>Really delete ~ . scalar(@$params_list) . q~ selected ~ . $self->item_title . q~ items?<br><br>~;
	$delete_msg .= $self->delete_item_confirm_html if (defined $self->delete_item_confirm_html);
	
	return
		q~Ext.Msg.show({~ .
			q~title: 'Confirm delete',~ .
			q~msg: '~ . $delete_msg . q~',~ .
			q~buttons: Ext.Msg.YESNO,~ .
			q~icon: Ext.MessageBox.QUESTION,~ .
			q~fn: function(buttonId) { if (buttonId=="yes") {~ .
				q~var params = ~ . JSON::to_json($self->c->req->body_params) . q~;~ .
				q~Ext.ux.FetchEval('~ . $self->base_url . q~/action_batch_delete?~ . $self->base_query_string . q~',params);~ .
			q~}}~ .
		q~});~;
}

sub action_batch_delete {
	my $self = shift;
	
	my $code = '';
	try {
		my $params_list = JSON::decode_json($self->c->req->params->{grid_rows_params});
		foreach my $params (@$params_list) {
			my $h = $self->delete_item_coderef->($params);
			next if (ref($h) eq '' and $h); # <-- if the delete_item_coderef just returned true (non-ref)...
			if (ref($h) eq 'HASH') {
				unless ($h->{success}) {
					$h->{msg} = '' unless (defined $h->{msg});
					$h->{msg} =~ s/\r?\n/_/g;
					$code = q~var data = ~ . JSON::to_json([$h->{msg}]) . q~;~;
					$code .= q~Ext.Msg.alert('Failed to delete item...',data[0]);~;
					last;
				}
			}
			else {
				die "Invalid response returned from server; batch delete aborted.";
			}
		}
	}
	catch {
		my $msg = $_;
		chomp $msg;
		
		$code = q~var caught = ~ . JSON::to_json({msg => $msg}) . ';' .
			q~Ext.Msg.alert('Delete failed...','<br><div style="~ . $self->exception_style . q~">' + caught['msg'] + '</div>');~;
	};

	return $code . $self->reload_store_eval;
}
##



## Single item rowaction delete:
sub action_icon_delete {
	my $self = shift;
	return $self->delete_confirm_window(JSON::decode_json($self->c->req->params->{orig_params}));
}

sub delete_confirm_window {
	my $self = shift;
	my $params = shift;
	
	my $msg;
	if (defined $self->delete_allowed_coderef and not $self->delete_allowed_coderef->($params,\$msg)) {
		$msg = 'You are not allowed to delete this item' unless (defined $msg);
	
		return
			q~Ext.Msg.show({~ .
				q~title: 'Permission denied',~ .
				q~msg: '~ . $msg . q~',~ .
				q~buttons: Ext.Msg.OK,~ .
				q~icon: Ext.MessageBox.WARNING~ .
			q~});~;
	}
	
	my $delete_msg = q~<br>Really delete ~ . $self->item_title . ' ' . $params->{$self->item_key} . q~ ?<br><br>~;
	$delete_msg .= $self->delete_item_confirm_html if (defined $self->delete_item_confirm_html);
	
	return
		q~Ext.Msg.show({~ .
			q~title: 'Confirm delete',~ .
			q~msg: '~ . $delete_msg . q~',~ .
			q~buttons: Ext.Msg.YESNO,~ .
			q~icon: Ext.MessageBox.QUESTION,~ .
			q~fn: function(buttonId) { if (buttonId=="yes") {~ .
				q~var params = ~ . JSON::to_json($self->c->req->body_params) . q~;~ .
				q~Ext.ux.FetchEval('~ . $self->base_url . q~/action_delete?~ . $self->base_query_string . q~',params);~ .
			q~}}~ .
		q~});~;
}

sub action_delete {
	my $self = shift;
	
	my $code = '';
	try {
		my $h = $self->delete_item_coderef->(JSON::decode_json($self->c->req->params->{orig_params}));
		if (ref($h) eq 'HASH' and defined $h->{success} and defined $h->{msg}) {
			unless ($h->{success}) {
				$h->{msg} =~ s/\r?\n/_/g;
				$code = q~var data = ~ . JSON::to_json([$h->{msg}]) . q~;~;
				$code .= q~Ext.Msg.alert('Failed to delete item...',data[0]);~;
			}
		}
	}
	catch {
		my $msg = $_;
		chomp $msg;
		
		$code = q~var caught = ~ . JSON::to_json({msg => $msg}) . ';' .
			q~Ext.Msg.alert('Delete failed...','<br><div style="~ . $self->exception_style . q~">' + caught['msg'] + '</div>');~;
	};

	return $code . $self->reload_store_eval;
}
##





sub process_submit_params {
	my $self = shift;
	my $params = shift;
	
	foreach my $k (keys %{$params}) {
		if (defined $self->fields_hash->{$k} and $self->fields_hash->{$k}->{checkbox}) {
			if ($params->{$k} eq 'false' or $params->{$k} eq '' or not $params->{$k}) {
				$params->{$k} = 0;
			}
			else {
				$params->{$k} = 1;
			}
		}
	}
	return $params;
}






no Moose;
#__PACKAGE__->meta->make_immutable;
1;