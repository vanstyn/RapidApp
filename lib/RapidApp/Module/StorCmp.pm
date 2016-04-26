package RapidApp::Module::StorCmp;

# ABSTRACT: Base class for modules with a Ext.data.Store

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::ExtComponent';

use RapidApp::Util qw(:all);
use Clone qw(clone);

use RapidApp::Module::DatStor;

has 'no_datastore_plus_plugin', is => 'ro', isa => 'Bool', lazy => 1, default => 0;

has 'TableSpec' => ( is => 'ro', isa => 'Maybe[RapidApp::TableSpec]', lazy_build => 1 );
sub _build_TableSpec { undef; }

has 'TableSpec_applied' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'record_pk'			=> ( is => 'ro', default => 'id' );
has 'DataStore_class'	=> ( is => 'ro', default => 'RapidApp::Module::DatStor' );

has 'max_pagesize'		=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );

has 'persist_all_immediately' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'persist_immediately' => ( is => 'ro', isa => 'HashRef', default => sub{{
	create	=> \0,
	update	=> \0,
	destroy	=> \0
}});

# New option added in GitHub Issue #85
has 'dedicated_add_form_enabled', is => 'ro', isa => 'Bool', default => 1;

# use_add_form/use_edit_form: 'tab', 'window' or undef
has 'use_add_form', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => undef;
has 'use_edit_form', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => undef;
has 'autoload_added_record', default => sub {
  my $self = shift;
  # Default to the same value as 'use_add_form'
  return $self->use_add_form ? 1 : 0;
}, is => 'ro', isa => 'Bool', lazy => 1;

has 'allow_batch_update', is => 'ro', isa => 'Bool', default => 1;
has 'batch_update_max_rows', is => 'ro', isa => 'Int', default => 500;
has 'confirm_on_destroy', is => 'ro', isa => 'Bool', default => 1;

# not implimented yet:
#has 'batch_update_warn_rows', is => 'ro', isa => 'Int', default => 100;

# If cache_total_count is true the total count query will be skipped and the value supplied
# by the client (if defined) will be returned instead. The code and logic to do the actual
# caching is in JavaScript, and utilization of this feature currently is only implemented
# within DbicLink2:
has 'cache_total_count', is => 'ro', isa => 'Bool', default => 1;

has 'DataStore' => (
	is			=> 'rw',
	isa		=> 'RapidApp::Module::DatStor',
	handles => {
		JsonStore								=> 'JsonStore',
#		store_read							=> 'store_read',
#		store_read_raw					=> 'store_read_raw',
		columns									=> 'columns',
		column_order						=> 'column_order',
		multisort_enabled				=> 'multisort_enabled',
		sorters									=> 'sorters',
		include_columns					=> 'include_columns',
		exclude_columns					=> 'exclude_columns',
		include_columns_hash		=> 'include_columns_hash',
		exclude_columns_hash		=> 'exclude_columns_hash',
		apply_columns						=> 'apply_columns',
		column_list							=> 'column_list',
		apply_to_all_columns		=> 'apply_to_all_columns',
		applyIf_to_all_columns	=> 'applyIf_to_all_columns',
		apply_columns_list			=> 'apply_columns_list',
		set_sort								=> 'set_sort',
		batch_apply_opts				=> 'batch_apply_opts',
		set_columns_order				=> 'set_columns_order',
#		record_pk								=> 'record_pk',
		getStore								=> 'getStore',
		getStore_code						=> 'getStore_code',
		getStore_func						=> 'getStore_func',
		store_load_code					=> 'store_load_code',
		store_listeners					=> 'listeners',
		apply_store_listeners		=> 'apply_listeners',
		apply_store_config			=> 'apply_extconfig',
		valid_colname						=> 'valid_colname',
		apply_columns_ordered		=> 'apply_columns_ordered',
		batch_apply_opts_existing => 'batch_apply_opts_existing',
		delete_columns					=> 'delete_columns',
		has_column							=> 'has_column',
		get_column							=> 'get_column',
		deleted_column_names		=> 'deleted_column_names',
		column_name_list				=> 'column_name_list',
		get_columns_wildcards		=> 'get_columns_wildcards',
		apply_coderef_columns 	=> 'apply_coderef_columns'
		
	}
);


has 'DataStore_build_params' => ( is => 'ro', default => undef, isa => 'Maybe[HashRef]' );

has 'defer_to_store_module' => ( is => 'ro', isa => 'Maybe[Object]', lazy => 1, default => undef ); 

around 'columns' => \&defer_store_around_modifier;
around 'column_order' => \&defer_store_around_modifier;
around 'has_column' => \&defer_store_around_modifier;
around 'get_column' => \&defer_store_around_modifier;

