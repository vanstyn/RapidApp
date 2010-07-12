package RapidApp::AppStoreForm;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use Clone;
use Try::Tiny;

use RapidApp::ExtJS::MsgBox;

use RapidApp::JSONFunc;

use Term::ANSIColor qw(:constants);

has 'no_persist'				=> ( is => 'rw',	default => 1 );
has 'reload_on_save' 		=> ( is => 'ro', default => 0 );

has 'formpanel_config'		=> ( is => 'ro', required => 1, isa => 'HashRef' );

has 'read_data_coderef'		=> ( is => 'ro', default => undef );
has 'update_data_coderef'	=> ( is => 'ro', default => undef );
has 'create_data_coderef'	=> ( is => 'ro', default => undef );



has 'item_key' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_key {
	my $self = shift;
	return $self->item_keys unless (ref($self->item_keys) eq 'ARRAY');
	return $self->item_keys->[0];
}


has 'item_keys' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_keys {
	my $self = shift;
	return 'id';
	return $self->parent_module->item_key if (
		defined $self->parent_module and
		defined $self->parent_module->item_key
	);
	return 'id';
}

has 'item_key_val' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_key_val {
	my $self = shift;
	return $self->base_params->{$self->item_key};
}


has 'save_button_text' => ( is => 'ro',	default => ' Save '	);
has 'save_button_iconCls' => ( is => 'ro',	default => 'icon-save'	);

has 'save_button_id' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button_id {
	my $self = shift;
	return 'save-button-' . $self->item_key_val . '-' . time;
}

has 'save_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> $self->save_button_text,
			iconCls	=> $self->save_button_iconCls,
			id 		=> $self->save_button_id,
			disabled => \1,
			style	=> { 
				'margin-left'	=> '2px',
				'margin-right'	=> '2px',
				'font-weight'	=> 'bold',
			},
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function() { ' . $self->form_save_code . '; }' 
			)
	});
}

has 'reload_button_text' => ( is => 'ro',	default => ' Reload '	);
has 'reload_button_iconCls' => ( is => 'ro',	default => 'x-tbar-loading'	);

has 'reload_button_id' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button_id {
	my $self = shift;
	return 'reload-button-' . $self->item_key_val . '-' . time;
}

has 'reload_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> $self->reload_button_text,
			iconCls	=> $self->reload_button_iconCls,
			id 		=> $self->reload_button_id,
			style	=> { 
				'margin-left'	=> '2px',
				'margin-right'	=> '2px',
				'font-weight'	=> 'bold',
			},
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function() { ' . $self->store_load_code . '; }' 
			)
	});
}


has 'base_params'			=> ( is => 'ro', lazy_build => 1 );
sub _build_base_params {
	my $self = shift;
	
	my $params = {};

	my $encoded = $self->c->req->params->{base_params};
	if (defined $encoded) {
		my $decoded = JSON::from_json($encoded) or die "Failed to decode base_params JSON";
		foreach my $k (keys %$decoded) {
			$params->{$k} = $decoded->{$k};
		}
	}
	
	my $keys = [];
	if (ref($self->item_keys) eq 'ARRAY') {
		$keys = $self->item_keys;
	}
	else {
		push @$keys, $self->item_keys;
	}
	
	my $orig_params = {};
	my $orig_params_enc = $self->c->req->params->{orig_params};
	$orig_params = JSON::from_json($orig_params_enc) if (defined $orig_params_enc);
	
	foreach my $key (@$keys) {
		$params->{$key} = $self->c->req->params->{$key} if (defined $self->c->req->params->{$key});
		$params->{$key} = $orig_params->{$key} if (defined $orig_params->{$key});
	}
	
	return $params;anchor => '95%',
}



has 'update_failed_callback' => ( is => 'ro', lazy_build => 1 );
sub _build_update_failed_callback {
	my $self = shift;
	return RapidApp::JSONFunc->new( raw => 1, func =>
		'function(message) { ' .
			RapidApp::ExtJS::MsgBox->new(
				title => 'Update Failed', 
				msg => 'message', 
				style => $self->exception_style
			)->code .
		'}'
	);
}



has 'getStore_code' => ( is => 'ro', lazy_build => 1 );
sub _build_getStore_code {
	my $self = shift;
	return 'Ext.StoreMgr.lookup("' . $self->storeId . '")';
}

has 'actions' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $actions = {};
	
	$actions->{read}				= sub { $self->read } if (defined $self->read_data_coderef);
	$actions->{update}			= sub { $self->update } if (defined $self->update_data_coderef);
	$actions->{create}			= sub { $self->create } if (defined $self->create_data_coderef);
	
	return $actions;
});$actions->{update}			= sub { $self->update } if (defined $self->update_data_coderef);

has 'formpanel_id' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_id {
	my $self = shift;
	return 'storeform-' . time;
}

has 'storeId' => ( is => 'ro', lazy_build => 1 );
sub _build_storeId {
	my $self = shift;
	my $val = $self->item_key_val;
	$val =~ s/\s+/\-/g; # <-- get rid of spaces
	return 'appstoreform-store-' . $val;
}

