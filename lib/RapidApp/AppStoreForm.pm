package RapidApp::AppStoreForm;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::AppBase';

use Clone;
use Try::Tiny;

use RapidApp::ExtJS::MsgBox;

use RapidApp::JSONFunc;

use String::Random;

use Term::ANSIColor qw(:constants);

has 'no_persist'				=> ( is => 'rw',	default => 1 );
has 'reload_on_save' 		=> ( is => 'ro', default => 0 );

has 'formpanel_config'		=> ( is => 'ro', required => 1, isa => 'HashRef' );

has 'read_data_coderef'		=> ( is => 'ro', default => undef );
has 'update_data_coderef'	=> ( is => 'ro', default => undef );
has 'create_data_coderef'	=> ( is => 'ro', default => undef );

has 'create_record_msg'		=> ( is => 'ro', default => 'Record added' );
has 'create_callback_code'	=> ( is => 'ro', default => '' ); # <-- JS code that gets called when a record is created (added)
has 'write_callback_code'	=> ( is => 'ro', default => '' ); # <-- JS code that gets called when any store write happens (including create)



sub BUILD {
	my $self = shift;
	
	$self->apply_actions( read => 'read' );
	$self->apply_actions( update => 'update' ) if (defined $self->update_data_coderef);
	$self->apply_actions( create => 'create' ) if (defined $self->create_data_coderef);
}




has 'item_key' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_key {
	my $self = shift;
	my $key;
	$key = $self->item_keys->[0] if (defined $self->item_keys and ref($self->item_keys) eq 'ARRAY');
	$key = $self->item_keys if (not defined $key and defined $self->item_keys);
	$key = 'id' unless (defined $key);
	return $key;
}


has 'item_keys' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_keys {
	my $self = shift;
	
	# Compat with AppGrid:
	return $self->parent_module->item_keys if (
		defined $self->parent_module and
		$self->parent_module->can('item_keys')
	);
	
	# Compat with AppGrid2:
	return $self->parent_module->record_pk if (
		defined $self->parent_module and
		$self->parent_module->can('record_pk')
	);
}

has 'item_key_val' => ( is => 'ro',	lazy_build => 1	);
sub _build_item_key_val {
	my $self = shift;
	return $self->base_params->{$self->item_key} ? $self->base_params->{$self->item_key} : 'item';
}



############# Buttons #################
has 'button_text_cls' => ( is => 'ro', default => 'tbar-button-medium' );
has 'button_scale' => ( is => 'ro',	default => 'medium'	);

has 'reload_button_text' => ( is => 'ro',	default => ' Reload '	);
#has 'reload_button_iconCls' => ( is => 'ro',	default => 'x-tbar-loading'	);
has 'reload_button_iconCls' => ( is => 'ro',	default => 'ra-icon-refresh-24x24'	);
has 'reload_button_id' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button_id {
	my $self = shift;
	return $self->formpanel_id . '-reload-btn';
	#return 'reload-button-' . $self->item_key_val . '-' . time;
}
has 'reload_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_reload_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->reload_button_text . '</div>',
			iconCls	=> $self->reload_button_iconCls,
			id 		=> $self->reload_button_id,
			scale		=> $self->button_scale,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function() { ' . $self->store_load_code . '; }' 
			)
	});
}

has 'save_button_text' => ( is => 'ro',	default => ' Save '	);
has 'save_button_iconCls' => ( is => 'ro',	default => 'ra-icon-save-24x24'	);
has 'save_button_id' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button_id {
	my $self = shift;
	return $self->formpanel_id . '-save-btn';
	#return 'save-button-' . $self->item_key_val . '-' . time;
}
has 'save_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_save_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->save_button_text . '</div>',
			iconCls	=> $self->save_button_iconCls,
			id 		=> $self->save_button_id,
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(b) { b.disable(); ' . $self->form_save_code . '; }' 
			)
	});
}


