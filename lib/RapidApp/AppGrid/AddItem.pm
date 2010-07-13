package RapidApp::AppGrid::AddItem;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppStoreForm';

use RapidApp::JSONFunc;
use Term::ANSIColor qw(:constants);

use Try::Tiny;

has 'no_persist'				=> ( is => 'rw', default => 1 );
has 'reload_on_save'			=> ( is => 'ro', default => 0 );

has 'create_record_msg'	=> ( is => 'ro', lazy_build => 1 );
sub _build_create_record_msg {
	my $self = shift;
	$self->parent_module->item_title . ' added';
}


has 'create_callback_code'	=> ( is => 'ro', lazy_build => 1 );
sub _build_create_callback_code {
	my $self = shift;
	#return 'var activePanel = tabPanelLayout.getActiveTab(); Layout.closeTab(activePanel); ';
	return 
		'var panel = Ext.getCmp("' . $self->formpanel_id . '");' . 
		'var tp = panel.findParentByType("tabpanel");' . 
		'var tab = tp.getActiveTab();' .
		'tp.remove(tab);';
}

has 'write_callback_code'	=> ( is => 'ro', lazy_build => 1 );
sub _build_write_callback_code {
	my $self = shift;
	return $self->parent_module->reload_store_eval . ';';
}




has 'create_data_coderef' => ( is => 'ro', lazy_build => 1 );
sub _build_create_data_coderef {
	my $self = shift;
	return sub {
		my $params = shift;

		my $h = {};

		try {
			my $hash = $self->parent_module->add_item_coderef->($self->process_submit_params($params));
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
	};
}




################################################################
################################################################


has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_tbar {
	my $self = shift;
	return [
		'->',
		$self->add_button
	];
}

has 'formpanel_config' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_config {
	my $self = shift;
	return {
		bodyStyle => 'padding:5px 5px 0',
		labelAlign	=> 'left',
		anchor => '95%',
		autoWidth => \1,
		id => 'tab-' . time,
		monitorValid => \1,
		frame => \1,
		autoScroll => \1,
		tbar => $self->formpanel_tbar,
		items => $self->form_fields
	};
}




sub form_fields {
	my $self = shift;
	 
	 return $self->parent_module->custom_add_form_items if (defined $self->parent_module->custom_add_form_items);
	 
	 my @list = ();

	foreach my $field (@{$self->parent_module->fields}) {
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

	return \@list;
	 
}


sub process_submit_params {
	my $self = shift;
	my $params = shift;
	
	foreach my $k (keys %{$params}) {
		if (defined $self->parent_module->fields_hash->{$k} and $self->parent_module->fields_hash->{$k}->{checkbox}) {
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



######## "set field" methods ##########
sub set_field_heading {
	my $self = shift;
	return $self->parent_module->set_field_heading(@_);
}

sub set_field_checktree {
	my $self = shift;
	return $self->parent_module->set_field_checktree(@_);
}

sub set_field_combo {
	my $self = shift;
	return $self->parent_module->set_field_combo(@_);
}

sub set_field_checkbox {
	my $self = shift;
	return $self->parent_module->set_field_checkbox(@_);
}

sub displayfield {
	my $self = shift;
	return $self->parent_module->displayfield(@_);
}
######################################



1;
