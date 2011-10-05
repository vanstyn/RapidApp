package RapidApp::DBIC::Component::TableSpec;
use base 'DBIx::Class';

# DBIx::Class Component: ties a RapidApp::TableSpec object to
# a Result class for use in configuring various modules that
# consume/use a DBIC Source

use RapidApp::Include qw(sugar perlutil);

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

__PACKAGE__->mk_classdata( 'TableSpec' );
__PACKAGE__->mk_classdata( 'TableSpec_rel_columns' );

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
	
	$self->TableSpec_rel_columns({});
}


sub TableSpec_add_columns_from_related {
	my $self = shift;
	my $rels = get_mixed_hash_args(@_);
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		$conf->{column_property_transforms}->{name} = sub { $rel . '_' . $_ };
		
		# If its a relationship column that will setup a combo:
		$conf->{column_property_transforms} = { %{$conf->{column_property_transforms}},
			key_col => sub { $rel . '_' . $_ },
			render_col => sub { $rel . '_' . $_ },
		};
		
		my $info = $self->relationship_info($rel) or next;
		
		# Make sure the related class is already loaded:
		eval 'use ' . $info->{class};
		
		my $TableSpec = $info->{class}->TableSpec->copy($conf) or next;
		
		my @added = $self->TableSpec->add_columns_from_TableSpec($TableSpec);
		foreach my $Column (@added) {
			$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
			push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
			
			# Add a new global_init_coderef entry if this column has one:
			rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } ) 
				if ($Column->rapidapp_init_coderef);
		}
	}
}


sub TableSpec_add_relationship_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my $rels = \%opt;
	
	foreach my $rel (keys %$rels) {
		my $conf = $rels->{$rel};
		$conf = {} unless (ref($conf) eq 'HASH');
		
		$conf = { %{ $self->TableSpec->default_column_properties }, %$conf } if ( $self->TableSpec->default_column_properties );
		
		die "displayField is required" unless (defined $conf->{displayField});
		
		$conf->{render_col} = $rel . '_' . $conf->{displayField} unless ($conf->{render_col});
		
		my $info = $self->relationship_info($rel) or die "Relationship '$rel' not found.";
		
		$conf->{foreign_col} = $self->get_foreign_column_from_cond($info->{cond});
		$conf->{valueField} = $conf->{foreign_col} unless (defined $conf->{valueField});
		$conf->{key_col} = $rel . '_' . $conf->{valueField};
		
		#Temporary/initial column setup:
		$self->TableSpec->add_columns({ name => $rel, %$conf });
		my $Column = $self->TableSpec->get_column($rel);
		
		#$self->TableSpec_rel_columns->{$rel} = [] unless ($self->TableSpec_rel_columns->{$rel});
		#push @{$self->TableSpec_rel_columns->{$rel}}, $Column->name;
		
		my $ResultClass = $self;
		
		$Column->rapidapp_init_coderef( sub {
			my $self = shift;
			
			my $rootModule = shift;
			$rootModule->apply_init_modules( tablespec => 'RapidApp::AppBase' ) 
				unless ( $rootModule->has_module('tablespec') );
			
			my $TableSpecModule = $rootModule->Module('tablespec');
			my $c = RapidApp::ScopedGlobals->get('catalystClass');
			my $Source = $c->model('DB')->source($info->{source});
			
			my $valueField = $self->get_property('valueField');
			my $displayField = $self->get_property('displayField');
			my $key_col = $self->get_property('key_col');
			my $render_col = $self->get_property('render_col');
			my $auto_editor_type = $self->get_property('auto_editor_type');
			
			my $column_params = {
				required_fetch_columns => [ 
					$key_col,
					$render_col
				],
				
				read_raw_munger => RapidApp::Handler->new( code => sub {
					my $rows = (shift)->{rows};
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						$row->{$self->name} = $row->{$key_col};
					}
				}),
				update_munger => RapidApp::Handler->new( code => sub {
					my $rows = shift;
					$rows = [ $rows ] unless (ref($rows) eq 'ARRAY');
					foreach my $row (@$rows) {
						if ($row->{$self->name}) {
							$row->{$key_col} = $row->{$self->name};
							delete $row->{$self->name};
						}
					}
				}),
				no_quick_search => \1,
				no_multifilter => \1
			};
			
			$column_params->{renderer} = jsfunc(
				'function(value, metaData, record, rowIndex, colIndex, store) {' .
					'return record.data["' . $render_col . '"];' .
				'}', $self->get_property('renderer')
			);
			
			if ($auto_editor_type eq 'combo') {
			
				my $module_name = $ResultClass->table . '_' . $self->name;
				$TableSpecModule->apply_init_modules(
					$module_name => {
						class	=> 'RapidApp::DbicAppCombo2',
						params	=> {
							valueField		=> $valueField,
							displayField	=> $displayField,
							name				=> $self->name,
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
			
			$self->set_properties({ %$column_params });
		});
		
		# This coderef gets called later, after the RapidApp
		# Root Module has been loaded.
		rapidapp_add_global_init_coderef( sub { $Column->call_rapidapp_init_coderef(@_) } );
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
