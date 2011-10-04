package RapidApp::DBIC::Component::TableSpec;
use base 'DBIx::Class';

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

__PACKAGE__->mk_classdata( 'TableSpec' );

sub apply_TableSpec {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	$self->TableSpec(RapidApp::TableSpec->new( 
		name => $self->table,
		%opt
	));
	
	foreach my $col ($self->columns) {
		$self->TableSpec->add_columns( { name => $col } ); 
	}
}


sub TableSpec_add_columns_from_related {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		$conf->{column_property_transforms}->{name} = sub { $rel . '_' . $_ };
	
		my $info = $self->relationship_info($rel) or next;
		my $TableSpec = $info->{class}->TableSpec->copy($conf) or next;
		
		$self->TableSpec->add_columns_from_TableSpec($TableSpec);
	}
}


sub TableSpec_add_relationship_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		die "displayField is required" unless (defined $conf->{displayField});
		
		$conf->{render_col} = $rel . '_' . $conf->{displayField} unless ($conf->{render_col});
		
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		my $foreign_col = $self->get_foreign_column_from_cond($info->{cond});
		$conf->{valueField} = $foreign_col unless (defined $conf->{valueField});
		
		my $key_col = $rel . '_' . $conf->{valueField};
		
		my $valueField = delete $conf->{valueField};
		my $displayField = delete $conf->{displayField};
		my $render_col = delete $conf->{render_col};
		my $auto_editor_type = delete $conf->{auto_editor_type};
		
		# This coderef gets called later, after the RapidApp
		# Root Module has been loaded.
		rapidapp_add_global_init_coderef( sub { 
			my $rootModule = shift;
			$rootModule->apply_init_modules( tablespec => 'RapidApp::AppBase' ) 
				unless ( $rootModule->has_module('tablespec') );
			
			my $TableSpecModule = $rootModule->Module('tablespec');
			my $c = RapidApp::ScopedGlobals->get('catalystClass');
			my $Source = $c->model('DB')->source($info->{source});
			
			my $column_params = {
				name => $rel,
				required_fetch_columns => [ $key_col,$render_col ],
				
				read_raw_munger => RapidApp::Handler->new( code => sub {
					my $rows = (shift)->{rows};
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						$row->{$rel} = $row->{$key_col};
					}
				}),
				update_munger => RapidApp::Handler->new( code => sub {
					my $rows = shift;
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						if ($row->{$rel}) {
							$row->{$key_col} = $row->{$rel};
							delete $row->{$rel};
						}
					}
				}),
				no_quick_search => \1,
				no_multifilter => \1
			};
			
			$conf->{renderer} = jsfunc(
				'function(value, metaData, record, rowIndex, colIndex, store) {' .
					'return record.data["' . $render_col . '"];' .
				'}', $conf->{renderer}
			);
			
			if ($auto_editor_type eq 'combo') {
			
				my $module_name = $self->table . '_' . $rel;
				$TableSpecModule->apply_init_modules(
					$module_name => {
						class	=> 'RapidApp::DbicAppCombo2',
						params	=> {
							valueField		=> $valueField,
							displayField	=> $displayField,
							name				=> $rel,
							ResultSet		=> $Source->resultset,
						}
					}
				);
				my $Module = $TableSpecModule->Module($module_name);
				
				# -- vv -- This is required in order to get all of the params applied
				$Module->call_ONREQUEST_handlers;
				$Module->DataStore->call_ONREQUEST_handlers;
				# -- ^^ --
				
				$column_params->{editor} = $Module->content;
			}
			
			$self->TableSpec->add_columns({ %$column_params, %$conf });
			
		});	
	}
}



sub TableSpec_setup_editor_dropdowns {
	my $self = shift;
	foreach my $colspec (@_) { 
	
		my $colname = $colspec;
		$colname =~ s/\./\_/g;
		
		my $Column = $self->TableSpec->get_column($colname);
	
		my ($rel,$col) = split(/\./,$colspec,2);
		
		die "Invalid colspec '$colspec'" unless ($col);
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		#scream($info);
		
		my $foreign_col = $self->get_foreign_column_from_cond($info->{cond});
		
		# This coderef gets called later, after the RapidApp
		# Root Module has been loaded.
		rapidapp_add_global_init_coderef( sub { 
			my $rootModule = shift;
			$rootModule->apply_init_modules( tablespec => 'RapidApp::AppBase' ) 
				unless ( $rootModule->has_module('tablespec') );
			
			my $TableSpecModule = $rootModule->Module('tablespec');

			my $c = RapidApp::ScopedGlobals->get('catalystClass');
			
			my $Source = $c->model('DB')->source($info->{source});
			
			
			my $module_name = $self->table . '_' . $colname;
			$TableSpecModule->apply_init_modules(
				$module_name => {
					class	=> 'RapidApp::DbicAppCombo2',
					params	=> {
						valueField		=> ($Source->primary_columns)[0],
						displayField	=> $col,
						name				=> $colname,
						ResultSet		=> $Source->resultset,
					}
				}
			);
			my $Module = $TableSpecModule->Module($module_name);
			
			# -- vv -- This is required in order to get all of the params applied
			$Module->call_ONREQUEST_handlers;
			$Module->DataStore->call_ONREQUEST_handlers;
			# -- ^^ --
			
			my $editor = $Module->content;
			
			#scream_color(GREEN . BOLD,$editor);
			
			$Column->set_properties( editor => $editor );
		
		});	
	}
}

# TODO: Find a better way to handle this. Is there a real API
# in DBIC to find this information?
sub get_foreign_column_from_cond {
	my $self = shift;
	my $cond = shift;
	
	die "currently only single-key hashref conditions are supported" unless (
		ref($cond) eq 'HASH' and
		scalar keys %$cond == 1
	);
	
	foreach my $i (%$cond) {
		my ($side,$col) = split(/\./,$i);
		return $col if (defined $col and $side eq 'foreign');
	}
	
	die "Failed to find forein column from condition: " . Dumper($cond);
}



1;