sub defer_store_around_modifier {
	my $orig = shift;
	my $self = shift;
	return $self->$orig(@_) unless (defined $self->defer_to_store_module);
	return $self->defer_to_store_module->$orig(@_);
}


# We are doing it this way so we can hook into this exact spot with method modifiers in other places:
sub BUILD {}
before 'BUILD' => sub { (shift)->DataStore2_BUILD };
sub DataStore2_BUILD {
	my $self = shift;
  
  # New for #85:
  $self->apply_actions( add => 'dedicated_add_form' ) if ($self->dedicated_add_form_enabled);
	
	my $store_params = { 
		record_pk 		=> $self->record_pk,
		max_pagesize	=> $self->max_pagesize
	};
	
	if ($self->can('create_records')) {
		$self->apply_flags( can_create => 1 ) unless ($self->flag_defined('can_create'));
		$store_params->{create_handler}	= RapidApp::Handler->new( scope => $self, method => 'create_records' ) if ($self->has_flag('can_create'));
	}
	
	if ($self->can('read_records')) {
		$self->apply_flags( can_read => 1 ) unless ($self->flag_defined('can_read'));
		$store_params->{read_handler}	= RapidApp::Handler->new( scope => $self, method => 'read_records' ) if ($self->has_flag('can_read'));
	}
	
	if ($self->can('update_records')) {
		$self->apply_flags( can_update => 1 ) unless ($self->flag_defined('can_update'));
		$store_params->{update_handler}	= RapidApp::Handler->new( scope => $self, method => 'update_records' ) if ($self->has_flag('can_update'));
	}
	
	if ($self->can('destroy_records')) {
		$self->apply_flags( can_destroy => 1 ) unless ($self->flag_defined('can_destroy'));
		$store_params->{destroy_handler}	= RapidApp::Handler->new( scope => $self, method => 'destroy_records' ) if ($self->has_flag('can_destroy'));
	}
	
	$store_params = {
		%$store_params,
		%{ $self->DataStore_build_params }
	} if (defined $self->DataStore_build_params);
	
	$self->apply_modules( store => {
		class		=> $self->DataStore_class,
		params	=> $store_params
	});
	$self->DataStore($self->Module('store',1));
	
	#init the store with all of our flags:
	$self->DataStore->apply_flags($self->all_flags);
	
	$self->add_ONREQUEST_calls('store_init_onrequest');
	$self->add_ONREQUEST_calls_late('apply_store_to_extconfig');
	
	# Init (but don't apply) TableSpec early
	$self->TableSpec;
}


after 'BUILD' => sub {
	my $self = shift;

	$self->apply_extconfig(
		persist_all_immediately => \scalar($self->persist_all_immediately),
		persist_immediately => $self->persist_immediately,
    use_add_form => $self->use_add_form,
    use_edit_form => $self->use_edit_form,
    autoload_added_record => $self->autoload_added_record ? \1 : \0,
		cache_total_count => $self->cache_total_count ? \1 : \0,
		confirm_on_destroy => $self->confirm_on_destroy ? \1 : \0
	);
	
	## Apply the TableSpec if its defined ##
	$self->apply_TableSpec_config;
	
	if(defined $self->Module('store',1)->create_handler) {
		$self->apply_actions( add_form => 'get_add_form' );
		$self->apply_extconfig( add_form_url => $self->suburl('add_form') );
	}
	
	if($self->allow_batch_update && defined $self->Module('store',1)->update_handler) {
		$self->apply_actions( edit_form => 'get_edit_form' );
		$self->apply_extconfig( edit_form_url => $self->suburl('edit_form') );
		
		$self->apply_actions( batch_update => 'batch_update' );
		$self->apply_extconfig( batch_update_url => $self->suburl('batch_update') );
	}
	
	$self->add_plugin( 'datastore-plus' ) unless ($self->no_datastore_plus_plugin);
};


sub apply_TableSpec_config {
	my $self = shift;
	$self->TableSpec or return;
	$self->TableSpec_applied and return;
	
	my $prop_names = [ @RapidApp::Module::DatStor::Column::attrs ];
	my $columns = $self->TableSpec->columns_properties_limited($prop_names);
	
	$self->apply_columns($columns);
	$self->set_columns_order(0,$self->TableSpec->column_names_ordered);
	
	$self->DataStore->add_onrequest_columns_mungers(
		$self->TableSpec->all_onrequest_columns_mungers
	) unless ($self->TableSpec->has_no_onrequest_columns_mungers);
	
	$self->TableSpec_applied(1);
}