has 'add_button_text' => ( is => 'ro',	default => ' Add '	);
has 'add_button_iconCls' => ( is => 'ro',	default => 'ra-icon-save-ok-24x24'	);
has 'add_button_id' => ( is => 'ro',	lazy_build => 1	);
sub _build_add_button_id {
	my $self = shift;
	return $self->formpanel_id . '-add-btn';
	#return 'add-button-' . $self->item_key_val . '-' . time;
}
has 'add_button' => ( is => 'ro',	lazy_build => 1	);
sub _build_add_button {
	my $self = shift;
	return RapidApp::JSONFunc->new(
		func => 'new Ext.Button', 
		parm => {
			text 		=> '<div class="' . $self->button_text_cls . '">' . $self->add_button_text . '</div>',
			iconCls	=> $self->add_button_iconCls,
			id 		=> $self->add_button_id,
			scale		=> $self->button_scale,
			disabledClass => 'item-disabled',
			disabled => \1,
			handler 	=> RapidApp::JSONFunc->new( 
				raw => 1, 
				func => 'function(b) { b.disable(); ' . $self->form_add_code . '; }' 
			)
	});
}
###############################################



has 'base_params'			=> ( is => 'ro', lazy_build => 1 );
sub _build_base_params {
	my $self = shift;
	
	my $params = {};

	my $encoded = $self->c->req->params->{base_params};
	if (defined $encoded) {
		my $decoded = RapidApp::JSON::MixedEncoder::decode_json($encoded) or die "Failed to decode base_params JSON";
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
	$orig_params = RapidApp::JSON::MixedEncoder::decode_json($orig_params_enc) if (defined $orig_params_enc);
	
	foreach my $key (@$keys) {
		$params->{$key} = $orig_params->{$key} if (defined $orig_params->{$key});
		$params->{$key} = $self->c->req->params->{$key} if (defined $self->c->req->params->{$key});
	}
	
	return $params;
}




has 'exception_callback' => ( is => 'ro', lazy_build => 1 );
sub _build_exception_callback {
	my $self = shift;
	return RapidApp::JSONFunc->new( raw => 1, func =>
		'function(DataProxy, type, action, options, response, arg) { ' .
			RapidApp::ExtJS::MsgBox->new(
				title => "ExtJS JsonStore Exception - action: ' + action + ', type: ' + type + '", 
				msg => 'Ext.util.JSON.decode(response.responseText).msg', 
				style => $self->exception_style
			)->code .
		'}'
	);
}


has 'write_callback' => ( is => 'ro', lazy_build => 1 );
sub _build_write_callback {
	my $self = shift;
	return RapidApp::JSONFunc->new( raw => 1, func =>
		'function(store,action,result,res,rs) { ' .
			'if (action == "create") store.create_callback.apply(this,arguments);' . # <-- real js callback style
			$self->write_callback_code . # <-- optional extra raw callback code
		'}'
	);
}


has 'create_callback' => ( is => 'ro', lazy_build => 1 );
sub _build_create_callback {
	my $self = shift;
	return RapidApp::JSONFunc->new( raw => 1, func =>
		'function(store,action,result,res,rs) { ' .
			#'console.dir(res);' . 
			RapidApp::ExtJS::MsgBox->new(
					title => "Success", 
					msg => '"' . $self->create_record_msg . '"', 
					style => "color: green; font-weight: bolder;"
				)->code .
			$self->create_callback_code . # <-- optional extra raw callback code
		'}'
	);
}




has 'formpanel_id' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_id {
	my $self = shift;
	return 'storeform-' . String::Random->new->randregex('[a-z0-9A-Z]{5}');
}

has 'storeId' => ( is => 'ro', lazy_build => 1 );
sub _build_storeId {
	my $self = shift;
	return $self->formpanel_id . '-store';
	#my $val = $self->item_key_val;
	#$val =~ s/\s+/\-/g; # <-- get rid of spaces
	#return 'appstoreform-store-' . $val;
}

has 'getStore_code' => ( is => 'ro', lazy_build => 1 );
sub _build_getStore_code {
	my $self = shift;
	return 'Ext.StoreMgr.lookup("' . $self->storeId . '")';
}

has 'store_load_code' => ( is => 'ro', lazy_build => 1 );
sub _build_store_load_code {
	my $self = shift;
	return $self->getStore_code . '.load()';
}


has 'getForm_code' => ( is => 'ro', lazy_build => 1 );
sub _build_getForm_code {
	my $self = shift;
	return 'Ext.getCmp("' . $self->formpanel_id . '").getForm()';
}


has 'form_prerecord_code' => ( is => 'ro', default => '' );


has 'form_save_code' => ( is => 'ro', lazy_build => 1 );
sub _build_form_save_code {
	my $self = shift;
	return 
		'try {' .
			$self->form_prerecord_code .
			'var store = ' . $self->getStore_code . ';' .
			'var record = store.getAt(0);' .
			'var form = ' . $self->getForm_code . ';' .
			'record.beginEdit();' .
			'form.updateRecord(record);' .
			'record.endEdit();' . 
			'store.save();' .
		'} catch (err) { Ext.log(err); }';
}

has 'form_add_code' => ( is => 'ro', lazy_build => 1 );
sub _build_form_add_code {
	my $self = shift;
	return 
		'try {' .
			$self->form_prerecord_code .
			'var store = ' . $self->getStore_code . ';' .
			#'var record = new store.recordType();' .
			'var form = ' . $self->getForm_code . ';' .
			'var form_data = form.getFieldValues();' .
			'var store_fields = [];' .
			'for (i in form_data) {' .
				'store_fields.push({name: i});' .
			'}' .
			'var record_obj = Ext.data.Record.create(store_fields);' .
			'var record = new record_obj;' .
			'if (record) Ext.log("record created...");' .
			'record.beginEdit();' .
			'if (form.updateRecord(record)) Ext.log("record updated with form...");' .
			'record.endEdit();' . 
			'store.add(record);' .
			'store.save();' .
		'} catch (err) { Ext.log(err); }';
}

sub JsonStore {
	my $self = shift;
	
	my $config = {
		exception_callback 	=> $self->exception_callback,
		write_callback 		=> $self->write_callback,
		create_callback 		=> $self->create_callback,
		storeId => $self->storeId,
		autoLoad => \0,
		autoSave => \0,
		loadMask => \1,
		autoDestroy => \1,
		
		root => 'rows',
		idProperty => $self->item_key,
		messageProperty => 'msg',
		successProperty => 'success',
		totalProperty => 'results',
		
		
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
						'var Record = records[0];' .
						'if(!Record) return;' . 
						'form.loadRecord(Record);' .
						'store.setBaseParam("orig_params",Ext.util.JSON.encode(Record.data));' .
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
					'store.write_callback.apply(this,arguments);' .
				'}' 
			),
			add => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(store, batch, data) { ' .
					'Ext.log("add event");' . 
				'}' 
			),
			exception => RapidApp::JSONFunc->new( raw => 1, func => 
				'function(DataProxy, type, action, options, response, arg) { ' .
					'Ext.log("exception event -> action: " + action);' .
					'if (action == "update" || action == "create") {' .
						'var store = ' . $self->getStore_code . ';' .
						'store.rejectChanges();' .
						'store.exception_callback.apply(this,arguments);' .
					'}' .
				'}' 
			)
		}
	};
	
	$config->{writer} = RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonWriter',
		parm => {
			encode => \1,
			writeAllFields => \1
	}) if (defined $self->actions->{update} or defined $self->actions->{create});
	
	$config->{api}->{update} = $self->suburl('/update') if (defined $self->actions->{update});
	$config->{api}->{create} = $self->suburl('/create') if (defined $self->actions->{create});
	
	return RapidApp::JSONFunc->new( 
		func => 'new Ext.data.JsonStore',
		parm => $config
	);
}

