package RapidApp::AppGrid::EditItem;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppStoreForm';

use RapidApp::JSONFunc;
use Term::ANSIColor qw(:constants);

use Try::Tiny;

has 'no_persist'				=> ( is => 'rw', default => 1 );
has 'reload_on_save'			=> ( is => 'ro', default => 1 );


has 'write_callback_code'	=> ( is => 'ro', lazy_build => 1 );
sub _build_write_callback_code {
	my $self = shift;
	return $self->parent_module->reload_store_eval . ';';
}


has 'read_data_coderef' => ( is => 'ro', lazy_build => 1 );
sub _build_read_data_coderef {
	my $self = shift;
	return sub {
		my $params = shift; 
		
		
		use Data::Dumper;
		$self->c->log->is_debug and
			$self->c->log->debug(Dumper($params));
		
		return $self->parent_module->itemfetch_coderef->($params);
	};
}
  

has 'update_data_coderef' => ( is => 'ro', lazy_build => 1 );
sub _build_update_data_coderef {
	my $self = shift;
	return sub {
		my $params = shift;
		my $orig_params = shift;

		my $h = {};

		try {
		
			my $hash = $self->parent_module->edit_item_coderef->($self->process_submit_params($params),$orig_params);
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
	};
}




################################################################
################################################################

#has 'formpanel_tbar' => ( is => 'ro', lazy_build => 1 );
#sub _build_formpanel_tbar {
#	my $self = shift;
#	return [
#		'->',
#		$self->reload_button, 
#		$self->save_button
#	];
#}
#
#has 'formpanel_config' => ( is => 'ro', lazy_build => 1 );
#sub _build_formpanel_config {
#	my $self = shift;
#	return {
#		bodyStyle => 'padding:5px 5px 0',
#		labelAlign	=> 'left',
#		anchor => '95%',
#		autoWidth => \1,
#		id => 'tab-' . time,
#		monitorValid => \1,
#		frame => \1,
#		autoScroll => \1,
#		tbar => $self->formpanel_tbar,
#		items => $self->form_fields
#	};
#}


#has 'tbar_icon' => ( is => 'ro', default => '/static/images/form_green_32x32.png' );
#has 'tbar_title' => ( is => 'ro', default => 'ADD NEW PROJECT (GREEN SHEET)' );

has 'formpanel_baseconfig' => ( is => 'ro', default => sub { 
	return {
		labelAlign	=> 'left',
		labelWidth 	=> 120,
		defaults => {
			labelStyle	=> 'text-align:right;',
			xtype 		=> 'textfield',
		}
	};
});



has 'formpanel_items' => ( is => 'ro', lazy_build => 1 );
sub _build_formpanel_items {
	my $self = shift;
	 
	 return $self->parent_module->custom_edit_form_items if (defined $self->parent_module->custom_edit_form_items);
	 
	 my @list = ();
	 
	 push @list, { 'height' => 20, 'xtype' => 'spacer' };

	foreach my $field (@{$self->parent_module->fields}) {
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
		
#		unless (defined $new_field->{viewable} and not $new_field->{viewable}) {
#			$new_field->{value} = $params->{$new_field->{name}} if (
#				defined $params->{$new_field->{name}} and
#				not $self->edit_form_ajax_load
#			);
#		}
		
		$self->set_field_combo($new_field) if (
			defined $new_field->{enum_list} and 
			ref($new_field->{enum_list}) eq 'ARRAY'
		);
	
		$self->set_field_checkbox($new_field) if ($new_field->{checkbox});
		
#		if ($new_field->{checktree} and defined $params->{$new_field->{name}}) {
#			my $newer_field = $self->set_field_checktree($new_field,$params->{$new_field->{name}});
#			$new_field = $newer_field;
#		}
		
		push @list, $new_field;
	}
	unshift @list, { 'height' => 15, 'xtype' => 'spacer' };
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