sub defer_DataStore {
	my $self = shift;
	return $self->DataStore unless (defined $self->defer_to_store_module);
	return $self->defer_to_store_module->defer_DataStore if ($self->defer_to_store_module->can('defer_DataStore'));
	return $self->defer_to_store_module;
}

sub store_init_onrequest {
	my $self = shift;
	
	# Simulate direct ONREQUEST:
	$self->Module('store');
	
	$self->apply_extconfig( columns => $self->defer_DataStore->column_list );
	$self->apply_extconfig( sort => $self->defer_DataStore->get_extconfig_param('sort_spec') );
}


# ----
# NEW: use Tie::IxHash to setup the extconfig hash to be ordered with the 'store'
# key predeclared as the first key. Because the ExtJS client decodes and processes
# JSON in order, we want to make sure the store is processed before other parts
# which may need to reference it by storeId. This is needed after perl 5.18 because
# the order of hashes was changed in that version. We just happened to be lucky
# that the order before 5.18 just happened to have the store key showup earlier
# than we happened to be using it. After 5.18, its random. This solves the problem
# once and for all. (Note: the case where this was a problem was in cases of
# several nested modules maing use of defer_to_store_module feature which is not
# a common use-case, so this was only an issue for very specific circumstances)
has '+extconfig', default => sub {
  use Tie::IxHash;
  my %cfg;
  tie(%cfg, 'Tie::IxHash', store => undef );
  return \%cfg
};
# ----

sub apply_store_to_extconfig {
	my $self = shift;
	
	if (defined $self->defer_to_store_module) {
		$self->apply_extconfig( store => $self->defer_DataStore->getStore_func );
	}
	else {
		$self->apply_extconfig( store => $self->Module('store')->JsonStore );
	}
}


has 'add_edit_formpanel_defaults', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {{
	xtype => 'form',
	frame => \1,
	labelAlign => 'right',
	labelWidth => 100,
	plugins => ['dynamic-label-width'],
	bodyStyle => 'padding: 25px 10px 5px 5px;',
  cls => 'ra-datastore-add-edit-form',
	defaults => {
		width => 250
	},
	autoScroll => \1,
	monitorValid => \1,
	buttonAlign => 'center',
	minButtonWidth => 100,
	
	# datastore-plus (client side) adds handlers based on the "name" properties 'save' and 'cancel' below
	buttons => [
		{
			name => 'save',
			text => 'Save',
			iconCls => 'ra-icon-save-ok',
			formBind => \1
		},
		{
			name => 'cancel',
			text => 'Cancel',
		}
	]
}};

sub get_add_edit_form_items {
	my $self = shift;
	my $mode = shift;
	die '$mode should be "add" or "edit"' unless ($mode eq 'add' || $mode eq 'edit');
	
	my $allow_flag = "allow_$mode";
	
	my @items = ();
	
	foreach my $colname (@{$self->column_order}) {
		my $Cnf = $self->columns->{$colname} or next;
		next unless (defined $Cnf->{editor} and $Cnf->{editor} ne '');
		
		my $allow = jstrue($Cnf->{$allow_flag});
		$allow = $allow || jstrue($Cnf->{allow_batchedit}) if (
			$mode eq 'edit' && 
			!jstrue($Cnf->{no_column})
		);
		
		#Skip columns with 'no_column' set to true except if $allow_flag is true:
		next if (jstrue($Cnf->{no_column}) && ! $allow);
		
		#Skip if $allow_flag is defined but set to false:
		next if (defined $Cnf->{$allow_flag} && ! $allow);
		
		my $field = clone($Cnf->{editor});
		$field->{name} = $colname;
		$field->{allowBlank} = \1 unless (defined $field->{allowBlank});
    
    # New, extra check for newly added 'is_nullable' column attr (Github Issue #33)
    $field->{allowBlank} = \0 unless ($Cnf->{is_nullable});
    
		unless (jstrue $field->{allowBlank}) {
			$field->{labelStyle} = '' unless (defined $field->{labelStyle});
			$field->{labelStyle} .= 'font-weight:bold;';
		}
		$field->{header} = $Cnf->{header} if(defined $Cnf->{header});
		$field->{header} = $colname unless (defined $field->{header} and $field->{header} ne '');
		$field->{fieldLabel} = $field->{header};
    $field->{anchor} = '-20';
    
    # ---- Moved from DataStorePlus JS (client-side):
    # Important: autoDestroy must be false on the store or else store-driven
    # components (i.e. combos) will be broken as soon as the form is closed 
    # the first time
    $field->{store}{autoDestroy} = \1 if ($field->{store});
    
    # Make sure that hidden fields that can't be changed don't 
    # block validation of the form if they are empty and erroneously
    # set with allowBlank: false (common-sense failsafe):
    $field->{allowBlank} = \1 if (jstrue $field->{hidden});
    # ----
    
    # -- New: if column 'documentation' is present, render it via Ext.ux.FieldHelp plugin
    if($Cnf->{documentation}) {
      $field->{plugins} ||= [];
      push @{$field->{plugins}}, 'fieldhelp';
      $field->{helpText} = $Cnf->{documentation};
    }
    # --
		
		push @items, $field;
	}
	
	return @items;
}