sub read {
	my $self = shift;
	
	my $results = 0;
	my $fields = [];
	my $rows = [];

	if (defined $self->read_data_coderef) {
		$results = 1;
		my $record = $self->fetch_item;
		$fields = $self->hash_to_store_fields($record);
		$rows = [ $record ];
	}
	# If there is no read_data_coderef this will be an add-only StoreForm and we'll
	# return a store with no records.

	return {
		metaData => {
			fields => $fields,
			root => 'rows',
			idProperty => $self->item_key,
			messageProperty => 'msg',
			successProperty => 'success',
			totalProperty => 'results',
		},
		success => \1,
		results => $results,
		rows => $rows
	};
}


sub hash_to_store_fields {
	my $self = shift;
	my $h = shift;
	my $fields = [];
	foreach my $k (keys %$h) {
		push @$fields, { name => $k };
	}
	return $fields;
}




sub update {
	my $self = shift;
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
	
	if (defined $params->{orig_params}) {
		my $orig_params = $self->json->decode($params->{orig_params});
		delete $params->{orig_params};
		
		# merge orig_params, preserving real params that are set:
		foreach my $k (keys %$orig_params) {
			next if (defined $params->{$k});
			$params->{$k} = $orig_params->{$k};
		}
	}
	
	my $result = $self->update_data_coderef->($rows,$params);
	
	if (ref($result) and defined $result->{success} and defined $result->{msg}) {
		if ($result->{success}) {
			$result->{success} = \1;
		}
		else {
			$result->{success} = \0;
		}
		return $result;
	}

	
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
	
	my $params = $self->c->req->params;
	my $rows = $self->json->decode($params->{rows});
	delete $params->{rows};
		
	my $result = $self->create_data_coderef->($rows);
	
	# we don't actually care about the new record, so we simply give the store back
	# the row it gave to us. We have to make sure that pk (primary key) is set to 
	# something or else it will throw an error
	$rows->{$self->item_key} = 'dummy-key';
	
	# If the id of the new record was provided in the response, we'll use it:
	$rows = $result->{rows} if (ref($result) and defined $result->{rows} and defined $result->{rows}->{$self->item_key});
	
	
	if (ref($result) and defined $result->{success} and defined $result->{msg}) {
		$result->{rows} = $rows;
		if ($result->{success}) {
			$result->{success} = \1;
		}
		else {
			$result->{success} = \0;
		}
		return $result;
	}
	
	
	if ($result and not (ref($result) and $result->{success} == 0 )) {
		return {
			success => \1,
			msg => 'Create Succeeded',
			rows => $rows
		}
	}
	
	if(ref($result) eq 'HASH') {
		$result->{success} = \0;
		$result->{msg} = 'Create Failed' unless (defined $result->{msg});
		return $result;
	}
	
	return {
		success => \0,
		msg => 'Create Failed'
	};
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
					'var save_btn = Ext.getCmp("' . $self->save_button_id . '");' . 
					'if(save_btn) save_btn.enable();' .
					'var add_btn = Ext.getCmp("' . $self->add_button_id . '");' . 
					'if(add_btn) add_btn.enable();' .
				'} else {' .
					'var save_btn = Ext.getCmp("' . $self->save_button_id . '");' . 
					'if (save_btn && !save_btn.disabled) save_btn.disable();' .
					'var add_btn = Ext.getCmp("' . $self->add_button_id . '");' . 
					'if (add_btn && !add_btn.disabled) add_btn.disable();' .
				'}' .
			'}'
		),
		afterrender => RapidApp::JSONFunc->new( raw => 1, func =>
			'function(FormPanel) { ' .
				'new Ext.LoadMask(FormPanel.getEl(),{msg: "StoreForm Loading...", store: ' . $self->getStore_code . '});' .
				'try {' . $self->store_load_code . ';' . '} catch(err) { Ext.log(err); }' .
			'}'
		),
		%{ $self->formpanel_listeners }
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


