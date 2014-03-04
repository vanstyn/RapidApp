package RapidApp::DBIC::Component::SchemaTableSpec;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class::Schema');


# DBIx::Class Component: Applies TableSpec configs to the Result classes within a
# Schema -- DEPRECATED - do not use

use RapidApp::Include qw(sugar perlutil);

sub apply_TableSpecs {
	my $self = shift;
	my %opt = @_;
	
	$opt{TableSpec_confs} = $opt{TableSpec_confs} || {};
	$opt{TableSpec_column_properties} = $opt{TableSpec_column_properties} || {};
	
	# Optional coderef to dynamically calculate the "open_url" and "open_url_multi"
	$opt{get_path_code} = $opt{get_path_code} || sub {
		my $Source = $_;
		my $from = $Source->from;
		$from = (split(/\./,$from,2))[1] || $from; #<-- get 'table' for both 'db.table' and 'table' format
		my $module_name = lc('table_' . $from);
		my $path = '/tablespec/' . $module_name;
	};
	
	$opt{set_conf_code} = $opt{set_conf_code} || sub {
		my $Source = $_;
		
		local $_ = $Source;
		my $path = $opt{get_path_code}->($Source);
		
		my ($disp) = ($Source->primary_columns,$Source->columns);
		
		my $from = $Source->from;
		$from = (split(/\./,$from,2))[1] || $from; #<-- get 'table' for both 'db.table' and 'table' format
		my $table = $from;
		
		my %conf = (
			title => $table,
			title_multi => $table . ' set',
			#iconCls => 'ra-icon-page-white',
			#multiIconCls => 'ra-icon-folder',
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
		);
    
    my $col_props = $opt{TableSpec_column_properties}{$source} || {};
    
    if($opt{auto_headers}) {
      $col_props->{$_}{header} ||= $_ for ($class->TableSpec_valid_db_columns);
    }
    
    $class->TableSpec_merge_columns_conf($col_props);
  }
}



1;__END__