sub get_add_form {
	my $self = shift;
	return {
		%{$self->add_edit_formpanel_defaults},
		items => [ $self->get_add_form_items ]
	};
}

sub get_add_form_items {
	my $self = shift;
	return $self->get_add_edit_form_items('add');
}

sub get_edit_form {
	my $self = shift;
	return {
		%{$self->add_edit_formpanel_defaults},
		items => [ $self->get_edit_form_items ]
	};
}

sub get_edit_form_items {
	my $self = shift;
	return $self->get_add_edit_form_items('edit');
}



sub before_batch_update {
	my $self = shift;
	my $editSpec = $self->param_decodeIf($self->c->req->params->{editSpec});
	my $update = $editSpec->{update};
	
	die usererr "Invalid editSpec - record_pk found in update data!!" 
		if (exists $update->{$self->record_pk});
	
	my $count = $editSpec->{count} or die usererr "Invalid editSpec - no count supplied";
	
	my $max = $self->batch_update_max_rows;
	
	die usererr 
		"Too many rows for batch update ($count) - max allowed rows: $max",
		title => "Batch Update Denied"
	if($max && $count > $max);
};

# This is expensive, but compatible with the generic DataStore2 (update) API.
# Should be overridden in more specific derived classes, like in DbicLink2, to
# perform a smarter/more efficient operation
sub batch_update {
	my $self = shift;
	
	# this is called directly instead of adding a method modifier because a modifier
	# would not get called when batch_update is overridden by another Role (such as in
	# DbicLink2)
	$self->before_batch_update;
	
	my $editSpec = $self->param_decodeIf($self->c->req->params->{editSpec});
	my $read_params = $editSpec->{read_params};
	my $update = $editSpec->{update};
	
	delete $read_params->{start};
	delete $read_params->{limit};
	
	# perform a read to verify that totalCount matches the supplied/expected count
	my %orig_params = %{$self->c->req->params};
	%{$self->c->req->params} = %$read_params;
	my $readdata = $self->read_records();
	my $rows = $readdata->{rows};
	
	die "Actual row count (" . @$rows . ") doesn't agree with 'results' property (" . $readdata->{results} . ")"
		unless (@$rows == $readdata->{results});
	
	die usererr "Update count mismatch (" . 
		$editSpec->{count} . ' vs ' . $readdata->{results} . ') ' .
		"- This can happen if someone else modified one or more of the records in the update set.\n\n" .
		"Reload the the grid and try again."
	unless ($editSpec->{count} == $readdata->{results});
	
	# apply update data to rows:
	%$_ = (%$_,%$update) for (@$rows);
	
	my $result;
	{
		local $RapidApp::Module::DatStor::BATCH_UPDATE_IN_PROGRESS = 1;
		$result = $self->DataStore->update_handler->call($rows,$read_params);
	}
	
	%{$self->c->req->params} = %orig_params;
	
	return $result if (
		ref($result) eq 'HASH' and
		defined $result->{success}
	);
	
	return {
		success => \1,
		msg => 'Batch Update Succeeded'
	} if ($result);
	
	die "Update Failed";
}


sub param_decodeIf {
	my $self = shift;
	my $param = shift;
	my $default = shift || undef;
	
	return $default unless (defined $param);
	
	return $param if (ref $param);
	return $self->json->decode($param);
}


# New for #85:
sub dedicated_add_form {
  my $self = shift;
  die "Not allowed" unless $self->dedicated_add_form_enabled;
  
  my $c = $self->c;
  my $content = $self->content;
  
  # Just in case custom add_form_url_params are configured, merge them into the current
  # request params so they are available as they would be if called via Ajax...
  my $afuParams = $self->get_extconfig_param('add_form_url_params') || {};
  %{$c->req->params} = ( %{$c->req->params}, %$afuParams );
  
  my $fp = $self->get_add_form;
  
  my $btnCfg = ($self->get_extconfig_param('store_button_cnf')||{})->{add} || {};
  
  return $self->render_data({
    xtype      => 'datastore-dedicated-add-form',
    
    source_cmp => $content,
    formpanel  => $fp,
    
    tabTitle   => $btnCfg->{text}    || '(Add ...)',
    tabIconCls => $btnCfg->{iconCls} || 'ra-icon-add'
    
  });
}
  


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;

