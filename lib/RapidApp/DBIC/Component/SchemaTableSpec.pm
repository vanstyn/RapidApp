package RapidApp::DBIC::Component::SchemaTableSpec;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class::Schema');


# DBIx::Class Component: Applies TableSpec configs to the Result classes within a
# Schema

use RapidApp::Include qw(sugar perlutil);

sub apply_TableSpecs {
	my $self = shift;
	my %opt = @_;
	
	$opt{TableSpec_confs} = $opt{TableSpec_confs} || {};
	$opt{TableSpec_column_properties} = $opt{TableSpec_column_properties} || {};
	
	# Optional coderef to dynamically calculate the "open_url" and "open_url_multi"
	$opt{get_path_code} = $opt{get_path_code} || sub {
		my $Source = $_;
		my $module_name = lc('table_' . $Source->from);
		my $path = '/tablespec/' . $module_name;
	};
	
	$opt{set_conf_code} = $opt{set_conf_code} || sub {
		my $Source = $_;
		
		local $_ = $Source;
		my $path = $opt{get_path_code}->($Source);
		
		my ($disp) = ($Source->primary_columns,$Source->columns);
		
		my $table = $Source->from;
		
		my %conf = (
			title => $table,
			title_multi => $table . ' set',
			#iconCls => 'icon-page-white',
			#multiIconCls => 'icon-folder',
			display_column => $disp,
		);
		
		%conf = ( %conf,
			open_url => $path . "/item",
			open_url_multi => $path,
		) if ($path and $path ne '');
		
		$conf{priority_rel_columns} = $opt{priority_rel_columns} if ($opt{priority_rel_columns});
		
		return %conf;
	};
	
	foreach my $source ($self->sources) {
		my $Source = $self->source($source);
		my $class = $self->class($source);
		
		$class->load_components('+RapidApp::DBIC::Component::TableSpec');
		$class->apply_TableSpec;
		
		local $_ = $Source;
		$class->TableSpec_set_conf(
			$opt{set_conf_code}->($Source), # <-- conf returned by the dynamic 'set_conf_code' coderef
			%{ $opt{TableSpec_confs}->{$source} || {} }, # <-- (optional) static conf defined in the Schema class
			%{ $class->TableSpec_cnf } # <-- (optional) static conf defined in the Result class (highest priority)
		);

		my $col_props = $opt{TableSpec_column_properties}->{$source} or next;
		$class->TableSpec_set_conf('column_properties_ordered', %$col_props);
	}
}



1;__END__
