package RapidApp::DBIC::Component::VirtualColumnsExt;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class');

use RapidApp::Include qw(sugar perlutil);

# Load the vanilla/original DBIx::Class::VirtualColumns component:
__PACKAGE__->load_components('+RapidApp::DBIC::Component::VirtualColumns');

__PACKAGE__->mk_classdata( '_virtual_columns_order' );

sub init_vcols_class_data {
	my $self = shift;
	
	$self->_virtual_columns( {} )
        unless defined $self->_virtual_columns();
     
    $self->_virtual_columns_order( [] )
        unless defined $self->_virtual_columns_order();
}

# extend add_virtual_columns to also track column order
sub add_virtual_columns {
	my $self = shift;
    my @columns = @_;
	
	$self->init_vcols_class_data;
	
	foreach my $column (@columns) {
		next if (
			ref $column or
			$self->has_column($column) or 
			exists $self->_virtual_columns->{$column} #<-- redundant since we override 'has_column'
		);
		
		push @{$self->_virtual_columns_order}, $column;
	}
	
	return $self->next::method(@_);
}

sub virtual_columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return @{$self->_virtual_columns_order};
}

# Take-over has_column to include virtual columns
sub has_column {
    my $self = shift;
    my $column = shift;
	$self->init_vcols_class_data;
    return ($self->_virtual_columns->{$column} ||
        $self->next::method($column)) ? 1:0;
}

# Take-over columns to include virtual columns:
sub columns {
	my $self = shift;
	$self->init_vcols_class_data;
	return ($self->next::method(@_),$self->virtual_columns);
}

#TODO: init_virtual_column_value via get_columns, too
sub get_column {
    my ($self, $column) = @_;

    return $self->next::method($column) unless (
		defined $self->_virtual_columns &&
        exists $self->_virtual_columns->{$column}
	);
	
	$self->init_virtual_column_value($column);
	
	return $self->next::method($column);
}


sub init_virtual_column_value {
	my ($self, $column) = @_;
	return if (exists $self->{_virtual_values}{$column});
	my $sql = try{$self->column_info($column)->{sql}} or return;
	
	my $rel = 'me';
	$sql =~ s/self\./${rel}\./g;
	$sql =~ s/\`self\`\./\`${rel}\`\./g; #<-- also support backtic quoted form (quote_sep)
	
	my $Source = $self->result_source;
	my $cond = { map { $rel . '.' . $_ => $self->get_column($_) } $Source->primary_columns };
	
	my $row = $Source->resultset->search_rs($cond,{
		select => [{ '' => \"($sql)", -as => $col }],
		as => [$column],
		result_class => 'DBIx::Class::ResultClass::HashRefInflator'
	})->first or return undef;
	
	return $self->store_column($column,$row->{$column});
}


1;