has 'tbar_icon' => ( is => 'ro', default => undef );
has 'tbar_title' => ( is => 'ro', default => undef );
has 'formpanel_items' => ( is => 'ro', default => sub {[]} );
has 'formpanel_baseconfig' => ( is => 'ro', default => sub {{}} );

has 'formpanel_config' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_config {
	my $self = shift;
	
	my $base = $self->formpanel_baseconfig;
	
	my $config = {
		bodyCssClass 	=> 'panel-borders',
		id 				=> 'storeform-' . time,
		monitorValid 	=> \1,
		frame 			=> \1,
		autoScroll 		=> \1,
		tbar 				=> $self->formpanel_tbar,
		items 			=> $self->formpanel_items
	};
	
	foreach my $k (keys %$base) {
		$config->{$k} = $base->{$k};
	}
	
	return $config;
}

has 'formpanel_listeners' => ( is => 'ro', default => sub {{}} );




has 'tbar_title_text_cls' => ( is => 'ro', default => 'tbar-title-medium' );
has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_tbar {
	my $self = shift;
	
	my $items = [];
		
	push @$items, '<img src="' . $self->tbar_icon . '">' if (defined $self->tbar_icon);
	push @$items, '<div class="' . $self->tbar_title_text_cls . '">' . $self->tbar_title . '</div>' if (defined $self->tbar_title);
	
	push @$items, '->';
	
	push @$items, $self->add_button if (defined $self->create_data_coderef);
	push @$items, $self->reload_button if (defined $self->read_data_coderef and not defined $self->create_data_coderef);
	push @$items, '-' if (defined $self->read_data_coderef and defined $self->update_data_coderef);
	push @$items, $self->save_button if (defined $self->update_data_coderef);
	
	return {
		items => $items
	};
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;