has 'store_load_code' => ( is => 'ro', lazy_build => 1 );
sub _build_store_load_code {
	my $self = shift;
	return 'Ext.StoreMgr.lookup("' . $self->storeId . '").load()';
}


has 'form_save_code' => ( is => 'ro', lazy_build => 1 );
sub _build_form_save_code {
	my $self = shift;
	return 
		'try {' .
			'var store = ' . $self->getStore_code . ';' .
			'var record = store.getAt(0);' .
			'var form = Ext.getCmp("' . $self->formpanel_id . '").getForm();' .
			#'var params = form.getFieldValues();' .
			'record.beginEdit();' .
			'form.updateRecord(record);' .
			#'for (i in params) {' .
			#	'record.set(i,params[i]);' .
			#'}' .
			'record.endEdit();' . 
			#'record.commit();' .
			
			'store.save();' .
			#'store.commitChanges();' .
		'} catch (err) { Ext.log(err); }';
}


sub JsonStore {
	my $self = shift;
	
	my $config = {
		update_failed_callback => $self->update_failed_callback,
		storeId => $self->storeId,
		autoLoad => \0,
		autoSave => \0,
		loadMask => \1,
		autoDestroy => \1,
		api => {
			read		=> $self->suburl('/read')
		},
		baseParams 	=> $self->base_params,
		listeners	=> {
			load => RapidApp::JSONFunc->new( raw => 1, func =>
				'function(store,records,options) { ' .
					'Ext.log("load event");' . 
					'try {' .
						'var form = Ext.getCmp("' . $self->formpanel_id . '").getForm();' .
						'form.loadRecord(records[0]);' .
					'} catch(err) { Ext.log(err); }' .
				'}'
			),
			update => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(store, record, operation) { ' .
					'Ext.log("update event");' . 
					'Ext.log(operation);' . 
					#'record.commit();' .
				'}' 
			),
			save => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(store, batch, data) { ' .
					'Ext.log("save event");' . 
				'}' 
			),
			write => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(store, action, result, res, rs) { ' .
					'Ext.log("write event");' . 
					($self->reload_on_save ? 'store.load();' : '') .
				'}' 
			),
			exception => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(DataProxy, type, action, options, response, arg) { ' .
					'if (action == "update") {' .
						'var store = ' . $self->getStore_code . ';' .
						'store.rejectChanges();' .
						'store.update_failed_callback(response.message);' .
					'}' .
				'}' 
			)
		}
	};
	
	if (defined $self->actions->{update}) {
		$config->{writer} = RapidApp::JSONFunc->new( 
			func => 'new Ext.data.JsonWriter',
			parm => {
				encode => \1,
				writeAllFields => \1
		});
		$config->{api}->{update} = $self->suburl('/update');
	};
	
	return RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $config
	);
}

sub read {
	my $self = shift;
	
	my $record = $self->fetch_item($self->c->req->params);
	my $fields = [];
	foreach my $k (keys %$record) {
		push @$fields, { name => $k };
	}
	
	return {
		metaData => {
			root => 'rows',
			fields => $fields,
			idProperty => $self->item_key,
			messageProperty => 'msg',
			successProperty => 'success',
			totalProperty => 'results',
		},
		success => \1,
		results => \1,
		rows => [ $record ]
	};
}


sub update {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = JSON::from_json($params->{rows});
	delete $params->{rows};
	
	my $result = $self->update_data_coderef->($rows,$params);
	return $result if (
		ref($result) eq 'HASH' and
		defined $result->{success}
	);
	
	return {
		success => \1,
		msg => 'Update Succeeded'
	} if ($result);
	
	return {
		success => \0,
		msg => 'Update Failed'
	};
}


sub create {
	my $self = shift;
	
	
}

sub content {
	my $self = shift;
	
	my $params = $self->c->req->params;
	delete $params->{_dc};
	
	my $config = Clone::clone($self->formpanel_config);
	
	$config->{id}			= $self->formpanel_id;			
	$config->{xtype} 		= 'form';
	$config->{store}		= $self->JsonStore;
	$config->{trackResetOnLoad} = \1,
	
	$config->{listeners} = {
		clientvalidation => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(FormPanel, valid) { ' .
				'if (valid && FormPanel.getForm().isDirty()) { ' .
					'var button = Ext.getCmp("' . $self->save_button_id . '");' . 
					'button.enable();' .
				'} else {' .
					'var button = Ext.getCmp("' . $self->save_button_id . '");' . 
					'if (!button.disabled) {' .
						'button.disable();' .
					'}' .
				'}' .
			'}'
		),
		afterrender => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(FormPanel) { ' .
				'new Ext.LoadMask(FormPanel.getEl(),{msg: "StoreForm Loading...", store: ' . $self->getStore_code . '});' .
				'try {' . $self->store_load_code . ';' . '} catch(err) { Ext.log(err); }' .
			'}'
		)
	};

	return $config;
}


sub fetch_item {
	my $self = shift;
	
	my $params = $self->c->req->params;
	$params = $self->json->decode($self->c->req->params->{orig_params}) if (defined $self->c->req->params->{orig_params});
	
	my $new = shift;
	$params = $new if ($new);
	
	return $self->read_data_coderef->($params);
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;